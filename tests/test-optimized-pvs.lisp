;;;; test-optimized-pvs.lisp -- the searches of Phase 3 in the optimized layer: PVS, NegaScout
;;;; and alpha-beta with the move ordering (src/optimized/ordering.lisp), the explicit node types
;;;; and the iterative deepening that hands the principal variation to the next iteration
;;;; (src/optimized/search.lisp).
;;;;
;;;; Suite optimized-pvs. Run without ordering, table or hook but with the node types, the node of
;;;; Phase 3 in alpha-beta mode returns what the baseline returns: value, best move, node count
;;;; and principal variation. PVS and NegaScout, with and without ordering, and alpha-beta with
;;;; ordering, return the value of the baseline alpha-beta at fixed depth on the search positions
;;;; and on seeded random positions, also when the moves of every node are permuted with the
;;;; seeds of *MOVE-ORDER-SEEDS* (tests/test-search.lisp); the reference replays every principal
;;;; variation (PRINCIPAL-VARIATION-PROBLEMS). The ordering follows its rule, which the test
;;;; computes again from the reference's board; the TT move and the PV move come first when they
;;;; are legal, and a move that is not legal takes no place. The node types: their counts add up
;;;; to the nodes, and PVS and NegaScout never observe a PV node where they expected a Cut or an
;;;; All node; with a perfect ordering (every node's moves sorted by their negamax value, a test
;;;; hook) each of the three searches visits exactly the minimal tree of Knuth and Moore, counted
;;;; here independently, and every node has the type it was expected to have. Iterative
;;;; deepening with ordering and the table in verification mode returns at every depth the value
;;;; of the baseline, and the PV move is searched first at every node of the previous line. A
;;;; search of Phase 3 with a preallocated context and table allocates nothing per node.

(in-package #:scacchiforge.test)

;;; --- values -----------------------------------------------------------------------------

(deftest :optimized-pvs the-phase-3-alpha-beta-node-equals-the-baseline
  ;; SEARCH-NODE in alpha-beta mode, with no ordering and no table, generalises
  ;; ALPHA-BETA-NODE: same value, best move, node count and principal variation, also with the
  ;; moves permuted by the same seed (the two nodes draw the permutations in the same order).
  (let ((compared 0))
    (loop for (name . fen) in *search-positions*
          do (loop for depth from 0 to 4
                   do (dolist (seed (list nil (first *move-order-seeds*)))
                        (flet ((run (node-types)
                                 (multiple-value-list
                                  (scf-opt:bitboard-search (optimized-position fen) depth
                                                           :node-types node-types
                                                           :shuffle-rng (and seed
                                                                             (make-rng seed))))))
                          (incf compared)
                          (is-equal (subseq (run nil) 0 4) (subseq (run t) 0 4)
                                    "~A depth ~D seed ~A" name depth seed)))))
    (note "~D searches compared" compared)))

(defun phase-3-value-problems (fen depth algorithm ordering table &optional seed)
  "The problems of the search ALGORITHM of Phase 3, with ORDERING and, when TABLE is true, a
fresh transposition table of 4096 slots in verification mode, of FEN at DEPTH, the moves
permuted by a generator seeded with SEED when SEED is given: its value differs from the
baseline's, its first move is not its best move, or the reference does not accept its line."
  (multiple-value-bind (score move nodes line)
      (phase-3-search fen depth :algorithm algorithm :ordering ordering
                                :tt (and table (scf-opt:make-bitboard-transposition-table
                                                :entries 4096 :mode :verification))
                                :shuffle-rng (and seed (make-rng seed)))
    (declare (ignore nodes))
    (append (search-value-problems (format nil "~(~A~)~:[~; ordered~]~:[~; with a table~]~@[ ~
                                                seed ~D~]"
                                           algorithm ordering table seed)
                                   fen depth score line)
            (unless (eql move (if line (first line) +no-move+))
              (list (format nil "~A depth ~D: the best move is not the first of the line"
                            fen depth))))))

