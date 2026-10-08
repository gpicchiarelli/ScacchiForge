;;;; search-variants-bench.lisp -- the searches of Phase 3 of the optimized layer, and the cost of
;;;; a lookup in its transposition table (docs/misure.md: hit rate, lookup cost, several sizes
;;;; and replacement policies, the ordering's efficiency apart; no assumption that more memory
;;;; does better).
;;;;
;;;; Search rows. Iterative deepening to the depth of the search signature, one thread, on a few
;;;; positions of the signature, with each configuration of *SEARCH-VARIANTS*: the baseline
;;;; alpha-beta, alpha-beta with the ordering of Phase 3, PVS and NegaScout with it, and PVS with
;;;; transposition tables of several sizes and policies in normal mode, one in verification mode
;;;; (the default search as the signature records it) and one without ordering. Every call starts
;;;; from a cleared table; the clearing is not timed. Each call is checked: the value of every
;;;; configuration but those with a table in normal mode must be the value the signature records,
;;;; and the node count of every call must be that of the first call of its row; the default
;;;; search must give the node count the signature records. A table in normal mode may cut on a
;;;; deeper entry, so its value is printed, with whether it is the alpha-beta value. The rows run
;;;; in two passes, the configurations in order and then in reverse, each row with an untimed
;;;; warm-up call and the timed samples; a sample makes as many calls as a calibration call says
;;;; reach *VARIANT-SAMPLE-SECONDS* of CPU. Printed per row: nodes (the root, interior nodes and
;;;; leaves of every iteration), CPU seconds per search (median, min and max over both passes,
;;;; and the median of each pass), nodes per CPU second, and from one untimed call the
;;;; ordering's efficiency (the share of beta cutoffs made by the first move, and beta cutoffs
;;;; over the nodes below the root that searched a move), the re-searches, the share of nodes
;;;; whose observed type was the expected one, and the table's hit rate (hits over probes), the
;;;; share of probes with a usable depth, and its cutoffs. The searches allocate their lists
;;;; (iterations, variations, statistics) once per iteration, and the harness times each call
;;;; on its own: the KiB column counts both.
;;;;
;;;; Lookup rows. Tables of several sizes in normal mode, and one in verification mode, each
;;;; filled with seeded random legal positions (seed :TT-LOOKUP): the cost of a store, of a probe
;;;; of the stored positions (a hit unless the position was replaced) and of a probe of other
;;;; random positions (seed :TT-MISS, nearly all misses), in nanoseconds per operation from CPU
;;;; time, the call included. The tables run in two passes, in order and in reverse.
;;;;
;;;; Every figure is a measurement of this machine at this moment. Which configuration is better
;;;; the rows do not say: nodes, time and hit rate pull in different directions, and none of them
;;;; is playing strength (docs/misure.md, "Gerarchia delle metriche").

