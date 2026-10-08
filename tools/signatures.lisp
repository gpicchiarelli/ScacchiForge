;;;; signatures.lisp -- write tests/search-signature.sexp, the search signature of the optimized
;;;; engine.
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/signatures.lisp
;;;; ("make signatures"). It loads the test system (a forced load, tools/load.lisp: the files are
;;;; compiled again with the SCF_SLIDERS of this run and the default policy), recomputes the
;;;; signature of every position of *SEARCH-SIGNATURE-POSITIONS* (tests/test-optimized-search.lisp:
;;;; value, best move, node count and principal variation at the signature depth, one thread, of
;;;; the baseline alpha-beta and of the default search of Phase 3 with its table in verification
;;;; mode), and writes the file with a provenance header: the git revision the working tree was
;;;; based on and whether the tree was clean, the policy of the hot path, the slider
;;;; implementation, the Lisp, the operating system and the machine type, and the date. It then
;;;; reads the file back and checks that it holds what was computed: the format, the algorithm,
;;;; the depth, the configuration of the default search and every entry of both searches (name,
;;;; FEN, value, best move, node count, principal variation) compared with EQUAL against the
;;;; entries it wrote. Exit code 0 on success, 1 otherwise.
;;;;
;;;; It is not part of "make check" and no other target runs it. The test
;;;; optimized-search/search-signature-is-reproduced fails when the committed file is not what
;;;; the search computes. When and how to run this tool is written in docs/verifica.md
;;;; ("Regressione di ricerca"): only for a change meant to change the output of the search, never
;;;; to make an [EXACT] change pass.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(defpackage #:scf-signatures
  (:use #:common-lisp))

(in-package #:scf-signatures)

(defun command-output (program &rest arguments)
  "The first line PROGRAM prints on standard output, trimmed, or NIL when it cannot be run, exits
with a code other than 0 or prints nothing."
  (handler-case
      (let* ((text (with-output-to-string (out)
                     (let ((process (sb-ext:run-program program arguments :search t :output out
                                                                          :error nil :input nil)))
                       (unless (eql 0 (sb-ext:process-exit-code process))
                         (return-from command-output nil)))))
             (line (string-trim '(#\Space #\Tab #\Newline #\Return)
                                (subseq text 0 (position #\Newline text)))))
        (and (plusp (length line)) line))
    (error () nil)))

(defun revision-base ()
  "The short git revision of HEAD and whether the working tree is clean, as a string."
  (let* ((root (namestring scf-tools:*repository-root*))
         (revision (command-output "git" "-C" root "rev-parse" "--short" "HEAD"))
         (status (and revision
                      (handler-case
                          (with-output-to-string (out)
                            (sb-ext:run-program "git" (list "-C" root "--no-optional-locks"
                                                            "status" "--porcelain")
                                                :search t :output out :error nil :input nil))
                        (error () nil)))))
    (cond ((null revision) "unknown (git did not answer)")
          ((null status) (format nil "~A, state of the working tree unknown" revision))
          ((zerop (length (string-trim '(#\Space #\Newline) status)))
           (format nil "~A, working tree clean" revision))
          (t (format nil "~A, working tree not clean (uncommitted changes on top of it)"
                     revision)))))

(defun utc-timestamp ()
  "The current time as an ISO 8601 date and time in UTC."
  (multiple-value-bind (second minute hour day month year) (decode-universal-time
                                                            (get-universal-time) 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ" year month day hour minute second)))

(defun header-lines ()
  "The provenance header of the signature file, one string per line."
  (let ((*print-pretty* nil)
        (package "SCACCHIFORGE.OPTIMIZED"))
    (list "Written by tools/signatures.lisp (\"make signatures\"); do not edit by hand. The test"
          "optimized-search/search-signature-is-reproduced recomputes every entry and compares"
          "it. When to regenerate it: docs/verifica.md, \"Regressione di ricerca\"."
          ""
          "Each entry: the name and FEN of a position (tests/test-optimized-search.lisp, where"
          "each position's origin is written), then the value from the side to move, the best"
          "move, the node count (root and leaves included) and the principal variation at the"
          "depth below, one thread, the classical evaluation of docs/valutazione.md. :ENTRIES"
          "holds those of the optimized layer's alpha-beta, the baseline of Phase 2: no"
          "transposition table, no move ordering (the generator's order). :DEFAULT-ENTRIES"
          "holds those of the default search of Phase 3 (:DEFAULT-SEARCH, ADR-0022): iterative"
          "deepening of PVS with the move ordering of Phase 3 and a fresh transposition table"
          "in verification mode; its node count is the sum over the iterations. The two give"
          "the same values. The moves are in long algebraic form."
          ""
          "Provenance of this file:"
          (format nil "  revision base: ~A" (revision-base))
          (format nil "  policy of the hot path: ~(~S~)"
                  (cons 'optimize (symbol-value (find-symbol "*OPTIMIZED-POLICY*" package))))
          (format nil "  slider implementation: ~(~A~) (SCF_SLIDERS ~:[not set~;~:*~S~])"
                  (uiop:symbol-call package '#:slider-interface-implementation)
                  (sb-ext:posix-getenv "SCF_SLIDERS"))
          (format nil "  Lisp: ~A ~A" (lisp-implementation-type) (lisp-implementation-version))
          (format nil "  system: ~A ~A, ~A" (software-type) (software-version) (machine-type))
          (format nil "  date: ~A" (utc-timestamp)))))

(defun entry-differences (computed found)
  "The parts in which the signature entry FOUND, read back, differs from COMPUTED, both lists
(NAME FEN :SCORE s :BEST-MOVE m :NODES n :PV line), as a list of strings."
  (let ((*print-pretty* nil))
    (append
     (loop for part in '("name" "FEN")
           for index from 0
           unless (equal (nth index computed) (nth index found))
             collect (format nil "~A ~S in the file, ~S computed" part (nth index found)
                             (nth index computed)))
     (loop for key in '(:score :best-move :nodes :pv)
           unless (equal (getf (cddr computed) key) (getf (cddr found) key))
             collect (format nil "~(~A~) ~S in the file, ~S computed" key
                             (getf (cddr found) key) (getf (cddr computed) key))))))

(defun entries-differences (label computed found)
  "The differences between the entries COMPUTED and the entries FOUND in the file, as a list of
strings, each preceded by LABEL: the number of entries, then each entry, by position."
  (append
   (unless (= (length computed) (length found))
     (list (format nil "~A: ~D entries in the file, ~D computed" label (length found)
                   (length computed))))
   (loop for entry in computed
         for other in found
         unless (equal entry other)
           collect (format nil "~A: ~A: ~{~A~^; ~}" label (first entry)
                           (or (entry-differences entry other)
                               (list "the entry has other contents"))))))

(defun read-back-differences (written read)
  "The differences between WRITTEN, the property list of the signature as computed, and READ,
the property list read back from the file, as a list of strings (empty when they are EQUAL):
the header keys :FORMAT, :ALGORITHM, :DEPTH and :DEFAULT-SEARCH, then the entries of each
search. Anything else that keeps the two from being EQUAL is reported as one line."
  (let* ((*print-pretty* nil)
         (differences
           (append
            (loop for key in '(:format :algorithm :depth :default-search)
                  unless (equal (getf written key) (getf read key))
                    collect (format nil "~(~S~) ~S in the file, ~S computed" key
                                    (getf read key) (getf written key)))
            (entries-differences "alpha-beta" (getf written :entries) (getf read :entries))
            (entries-differences "default search" (getf written :default-entries)
                                 (getf read :default-entries)))))
    (if (and (null differences) (not (equal written read)))
        (list "the file holds other contents than those computed")
        differences)))

(defun run ()
  "Load the test system, write the signature file, read it back and compare it with what was
computed."
  (scf-tools:load-strict "scacchiforge/test")
  (scf-tools:report-build-choices "signatures")
  (multiple-value-bind (pathname written)
      (uiop:symbol-call "SCACCHIFORGE.TEST" "WRITE-SEARCH-SIGNATURE-FILE" (header-lines))
    (let* ((read (uiop:symbol-call "SCACCHIFORGE.TEST" "READ-SEARCH-SIGNATURE" pathname))
           (differences (read-back-differences written read))
           (entries (getf read :entries)))
      (when differences
        (error "the file written does not read back as computed:~{~%  ~A~}" differences))
      (format t "signatures: wrote ~A, ~D positions at depth ~D, two searches each, read ~
                 back equal to what was computed~%"
              (enough-namestring pathname scf-tools:*repository-root*) (length entries)
              (getf read :depth)))))

(let ((ok nil))
  (handler-case (progn (run) (setf ok t))
    (error (condition)
      (format t "~&signatures: ~A~%" condition)))
  (format t "~&signatures: ~:[FAILED~;done~]~%" ok)
  (sb-ext:exit :code (if ok 0 1)))
