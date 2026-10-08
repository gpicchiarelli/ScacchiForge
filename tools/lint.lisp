;;;; lint.lisp -- a small linter for the Lisp sources.
;;;;
;;;; Usage:
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/lint.lisp \
;;;;        --end-toplevel-options src tests       lint the given directories
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/lint.lisp \
;;;;        --end-toplevel-options --self-test     check the linter on built-in samples
;;;; Exit code 0 when clean, 1 when there are violations (or a failed self-test).
;;;;
;;;; Rules
;;;;   tab                  a tab character anywhere
;;;;   trailing-whitespace  a space, tab or carriage return before the end of a line
;;;;   line-length          a line longer than 100 characters
;;;;   ignore-errors        the symbol IGNORE-ERRORS used in code
;;;;   eval                 the symbol EVAL used in code
;;;; Symbols inside comments, strings, character names and |quoted| names are not code.
;;;; Keywords (:eval) are not flagged. SBCL is the only requirement.

(defpackage #:scf-lint
  (:use #:common-lisp))

(in-package #:scf-lint)

(defparameter *max-columns* 100 "Longest allowed line, in characters.")

(defstruct (violation (:conc-name violation-))
  "A finding: the 1-based LINE of the file or sample, the RULE name and a MESSAGE."
  (line 0 :type fixnum)
  (rule "" :type string)
  (message "" :type string))

(defun split-lines (text)
  "The lines of TEXT without their newline characters (a final newline adds no empty line)."
  (let ((lines '()) (start 0))
    (loop for end = (position #\Newline text :start start)
          do (push (subseq text start end) lines)
             (if end (setf start (1+ end)) (return)))
    (when (and lines (string= (first lines) "") (plusp (length text))
               (char= (char text (1- (length text))) #\Newline))
      (pop lines))
    (nreverse lines)))

(defun text-violations (text)
  "Violations of the line-based rules in TEXT."
  (let ((found '()))
    (loop for line in (split-lines text)
          for number from 1
          do (when (find #\Tab line)
               (push (make-violation :line number :rule "tab" :message "tab character") found))
             (when (and (plusp (length line))
                        (member (char line (1- (length line))) '(#\Space #\Tab #\Return)))
               (push (make-violation :line number :rule "trailing-whitespace"
                                     :message "whitespace at the end of the line")
                     found))
             (when (> (length line) *max-columns*)
               (push (make-violation :line number :rule "line-length"
                                     :message (format nil "~D columns (limit ~D)"
                                                      (length line) *max-columns*))
                     found)))
    found))

(defun delimiter-p (char)
  "True when CHAR ends a Lisp token."
  (member char '(#\Space #\Tab #\Newline #\Return #\Page #\( #\) #\" #\; #\' #\` #\,)))

(defun skip-block-comment (text start)
  "The index after the nested #| ... |# comment whose opening #| is at START."
  (let ((depth 1) (index (+ start 2)) (end (length text)))
    (loop while (and (< index end) (plusp depth))
          do (cond ((and (char= (char text index) #\|) (< (1+ index) end)
                         (char= (char text (1+ index)) #\#))
                    (decf depth) (incf index 2))
                   ((and (char= (char text index) #\#) (< (1+ index) end)
                         (char= (char text (1+ index)) #\|))
                    (incf depth) (incf index 2))
                   (t (incf index))))
    index))

(defun skip-string (text start)
  "The index after the string literal whose opening quote is at START."
  (let ((index (1+ start)) (end (length text)))
    (loop while (and (< index end) (char/= (char text index) #\"))
          do (incf index (if (char= (char text index) #\\) 2 1)))
    (min end (1+ index))))

(defun code-symbols (text)
  "The symbols that appear as code in TEXT, as a list of (LINE . NAME) with NAME in lower
case and without a package prefix. Comments, strings, character literals and |quoted|
names are skipped."
  (let ((symbols '()) (index 0) (end (length text)) (line 1))
    (flet ((advance-to (new-index)
             (incf line (count #\Newline text :start index :end new-index))
             (setf index new-index)))
      (loop while (< index end)
            do (let ((char (char text index)))
                 (cond
                   ((char= char #\;)
                    (advance-to (or (position #\Newline text :start index) end)))
                   ((char= char #\")
                    (advance-to (skip-string text index)))
                   ((and (char= char #\#) (< (1+ index) end) (char= (char text (1+ index)) #\|))
                    (advance-to (skip-block-comment text index)))
                   ((and (char= char #\#) (< (1+ index) end) (char= (char text (1+ index)) #\\))
                    ;; A character literal: skip the character after the backslash, then
                    ;; the rest of a name such as Space or Newline.
                    (advance-to (min end (+ index 3)))
                    (advance-to (or (position-if #'delimiter-p text :start index) end)))
                   ((char= char #\|)
                    (advance-to (min end (1+ (or (position #\| text :start (1+ index)) end)))))
                   ((delimiter-p char)
                    (advance-to (1+ index)))
                   (t
                    (let* ((token-end (or (position-if #'delimiter-p text :start index) end))
                           (token (subseq text index token-end))
                           (colon (position #\: token :from-end t)))
                      (unless (char= (char token 0) #\:)
                        (push (cons line (string-downcase
                                          (if colon (subseq token (1+ colon)) token)))
                              symbols))
                      (advance-to token-end)))))))
    (nreverse symbols)))

(defun symbol-violations (text)
  "Violations of the rules about forbidden symbols in TEXT."
  (let ((found '()))
    (loop for (line . name) in (code-symbols text)
          do (cond ((string= name "ignore-errors")
                    (push (make-violation :line line :rule "ignore-errors"
                                          :message "IGNORE-ERRORS hides failures")
                          found))
                   ((string= name "eval")
                    (push (make-violation :line line :rule "eval"
                                          :message "EVAL is not allowed in the sources")
                          found))))
    found))

(defun lint-text (text)
  "All violations of TEXT, sorted by line, as a list of VIOLATION."
  (sort (append (text-violations text) (symbol-violations text))
        (lambda (a b) (or (< (violation-line a) (violation-line b))
                          (and (= (violation-line a) (violation-line b))
                               (string< (violation-rule a) (violation-rule b)))))))

(defun read-text (path)
  "The contents of PATH as a string, decoding as UTF-8 and replacing bad bytes."
  (with-open-file (in path :external-format '(:utf-8 :replacement #\?))
    (let* ((buffer (make-string (file-length in)))
           (count (read-sequence buffer in)))
      (subseq buffer 0 count))))

(defun lisp-files (directory)
  "The .lisp files below DIRECTORY, sorted by name."
  (sort (directory (merge-pathnames "**/*.lisp"
                                    (make-pathname :name nil :type nil :defaults
                                                   (truename (concatenate 'string directory "/")))))
        #'string< :key #'namestring))

;;; --- self test -------------------------------------------------------------------

(defun repeat-char (char count)
  "A string of COUNT copies of CHAR."
  (make-string count :initial-element char))

(defun sample-cases ()
  "Samples as (NAME TEXT EXPECTED) with EXPECTED a list of (LINE . RULE)."
  (let ((tab (string #\Tab)))
    (list
     (list "clean code" (format nil "(defun f (x)~%  \"Doc.\"~%  (+ x 1))~%") '())
     (list "empty text" "" '())
     (list "a tab" (format nil "(defun f ()~%~A1)~%" tab) '((2 . "tab")))
     (list "a trailing space" (format nil "(defun f () 1) ~%") '((1 . "trailing-whitespace")))
     (list "a trailing tab" (format nil "(defun f () 1)~A~%" tab)
           '((1 . "tab") (1 . "trailing-whitespace")))
     (list "a carriage return" (format nil "(f)~C~%" #\Return) '((1 . "trailing-whitespace")))
     (list "exactly 100 columns" (format nil ";~A~%" (repeat-char #\x 99)) '())
     (list "101 columns" (format nil ";~A~%" (repeat-char #\x 100)) '((1 . "line-length")))
     (list "ignore-errors" (format nil "(defun f ()~%  (ignore-errors (g)))~%")
           '((2 . "ignore-errors")))
     (list "package-qualified ignore-errors" "(cl:ignore-errors (g))" '((1 . "ignore-errors")))
     (list "eval" "(eval '(+ 1 2))" '((1 . "eval")))
     (list "eval as a function object" "(mapcar #'eval forms)" '((1 . "eval")))
     (list "eval-when is not eval" "(eval-when (:compile-toplevel) (f))" '())
     (list "keyword :eval is not code" "(list :eval :ignore-errors)" '())
     (list "words in a comment" (format nil "; do not use eval or ignore-errors~%(f)~%") '())
     (list "words in a string" "(defun f () \"eval and ignore-errors\")" '())
     (list "words in a block comment" (format nil "#| eval~%ignore-errors |#~%(f)~%") '())
     (list "a nested block comment" "#| a #| eval |# eval |# (f)" '())
     (list "a quoted name" "(list '|eval|)" '())
     (list "a semicolon character literal" "(list #\\; (eval x))" '((1 . "eval")))
     (list "a quote character literal" "(list #\\\" (eval x))" '((1 . "eval")))
     (list "a space character literal" "(list #\\Space (ignore-errors x))" '((1 . "ignore-errors")))
     (list "an escaped quote in a string" "(f \"a \\\" eval\") (g)" '())
     (list "line numbers after a multi-line string"
           (format nil "(f \"one~%two~%three\")~%(eval x)~%") '((4 . "eval")))
     (list "several rules at once"
           (format nil "(eval x)~A~%(ignore-errors y) ~%" tab)
           '((1 . "eval") (1 . "tab") (1 . "trailing-whitespace") (2 . "ignore-errors")
             (2 . "trailing-whitespace"))))))

(defun finding< (a b)
  "Order (LINE . RULE) findings by line, then by rule name."
  (or (< (car a) (car b))
      (and (= (car a) (car b)) (string< (cdr a) (cdr b)))))

(defun run-self-test ()
  "Check the linter on the built-in samples. Return true when all are as expected."
  (let ((failures 0) (cases (sample-cases)))
    (dolist (case cases)
      (destructuring-bind (name text expected) case
        (let ((actual (sort (mapcar (lambda (v) (cons (violation-line v) (violation-rule v)))
                                    (lint-text text))
                            #'finding<))
              (expected (sort (copy-list expected) #'finding<)))
          (unless (equal actual expected)
            (incf failures)
            (format t "FAIL  ~A: expected ~S, found ~S~%" name expected actual)))))
    (format t "lint self-test: ~D sample~:P, ~D failure~:P~%" (length cases) failures)
    (zerop failures)))

;;; --- main -----------------------------------------------------------------------------

(defun lint-directories (directories)
  "Lint every .lisp file below DIRECTORIES, print the findings and return their number."
  (let ((files 0) (total 0))
    (dolist (directory directories)
      (dolist (path (lisp-files directory))
        (incf files)
        (dolist (violation (lint-text (read-text path)))
          (incf total)
          (format t "~A:~D: ~A: ~A~%" (enough-namestring path (truename "./"))
                  (violation-line violation) (violation-rule violation)
                  (violation-message violation)))))
    (format t "lint: ~D file~:P, ~D violation~:P~%" files total)
    total))

(defun main ()
  "Entry point: read the arguments after --end-toplevel-options."
  (let ((arguments (rest sb-ext:*posix-argv*)))
    (sb-ext:exit :code (cond ((member "--self-test" arguments :test #'string=)
                              (if (run-self-test) 0 1))
                             (t (if (zerop (lint-directories (or arguments '("src")))) 0 1))))))

(main)
