;;;; bench.lisp -- run the benchmark harness.
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/bench.lisp
;;;; The number of repetitions can be changed with the environment variable
;;;; SCF_BENCH_REPETITIONS (default 5). The output starts with the environment record of
;;;; docs/misure.md. The figures are measurements of the machine that ran them, not results.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(let ((ok nil))
  (handler-case
      (progn
        ;; Recompile the systems in this process (LOAD-STRICT forces scacchiforge,
        ;; scacchiforge/test and scacchiforge/bench), so the build policy that the environment
        ;; record prints is the one the measured code was compiled with. The test system is
        ;; loaded for the expected perft counts (tests/test-perft.lisp).
        (scf-tools:load-strict "scacchiforge/bench")
        (uiop:symbol-call '#:scacchiforge.bench '#:run-benchmarks)
        (setf ok t))
    (error (condition)
      (format t "~&bench: ~A~%" condition)))
  (sb-ext:exit :code (if ok 0 1)))
