;;;; runner.lisp -- entry points used by tools/build.lisp, tools/perft-deep.lisp,
;;;; tools/differential-deep.lisp and ASDF.

(in-package #:scacchiforge.test)

(defun run-all ()
  "Run every suite with the :STANDARD perft and differential profiles. True when everything
passed."
  (let ((*perft-profile* :standard)
        (*differential-profile* :standard))
    (run-tests)))

(defun run-perft-deep ()
  "Run the perft suites of both layers with the :DEEP profile (deeper counts). True when
everything passed."
  (let ((*perft-profile* :deep))
    (run-tests :suites '(:perft :optimized-perft))))

(defun run-differential-deep ()
  "Run the differential suite with the :DEEP profile (millions of positions). True when
everything passed."
  (let ((*differential-profile* :deep))
    (run-tests :suites '(:differential))))
