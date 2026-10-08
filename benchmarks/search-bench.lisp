;;;; search-bench.lisp -- search nodes per CPU second of the optimized layer at fixed depth, and
;;;; the cost of one call of the classical evaluation in both layers.
;;;;
;;;; Search rows. Alpha-beta of the optimized layer (BITBOARD-SEARCH-WITH-CONTEXT, one thread, no
;;;; transposition table, no move ordering, the classical evaluation) on positions of the search
;;;; signature, at the signature's depth. Every call is checked against the signature file
;;;; (tests/search-signature.sexp, read through SCF-TEST:READ-SEARCH-SIGNATURE): the value and the
;;;; node count must be the recorded ones, so a search that computes something else cannot
;;;; produce a number. Each timed sample repeats the search as many times as a calibration call
;;;; says it takes to last *SEARCH-SAMPLE-SECONDS* of CPU, as the perft rows do. Nodes per CPU
;;;; second are search nodes (the root, the interior nodes and the leaves, each with a move
;;;; generation or an evaluation) over the median CPU time of one search: not perft leaves, and
;;;; not a measure of playing strength.
;;;;
;;;; Evaluation rows. The classical evaluation of the optimized layer, with its incremental state
;;;; (BITBOARD-EVALUATE, what the search calls) and recomputed from scratch
;;;; (BITBOARD-EVALUATE-FROM-SCRATCH), and the reference's EVALUATE-CLASSICAL, on the same seeded
;;;; random legal positions. Before timing, the three must give the same sum of scores. The cost
;;;; per call is the CPU time of a sample divided by the calls it makes; it includes the call.
;;;; The two optimized rows compute one quantity in two ways, so they are compared with each
;;;; other: the three rows run in interleaved passes, A B C C B A as the perft rows do
;;;; (EVALUATION-PASS-ORDER), so that a drift of the machine during the run reaches each row in
;;;; the same way to first order, and the median of each pass is printed, so that the drift
;;;; shows. The difference between the first two rows estimates, on one machine at one moment,
;;;; what reading the incremental state saves at evaluation time; it is a measurement, and two
;;;; runs on a loaded machine can give different differences. What keeping the state costs is
;;;; inside make and unmake, which the perft and search rows time.

(in-package #:scacchiforge.bench)

(defparameter *search-benchmarks*
  '("startpos" "kiwipete" "pos3" "quiet-italian" "tactical-knight-takes-f7")
  "The positions of the search signature whose search is timed, by name.")

(defparameter *search-sample-seconds* 0.5d0
  "The CPU time a timed sample of a search row lasts at least.")

(defparameter *evaluation-positions* 4096
  "How many seeded random legal positions the evaluation rows evaluate per pass.")

(defparameter *evaluation-sample-seconds* 0.1d0
  "The CPU time a timed sample of an evaluation row lasts at least.")

(defun signature-entry (signature name)
  "The entry of the position NAME in the property list SIGNATURE of the signature file, as a
list (NAME FEN :SCORE s :BEST-MOVE m :NODES n :PV line)."
  (or (find name (getf signature :entries) :key #'first :test #'string=)
      (error "the search signature has no position ~S" name)))

(defun checked-search (context bbp depth score nodes name)
  "Alpha-beta of the optimized layer on BBP to DEPTH with CONTEXT; signal an error unless it
returns SCORE and visits NODES nodes, the signature's values for NAME."
  (multiple-value-bind (found-score move found-nodes)
      (scf-opt:bitboard-search-with-context context bbp depth :alpha-beta)
    (declare (ignore move))
    (unless (and (= found-score score) (= found-nodes nodes))
      (error "search ~A depth ~D gave ~D with ~D nodes; the signature says ~D with ~D nodes"
             name depth found-score found-nodes score nodes))
    found-nodes))

(defun run-search-benchmarks (repetitions)
  "Time the search rows, REPETITIONS samples each; return the row plists."
  (let* ((signature (scf-test:read-search-signature))
         (depth (getf signature :depth))
         (context (scf-opt:make-bitboard-search-context depth)))
    (loop for name in *search-benchmarks*
          collect (destructuring-bind (name fen &key score nodes &allow-other-keys)
                      (signature-entry signature name)
                    (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:parse-fen fen))))
                      (flet ((search-once ()
                               (checked-search context bbp depth score nodes name)))
                        ;; Warm-up, then calibration.
                        (search-once)
                        (let* ((start (get-internal-run-time))
                               (ignored (search-once))
                               (seconds (internal-seconds (- (get-internal-run-time) start)))
                               (calls (max 1 (ceiling *search-sample-seconds*
                                                      (max seconds 1d-4))))
                               (samples (mapcar (lambda (sample)
                                                  (list :cpu (/ (getf sample :cpu) calls)
                                                        :consed (getf sample :consed)
                                                        :gc (getf sample :gc)))
                                                (measure (lambda ()
                                                           (dotimes (i calls) (search-once)))
                                                         repetitions))))
                          (declare (ignore ignored))
                          (multiple-value-bind (median minimum maximum) (spread samples :cpu)
                            (list :name name :fen fen :depth depth :nodes nodes :score score
                                  :calls calls :median-cpu median :min-cpu minimum
                                  :max-cpu maximum
                                  :nodes-per-cpu-second (if (plusp median) (/ nodes median) nil)
                                  :consed-bytes (total samples :consed)
                                  :gc-seconds (total samples :gc))))))))))

