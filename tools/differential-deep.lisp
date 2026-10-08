;;;; differential-deep.lisp -- the differential suite with the deep profile: millions of
;;;; positions compared between the optimized layer and the reference model.
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/differential-deep.lisp
;;;; Exit code 0 when the layers agreed everywhere, 1 otherwise. It is not part of "make check".
;;;; What is compared, the positions and the seeds are written in the header of
;;;; tests/test-differential.lisp. The load is forced (tools/load.lisp): scacchiforge and
;;;; scacchiforge/test are compiled again, with the SCF_SLIDERS of this run and the default
;;;; policy, and the tool prints both.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(let ((ok nil))
  (handler-case
      (progn
        (scf-tools:load-strict "scacchiforge/test")
        (scf-tools:report-build-choices "differential-deep")
        (setf ok (uiop:symbol-call '#:scacchiforge.test '#:run-differential-deep)))
    (error (condition)
      (format t "~&differential-deep: ~A~%" condition)))
  (format t "~&differential-deep: ~:[FAILED~;the layers agreed everywhere~]~%" ok)
  (sb-ext:exit :code (if ok 0 1)))
