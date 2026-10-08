;;;; check-links.lisp -- checks the relative links and #anchors in the Markdown files.
;;;;
;;;; Ported from ArcDocDB tools/check-links.lisp, with these differences: anchors inside the
;;;; same file are checked too; links in fenced code blocks and inline code are ignored;
;;;; link targets may be <angle bracketed>, carry a "title", contain balanced parentheses
;;;; or %20 escapes; reference definitions "[label]: target" are checked; href, src and
;;;; srcset attributes of embedded HTML are checked; file names are matched with EXACT case
;;;; (GitHub is case sensitive, macOS is not).
;;;;
;;;; Usage:
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/check-links.lisp \
;;;;        --end-toplevel-options [directory]      check the .md files below DIRECTORY (default .)
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/check-links.lisp \
;;;;        --end-toplevel-options --self-test      check the checker on built-in samples
;;;; Exit code 0 when every link resolves, 1 otherwise.
;;;;
;;;; Limits: only ATX headings (# Title) produce anchors, not setext headings (underlined);
;;;; file names containing the characters * ? [ are not supported. SBCL is the only requirement.

(defpackage #:scf-links
  (:use #:common-lisp))

(in-package #:scf-links)

(defparameter *skipped-directories* '(".git" "build" "node_modules" ".cache")
  "Directories that are never scanned.")

(defun read-text (path)
  "The contents of PATH as a string, decoding as UTF-8 and replacing bad bytes."
  (with-open-file (in path :external-format '(:utf-8 :replacement #\?))
    (let* ((buffer (make-string (file-length in)))
           (count (read-sequence buffer in)))
      (subseq buffer 0 count))))

(defun split-lines (text)
  "The lines of TEXT."
  (let ((lines '()) (start 0))
    (loop for end = (position #\Newline text :start start)
          do (push (string-right-trim '(#\Return) (subseq text start end)) lines)
             (if end (setf start (1+ end)) (return)))
    (nreverse lines)))

(defun starts-with (prefix string)
  "True when STRING begins with PREFIX."
  (and (>= (length string) (length prefix)) (string= prefix string :end2 (length prefix))))

;;; --- anchors ---------------------------------------------------------------------

(defun strip-heading-markup (title)
  "TITLE as GitHub renders it: links reduced to their text, HTML tags and emphasis removed."
  (let ((out (make-string-output-stream)) (index 0) (end (length title)))
    (loop while (< index end)
          do (let ((char (char title index)))
               (cond
                 ((and (char= char #\<) (position #\> title :start index))
                  (setf index (1+ (position #\> title :start index))))
                 ((and (char= char #\[) (search "](" title :start2 index))
                  ;; [text](target) -> text
                  (let* ((close (search "](" title :start2 index))
                         (paren (position #\) title :start close)))
                    (write-string (subseq title (1+ index) close) out)
                    (setf index (if paren (1+ paren) end))))
                 ((member char '(#\` #\* #\[ #\])) (incf index))
                 (t (write-char char out) (incf index)))))
    (get-output-stream-string out)))

(defun slugify (heading)
  "GitHub's anchor for HEADING: lower case, punctuation removed, spaces become hyphens."
  (let ((out (make-string-output-stream)))
    (loop for char across (string-downcase (string-trim " " (strip-heading-markup heading)))
          do (cond ((or (alphanumericp char) (char= char #\-) (char= char #\_))
                    (write-char char out))
                   ((char= char #\Space) (write-char #\- out))))
    (get-output-stream-string out)))

(defun fence-line-p (line)
  "True when LINE opens or closes a fenced code block."
  (let ((trimmed (string-left-trim " " line)))
    (or (starts-with "```" trimmed) (starts-with "~~~" trimmed))))

(defun atx-heading (line)
  "The title text when LINE is an ATX heading (# to ######), else NIL."
  (let ((hashes (or (position #\# line :test #'char/=) (length line))))
    (when (and (<= 1 hashes 6) (starts-with (make-string hashes :initial-element #\#) line)
               (or (= hashes (length line)) (char= (char line hashes) #\Space)))
      (let ((title (string-trim " " (subseq line hashes))))
        ;; A closing run of hashes is not part of the title.
        (string-trim " " (string-right-trim "#" title))))))

(defun heading-anchors (text)
  "The anchors GitHub gives to the headings of TEXT; repeated titles get -1, -2, ..."
  (let ((seen (make-hash-table :test #'equal)) (anchors '()) (in-fence nil))
    (dolist (line (split-lines text))
      (cond ((fence-line-p line) (setf in-fence (not in-fence)))
            (in-fence nil)
            (t (let ((title (atx-heading line)))
                 (when title
                   (let* ((slug (slugify title))
                          (count (gethash slug seen 0)))
                     (setf (gethash slug seen) (1+ count))
                     (push (if (zerop count) slug (format nil "~A-~D" slug count)) anchors)))))))
    anchors))

(defun attribute-values (text name)
  "The values of the HTML attribute NAME (written NAME=\"...\") found in TEXT."
  (let ((values '()) (marker (format nil "~A=\"" name)) (start 0))
    (loop for position = (search marker text :start2 start)
          while position
          do (let* ((begin (+ position (length marker)))
                    (finish (position #\" text :start begin)))
               (when finish (push (subseq text begin finish) values))
               (setf start (1+ position))))
    (nreverse values)))

(defun explicit-anchors (text)
  "Anchors declared with id=\"...\" or name=\"...\" in embedded HTML."
  (append (attribute-values text "id") (attribute-values text "name")))

;;; --- link extraction -----------------------------------------------------------------

(defun blank-code-spans (line)
  "LINE with the contents of `inline code` replaced by spaces, so links in it are ignored."
  (let ((result (copy-seq line)) (start 0))
    (loop for open = (position #\` result :start start)
          while open
          do (let ((close (position #\` result :start (1+ open))))
               (if close
                   (progn (fill result #\Space :start open :end (1+ close))
                          (setf start (1+ close)))
                   (return))))
    result))

(defun link-destination (line start)
  "Read a Markdown link destination that begins at index START of LINE, just after \"](\".
Return the destination string, or NIL if the link is not closed."
  (let ((index start) (end (length line)))
    (loop while (and (< index end) (char= (char line index) #\Space)) do (incf index))
    (cond
      ((and (< index end) (char= (char line index) #\<))
       (let ((close (position #\> line :start index)))
         (and close (subseq line (1+ index) close))))
      (t
       (let ((depth 0) (begin index))
         (loop while (< index end)
               do (let ((char (char line index)))
                    (cond ((char= char #\() (incf depth))
                          ((char= char #\))
                           (if (zerop depth)
                               (return-from link-destination (subseq line begin index))
                               (decf depth)))
                          ((and (char= char #\Space) (zerop depth))
                           (return-from link-destination (subseq line begin index)))))
                  (incf index))
         nil)))))

(defun inline-link-targets (line)
  "Destinations of the inline links and images [text](target) in LINE."
  (let ((targets '()) (start 0) (clean (blank-code-spans line)))
    (loop for position = (search "](" clean :start2 start)
          while position
          do (let ((target (link-destination clean (+ position 2))))
               (when target (push target targets))
               (setf start (+ position 2))))
    (nreverse targets)))

(defun reference-definition-target (line)
  "The destination when LINE is a reference definition \"[label]: target\", else NIL."
  (let ((trimmed (string-left-trim " " line)))
    (when (and (starts-with "[" trimmed) (search "]:" trimmed))
      (let* ((colon (+ 2 (search "]:" trimmed)))
             (rest (string-trim " " (subseq trimmed colon)))
             (space (position #\Space rest)))
        (when (plusp (length rest))
          (if (char= (char rest 0) #\<)
              (let ((close (position #\> rest))) (and close (subseq rest 1 close)))
              (subseq rest 0 space)))))))

(defun html-targets (line)
  "Relative values of href, src and srcset attributes found in LINE."
  (let ((targets '()))
    (dolist (value (attribute-values line "href"))
      (push value targets))
    (dolist (value (attribute-values line "src"))
      (push value targets))
    (dolist (value (attribute-values line "srcset"))
      ;; "a.png 1x, b.png 2x" -> the URL part of each candidate.
      (let ((start 0))
        (loop for comma = (position #\, value :start start)
              do (let ((candidate (string-trim " " (subseq value start comma))))
                   (when (plusp (length candidate))
                     (push (subseq candidate 0 (position #\Space candidate)) targets)))
                 (if comma (setf start (1+ comma)) (return)))))
    targets))

(defun link-targets (text)
  "All link destinations of TEXT outside fenced code blocks, as (LINE-NUMBER . TARGET)."
  (let ((found '()) (in-fence nil) (number 0))
    (dolist (line (split-lines text))
      (incf number)
      (cond ((fence-line-p line) (setf in-fence (not in-fence)))
            (in-fence nil)
            (t (dolist (target (inline-link-targets line)) (push (cons number target) found))
               (let ((definition (reference-definition-target line)))
                 (when definition (push (cons number definition) found)))
               (dolist (target (html-targets (blank-code-spans line)))
                 (push (cons number target) found)))))
    (nreverse found)))

;;; --- resolving targets -----------------------------------------------------------------

(defun external-target-p (target)
  "True for URLs with a scheme (http:, mailto:, ...) and for protocol-relative URLs."
  (or (starts-with "//" target)
      (let ((colon (position #\: target)))
        (and colon (plusp colon)
             (alpha-char-p (char target 0))
             (every (lambda (char) (or (alphanumericp char) (find char "+.-")))
                    (subseq target 0 colon))))))

(defun percent-decode (string)
  "STRING with %XX escapes decoded (single-byte characters only)."
  (with-output-to-string (out)
    (let ((index 0) (end (length string)))
      (loop while (< index end)
            do (let ((char (char string index)))
                 (if (and (char= char #\%) (<= (+ index 3) end)
                          (digit-char-p (char string (+ index 1)) 16)
                          (digit-char-p (char string (+ index 2)) 16))
                     (progn (write-char (code-char (parse-integer string :start (1+ index)
                                                                         :end (+ index 3)
                                                                         :radix 16))
                                        out)
                            (incf index 3))
                     (progn (write-char char out) (incf index))))))))

(defvar *listing-cache* (make-hash-table :test #'equal)
  "Directory namestring -> list of (name . directory-p) entries, to avoid repeated listings.")

(defun directory-entries (directory)
  "The entries of the directory pathname DIRECTORY as a list of (NAME . DIRECTORY-P)."
  (let ((key (namestring directory)))
    (or (gethash key *listing-cache*)
        (setf (gethash key *listing-cache*)
              (mapcar (lambda (path)
                        (if (and (null (pathname-name path)) (null (pathname-type path)))
                            (cons (car (last (pathname-directory path))) t)
                            (cons (file-namestring path) nil)))
                      (directory (merge-pathnames "*.*" directory) :resolve-symlinks nil))))))

(defun split-path (path)
  "The /-separated components of PATH, without empty ones."
  (let ((parts '()) (start 0))
    (loop for end = (position #\/ path :start start)
          do (let ((part (subseq path start end)))
               (when (plusp (length part)) (push part parts)))
             (if end (setf start (1+ end)) (return)))
    (nreverse parts)))

(defun resolve-exact (base-directory relative)
  "Resolve RELATIVE from BASE-DIRECTORY matching every name with exact case. Return the
pathname of the file or directory, or NIL when it does not exist."
  (let ((current (pathname base-directory)))
    (dolist (part (split-path relative) current)
      (cond ((string= part ".") nil)
            ((string= part "..")
             (setf current (make-pathname :directory (butlast (pathname-directory current))
                                          :defaults current)))
            (t (let ((entry (find part (directory-entries current) :key #'car :test #'string=)))
                 (unless entry (return nil))
                 (setf current (if (cdr entry)
                                   (make-pathname :directory (append (pathname-directory current)
                                                                     (list part))
                                                  :name nil :type nil :defaults current)
                                   (merge-pathnames part current)))))))))

(defun split-anchor (target)
  "TARGET split at the first #, as two values: the path part and the anchor (or NIL)."
  (let ((hash (position #\# target)))
    (if hash
        (values (subseq target 0 hash) (subseq target (1+ hash)))
        (values target nil))))

(defun strip-query (path)
  "PATH without a ?query part."
  (subseq path 0 (position #\? path)))

(defun markdown-path-p (path)
  "True when PATH names a Markdown file."
  (let ((type (pathname-type path)))
    (and type (string-equal type "md") (pathname-name path) t)))

(defun markdown-files (root)
  "The .md files below ROOT, sorted by name."
  (let ((found '()))
    (labels ((walk (directory)
               (dolist (path (directory (merge-pathnames "*.*" directory) :resolve-symlinks nil))
                 (cond ((and (null (pathname-name path)) (null (pathname-type path)))
                        (unless (member (car (last (pathname-directory path)))
                                        *skipped-directories* :test #'string=)
                          (walk path)))
                       ((markdown-path-p path) (push path found))))))
      (walk root))
    (sort found #'string< :key #'namestring)))

(defvar *anchor-cache* (make-hash-table :test #'equal)
  "Namestring of a Markdown file -> its anchors.")

(defun file-anchors (path)
  "The anchors (headings and explicit ids) of the Markdown file PATH."
  (let ((key (namestring path)))
    (or (gethash key *anchor-cache*)
        (setf (gethash key *anchor-cache*)
              (let ((text (read-text path)))
                (append (heading-anchors text) (explicit-anchors text)))))))

(defun check-target (file root target)
  "Check one TARGET found in FILE. Return NIL when fine, else a string saying what is wrong."
  (unless (or (zerop (length target)) (external-target-p target))
    (multiple-value-bind (raw-path anchor) (split-anchor target)
      (let* ((path-text (percent-decode (strip-query raw-path)))
             (anchor-text (and anchor (percent-decode anchor)))
             (base (if (starts-with "/" path-text) root
                       (make-pathname :name nil :type nil :defaults file)))
             (resolved (if (zerop (length path-text)) file (resolve-exact base path-text))))
        (cond ((null resolved) "file not found")
              ((and anchor-text (plusp (length anchor-text)) (markdown-path-p resolved)
                    (not (member anchor-text (file-anchors resolved) :test #'string=)))
               "anchor not found"))))))

(defun check-root (root)
  "Check every Markdown file below ROOT. Return the number of files, links and broken links."
  (clrhash *listing-cache*)
  (clrhash *anchor-cache*)
  (let* ((root (truename (if (char= (char root (1- (length root))) #\/)
                             root
                             (concatenate 'string root "/"))))
         (files (markdown-files root))
         (checked 0)
         (broken 0))
    (dolist (file files)
      (loop for (number . target) in (link-targets (read-text file))
            do (incf checked)
               (let ((problem (check-target file root target)))
                 (when problem
                   (incf broken)
                   (format t "BROKEN  ~A:~D  ~A  (~A)~%" (enough-namestring file root) number
                           target problem)))))
    (format t "links: ~D file~:P, ~D link~:P checked, ~D broken~%" (length files) checked broken)
    (values (length files) checked broken)))

;;; --- self test -----------------------------------------------------------------------------

(defvar *self-test-failures* 0)

(defun expect-equal (name expected actual)
  "Count a failure and print it when ACTUAL is not EQUAL to EXPECTED."
  (unless (equal expected actual)
    (incf *self-test-failures*)
    (format t "FAIL  ~A~%        expected ~S~%        actual   ~S~%" name expected actual)))

(defun unit-self-tests ()
  "Self-tests that need no files."
  (expect-equal "slug of plain words" "section-one" (slugify "Section One"))
  (expect-equal "slug drops punctuation" "what-is-it" (slugify "What is it?"))
  (expect-equal "slug keeps a double hyphen around a dash" "fase-0--repository"
                (slugify (format nil "Fase 0 ~C Repository" (code-char #x2014))))
  (expect-equal "slug keeps accented letters (E grave)"
                (format nil "~C-vero" (code-char #xE8))
                (slugify (format nil "~C vero" (code-char #xC8))))
  (expect-equal "slug removes code marks" "make-check" (slugify "`make` check"))
  (expect-equal "slug reduces a link to its text" "see-docs" (slugify "See [docs](a.md)"))
  (expect-equal "slug keeps underscores" "snake_case" (slugify "snake_case"))
  (expect-equal "headings with repeats" '("a" "a-1" "a-2" "b")
                (reverse (heading-anchors (format nil "# A~%## A~%## a~%## B~%"))))
  (expect-equal "headings in code fences are ignored" '("real")
                (heading-anchors (format nil "```~%# fake~%```~%# Real~%")))
  (expect-equal "closing hashes are dropped" '("title")
                (heading-anchors (format nil "## Title ##~%")))
  (expect-equal "a hash without a space is no heading" '()
                (heading-anchors (format nil "#nospace~%")))
  (expect-equal "explicit ids" '("x" "y")
                (explicit-anchors "<a id=\"x\"></a> <a name=\"y\"></a>"))
  (expect-equal "inline links and images" '("a.md" "b.png")
                (inline-link-targets "see [a](a.md) and ![b](b.png)"))
  (expect-equal "title after the target" '("a.md")
                (inline-link-targets "[a](a.md \"A title\")"))
  (expect-equal "angle brackets allow spaces" '("a b.md")
                (inline-link-targets "[a](<a b.md>)"))
  (expect-equal "balanced parentheses" '("a_(b).md")
                (inline-link-targets "[a](a_(b).md)"))
  (expect-equal "links in inline code are ignored" '("real.md")
                (inline-link-targets "`[x](fake.md)` [y](real.md)"))
  (expect-equal "links in code fences are ignored" '((4 . "real.md"))
                (link-targets (format nil "```~%[x](fake.md)~%```~%[y](real.md)~%")))
  (expect-equal "reference definitions" "docs/a.md" (reference-definition-target "[a]: docs/a.md"))
  (expect-equal "html attributes" '("x.svg" "y.svg" "z.svg")
                (sort (html-targets "<source srcset=\"y.svg 1x, z.svg 2x\"><img src=\"x.svg\">")
                      #'string<))
  (expect-equal "scheme urls are external" '(t t t nil nil)
                (mapcar #'external-target-p
                        '("https://x.org" "mailto:a@b.c" "//cdn.x/y" "docs/a.md" "a.md#x")))
  (expect-equal "percent decoding" "a b.md" (percent-decode "a%20b.md")))

(defun write-fixture-file (root name text)
  "Write TEXT to NAME below ROOT, creating directories."
  (let ((path (merge-pathnames name root)))
    (ensure-directories-exist path)
    (with-open-file (out path :direction :output :if-exists :supersede
                              :external-format :utf-8)
      (write-string text out))))

(defun fixture-self-test ()
  "Build a small tree under build/link-selftest/, check it and compare with what must be
found. The tree is removed afterwards."
  (let* ((root (merge-pathnames "build/link-selftest/" (truename "./")))
         (expected '("a.md:3 missing.md"
                     "a.md:4 b.md#nope"
                     "a.md:6 #section-three"
                     "a.md:9 B.md"
                     "a.md:12 missing.svg"
                     "a.md:13 missing2.svg"
                     "c.md:1 ../nowhere.md"))
         (found '()))
    (ensure-directories-exist root)
    (write-fixture-file
     root "a.md"
     (format nil "~{~A~%~}"
             '("# Title"
               "## Section One"
               "[bad](missing.md) [ok](b.md)"
               "[ok](b.md#target-heading) [bad](b.md#nope) [ok](b.md#explicit)"
               "## Section One"
               "[ok](#section-one) [ok](#section-one-1) [bad](#section-three)"
               "[ok](sub/) [ok](sub/with%20space.md) [ext](https://example.com/x)"
               "[mail](mailto:a@b.c)"
               "[bad](B.md)"
               "![ok](img.svg)"
               "<img src=\"img.svg\">"
               "<img src=\"missing.svg\">"
               "<source srcset=\"img.svg 1x, missing2.svg 2x\">"
               "`[in code](nowhere.md)`"
               "```"
               "[in fence](nowhere2.md)"
               "```")))
    (write-fixture-file root "b.md" (format nil "# Target Heading~%<a id=\"explicit\"></a>~%"))
    (write-fixture-file root "sub/with space.md" (format nil "# Spaced~%"))
    (write-fixture-file root "img.svg" "<svg/>")
    (write-fixture-file root "c.md" (format nil "[bad](../nowhere.md)~%"))
    (let ((output (with-output-to-string (*standard-output*)
                    (check-root (namestring root)))))
      (dolist (line (split-lines output))
        (when (starts-with "BROKEN" line)
          (let* ((fields (remove "" (let ((parts '()) (start 0))
                                      (loop for end = (search "  " line :start2 start)
                                            do (push (subseq line start end) parts)
                                               (if end (setf start (+ end 2)) (return)))
                                      (nreverse parts))
                                 :test #'string=))
                 (where (string-trim " " (second fields)))
                 (target (string-trim " " (third fields))))
            (push (format nil "~A ~A" where target) found)))))
    (expect-equal "the fixture tree reports exactly the planted problems"
                  (sort (copy-list expected) #'string<) (sort found #'string<))
    ;; Remove the fixture.
    (dolist (name '("a.md" "b.md" "img.svg" "c.md" "sub/with space.md"))
      (delete-file (merge-pathnames name root)))
    (sb-ext:delete-directory (merge-pathnames "sub/" root))
    (sb-ext:delete-directory root)))

(defun run-self-test ()
  "Run the self-tests; return true when all passed."
  (setf *self-test-failures* 0)
  (unit-self-tests)
  (fixture-self-test)
  (format t "links self-test: ~D failure~:P~%" *self-test-failures*)
  (zerop *self-test-failures*))

(defun main ()
  "Entry point: read the arguments after --end-toplevel-options."
  (let ((arguments (rest sb-ext:*posix-argv*)))
    (if (member "--self-test" arguments :test #'string=)
        (sb-ext:exit :code (if (run-self-test) 0 1))
        (multiple-value-bind (files checked broken) (check-root (or (first arguments) "."))
          (declare (ignore files checked))
          (sb-ext:exit :code (if (zerop broken) 0 1))))))

(main)
