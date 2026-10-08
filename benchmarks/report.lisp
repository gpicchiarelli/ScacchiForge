;;;; report.lisp -- print the environment record and the benchmark tables.

(in-package #:scacchiforge.bench)

(defconstant +report-width+ 98 "Width of the rules and of wrapped record lines.")

(defun print-rule (stream)
  "Print a horizontal rule."
  (format stream "~&~A~%" (make-string +report-width+ :initial-element #\-)))

(defun print-wrapped (stream label text)
  "Print LABEL in a column of 22 characters and TEXT after it, wrapped at +REPORT-WIDTH+
on spaces; continuation lines are indented to the text column."
  (let* ((indent 22)
         (column indent)
         (first-word t))
    (format stream "~vA" indent label)
    (dolist (word (uiop:split-string text :separator " "))
      (when (plusp (length word))
        (cond (first-word (setf first-word nil))
              ((> (+ column 1 (length word)) +report-width+)
               (format stream "~%~vA" indent "")
               (setf column indent))
              (t (write-char #\Space stream)
                 (incf column)))
        (write-string word stream)
        (incf column (length word))))
    (terpri stream)))

(defun print-record (record stream)
  "Print the environment RECORD, a list of (LABEL . TEXT) and (LABEL . LIST-OF-LINES)."
  (format stream "~%Environment record~%")
  (print-rule stream)
  (loop for (label . value) in record
        do (if (listp value)
               (loop for line in value
                     for first = t then nil
                     do (print-wrapped stream (if first label "") line))
               (print-wrapped stream label value))))

(defun milliseconds (seconds)
  "SECONDS as a rounded number of milliseconds."
  (round (* 1000 seconds)))

(defun print-perft-table (results repetitions stream)
  "Print the perft results, one table per engine, the median of each pass of the optimized
rows, and the FEN of each position."
  (format stream "~%Perft, one thread. Times are per perft call: a timed sample repeats the call ~
                  CALLS times, enough~%for ~,1F s of CPU by a calibration call. Leaf nodes per ~
                  CPU second = leaf nodes / median CPU s.~%"
          *perft-sample-seconds*)
  (format stream "The reference runs one pass of ~D sample~:P per row; the optimized layer two ~
                  passes per slider~%implementation, ~D sample~:P each, in the order:~{ ~(~A~)~}.~%~
                  Its median, min and max are over both passes. Each call builds its position ~
                  and its move~%buffer: KiB (consed) and GC ms are the sums over every timed ~
                  call of a row.~%"
          repetitions repetitions (slider-pass-order))
  (loop for (engine slider label) in (perft-engines)
        do (format stream "~%~@(~A~)~%" label)
           (print-rule stream)
           (format stream "~10A ~5@A ~10@A ~5@A ~9@A ~8@A ~8@A ~9@A ~11@A ~8@A ~5@A~%"
                   "position" "depth" "nodes" "calls" "CPU s med" "min" "max" "wall med"
                   "nodes/CPU s" "KiB" "GC ms")
           (dolist (row results)
             (when (and (eq (getf row :engine) engine) (eq (getf row :slider) slider))
               (format stream "~10A ~5D ~10D ~5D ~9,5F ~8,5F ~8,5F ~9,5F ~11@A ~8D ~5D~%"
                       (getf row :name) (getf row :depth) (getf row :nodes) (getf row :calls)
                       (getf row :median-cpu) (getf row :min-cpu) (getf row :max-cpu)
                       (getf row :median-wall)
                       (let ((rate (getf row :nodes-per-cpu-second)))
                         (if rate (format nil "~D" (round rate)) "-"))
                       (floor (getf row :consed-bytes) 1024)
                       (milliseconds (getf row :gc-seconds))))))
  (format stream "~%Optimized layer: median CPU s per call in each pass, in run order, and the ~
                  second over the first.~%")
  (print-rule stream)
  (format stream "~12A ~10A ~10@A ~10@A ~8@A~%" "sliders" "position" "pass 1" "pass 2"
          "2 / 1")
  (dolist (row results)
    (when (eq (getf row :engine) :optimized)
      (destructuring-bind (first second &rest others) (getf row :pass-medians)
        (declare (ignore others))
        (format stream "~12A ~10A ~10,5F ~10,5F ~8,3F~%" (string-downcase (getf row :slider))
                (getf row :name) first second (if (plusp first) (/ second first) 0)))))
  (format stream "~%")
  (dolist (row (remove-duplicates results :key (lambda (row) (getf row :name)) :from-end t))
    (format stream "~10A ~A~%" (getf row :name) (getf row :fen))))

(defun print-micro-table (results repetitions stream)
  "Print the microbenchmark results."
  (format stream "~%Bit utilities (~D seeded random words per pass). Nanoseconds per operation ~
                  from CPU time.~%" +micro-values+)
  (format stream "Consed KiB and GC ms are the sums over the ~D timed call~:P of a row.~%"
          repetitions)
  (print-rule stream)
  (format stream "~24A ~11@A ~8@A ~7@A ~7@A ~10@A ~6@A ~17@A~%" "operation" "operations"
          "ns med" "min" "max" "consed KiB" "GC ms" "one-pass checksum")
  (dolist (row results)
    (format stream "~24A ~11D ~8,2F ~7,2F ~7,2F ~10D ~6D ~17@A~%"
            (getf row :label) (getf row :operations) (getf row :median-ns)
            (getf row :min-ns) (getf row :max-ns) (floor (getf row :consed-bytes) 1024)
            (milliseconds (getf row :gc-seconds)) (format nil "~16,'0X" (getf row :checksum)))))

(defun print-slider-table (results repetitions stream)
  "Print the slider-attack results."
  (format stream "~%Slider attacks of the optimized layer, by implementation (~D seeded (square, ~
                  occupancy)~%pairs per pass: the square uniform, the occupancy the AND of two ~
                  random words, 16 squares~%on average). Kernels compiled with ~(~S~).~%~
                  Nanoseconds per attack from CPU time; attacks per CPU second = 1 / median ~
                  CPU s per attack.~%Consed KiB and GC ms are the sums over the ~D timed ~
                  call~:P of a row.~%"
          +micro-values+ (cons 'optimize scf-opt:*optimized-policy*) repetitions)
  (print-rule stream)
  (format stream "~19A ~10@A ~6@A ~5@A ~5@A ~13@A ~10@A ~5@A ~16@A~%" "attacks" "operations"
          "ns med" "min" "max" "attacks/CPU s" "consed KiB" "GC ms" "one-pass sum")
  (dolist (row results)
    (format stream "~19A ~10D ~6,2F ~5,2F ~5,2F ~13@A ~10D ~5D ~16@A~%"
            (getf row :label) (getf row :operations) (getf row :median-ns)
            (getf row :min-ns) (getf row :max-ns)
            (let ((ns (getf row :median-ns)))
              (if (plusp ns) (format nil "~D" (round 1d9 ns)) "-"))
            (floor (getf row :consed-bytes) 1024)
            (milliseconds (getf row :gc-seconds)) (format nil "~16,'0X" (getf row :checksum))))
  (format stream "PEXT (BMI2) is not measured: portable SBCL gives no access to the ~
                  instruction without native~%code, which the specification admits only ~
                  under five conditions (ADR-0001). Machine type: ~A.~%"
          (machine-type)))

(defun print-search-table (results repetitions stream)
  "Print the search rows."
  (format stream "~%Search of the optimized layer: alpha-beta at fixed depth, one thread, no ~
                  transposition table,~%no move ordering, the classical evaluation. Each call is ~
                  checked against the value and the node~%count of tests/search-signature.sexp. ~
                  A timed sample repeats the search CALLS times, enough~%for ~,1F s of CPU by a ~
                  calibration call; ~D sample~:P per row. Times are CPU seconds per search.~%~
                  Nodes/CPU s = search nodes (root, interior nodes and leaves) / median CPU s. KiB ~
                  (consed)~%and GC ms are the sums over every timed call.~%"
          *search-sample-seconds* repetitions)
  (print-rule stream)
  (format stream "~24A ~5@A ~7@A ~5@A ~9@A ~8@A ~8@A ~11@A ~6@A ~5@A~%"
          "position" "depth" "nodes" "calls" "CPU s med" "min" "max" "nodes/CPU s" "KiB"
          "GC ms")
  (dolist (row results)
    (format stream "~24A ~5D ~7D ~5D ~9,5F ~8,5F ~8,5F ~11@A ~6D ~5D~%"
            (getf row :name) (getf row :depth) (getf row :nodes) (getf row :calls)
            (getf row :median-cpu) (getf row :min-cpu) (getf row :max-cpu)
            (let ((rate (getf row :nodes-per-cpu-second)))
              (if rate (format nil "~D" (round rate)) "-"))
            (floor (getf row :consed-bytes) 1024)
            (milliseconds (getf row :gc-seconds))))
  (format stream "~%")
  (dolist (row results)
    (format stream "~24A ~A~%" (getf row :name) (getf row :fen))))

(defun print-evaluation-table (results repetitions stream)
  "Print the evaluation rows."
  (format stream "~%Classical evaluation, cost of one call, on ~D seeded random legal positions ~
                  (seed ~D); a call~%evaluates one of them. Before timing, the three rows gave ~
                  the same sum of scores, ~D.~%Nanoseconds per call from CPU time, the call ~
                  included. A sample makes CALLS calls, enough for~%~,1F s of CPU by a ~
                  calibration pass. The rows run in two interleaved passes, ~D sample~:P each, ~
                  in~%the order A B C C B A (the rows top to bottom, then bottom to top); ~
                  median, min and max are over~%both passes, and pass 1 and pass 2 are the ~
                  median of each: a drift during the run shows there.~%Consed KiB and GC ms are ~
                  the sums over the timed samples of a row. The difference between two~%rows is ~
                  a measurement of this machine at this moment.~%"
          *evaluation-positions* (input-seed :evaluation) (getf (first results) :checksum)
          *evaluation-sample-seconds* repetitions)
  (print-rule stream)
  (format stream "~28A ~7@A ~8@A ~8@A ~8@A ~8@A ~8@A ~8@A ~5@A~%" "evaluation" "calls"
          "ns med" "min" "max" "pass 1" "pass 2" "KiB" "GC ms")
  (dolist (row results)
    (destructuring-bind (first second &rest others) (getf row :pass-medians-ns)
      (declare (ignore others))
      (format stream "~28A ~7D ~8,1F ~8,1F ~8,1F ~8,1F ~8,1F ~8D ~5D~%"
              (getf row :label) (getf row :calls) (getf row :median-ns) (getf row :min-ns)
              (getf row :max-ns) first second (floor (getf row :consed-bytes) 1024)
              (milliseconds (getf row :gc-seconds))))))

(defun print-evaluation-state-table (results repetitions stream)
  "Print the evaluation-state rows of EXP-0002 and the outcome of its decision rule."
  (destructuring-bind (a b) scf-opt:*evaluation-states*
    (format stream "~%Evaluation state of the optimized layer, research/exp-0002 (A = ~(~A~), the ~
                    build's default;~%B = ~(~A~)). The hot path is compiled once per state and the ~
                    rows run in passes in the~%order~{ ~(~A~)~}, ~D sample~:P each;~%median, ~
                    min and max are over both passes of a state, pass 1 and pass 2 the median of ~
                    each.~%~
                    Every search is checked against the signature and every perft~%against its ~
                    count. CPU seconds per call. Measurements of this machine at this moment.~%"
            a b (evaluation-state-pass-order) repetitions))
  (print-rule stream)
  (format stream "~6A ~24A ~12A ~5@A ~9@A ~8@A ~8@A ~9@A ~9@A ~6@A ~5@A~%" "kind" "position"
          "state" "calls" "CPU s med" "min" "max" "pass 1" "pass 2" "KiB" "GC ms")
  (dolist (row results)
    (destructuring-bind (first second &rest others) (getf row :pass-medians)
      (declare (ignore others))
      (format stream "~6A ~24A ~12A ~5D ~9,5F ~8,5F ~8,5F ~9,5F ~9,5F ~6D ~5D~%"
              (string-downcase (getf row :kind)) (getf row :name)
              (string-downcase (getf row :state)) (getf row :calls) (getf row :median-cpu)
              (getf row :min-cpu) (getf row :max-cpu) first second
              (floor (getf row :consed-bytes) 1024) (milliseconds (getf row :gc-seconds)))))
  (format stream "Decision rule of research/exp-0002, section 1, on the search rows of this ~
                  run: ~A.~%"
          (ecase (evaluation-state-verdict results)
            (:a-faster "A faster than B")
            (:b-faster "B faster than A")
            (:not-distinguishable "the difference is not distinguishable"))))

(defun run-benchmarks (&key (stream *standard-output*) (repetitions (repetitions-setting)))
  "Run all benchmarks and print the environment record and the results to STREAM.
Returns NIL."
  (let ((start-time (get-universal-time))
        (start (counters)))
    (format stream "~&ScacchiForge benchmark~%")
    (print-rule stream)
    (format stream "These are measurements of this machine at this moment. They are not results~%")
    (format stream "of the project and not targets, and they say nothing about playing strength.~%")
    (print-record (environment-record :start-time start-time :repetitions repetitions) stream)
    (finish-output stream)
    (print-perft-table (run-perft-benchmarks repetitions) repetitions stream)
    (finish-output stream)
    (print-search-table (run-search-benchmarks repetitions) repetitions stream)
    (finish-output stream)
    (print-evaluation-table (run-evaluation-benchmarks repetitions) repetitions stream)
    (finish-output stream)
    (print-evaluation-state-table (run-evaluation-state-benchmarks repetitions) repetitions stream)
    (finish-output stream)
    (print-micro-table (run-micro-benchmarks repetitions) repetitions stream)
    (finish-output stream)
    (print-slider-table (run-slider-benchmarks repetitions) repetitions stream)
    (print-rule stream)
    (format stream "Checksums of rows that compute the same quantity must be equal; the harness~%")
    (format stream "checked this before timing.~%")
    (let ((whole (counters-since start)))
      (format stream "Whole run, record included: CPU ~,2F s, wall ~,2F s, ~D KiB consed, ~D ms ~
                      of GC.~%"
              (getf whole :cpu) (getf whole :wall) (floor (getf whole :consed) 1024)
              (milliseconds (getf whole :gc))))
    (format stream "Load average at the end: ~A (at the start: in the environment record).~%"
            (load-average))
    (finish-output stream)
    nil))
