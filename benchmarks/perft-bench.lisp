;;;; perft-bench.lisp -- perft leaf nodes per CPU second of the reference engine and of the
;;;; optimized layer, the latter for each implementation of its slider attacks.
;;;;
;;;; Perft is a throughput measurement of move generation, make/unmake and the legality
;;;; filter together. It says nothing about playing strength. Every call is checked against
;;;; the expected node count, so a wrong engine cannot produce a number; the counts are read
;;;; from the test table *MAIN-PERFT-TABLE* (SCF-TEST:MAIN-PERFT-COUNT, tests/test-perft.lisp,
;;;; whose header says where each comes from), not copied here. Both engines run the same
;;;; positions to the same depths, and each call builds its position from the FEN (the
;;;; optimized layer converts the reference position, as it has no FEN reader).
;;;;
;;;; Each timed sample repeats the perft call as many times as it takes to last at least
;;;; *PERFT-SAMPLE-SECONDS* of CPU time, by a calibration call made once per row, so that the
;;;; length of a sample does not depend on how long one call lasts; the report gives the time
;;;; per call and the number of calls of each sample.
;;;;
;;;; The slider implementation of the optimized layer is fixed when its hot path is compiled
;;;; (src/optimized/policy.lisp). This file compiles the hot-path files once with each
;;;; implementation, into build/bench/, and then runs the optimized rows in passes: each
;;;; implementation twice, in the order A B C C B A (SLIDER-PASS-ORDER), loading the files
;;;; compiled with it before each of its passes. A drift of the machine during the run (heat,
;;;; other processes) then reaches every implementation in the same way, to first order, and
;;;; the median of each pass, printed for every row, shows how large it was. At the end the
;;;; hot path is compiled again with the implementation of the build. Every optimized row runs
;;;; code compiled the same way, by this process, with the same policy.

