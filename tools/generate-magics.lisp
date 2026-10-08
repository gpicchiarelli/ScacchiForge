;;;; generate-magics.lisp -- write src/optimized/magic-numbers.lisp from the seeded search.
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/generate-magics.lisp
;;;; ("make magics"). It loads the system with the feature :SCACCHIFORGE-MAGIC-SEARCH, so that
;;;; magic.lisp does not build the tables from the committed numbers; runs SEARCH-MAGIC-NUMBERS
;;;; (src/optimized/magic.lisp) from +MAGIC-SEED+; writes the numbers of both table layouts to
;;;; src/optimized/magic-numbers.lisp; then loads the system again, without the feature, so that
;;;; the new file builds the tables (a number that is not magic would stop that load), and
;;;; checks that the file reads back as the numbers found. It prints how many candidates the
;;;; search drew and its CPU time. Exit code 0 on success, 1 otherwise. It is not part of
;;;; "make check"; the test committed-magic-numbers-are-the-output-of-the-seeded-search
;;;; (tests/test-optimized.lisp) fails when the committed file is not what this tool writes.
;;;;
;;;; Run it after changing the seed, the search or the layouts of magic.lisp. The search does not
;;;; use the committed numbers: numbers that are not magic for new masks or index bits, or a file
;;;; edited by hand, do not stop it. The committed file must still compile, as a DEFPARAMETER of
;;;; *COMMITTED-MAGIC-NUMBERS* in the package of the layer, whatever numbers it holds. The search
;;;; stops only when it has found a magic number for every slot: for a layout in which a slot
;;;; has none (too few index bits), it does not end.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(defpackage #:scf-generate-magics
  (:use #:common-lisp))

(in-package #:scf-generate-magics)

(defparameter *output* "src/optimized/magic-numbers.lisp"
  "The file written, relative to the repository root.")

(defun opt (name)
  "The symbol NAME of the optimized layer."
  (or (find-symbol name "SCACCHIFORGE.OPTIMIZED")
      (error "No symbol ~A in the optimized layer" name)))

(defun write-numbers (out numbers)
  "Write the list NUMBERS to OUT as a parenthesised list, four hexadecimal numbers per line."
  (format out "    (")
  (loop for number in numbers
        for index from 0
        do (cond ((zerop index))
                 ((zerop (mod index 4)) (format out "~%     "))
                 (t (format out " ")))
           (format out "#x~16,'0X" number))
  (format out ")"))

(defun write-magic-numbers (search pathname)
  "Write the property list SEARCH, as SEARCH-MAGIC-NUMBERS returns it, to PATHNAME."
  (destructuring-bind (magic-candidates fixed-candidates) (getf search :candidates)
    (with-open-file (out pathname :direction :output :if-exists :supersede
                                  :external-format :utf-8)
      (format out ";;;; magic-numbers.lisp -- the magic numbers of the slider tables (magic.lisp). ~
                   GENERATED~%")
      (format out ";;;; by tools/generate-magics.lisp (\"make magics\"); do not edit by hand.~%")
      (format out ";;;;~%")
      (format out ";;;; They are the output of SEARCH-MAGIC-NUMBERS (magic.lisp) run from the seed ~
                   below with the~%")
      (format out ";;;; core's splitmix64 generator: no number comes from another engine ~
                   (ADR-0016). The test~%")
      (format out ";;;; committed-magic-numbers-are-the-output-of-the-seeded-search ~
                   (tests/test-optimized.lisp)~%")
      (format out ";;;; runs the search again and requires these numbers. Each list holds 128 ~
                   numbers, one per~%")
      (format out ";;;; slot: the rook squares a1 to h8, then the bishop squares a1 to h8. The ~
                   search drew~%")
      (format out ";;;; ~D candidates for :MAGIC and ~D for :FIXED-MAGIC.~%"
              magic-candidates fixed-candidates)
      (format out "~%(in-package #:scacchiforge.optimized)~%~%")
      (format out "(defparameter *committed-magic-numbers*~%")
      (format out "  '(:seed #x~16,'0X~%" (getf search :seed))
      (format out "    :magic~%")
      (write-numbers out (getf search :magic))
      (format out "~%    :fixed-magic~%")
      (write-numbers out (getf search :fixed-magic))
      (format out ")~%")
      (format out "  \"The magic numbers of both table layouts, as SEARCH-MAGIC-NUMBERS ~
                   returns them.\")~%"))))

(defun run ()
  "Load the system without building the magic tables, search, write, load again with the
tables built from the file written."
  (let ((*features* (cons :scacchiforge-magic-search *features*)))
    (scf-tools:load-strict "scacchiforge"))
  ;; In this fresh process the attack tables are still the zeroed vectors of DEFINE-TABLE: the
  ;; committed numbers have not been used.
  (unless (every (lambda (name) (every #'zerop (symbol-value (opt name))))
                 '("**MAGIC-ATTACKS**" "**FIXED-MAGIC-ATTACKS**"))
    (error "the magic tables were built before the search"))
  (format t "generate-magics: system loaded without building the magic tables (feature ~
             :scacchiforge-magic-search)~%")
  (let* ((seed (symbol-value (opt "+MAGIC-SEED+")))
         (start (get-internal-run-time))
         (search (funcall (opt "SEARCH-MAGIC-NUMBERS") seed))
         (seconds (/ (- (get-internal-run-time) start)
                     (float internal-time-units-per-second 1d0)))
         (pathname (merge-pathnames *output* scf-tools:*repository-root*)))
    (destructuring-bind (magic-candidates fixed-candidates) (getf search :candidates)
      (format t "generate-magics: seed #x~16,'0X, ~D candidates for :magic and ~D for ~
                 :fixed-magic, ~,2F s of CPU (~A ~A, ~A)~%"
              seed magic-candidates fixed-candidates seconds (lisp-implementation-type)
              (lisp-implementation-version) (machine-type)))
    (write-magic-numbers search pathname)
    (format t "generate-magics: wrote ~A~%" *output*)
    (scf-tools:load-strict "scacchiforge")
    (unless (equal (symbol-value (opt "*COMMITTED-MAGIC-NUMBERS*"))
                   (list :seed seed :magic (getf search :magic)
                         :fixed-magic (getf search :fixed-magic)))
      (error "the file written does not read back as the numbers found"))
    (format t "generate-magics: the system loads with the new numbers~%")))

(let ((ok nil))
  (handler-case (progn (run) (setf ok t))
    (error (condition)
      (format t "~&generate-magics: ~A~%" condition)))
  (format t "~&generate-magics: ~:[FAILED~;done~]~%" ok)
  (sb-ext:exit :code (if ok 0 1)))