(defun check-phase-3-values (configurations)
  "For each (ALGORITHM ORDERING TABLE) of CONFIGURATIONS: on the search positions at depths 0 to
4, on 40 seeded random positions at depth 3, and permuted with each seed of *MOVE-ORDER-SEEDS*
at depths 1 to 3, the value is the baseline's and the reference accepts the line. Returns the
number of searches."
  (let ((searches 0)
        (random-fens (random-search-fens 20261010 40)))
    (flet ((check (fen depth algorithm ordering table &optional seed)
             (incf searches)
             (incf *assertions*)
             (dolist (problem (phase-3-value-problems fen depth algorithm ordering table seed))
               (record-failure "~A" problem))))
      (loop for (algorithm ordering table) in configurations
            do (loop for (nil . fen) in *search-positions*
                     do (loop for depth from 0 to 4
                              do (check fen depth algorithm ordering table))
                        (dolist (seed *move-order-seeds*)
                          (loop for depth from 1 to 3
                                do (check fen depth algorithm ordering table seed))))
               (dolist (fen random-fens)
                 (check fen 3 algorithm ordering table))))
    searches))

(deftest :optimized-pvs pvs-and-negascout-return-the-alpha-beta-value
  ;; Without a table and, permutations included, with a table in verification mode.
  (note "~D searches compared with alpha-beta"
        (check-phase-3-values '((:pvs nil nil) (:pvs t nil) (:negascout nil nil)
                                (:negascout t nil) (:pvs t t) (:negascout t t)
                                (:pvs nil t) (:negascout nil t)))))