(in-package #:scacchiforge.bench)

(defparameter *perft-benchmarks*
  '(("startpos" 5)
    ("kiwipete" 4)
    ("pos3" 5)
    ("pos5" 4))
  "(position-name depth) of each perft row; the expected count is
SCF-TEST:MAIN-PERFT-COUNT of the two.")

(defparameter *perft-sample-seconds* 0.5d0
  "The CPU time a timed sample of a perft row lasts at least: a sample repeats the perft call
as many times as the calibration call says it takes.")

(defun slider-pass-order ()
  "The slider implementations in the order of the passes of the optimized rows: those of
SCF-OPT:*SLIDER-IMPLEMENTATIONS*, then the same in reverse (A B C C B A)."
  (append scf-opt:*slider-implementations* (reverse scf-opt:*slider-implementations*)))

(defun perft-engines ()
  "(engine slider label) of each engine whose perft is timed, in the order of the report: the
reference engine, then the optimized layer once for each slider implementation, in the order
of SCF-OPT:*SLIDER-IMPLEMENTATIONS* (the default first)."
  (cons (list :reference nil "reference engine")
        (loop for slider in scf-opt:*slider-implementations*
              collect (list :optimized slider
                            (format nil "optimized layer, slider attacks by ~(~A~)~:[~; (the ~
                                         build's choice)~]"
                                    slider (eq slider scf-opt:*slider-implementation*))))))

(defun hot-path-fasl (slider name)
  "Where COMPILE-HOT-PATH writes the compiled hot-path file NAME for the implementation
SLIDER."
  (merge-pathnames (format nil "build/bench/~(~A~)/~A.fasl" slider name)
                   (asdf:system-source-directory "scacchiforge")))

(defun check-loaded-slider (slider)
  "Signal an error unless the loaded slider interface reports SLIDER."
  (unless (eq (scf-opt:slider-interface-implementation) slider)
    (error "The slider interface reports ~(~A~) instead of ~(~A~)"
           (scf-opt:slider-interface-implementation) slider)))

(defun compile-hot-path (slider)
  "Compile the hot-path files of the optimized layer (SCF-OPT:*HOT-PATH-FILES*) with the slider
implementation SLIDER into build/bench/SLIDER/ and load them, so that the optimized perft
calls that follow run that implementation. Signal an error on a compiler warning or failure."
  (let ((root (asdf:system-source-directory "scacchiforge"))
        (scf-opt:*slider-implementation* slider)
        (*compile-verbose* nil)
        (*compile-print* nil))
    (dolist (name scf-opt:*hot-path-files*)
      (let ((source (merge-pathnames (format nil "src/optimized/~A.lisp" name) root))
            (output (hot-path-fasl slider name)))
        (ensure-directories-exist output)
        (multiple-value-bind (fasl warnings-p failure-p) (compile-file source :output-file output)
          (when (or (null fasl) warnings-p failure-p)
            (error "Compiling ~A with the ~(~A~) sliders failed" source slider))
          (load fasl)))))
  (check-loaded-slider slider))

(defun load-hot-path (slider)
  "Load the hot-path files that COMPILE-HOT-PATH compiled in this run with the implementation
SLIDER. Each checks, as it loads, that it was compiled with SLIDER (SCF-OPT:CHECK-COMPILED-CHOICE)."
  (let ((scf-opt:*slider-implementation* slider))
    (dolist (name scf-opt:*hot-path-files*)
      (load (hot-path-fasl slider name))))
  (check-loaded-slider slider))

(defun engine-perft (engine fen depth)
  "Perft of FEN to DEPTH by ENGINE, on a position built from FEN by this call."
  (ecase engine
    (:reference (scf-ref:perft (scf-ref:parse-fen fen) depth))
    (:optimized (scf-opt:bitboard-perft (scf-opt:bitboard-from-reference (scf-ref:parse-fen fen))
                                        depth))))

(defun checked-perft (engine name fen depth expected)
  "Perft of FEN to DEPTH by ENGINE on a fresh position; signal an error unless it is
EXPECTED."
  (let ((nodes (engine-perft engine fen depth)))
    (unless (= nodes expected)
      (error "~(~A~) perft ~A depth ~D gave ~D, expected ~D" engine name depth nodes expected))
    nodes))

(defun calibrate-calls (engine name fen depth expected)
  "Time one checked perft call in CPU time and return how many calls a timed sample makes so
that it lasts at least *PERFT-SAMPLE-SECONDS*."
  (let ((start (get-internal-run-time)))
    (checked-perft engine name fen depth expected)
    (let ((seconds (internal-seconds (- (get-internal-run-time) start))))
      (max 1 (ceiling *perft-sample-seconds* (max seconds 1d-4))))))

(defun time-perft-pass (engine name fen depth expected calls repetitions)
  "One pass of a perft row: an untimed warm-up call, then REPETITIONS timed samples of CALLS
checked calls each. Return the samples (see MEASURE) with :CPU and :WALL divided by CALLS, the
time of one call; :CONSED and :GC stay the totals of the sample."
  (checked-perft engine name fen depth expected)
  (mapcar (lambda (sample)
            (list :cpu (/ (getf sample :cpu) calls)
                  :wall (/ (getf sample :wall) calls)
                  :consed (getf sample :consed)
                  :gc (getf sample :gc)))
          (measure (lambda ()
                     (dotimes (i calls)
                       (checked-perft engine name fen depth expected)))
                   repetitions)))

(defun perft-row (engine slider name depth calls passes)
  "The report plist of the perft row of ENGINE (with the slider implementation SLIDER, NIL for
the reference) on the position NAME to DEPTH, from PASSES, a list of the sample lists of its
passes in run order, each sample of CALLS calls."
  (let ((samples (reduce #'append passes))
        (nodes (scf-test:main-perft-count name depth)))
    (multiple-value-bind (median minimum maximum) (spread samples :cpu)
      (list :engine engine :slider slider :name name :fen (scf-ref:standard-position-fen name)
            :depth depth :nodes nodes :calls calls :samples (length samples)
            :median-cpu median :min-cpu minimum :max-cpu maximum
            :pass-medians (mapcar (lambda (pass) (spread pass :cpu)) passes)
            :median-wall (spread samples :wall)
            :nodes-per-cpu-second (if (plusp median) (/ nodes median) nil)
            :consed-bytes (total samples :consed)
            :gc-seconds (total samples :gc)))))

(defun run-perft-benchmarks (repetitions)
  "Run every perft row with REPETITIONS timed samples per pass: the reference engine in one
pass, the optimized layer in the passes of SLIDER-PASS-ORDER. Return the row plists, engine by
engine in the order of PERFT-ENGINES. The hot path is left compiled with the build's slider
implementation."
  (let ((build-slider scf-opt:*slider-implementation*)
        (calls (make-hash-table :test #'equal))
        (passes (make-hash-table :test #'equal)))
    (flet ((run-pass (engine slider)
             (loop for (name depth) in *perft-benchmarks*
                   do (let ((fen (scf-ref:standard-position-fen name))
                            (expected (scf-test:main-perft-count name depth))
                            (key (list engine slider name)))
                        (unless (gethash key calls)
                          ;; The first call of a row is untimed, as every warm-up call; the
                          ;; second is the calibration call.
                          (checked-perft engine name fen depth expected)
                          (setf (gethash key calls)
                                (calibrate-calls engine name fen depth expected)))
                        (push (time-perft-pass engine name fen depth expected
                                               (gethash key calls) repetitions)
                              (gethash key passes))))))
      (unwind-protect
           (progn
             (run-pass :reference nil)
             (dolist (slider scf-opt:*slider-implementations*)
               (compile-hot-path slider))
             (dolist (slider (slider-pass-order))
               (load-hot-path slider)
               (run-pass :optimized slider)))
        (compile-hot-path build-slider)))
    (loop for (engine slider) in (perft-engines)
          append (loop for (name depth) in *perft-benchmarks*
                       collect (let ((key (list engine slider name)))
                                 (perft-row engine slider name depth (gethash key calls)
                                            (reverse (gethash key passes))))))))
