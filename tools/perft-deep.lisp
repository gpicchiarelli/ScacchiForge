;;;; perft-deep.lisp -- the perft suite with the deep profile (the deepest recorded counts).
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/perft-deep.lisp
;;;; Exit code 0 when every count matched, 1 otherwise. It is not part of "make check".
;;;; Where each expected count comes from is written in the header of tests/test-perft.lisp.
;;;; The load is forced (tools/load.lisp): scacchiforge and scacchiforge/test are compiled
;;;; again, with the SCF_SLIDERS of this run and the default policy, and the tool prints both.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(let ((ok nil))
  (handler-case
      (progn
        (scf-tools:load-strict "scacchiforge/test")
        (scf-tools:report-build-choices "perft-deep")
        (setf ok (uiop:symbol-call '#:scacchiforge.test '#:run-perft-deep)))
    (error (condition)
      (format t "~&perft-deep: ~A~%" condition)))
  (format t "~&perft-deep: ~:[FAILED~;every count matched~]~%" ok)
  (sb-ext:exit :code (if ok 0 1)))