(in-package #:scacchiforge.bench)

(defparameter *variant-positions* '("kiwipete" "quiet-italian" "tactical-knight-takes-f7")
  "The positions of the search signature on which the configurations are timed, by name.")

(defparameter *variant-sample-seconds* 0.2d0
  "The CPU time a timed sample of a search-variant row lasts at least.")

(defparameter *search-variants*
  `(("alpha-beta" :alpha-beta nil nil)
    ("alpha-beta, ordered" :alpha-beta t nil)
    ("PVS, ordered" :pvs t nil)
    ("NegaScout, ordered" :negascout t nil)
    ("PVS, ordered, TT 2^16 two-slot verif." :pvs t (:entries 65536 :policy :two-slot
                                                      :mode :verification))
    ("PVS, ordered, TT 2^10 two-slot" :pvs t (:entries 1024 :policy :two-slot :mode :normal))
    ("PVS, ordered, TT 2^16 two-slot" :pvs t (:entries 65536 :policy :two-slot :mode :normal))
    ("PVS, ordered, TT 2^20 two-slot" :pvs t (:entries 1048576 :policy :two-slot
                                               :mode :normal))
    ("PVS, ordered, TT 2^16 depth-pref." :pvs t (:entries 65536 :policy :depth-preferred
                                                  :mode :normal))
    ("PVS, ordered, TT 2^16 always" :pvs t (:entries 65536 :policy :always :mode :normal))
    ("PVS, TT 2^16 two-slot" :pvs nil (:entries 65536 :policy :two-slot :mode :normal)))
  "The configurations of the search-variant rows: (label algorithm ordering table), the table a
property list for MAKE-BITBOARD-TRANSPOSITION-TABLE or NIL. The fifth is the default search of
Phase 3 as the signature records it (SCF-OPT:*BITBOARD-DEFAULT-SEARCH*, verification mode).")

(defparameter *lookup-tables*
  '((:entries 1024 :policy :two-slot :mode :normal)
    (:entries 65536 :policy :two-slot :mode :normal)
    (:entries 1048576 :policy :two-slot :mode :normal)
    (:entries 65536 :policy :depth-preferred :mode :normal)
    (:entries 65536 :policy :two-slot :mode :verification))
  "The tables of the lookup rows, as property lists for MAKE-BITBOARD-TRANSPOSITION-TABLE.")

(defparameter *lookup-positions* 4096
  "How many seeded random legal positions the lookup rows store and probe.")

(defparameter *lookup-sample-seconds* 0.1d0
  "The CPU time a timed sample of a lookup row lasts at least.")

(defun table-label (plist)
  "A short label of the table property list PLIST."
  (destructuring-bind (&key entries policy mode) plist
    (format nil "2^~D ~(~A~)~:[~; verif.~]" (1- (integer-length entries)) policy
            (eq mode :verification))))

(defun default-variant-p (variant)
  "True when VARIANT is the default search of Phase 3 as the signature records it."
  (destructuring-bind (label algorithm ordering table) variant
    (declare (ignore label))
    (destructuring-bind (&key driver ((:algorithm default-algorithm)) ((:ordering default-ordering))
                           tt-entries tt-policy)
        scf-opt:*bitboard-default-search*
      (and (eq driver :iterative-deepening) (eq algorithm default-algorithm)
           (eq ordering default-ordering) table
           (= (getf table :entries) tt-entries) (eq (getf table :policy) tt-policy)
           (eq (getf table :mode) :verification)))))

(defun timed-calls (setup thunk calls)
  "A sample of CALLS calls of THUNK, each after an untimed call of SETUP: :CPU, the CPU seconds
per call of THUNK, and the bytes consed and GC seconds of the THUNK calls. Each call is timed
on its own, so the bytes consed include the harness's counters of every call."
  (let ((cpu 0) (consed 0) (gc 0))
    (dotimes (i calls)
      (funcall setup)
      (let ((start (counters)))
        (funcall thunk)
        (let ((sample (counters-since start)))
          (incf cpu (getf sample :cpu))
          (incf consed (getf sample :consed))
          (incf gc (getf sample :gc)))))
    (list :cpu (/ cpu calls) :consed consed :gc gc)))

(defun safe-ratio (numerator denominator)
  "NUMERATOR / DENOMINATOR as a float, or NIL when DENOMINATOR is zero."
  (and (plusp denominator) (/ numerator (float denominator 1d0))))

(defun variant-row-statistics (statistics)
  "The figures of a search-variant row taken from the STATISTICS of one search."
  (let* ((types (getf statistics :node-types))
         (nodes (reduce #'+ types :key #'third))
         (tt (getf statistics :tt)))
    (list :first-move-rate (safe-ratio (getf statistics :first-move-cutoffs)
                                  (getf statistics :beta-cutoffs))
          :cutoff-rate (safe-ratio (getf statistics :beta-cutoffs) (getf statistics :cutoff-nodes))
          :re-searches (getf statistics :re-searches)
          :agreement (safe-ratio (loop for (expected observed count) in types
                                  when (eq expected observed) sum count)
                            nodes)
          :hit-rate (and tt (safe-ratio (getf tt :hits) (getf tt :probes)))
          :usable-rate (and tt (safe-ratio (getf tt :usable-hits) (getf tt :probes)))
          :tt-cutoffs (and tt (getf tt :cutoffs)))))

(defun run-search-variant-benchmarks (repetitions)
  "Time the search-variant rows, REPETITIONS samples per pass; return the row plists."
  (let* ((signature (scf-test:read-search-signature))
         (depth (getf signature :depth))
         (context (scf-opt:make-bitboard-search-context depth))
         (rows (make-hash-table :test #'equal))
         (passes (make-hash-table :test #'equal)))
    (labels ((entry (key name)
               (or (find name (getf signature key) :key #'first :test #'string=)
                   (error "the search signature has no position ~S" name)))
             (prepare (variant name)
               ;; The row: its table, position, thunks, checks and, from a calibration call, its
               ;; statistics and the calls a sample makes.
               (destructuring-bind (label algorithm ordering table-plist) variant
                 (let* ((fen (second (entry :entries name)))
                        (score (getf (cddr (entry :entries name)) :score))
                        (default-nodes (getf (cddr (entry :default-entries name)) :nodes))
                        (bbp (scf-opt:bitboard-from-reference (scf-ref:parse-fen fen)))
                        (table (and table-plist
                                    (apply #'scf-opt:make-bitboard-transposition-table
                                           table-plist)))
                        (normal (and table-plist (eq (getf table-plist :mode) :normal)))
                        (expected-nodes (and (default-variant-p variant) default-nodes))
                        (found-score nil)
                        (found-nodes nil)
                        (statistics nil))
                   (labels ((setup ()
                              (when table
                                (scf-opt:bitboard-tt-clear table)))
                            (run (node-types)
                              ;; With NODE-TYPES the baseline alpha-beta runs as the node of
                              ;; Phase 3, which visits the same nodes and counts their types.
                              (multiple-value-bind (s m n iterations line stats)
                                  (scf-opt:bitboard-iterative-deepening
                                   bbp depth :algorithm algorithm :ordering ordering :tt table
                                             :node-types node-types :context context)
                                (declare (ignore m iterations line))
                                (unless (or normal (= s score))
                                  (error "~A on ~A gave ~D; the signature says ~D" label name s
                                         score))
                                (unless (or (null expected-nodes) (= n expected-nodes))
                                  (error "~A on ~A visited ~D nodes; the signature says ~D"
                                         label name n expected-nodes))
                                (unless (or (null found-nodes) (= n found-nodes))
                                  (error "~A on ~A visited ~D nodes, then ~D" label name
                                         found-nodes n))
                                (setf found-score s
                                      found-nodes n)
                                stats))
                            (search-once ()
                              (run nil)))
                     (setup)
                     (setf statistics (run t))
                     (setup)
                     (search-once)
                     (let ((calls (max 1 (ceiling *variant-sample-seconds*
                                                  (max 1d-4 (getf (timed-calls #'setup
                                                                               #'search-once 1)
                                                                  :cpu))))))
                       (setf (gethash (list label name) rows)
                             (append (list :label label :name name :depth depth :calls calls
                                           :nodes found-nodes :score found-score
                                           :alpha-beta-value-p (= found-score score)
                                           :setup #'setup :search #'search-once)
                                     (variant-row-statistics statistics)))))))))
      (dolist (variant *search-variants*)
        (dolist (name *variant-positions*)
          (prepare variant name)))
      (dolist (variant (append *search-variants* (reverse *search-variants*)))
        (dolist (name *variant-positions*)
          (let* ((row (gethash (list (first variant) name) rows))
                 (setup (getf row :setup))
                 (search (getf row :search)))
            (funcall setup)
            (funcall search)
            (push (loop repeat repetitions
                        collect (timed-calls setup search (getf row :calls)))
                  (gethash (list (first variant) name) passes)))))
      (loop for (label) in *search-variants*
            append (loop for name in *variant-positions*
                         collect (let* ((key (list label name))
                                        (row (gethash key rows))
                                        (pass-list (reverse (gethash key passes)))
                                        (samples (reduce #'append pass-list)))
                                   (multiple-value-bind (median minimum maximum)
                                       (spread samples :cpu)
                                     (append
                                      (list :median-cpu median :min-cpu minimum
                                            :max-cpu maximum
                                            :pass-medians (mapcar (lambda (pass)
                                                                    (spread pass :cpu))
                                                                  pass-list)
                                            :nodes-per-cpu-second
                                            (and (plusp median) (/ (getf row :nodes) median))
                                            :consed-bytes (total samples :consed)
                                            :gc-seconds (total samples :gc))
                                      (loop for (key value) on row by #'cddr
                                            unless (member key '(:setup :search))
                                              append (list key value))))))))))

(defun lookup-inputs (seed)
  "*LOOKUP-POSITIONS* seeded random legal positions, from SEED, as a vector of bitboard
positions."
  (let ((rng (make-rng seed))
        (starts (mapcar #'cdr scf-ref:*standard-positions*)))
    (coerce (loop repeat *lookup-positions*
                  collect (scf-opt:bitboard-from-reference
                           (scf-ref:random-legal-position starts rng 120)))
            'simple-vector)))

(defun store-pass (table positions)
  "Store every position of POSITIONS in TABLE (depth 1, score 0, exact, no move)."
  (declare (type simple-vector positions))
  (loop for bbp across positions
        do (scf-opt:bitboard-tt-store table bbp 1 0 scf-opt:+bitboard-tt-exact+ +no-move+))
  nil)

(defun probe-pass (table positions)
  "Probe TABLE with every position of POSITIONS; return how many were found."
  (declare (type simple-vector positions))
  (loop for bbp across positions
        count (>= (scf-opt:bitboard-tt-probe table bbp) 0)))

(defun lookup-operation-figures (pass-list)
  "The figures of one operation of a lookup row from its PASS-LIST, a list of passes, each a
list of samples: the median in nanoseconds per operation over every sample, the median of each
pass, and the bytes consed."
  (let ((samples (reduce #'append pass-list)))
    (flet ((nanoseconds (seconds)
             (* 1d9 (/ seconds *lookup-positions*))))
      (list :median-ns (nanoseconds (spread samples :cpu))
            :pass-medians-ns (mapcar (lambda (pass) (nanoseconds (spread pass :cpu))) pass-list)
            :consed-bytes (total samples :consed)))))

(defun run-lookup-benchmarks (repetitions)
  "Time the lookup rows, REPETITIONS samples per pass; return the row plists."
  (let ((stored (lookup-inputs (input-seed :tt-lookup)))
        (others (lookup-inputs (input-seed :tt-miss)))
        (rows '())
        (calls (make-hash-table :test #'equal))
        (passes (make-hash-table :test #'equal))
        (operations '(:store :probe-stored :probe-others)))
    (dolist (plist *lookup-tables*)
      (let ((table (apply #'scf-opt:make-bitboard-transposition-table plist)))
        (store-pass table stored)
        (push (list :label (table-label plist) :table table
                    :found (probe-pass table stored) :found-others (probe-pass table others))
              rows)))
    (setf rows (nreverse rows))
    (dolist (row (append rows (reverse rows)))
      (let ((table (getf row :table)))
        (dolist (operation operations)
          (let ((key (list (getf row :label) operation))
                (thunk (ecase operation
                         (:store (lambda () (store-pass table stored)))
                         (:probe-stored (lambda () (probe-pass table stored)))
                         (:probe-others (lambda () (probe-pass table others))))))
            ;; An untimed warm-up call; the first pass also calibrates. A sample times its calls
            ;; together (PER-CALL-SAMPLES, search-bench.lisp), so that the bytes consed are
            ;; those of the operations, not of the harness.
            (funcall thunk)
            (unless (gethash key calls)
              (setf (gethash key calls) (calibrated-calls thunk *lookup-sample-seconds*)))
            (push (per-call-samples thunk (gethash key calls) repetitions)
                  (gethash key passes))))))
    (loop for row in rows
          collect (append (list :label (getf row :label) :found (getf row :found)
                                :found-others (getf row :found-others))
                          (loop for operation in operations
                                append (list operation
                                             (lookup-operation-figures
                                              (reverse (gethash (list (getf row :label)
                                                                      operation)
                                                                passes)))))))))

(defun format-rate (rate)
  "RATE, a fraction or NIL, as a percentage with one decimal, or a dash."
  (if rate (format nil "~,1F" (* 100 rate)) "-"))

(defun print-search-variant-table (results repetitions stream)
  "Print the search-variant rows: the legend of the configurations, the timing and the
efficiency of each row."
  (format stream "~%Searches of Phase 3 of the optimized layer: iterative deepening to depth ~D, ~
                  one thread, the~%classical evaluation, a cleared table before each call (not ~
                  timed). The value of every~%configuration but those with a table in normal ~
                  mode is checked against the signature, and every~%node count against the first ~
                  call of its row; the default search (5) against the signature's.~%Two ~
                  passes, the configurations in order then in reverse, ~D sample~:P each; a ~
                  sample~%repeats ~
                  the search CALLS times, enough for ~,1F s of CPU by a calibration call.~%"
          (getf (first results) :depth) repetitions *variant-sample-seconds*)
  (loop for (label) in *search-variants*
        for number from 1
        do (format stream "  ~2D ~A~%" number label))
  (flet ((number-of (row)
           (1+ (position (getf row :label) *search-variants* :key #'first :test #'string=))))
    (format stream "CPU seconds per search; median, min and max over both passes, pass 1 and ~
                    pass 2 the median of~%each. Nodes: root, interior nodes and leaves of every ~
                    iteration. AB: the value is the~%alpha-beta value.~%")
    (print-rule stream)
    (format stream "~3A ~24A ~7@A ~3@A ~9@A ~8@A ~8@A ~8@A ~8@A ~11@A~%" "cfg" "position" "nodes"
            "AB" "CPU s med" "min" "max" "pass 1" "pass 2" "nodes/CPU s")
    (dolist (row results)
      (destructuring-bind (first second &rest others) (getf row :pass-medians)
        (declare (ignore others))
        (format stream "~3D ~24A ~7D ~3@A ~9,5F ~8,5F ~8,5F ~8,5F ~8,5F ~11@A~%"
                (number-of row) (getf row :name) (getf row :nodes)
                (if (getf row :alpha-beta-value-p) "yes" "no")
                (getf row :median-cpu) (getf row :min-cpu) (getf row :max-cpu) first second
                (let ((rate (getf row :nodes-per-cpu-second)))
                  (if rate (format nil "~D" (round rate)) "-")))))
    (format stream "~%Efficiency, from one untimed call of each row. 1st%: beta cutoffs made by ~
                    the first move;~%cut%: beta cutoffs over the nodes below the root that ~
                    searched a move; re: re-searches;~%types%: nodes whose observed type was the ~
                    expected one; hit%: TT hits over probes; use%:~%probes with a usable depth; ~
                    TT cut: cutoffs on an entry. KiB (consed) and GC ms: over the~%timed calls, ~
                    the lists the search returns and the harness's counters of each call ~
                    included.~%")
    (print-rule stream)
    (format stream "~3A ~24A ~6@A ~6@A ~6@A ~7@A ~6@A ~6@A ~7@A ~8@A ~5@A~%" "cfg" "position"
            "1st%" "cut%" "re" "types%" "hit%" "use%" "TT cut" "KiB" "GC ms")
    (dolist (row results)
      (format stream "~3D ~24A ~6@A ~6@A ~6D ~7@A ~6@A ~6@A ~7@A ~8D ~5D~%"
              (number-of row) (getf row :name)
              (format-rate (getf row :first-move-rate)) (format-rate (getf row :cutoff-rate))
              (getf row :re-searches) (format-rate (getf row :agreement))
              (format-rate (getf row :hit-rate)) (format-rate (getf row :usable-rate))
              (or (getf row :tt-cutoffs) "-") (floor (getf row :consed-bytes) 1024)
              (milliseconds (getf row :gc-seconds))))))

(defun print-lookup-table (results repetitions stream)
  "Print the lookup rows: one line per table and operation."
  (format stream "~%Transposition table of the optimized layer: cost of one operation on ~D ~
                  seeded random legal~%positions (seeds ~D and ~D), nanoseconds per operation ~
                  from CPU time, the call included.~%Found: how many of the positions a probe ~
                  finds (the stored ones, or the others). Two passes,~%the tables in order then ~
                  in reverse, ~D sample~:P each; pass 1 and pass 2 are the median of each.~%~
                  KiB: bytes consed by the timed samples of the row.~%"
          *lookup-positions* (input-seed :tt-lookup) (input-seed :tt-miss) repetitions)
  (print-rule stream)
  (format stream "~24A ~14A ~6@A ~9@A ~9@A ~9@A ~8@A~%" "table" "operation" "found" "ns med"
          "pass 1" "pass 2" "KiB")
  (dolist (row results)
    (loop for (operation label found) in (list (list :store "store" nil)
                                               (list :probe-stored "probe stored"
                                                     (getf row :found))
                                               (list :probe-others "probe others"
                                                     (getf row :found-others)))
          do (let ((figures (getf row operation)))
               (destructuring-bind (first second &rest others) (getf figures :pass-medians-ns)
                 (declare (ignore others))
                 (format stream "~24A ~14A ~6@A ~9,1F ~9,1F ~9,1F ~8D~%" (getf row :label) label
                         (or found "-") (getf figures :median-ns) first second
                         (floor (getf figures :consed-bytes) 1024)))))))