(deftest :optimized-pvs ordering-does-not-change-the-value
  (note "~D searches compared with alpha-beta"
        (check-phase-3-values '((:alpha-beta t nil) (:alpha-beta t t)))))

(deftest :optimized-pvs pvs-and-negascout-differ
  ;; The two names are two searches: on these positions NegaScout re-searches less than PVS (no
  ;; re-search of a child at depth 0, or at depth 1 when it searched its moves), and the node
  ;; counts differ. Without this the tests above could pass with one search run twice.
  (let ((pvs-re-searches 0)
        (negascout-re-searches 0)
        (different 0))
    (loop for (nil . fen) in *search-positions*
          do (let ((pvs (multiple-value-list (phase-3-search fen 4 :algorithm :pvs)))
                   (negascout (multiple-value-list (phase-3-search fen 4 :algorithm :negascout))))
               (incf pvs-re-searches (getf (fifth pvs) :re-searches))
               (incf negascout-re-searches (getf (fifth negascout) :re-searches))
               (unless (= (third pvs) (third negascout))
                 (incf different))))
    (is (< negascout-re-searches pvs-re-searches) "re-searches: PVS ~D, NegaScout ~D"
        pvs-re-searches negascout-re-searches)
    (is (plusp different) "the node counts never differ")
    (note "depth 4, no ordering: PVS ~D re-searches, NegaScout ~D; node counts differ on ~D ~
           positions" pvs-re-searches negascout-re-searches different)))

;;; --- the ordering -----------------------------------------------------------------------

(defun reference-order-key (pos move tt-move pv-move)
  "The order key of MOVE in the reference position POS by the rule of Phase 3
(src/optimized/ordering.lisp), computed again here from the reference's board: TT move, PV move,
captures by victim and attacker, promotions, the rest. Higher first."
  (cond ((eql move tt-move) 400000)
        ((eql move pv-move) 300000)
        ((move-capture-p move)
         (let ((victim (if (move-en-passant-p move)
                           +pawn+
                           (piece-type (scf-ref:piece-at pos (move-to move)))))
               (attacker (piece-type (scf-ref:piece-at pos (move-from move)))))
           (+ 200000 (* 100 victim) (- 10 attacker))))
        ((move-promotion-p move) (+ 100000 (move-promotion move)))
        (t 0)))

(defun expected-order (fen tt-move pv-move)
  "The legal moves of FEN in the order of Phase 3, computed from the definition with the
reference's board, from the generator order of the optimized layer (ties keep it)."
  (let ((pos (fen-position fen))
        (moves (scf-opt:bitboard-legal-moves (optimized-position fen))))
    (stable-sort (copy-list moves) #'>
                 :key (lambda (move) (reference-order-key pos move tt-move pv-move)))))

(deftest :optimized-pvs the-ordering-follows-its-rule
  ;; On the search positions, the positions of the search signature and seeded random positions,
  ;; with no TT or PV move, with a quiet TT move and a PV move, and with a TT move that is not
  ;; legal in the position (a1 to h8): the order is the one the rule gives.
  (let ((checked 0)
        (captures 0)
        (promotions 0)
        (bogus (encode-move 0 63 0 0)))
    (dolist (fen (append (mapcar #'cdr *search-positions*)
                         (mapcar #'second *search-signature-positions*)
                         (random-search-fens 20261011 60)))
      (let* ((bbp (optimized-position fen))
             (moves (scf-opt:bitboard-legal-moves bbp)))
        (incf captures (count-if #'move-capture-p moves))
        (incf promotions (count-if #'move-promotion-p moves))
        (dolist (choice (list (list +no-move+ +no-move+)
                              (list (car (last moves)) (and moves (first moves)))
                              (list bogus (and moves (second moves)))))
          (destructuring-bind (tt-move pv-move) choice
            (let ((tt-move (or tt-move +no-move+))
                  (pv-move (or pv-move +no-move+)))
              (incf checked)
              (is-equal (move-strings (expected-order fen tt-move pv-move))
                        (move-strings (scf-opt:bitboard-ordered-moves bbp :tt-move tt-move
                                                                          :pv-move pv-move))
                        "~A, TT move ~A, PV move ~A" fen (move-to-string tt-move)
                        (move-to-string pv-move)))))))
    (note "~D orders checked, over positions with ~D captures and ~D promotions"
          checked captures promotions)))

(deftest :optimized-pvs the-tt-move-and-the-pv-move-come-first
  ;; A legal TT move is first and a legal PV move second; a TT move that is not legal is not in
  ;; the list, which holds exactly the legal moves.
  (dolist (fen (mapcar #'cdr *search-positions*))
    (let* ((bbp (optimized-position fen))
           (moves (scf-opt:bitboard-legal-moves bbp)))
      (when (>= (length moves) 2)
        (let ((tt-move (car (last moves)))
              (pv-move (second moves)))
          (let ((ordered (scf-opt:bitboard-ordered-moves bbp :tt-move tt-move :pv-move pv-move)))
            (is-eql tt-move (first ordered) "~A: the TT move first" fen)
            (is-eql pv-move (second ordered) "~A: the PV move second" fen)
            (is-set-equal (move-strings moves) (move-strings ordered) "~A: the same moves" fen))
          (let ((ordered (scf-opt:bitboard-ordered-moves bbp :tt-move (encode-move 0 63 0 0)
                                                             :pv-move pv-move)))
            (is-eql pv-move (first ordered) "~A: an illegal TT move takes no place" fen)
            (is-set-equal (move-strings moves) (move-strings ordered) "~A: legal moves" fen))))))
  ;; In iterative deepening with ordering and no table, the PV move is searched first at every
  ;; node of the previous line: at iteration D as many times as the line of D - 1 has moves.
  (loop for (name . fen) in *search-positions*
        do (dolist (algorithm '(:alpha-beta :pvs :negascout))
             (multiple-value-bind (score move nodes iterations line statistics)
                 (scf-opt:bitboard-iterative-deepening (optimized-position fen) 4
                                                       :algorithm algorithm :ordering t)
               (declare (ignore score move nodes line))
               (is-eql (loop for iteration in (butlast iterations)
                             sum (length (getf iteration :pv)))
                       (getf statistics :pv-move-first)
                       "~A ~A: PV moves searched first" name algorithm))))
  ;; With the table in verification mode the TT move is searched first wherever there is one,
  ;; and none is rejected.
  (let ((first-moves 0))
    (loop for (name . fen) in *search-positions*
          do (let ((table (scf-opt:make-bitboard-transposition-table :mode :verification)))
               (multiple-value-bind (score move nodes iterations line statistics)
                   (scf-opt:bitboard-iterative-deepening (optimized-position fen) 4
                                                         :algorithm :pvs :ordering t :tt table)
                 (declare (ignore score move nodes iterations line))
                 (incf first-moves (tt-statistic statistics :move-first))
                 (is-eql 0 (tt-statistic statistics :rejected-moves) "~A" name))))
    (is (plusp first-moves) "no TT move was searched first")))

;;; --- node types -------------------------------------------------------------------------

(defun node-type-count (statistics expected observed)
  "The nodes of STATISTICS expected of type EXPECTED and observed of type OBSERVED."
  (third (find-if (lambda (entry) (and (eq (first entry) expected) (eq (second entry) observed)))
                  (getf statistics :node-types))))

(deftest :optimized-pvs node-type-counts-hold
  ;; Every node is counted once by its pair of types; the root, searched with the full window,
  ;; is a PV node that is observed PV; PVS and NegaScout search every node expected Cut or All
  ;; with a null window, which has no score strictly inside, so none is observed PV. A beta
  ;; cutoff happens only at a node that searched a move, and at most once per node.
  (let ((searches 0)
        (agreement 0)
        (counted 0))
    (loop for (name . fen) in *search-positions*
          do (loop for depth from 1 to 4
                   do (dolist (algorithm '(:alpha-beta :pvs :negascout))
                        (dolist (tt (list nil :verification))
                          (multiple-value-bind (score move nodes line statistics)
                              (phase-3-search
                               fen depth :algorithm algorithm :ordering t :node-types t
                                         :tt (and tt (scf-opt:make-bitboard-transposition-table
                                                      :mode tt)))
                            (declare (ignore score move line))
                            (incf searches)
                            (let ((types (getf statistics :node-types)))
                              (is-eql nodes (reduce #'+ types :key #'third)
                                      "~A ~A depth ~D: the counts add up to the nodes"
                                      name algorithm depth)
                              (incf counted nodes)
                              (incf agreement (loop for (expected observed count) in types
                                                    when (eq expected observed) sum count)))
                            (when (scf-opt:bitboard-legal-moves (optimized-position fen))
                              (is (plusp (node-type-count statistics :pv :pv))
                                  "~A ~A depth ~D: the root" name algorithm depth))
                            (unless (eq algorithm :alpha-beta)
                              (is-equal '(0 0) (list (node-type-count statistics :cut :pv)
                                                     (node-type-count statistics :all :pv))
                                        "~A ~A depth ~D: a null-window node observed PV"
                                        name algorithm depth))
                            (is (<= (getf statistics :first-move-cutoffs)
                                    (getf statistics :beta-cutoffs)
                                    (getf statistics :cutoff-nodes))
                                "~A ~A depth ~D: cutoff counters" name algorithm depth))))))
    (note "~D searches with ordering: ~D nodes, ~D of them of the type they were expected to have"
          searches counted agreement)))

(defun oracle-order (bbp moves depth context)
  "MOVES of BBP sorted by their negamax value at DEPTH - 1 from the child, negated (the value
for the side to move at BBP), best first; equal values keep the order of MOVES. CONTEXT is a
search context for the negamax searches."
  (let ((scored (mapcar (lambda (move)
                          (scf-opt:bitboard-make-move bbp move)
                          (prog1 (cons (- (scf-opt:bitboard-negamax-search bbp (1- depth)
                                                                           :context context))
                                       move)
                            (scf-opt:bitboard-unmake-move bbp)))
                        moves)))
    (mapcar #'cdr (stable-sort scored #'> :key #'car))))

(defun oracle-order-hook (context)
  "An order hook (BITBOARD-SEARCH :ORDER-HOOK) that puts the moves of every node in the order of
ORACLE-ORDER: a perfect ordering, best move first."
  (lambda (bbp buffer start end depth)
    (let ((ordered (oracle-order bbp (loop for index from start below end
                                           collect (aref buffer index))
                                 depth context)))
      (loop for move in ordered
            for index from start
            do (setf (aref buffer index) move)))))

(defun minimal-tree-size (bbp depth type context)
  "The number of nodes of the minimal tree of Knuth and Moore of BBP to DEPTH, the root of TYPE
(:PV, :CUT or :ALL), the moves of every node in the order of ORACLE-ORDER: a PV node has its
first child PV and the others Cut; a Cut node has only its first child, All; an All node has
every child, Cut. A node at depth 0 or without legal moves is a leaf."
  (let ((moves (and (plusp depth) (scf-opt:bitboard-legal-moves bbp))))
    (if (null moves)
        1
        (let ((ordered (oracle-order bbp moves depth context)))
          (flet ((size (move child-type)
                   (scf-opt:bitboard-make-move bbp move)
                   (prog1 (minimal-tree-size bbp (1- depth) child-type context)
                     (scf-opt:bitboard-unmake-move bbp))))
            (1+ (ecase type
                  (:pv (+ (size (first ordered) :pv)
                          (loop for move in (rest ordered) sum (size move :cut))))
                  (:cut (size (first ordered) :all))
                  (:all (loop for move in ordered sum (size move :cut))))))))))

(deftest :optimized-pvs perfect-ordering-searches-the-minimal-tree
  ;; Knuth and Moore (1975): with the best move first at every node, alpha-beta at full window
  ;; visits exactly the minimal tree, in which every PV node searches all its moves, every Cut
  ;; node one, every All node all, and each node has the type the rule gives it before it is
  ;; searched. PVS and NegaScout then never re-search. The test counts the minimal tree on its
  ;; own (MINIMAL-TREE-SIZE) and checks the three searches against it: node count, no node
  ;; whose observed type differs from the expected one, value of the baseline.
  (let ((context (scf-opt:make-bitboard-search-context 6))
        (checked 0))
    (dolist (case '(("startpos" 3) ("pos3" 4) ("back-rank" 3) ("rook-ladder" 4)
                    ("promotion" 4) ("en-passant-pin" 4) ("stalemate" 3) ("fools-mate" 3)
                    ("endgame" 4) ("kiwipete" 2) ("black-to-move" 2)))
      (destructuring-bind (name depth) case
        (let* ((fen (or (cdr (assoc name *search-positions* :test #'string=))
                        (scf-ref:standard-position-fen name)))
               (minimal (minimal-tree-size (optimized-position fen) depth :pv context)))
          (dolist (algorithm '(:alpha-beta :pvs :negascout))
            (multiple-value-bind (score move nodes line statistics)
                (phase-3-search fen depth :algorithm algorithm :node-types t
                                          :order-hook (oracle-order-hook context))
              (declare (ignore move line))
              (incf checked)
              (is-eql minimal nodes "~A ~A depth ~D: nodes of the minimal tree" name algorithm
                      depth)
              (is-eql (baseline-value fen depth) score "~A ~A depth ~D: value" name algorithm
                      depth)
              (is-eql 0 (getf statistics :re-searches) "~A ~A: re-searches" name algorithm)
              (is-equal '() (loop for (expected observed count) in (getf statistics :node-types)
                                  when (and (not (eq expected observed)) (plusp count))
                                    collect (list expected observed count))
                        "~A ~A depth ~D: nodes whose type was not the expected one"
                        name algorithm depth))))))
    (note "~D searches with a perfect ordering compared with the minimal tree" checked)))

;;; --- iterative deepening of Phase 3 -------------------------------------------------------

(deftest :optimized-pvs phase-3-iterative-deepening-returns-the-alpha-beta-value-at-every-depth
  ;; With ordering and the table in verification mode, each iteration hands the next its line
  ;; and its entries; at every depth the value is the baseline's, and the reference replays the
  ;; last line. On the positions with a forced mate the run stops at the mate, with the value
  ;; of the baseline at the full depth.
  (loop for (name . fen) in *search-positions*
        do (dolist (algorithm '(:alpha-beta :pvs :negascout))
             (let ((table (scf-opt:make-bitboard-transposition-table :mode :verification)))
               (multiple-value-bind (score move nodes iterations line)
                   (scf-opt:bitboard-iterative-deepening (optimized-position fen) 4
                                                         :algorithm algorithm :ordering t
                                                         :tt table)
                 (declare (ignore nodes))
                 (dolist (iteration iterations)
                   (is-eql (baseline-value fen (getf iteration :depth)) (getf iteration :score)
                           "~A ~A depth ~D" name algorithm (getf iteration :depth)))
                 (is-eql (baseline-value fen 4) score "~A ~A: the last score" name algorithm)
                 (is-eql (if line (first line) +no-move+) move "~A ~A: best move" name algorithm)
                 (is-equal '() (principal-variation-problems (fen-position fen) (length iterations)
                                                             score line
                                                             #'scf-ref:evaluate-classical)
                           "~A ~A: the last variation" name algorithm))))))

;;; --- arguments and allocation -----------------------------------------------------------

(deftest :optimized-pvs phase-3-search-arguments-are-checked
  (let ((bbp (optimized-position scf-ref:*start-fen*))
        (table (scf-opt:make-bitboard-transposition-table :entries 64)))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :negamax :ordering t))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :negamax :tt table))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :negamax :node-types t))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :mtd-f))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :pvs :tt :table))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :pvs :order-hook 3))
    (is (and (scf-opt:bitboard-equal-p bbp (optimized-position scf-ref:*start-fen*))
             (zerop (scf-opt:bbp-ply bbp)))
        "the refused calls changed nothing")))

(defparameter *phase-3-allocation-runs*
  '(("startpos" 6) ("kiwipete" 5) ("pos3" 7) ("pos4" 5) ("pos5" 5) ("pos6" 5) ("promo" 6))
  "Searches (standard position, depth) of Phase 3 whose allocation is measured. The test prints
how many nodes they visit.")

(deftest :optimized-pvs phase-3-search-allocates-nothing-after-warm-up
  ;; As search-allocates-nothing-after-warm-up (tests/test-optimized-search.lisp), for PVS and
  ;; NegaScout with ordering and a preallocated table in each mode: after a warm-up, more than a
  ;; million nodes and at most 1 MiB consed.
  (let ((context (scf-opt:make-bitboard-search-context 7))
        (tables (list (scf-opt:make-bitboard-transposition-table :mode :verification)
                      (scf-opt:make-bitboard-transposition-table :mode :normal)))
        (runs (loop for (name depth) in *phase-3-allocation-runs*
                    collect (list depth (optimized-position
                                         (scf-ref:standard-position-fen name))))))
    (flet ((run ()
             (let ((nodes 0))
               (dolist (table tables)
                 (scf-opt:bitboard-tt-clear table)
                 (loop for (depth bbp) in runs
                       do (dolist (algorithm '(:pvs :negascout))
                            (incf nodes (nth-value 2 (scf-opt:bitboard-search-with-context
                                                      context bbp depth algorithm
                                                      :ordering t :tt table))))))
               nodes)))
      (run)
      (let* ((before (sb-ext:get-bytes-consed))
             (nodes (run)))
        (let ((consed (- (sb-ext:get-bytes-consed) before)))
          (note "~D nodes searched, ~D bytes consed" nodes consed)
          (is (> nodes 1000000) "enough nodes for the bound to mean something: ~D" nodes)
          (is (<= consed (* 1024 1024)) "~D bytes consed over ~D nodes" consed nodes))))))