(defun evaluation-inputs ()
  "*EVALUATION-POSITIONS* random legal positions from the fuzzer's start positions, drawn with a
generator seeded with the :EVALUATION seed: two values, the vector of reference positions and
the vector of the same positions converted to bitboards."
  (let* ((rng (make-rng (input-seed :evaluation)))
         (starts (mapcar #'cdr scf-ref:*standard-positions*))
         (reference (coerce (loop repeat *evaluation-positions*
                                  collect (scf-ref:random-legal-position starts rng 120))
                            'simple-vector)))
    (values reference (map 'simple-vector #'scf-opt:bitboard-from-reference reference))))

(defun evaluation-pass (function positions)
  "The sum of FUNCTION over the vector POSITIONS."
  (declare (type function function) (type simple-vector positions))
  (let ((sum 0))
    (declare (type fixnum sum))
    (loop for pos across positions
          do (setf sum (+ sum (the fixnum (funcall function pos)))))
    sum))

(defun evaluation-pass-order (labels)
  "The rows named by LABELS in the order of the timed passes: each once, then the same in
reverse (A B C C B A)."
  (append labels (reverse labels)))

(defun run-evaluation-benchmarks (repetitions)
  "Time the evaluation rows after checking that the three evaluations give the same sum; return
the row plists. Each row is calibrated once; then the rows run in the passes of
EVALUATION-PASS-ORDER, each pass an untimed warm-up pass over the positions and REPETITIONS
timed samples. Median, minimum and maximum are over both passes of a row, and the median of each
pass is returned too, so that a drift of the machine during the run shows."
  (multiple-value-bind (reference optimized) (evaluation-inputs)
    (let* ((rows (list (list "optimized, incremental state" #'scf-opt:bitboard-evaluate
                             optimized)
                       (list "optimized, from scratch" #'scf-opt:bitboard-evaluate-from-scratch
                             optimized)
                       (list "reference" #'scf-ref:evaluate-classical reference)))
           (sums (loop for (nil function positions) in rows
                       collect (evaluation-pass function positions)))
           (passes-per-sample (make-hash-table :test #'equal))
           (runs (make-hash-table :test #'equal)))
      (unless (every (lambda (sum) (= sum (first sums))) sums)
        (error "the evaluations disagree on the benchmark positions: sums ~S" sums))
      ;; Calibration: how many passes over the positions a sample makes, from one timed pass
      ;; (the passes that computed the sums above were the warm-up).
      (loop for (label function positions) in rows
            do (let* ((start (get-internal-run-time))
                      (ignored (evaluation-pass function positions))
                      (seconds (internal-seconds (- (get-internal-run-time) start))))
                 (declare (ignore ignored))
                 (setf (gethash label passes-per-sample)
                       (max 1 (ceiling *evaluation-sample-seconds* (max seconds 1d-4))))))
      ;; The timed passes, A B C C B A.
      (dolist (label (evaluation-pass-order (mapcar #'first rows)))
        (destructuring-bind (function positions) (rest (assoc label rows :test #'string=))
          (let ((passes (gethash label passes-per-sample)))
            (evaluation-pass function positions)
            (push (measure (lambda ()
                             (dotimes (i passes)
                               (evaluation-pass function positions)))
                           repetitions)
                  (gethash label runs)))))
      (loop for (label nil positions) in rows
            collect (let* ((passes (reverse (gethash label runs)))
                           (samples (reduce #'append passes))
                           (calls (* (gethash label passes-per-sample) (length positions))))
                      (flet ((nanoseconds (seconds) (* 1d9 (/ seconds calls))))
                        (multiple-value-bind (median minimum maximum) (spread samples :cpu)
                          (list :label label :calls calls :median-ns (nanoseconds median)
                                :min-ns (nanoseconds minimum) :max-ns (nanoseconds maximum)
                                :pass-medians-ns (mapcar (lambda (pass)
                                                           (nanoseconds (spread pass :cpu)))
                                                         passes)
                                :consed-bytes (total samples :consed)
                                :gc-seconds (total samples :gc)
                                :checksum (first sums)))))))))

;;; Evaluation-state rows: research/exp-0002-stato-incrementale-della-valutazione.md. Whether
;;; make and unmake keep the evaluation state is fixed when the hot path is compiled
;;; (SCF_EVAL_STATE, src/optimized/policy.lisp). This part compiles the hot-path files once with
;;; each state of SCF-OPT:*EVALUATION-STATES*, with the build's slider implementation, into
;;; build/bench/state-STATE/, and runs the search rows and the optimized perft rows in passes in
;;; the order A B B A (EVALUATION-STATE-PASS-ORDER), so that a drift of the machine reaches both
;;; variants in the same way to first order. Every search is checked against the signature and
;;; every perft against its count: the two variants must compute the same thing. At the end the
;;; hot path is compiled again with the build's state.

(defun evaluation-state-pass-order ()
  "The evaluation states in the order of the passes: each once, then the same in reverse
(A B B A)."
  (append scf-opt:*evaluation-states* (reverse scf-opt:*evaluation-states*)))

(defun state-hot-path-fasl (state name)
  "Where COMPILE-STATE-HOT-PATH writes the compiled hot-path file NAME for the evaluation state
STATE."
  (merge-pathnames (format nil "build/bench/state-~(~A~)/~A.fasl" state name)
                   (asdf:system-source-directory "scacchiforge")))

(defun check-loaded-state (state)
  "Signal an error unless the loaded hot path reports the evaluation state STATE."
  (unless (eq (scf-opt:evaluation-state-implementation) state)
    (error "The hot path reports the evaluation state ~(~A~) instead of ~(~A~)"
           (scf-opt:evaluation-state-implementation) state)))

(defun compile-state-hot-path (state)
  "Compile the hot-path files of the optimized layer with the evaluation state STATE into
build/bench/state-STATE/ and load them. Signal an error on a compiler warning or failure."
  (let ((root (asdf:system-source-directory "scacchiforge"))
        (scf-opt:*evaluation-state* state)
        (*compile-verbose* nil)
        (*compile-print* nil))
    (dolist (name scf-opt:*hot-path-files*)
      (let ((source (merge-pathnames (format nil "src/optimized/~A.lisp" name) root))
            (output (state-hot-path-fasl state name)))
        (ensure-directories-exist output)
        (multiple-value-bind (fasl warnings-p failure-p) (compile-file source :output-file output)
          (when (or (null fasl) warnings-p failure-p)
            (error "Compiling ~A with the evaluation state ~(~A~) failed" source state))
          (load fasl)))))
  (check-loaded-state state))

(defun load-state-hot-path (state)
  "Load the hot-path files that COMPILE-STATE-HOT-PATH compiled in this run with STATE. Each
checks, as it loads, that it was compiled with STATE (SCF-OPT:CHECK-COMPILED-CHOICE)."
  (let ((scf-opt:*evaluation-state* state))
    (dolist (name scf-opt:*hot-path-files*)
      (load (state-hot-path-fasl state name))))
  (check-loaded-state state))

(defun calibrated-calls (thunk seconds)
  "Time one call of THUNK in CPU time; return how many calls a sample makes so that it lasts at
least SECONDS."
  (let ((start (get-internal-run-time)))
    (funcall thunk)
    (max 1 (ceiling seconds (max (internal-seconds (- (get-internal-run-time) start)) 1d-4)))))

(defun per-call-samples (thunk calls repetitions)
  "REPETITIONS timed samples of CALLS calls of THUNK, with :CPU divided by CALLS."
  (mapcar (lambda (sample)
            (list :cpu (/ (getf sample :cpu) calls)
                  :consed (getf sample :consed)
                  :gc (getf sample :gc)))
          (measure (lambda () (dotimes (i calls) (funcall thunk))) repetitions)))

(defun run-evaluation-state-benchmarks (repetitions)
  "Time the search rows and the optimized perft rows with each evaluation state, in the passes
of EVALUATION-STATE-PASS-ORDER, REPETITIONS samples per pass. Return the row plists: for each
kind (:SEARCH, then :PERFT), each position, each state. The hot path is left compiled with the
build's state."
  (let* ((build-state scf-opt:*evaluation-state*)
         (signature (scf-test:read-search-signature))
         (depth (getf signature :depth))
         (calls (make-hash-table :test #'equal))
         (passes (make-hash-table :test #'equal)))
    (flet ((time-row (key thunk seconds)
             ;; An untimed warm-up call in every pass; the first pass of a row also calibrates.
             (funcall thunk)
             (unless (gethash key calls)
               (setf (gethash key calls) (calibrated-calls thunk seconds)))
             (push (per-call-samples thunk (gethash key calls) repetitions)
                   (gethash key passes))))
      (unwind-protect
           (progn
             (dolist (state scf-opt:*evaluation-states*)
               (compile-state-hot-path state))
             (dolist (state (evaluation-state-pass-order))
               (load-state-hot-path state)
               (let ((context (scf-opt:make-bitboard-search-context depth)))
                 (dolist (name *search-benchmarks*)
                   (destructuring-bind (name fen &key score nodes &allow-other-keys)
                       (signature-entry signature name)
                     (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:parse-fen fen))))
                       (time-row (list :search state name)
                                 (lambda () (checked-search context bbp depth score nodes name))
                                 *search-sample-seconds*)))))
               (loop for (name perft-depth) in *perft-benchmarks*
                     do (let ((fen (scf-ref:standard-position-fen name))
                              (expected (scf-test:main-perft-count name perft-depth))
                              (row-name name)
                              (row-depth perft-depth))
                          (time-row (list :perft state name)
                                    (lambda ()
                                      (checked-perft :optimized row-name fen row-depth expected))
                                    *perft-sample-seconds*)))))
        (compile-state-hot-path build-state)))
    (loop for (kind names) in (list (list :search *search-benchmarks*)
                                    (list :perft (mapcar #'first *perft-benchmarks*)))
          append (loop for name in names
                       append (loop for state in scf-opt:*evaluation-states*
                                    collect (let* ((key (list kind state name))
                                                   (pass-list (reverse (gethash key passes)))
                                                   (samples (reduce #'append pass-list)))
                                              (multiple-value-bind (median minimum maximum)
                                                  (spread samples :cpu)
                                                (list :kind kind :state state :name name
                                                      :calls (gethash key calls)
                                                      :median-cpu median :min-cpu minimum
                                                      :max-cpu maximum
                                                      :pass-medians
                                                      (mapcar (lambda (pass) (spread pass :cpu))
                                                              pass-list)
                                                      :consed-bytes (total samples :consed)
                                                      :gc-seconds (total samples :gc)))))))))

(defun evaluation-state-verdict (results)
  "The outcome of the decision rule of EXP-0002 (section 1) on the search rows of RESULTS: the
keyword :A-FASTER when, in every search row, the maximum of the first state of
SCF-OPT:*EVALUATION-STATES* is below the minimum of the second and its median is below the
second's in each of the two passes; :B-FASTER with the roles exchanged; :NOT-DISTINGUISHABLE
otherwise."
  (destructuring-bind (a b) scf-opt:*evaluation-states*
    (labels ((row (state name)
               (find-if (lambda (row) (and (eq (getf row :kind) :search)
                                           (eq (getf row :state) state)
                                           (string= (getf row :name) name)))
                        results))
             (faster-p (x y)
               (every (lambda (name)
                        (let ((rx (row x name)) (ry (row y name)))
                          (and (< (getf rx :max-cpu) (getf ry :min-cpu))
                               (every #'< (getf rx :pass-medians) (getf ry :pass-medians)))))
                      *search-benchmarks*)))
      (cond ((faster-p a b) :a-faster)
            ((faster-p b a) :b-faster)
            (t :not-distinguishable)))))

