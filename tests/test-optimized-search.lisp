;;;; test-optimized-search.lisp -- the search baselines of the optimized layer (negamax,
;;;; alpha-beta, iterative deepening: src/optimized/search.lisp), their comparison with the
;;;; reference's searches, and the first search signature.
;;;;
;;;; Suite optimized-search: the gate checks of Phase 2 (docs/roadmap.md) on this layer, as
;;;; tests/test-search.lisp makes them on the reference. Alpha-beta and negamax return the same
;;;; value, the same best move and the same principal variation at depths 0 to 3 on the search
;;;; positions; the value does not change when the moves of every node are permuted with a
;;;; declared seed; iterative deepening at depth d returns what the direct search at d returns.
;;;; Mate scores are relative to the ply. A search with a preallocated context allocates nothing
;;;; after a warm-up. The search signature recorded in tests/search-signature.sexp is recomputed
;;;; and compared, value, best move, node count and principal variation, for its two searches:
;;;; the baseline alpha-beta of Phase 2 and the default search of Phase 3
;;;; (SCF-OPT:*BITBOARD-DEFAULT-SEARCH*, with the table in verification mode), whose values must
;;;; be equal.
;;;;
;;;; The reference checks principal variations of this layer (PRINCIPAL-VARIATION-PROBLEMS,
;;;; tests/test-search.lisp): each one is replayed through the reference position read from the
;;;; FEN, its moves must be legal for the reference, and it must lead to the score, by the
;;;; reference's classical evaluation at its end, or by a checkmate at the ply a mate score
;;;; states, or by a stalemate. In MAKE TEST, every variation of these searches: on the search
;;;; positions, alpha-beta at depths 0 to 4 and negamax at depths 0 to 3 in generation order
;;;; (principal-variation-leads-to-the-score), alpha-beta at depths 1 to 4 with each seed of
;;;; *MOVE-ORDER-SEEDS* and negamax at depths 1 to 3 with the first
;;;; (alpha-beta-value-does-not-depend-on-the-move-order); on the positions of the search
;;;; signature, alpha-beta at its depth, 4 (principal-variation-leads-to-the-score); the direct
;;;; search and the last iteration on four positions with a forced mate, to depth 5
;;;; (iterative-deepening-mate-stop-equals-the-full-depth-search); and those of the suite
;;;; differential below; and those of the default search of Phase 3 on the positions of the
;;;; signature, at its depth (principal-variation-leads-to-the-score).
;;;;
;;;; Suite differential (INV-C1, "dove applicabile"): the value of alpha-beta, of negamax and of
;;;; the default search of Phase 3 (table in verification mode) at fixed depth equals the value
;;;; of the reference's alpha-beta, at depths 1 to 3 in MAKE TEST and to depth 4 in MAKE
;;;; DIFFERENTIAL-DEEP, on the search positions, and at depth 2 (3) on seeded random positions;
;;;; the principal variations of the four searches are checked by the reference
;;;; (search-values-equal-the-reference). The principal variation of alpha-beta
;;;; of this layer at depth 3 (5) on other seeded random positions is checked by the reference
;;;; (random-position-variations-are-checked-by-the-reference). The values and the principal
;;;; variations recorded in the search signature, of both its searches, are judged by the
;;;; reference (search-signature-is-judged-by-the-reference): in MAKE TEST each recorded
;;;; variation is replayed by the reference; in MAKE DIFFERENTIAL-DEEP the reference's
;;;; alpha-beta also searches each signature position at the signature depth, and its value must
;;;; be the two recorded values, the value of this layer's alpha-beta and that of its default
;;;; search. The best move, the principal
;;;; variation and the node count of alpha-beta are not compared with the reference's: this
;;;; layer's generator writes the moves in another order, and among moves of equal value, and in
;;;; how much alpha-beta prunes, the order decides. The node count of negamax does not depend on
;;;; the order, and is compared.

(in-package #:scacchiforge.test)

(defun optimized-position (fen)
  "A bitboard position for FEN, read by the reference and converted."
  (scf-opt:bitboard-from-reference (fen-position fen)))

(defun optimized-search (bbp depth algorithm &rest options)
  "The search ALGORITHM (:ALPHA-BETA or :NEGAMAX) of the optimized layer on BBP to DEPTH, with
OPTIONS passed on: score, best move, nodes and principal variation."
  (apply #'scf-opt:bitboard-search bbp depth :algorithm algorithm options))

;;; --- properties of the optimized search ------------------------------------------------

(deftest :optimized-search negamax-visits-every-node-of-the-legal-tree
  ;; From the start position no line ends before depth 4, so negamax visits exactly
  ;; perft(0) + perft(1) + ... + perft(depth) nodes, in any move order.
  (let ((bbp (optimized-position scf-ref:*start-fen*)))
    (is-equal '(1 21 421 9323)
              (loop for depth from 0 to 3
                    collect (nth-value 2 (scf-opt:bitboard-negamax-search bbp depth))))))

(deftest :optimized-search search-leaves-the-position-unchanged
  (let* ((bbp (optimized-position (scf-ref:standard-position-fen "kiwipete")))
         (before (scf-opt:bitboard-clone bbp)))
    (flet ((unchanged-p ()
             (and (scf-opt:bitboard-equal-p bbp before) (zerop (scf-opt:bbp-ply bbp)))))
      (scf-opt:bitboard-negamax-search bbp 2)
      (is (unchanged-p) "negamax")
      (scf-opt:bitboard-alpha-beta-search bbp 3)
      (is (unchanged-p) "alpha-beta")
      (scf-opt:bitboard-alpha-beta-search bbp 3 :shuffle-rng (make-rng 1))
      (is (unchanged-p) "alpha-beta with permuted moves")
      (scf-opt:bitboard-iterative-deepening bbp 3)
      (is (unchanged-p) "iterative deepening"))))

(deftest :optimized-search alpha-beta-equals-negamax-up-to-depth-three
  ;; Same score, same best move and same principal variation: both take, at each node, the first
  ;; move reaching the best score, in the same order.
  (let ((compared 0))
    (loop for (name . fen) in *search-positions*
          do (let ((bbp (optimized-position fen)))
               (loop for depth from 0 to 3
                     do (multiple-value-bind (nm-score nm-move nm-nodes nm-line)
                            (scf-opt:bitboard-negamax-search bbp depth)
                          (multiple-value-bind (ab-score ab-move ab-nodes ab-line)
                              (scf-opt:bitboard-alpha-beta-search bbp depth)
                            (incf compared)
                            (is-eql nm-score ab-score "~A depth ~D: score" name depth)
                            (is-eql nm-move ab-move "~A depth ~D: best move" name depth)
                            (is-equal nm-line ab-line "~A depth ~D: variation" name depth)
                            (is (<= ab-nodes nm-nodes)
                                "~A depth ~D: alpha-beta searched more nodes (~D) than negamax ~
                                 (~D)" name depth ab-nodes nm-nodes))))))
    (note "~D position/depth pairs compared" compared)))

(deftest :optimized-search alpha-beta-prunes
  (let ((bbp (optimized-position (scf-ref:standard-position-fen "kiwipete"))))
    (let ((negamax-nodes (nth-value 2 (scf-opt:bitboard-negamax-search bbp 3)))
          (alpha-beta-nodes (nth-value 2 (scf-opt:bitboard-alpha-beta-search bbp 3))))
      (note "kiwipete depth 3: negamax ~D nodes, alpha-beta ~D nodes" negamax-nodes
            alpha-beta-nodes)
      (is (< alpha-beta-nodes negamax-nodes)))))

(deftest :optimized-search depth-zero-is-the-static-evaluation
  (dolist (fen (list "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
                     ;; No mate or stalemate check at depth 0.
                     "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))
    (let ((bbp (optimized-position fen)))
      (dolist (algorithm '(:alpha-beta :negamax))
        (multiple-value-bind (score move nodes line) (optimized-search bbp 0 algorithm)
          (is-eql (scf-opt:bitboard-evaluate bbp) score "~A ~A" fen algorithm)
          (is-eql +no-move+ move)
          (is-eql 1 nodes)
          (is-eql nil line))))))

(deftest :optimized-search depth-one-is-the-best-negated-child-evaluation
  ;; Worked out from the definition of negamax, with this layer's make, unmake and evaluation,
  ;; independently of the search code.
  (dolist (fen (mapcar #'cdr scf-ref:*standard-positions*))
    (let* ((bbp (optimized-position fen))
           (moves (scf-opt:bitboard-legal-moves bbp))
           (scores (loop for move in moves
                         collect (progn (scf-opt:bitboard-make-move bbp move)
                                        (prog1 (- (scf-opt:bitboard-evaluate bbp))
                                          (scf-opt:bitboard-unmake-move bbp)))))
           (best (reduce #'max scores)))
      (multiple-value-bind (score move nodes line) (scf-opt:bitboard-alpha-beta-search bbp 1)
        (is-eql best score "~A: score" fen)
        (is-eql (nth (position best scores) moves) move
                "~A: the first move reaching the best score" fen)
        (is-eql (1+ (length scores)) nodes "~A: the root and every leaf" fen)
        (is-equal (list move) line "~A: variation" fen)))))

(deftest :optimized-search mate-scores-are-relative-to-the-ply
  (let ((mate scf-opt:+bitboard-mate-score+))
    (is-eql scf-ref:+mate-score+ mate "the same mate score as the reference")
    ;; Mate in one: the mated side is to move at ply 1, so the root sees MATE - 1.
    (let ((bbp (optimized-position "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")))
      (dolist (algorithm '(:alpha-beta :negamax))
        (multiple-value-bind (score move) (optimized-search bbp 2 algorithm)
          (is-eql (- mate 1) score "~A" algorithm)
          (is-equal "a1a8" (move-to-string move) "~A" algorithm)))
      (is-false (scf-opt:bitboard-mate-score-p (scf-opt:bitboard-alpha-beta-search bbp 1))
                "one ply is too shallow"))
    (multiple-value-bind (score move)
        (scf-opt:bitboard-alpha-beta-search
         (optimized-position
          "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4") 2)
      (is-eql (- mate 1) score)
      (is-equal "h5f7" (move-to-string move)))
    ;; Mate in two: the mate happens at ply 3.
    (multiple-value-bind (score move)
        (scf-opt:bitboard-alpha-beta-search (optimized-position "7k/8/8/8/8/8/R7/1R2K3 w - - 0 1")
                                            4)
      (is-eql (- mate 3) score)
      (is (member (move-to-string move) '("a2a7" "b1b7") :test #'string=)
          "first move of the rook ladder: ~A" (move-to-string move))
      (is-true (scf-opt:bitboard-mate-score-p score)))
    ;; Checkmated at the root, stalemated at the root, mated at ply 2.
    (multiple-value-bind (score move nodes)
        (scf-opt:bitboard-alpha-beta-search
         (optimized-position "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3") 3)
      (is-eql (- mate) score "checkmated at the root: ply 0")
      (is-eql +no-move+ move)
      (is-eql 1 nodes))
    (multiple-value-bind (score move)
        (scf-opt:bitboard-alpha-beta-search (optimized-position "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
                                            3)
      (is-eql 0 score "stalemate scores zero")
      (is-eql +no-move+ move))
    (is-eql (- 2 mate) (scf-opt:bitboard-alpha-beta-search
                        (optimized-position "7k/1R6/8/8/8/8/R7/4K3 b - - 1 1") 3)
            "Black is mated at ply 2 from this root")))

(deftest :optimized-search alpha-beta-value-does-not-depend-on-the-move-order
  ;; "Proprietà di alpha-beta puro" (docs/verifica.md): the moves of every node are permuted by
  ;; generators with the seeds of *MOVE-ORDER-SEEDS* (tests/test-search.lisp); the value must
  ;; not change, the best move and the node count may. Negamax is permuted too. The principal
  ;; variation of every permuted search is replayed by the reference, through the reference
  ;; position read from the FEN (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp).
  (let ((compared 0))
    (loop for (name . fen) in *search-positions*
          do (let ((bbp (optimized-position fen))
                   (pos (fen-position fen)))
               (loop for depth from 1 to 4
                     do (let ((expected (scf-opt:bitboard-alpha-beta-search bbp depth)))
                          (dolist (seed *move-order-seeds*)
                            (multiple-value-bind (score move nodes line)
                                (scf-opt:bitboard-alpha-beta-search bbp depth
                                                                    :shuffle-rng (make-rng seed))
                              (declare (ignore nodes))
                              (incf compared)
                              (is-eql expected score "~A depth ~D seed ~D: alpha-beta"
                                      name depth seed)
                              (is-eql (if line (first line) +no-move+) move)
                              (is-equal '() (principal-variation-problems
                                             pos depth score line #'scf-ref:evaluate-classical)
                                        "~A depth ~D seed ~D: variation" name depth seed)))
                          (when (<= depth 3)
                            (multiple-value-bind (score move nodes line)
                                (scf-opt:bitboard-negamax-search
                                 bbp depth :shuffle-rng (make-rng (first *move-order-seeds*)))
                              (declare (ignore move nodes))
                              (is-eql expected score "~A depth ~D: negamax permuted" name depth)
                              (is-equal '() (principal-variation-problems
                                             pos depth score line #'scf-ref:evaluate-classical)
                                        "~A depth ~D: negamax permuted, variation"
                                        name depth)))))))
    (note "~D permuted searches compared, seeds ~S" compared *move-order-seeds*)))

(deftest :optimized-search a-permutation-really-changes-the-search-order
  ;; Without this the test above could pass with a hook that permutes nothing.
  (let ((bbp (optimized-position (scf-ref:standard-position-fen "kiwipete"))))
    (is (/= (nth-value 2 (scf-opt:bitboard-alpha-beta-search bbp 3))
            (nth-value 2 (scf-opt:bitboard-alpha-beta-search bbp 3 :shuffle-rng (make-rng 1))))
        "the node count of kiwipete at depth 3 is the same after the permutation")))

(deftest :optimized-search iterative-deepening-equals-the-direct-search-at-every-depth
  ;; Each iteration is a complete search from scratch: iteration d returns what the direct
  ;; search at d returns, value, best move, node count and variation, with both algorithms.
  (loop for (name . fen) in *search-positions*
        do (let ((bbp (optimized-position fen)))
             (dolist (algorithm '(:alpha-beta :negamax))
               (let ((max-depth (if (eq algorithm :alpha-beta) 4 3))
                     (seen '()))
                 (multiple-value-bind (score move total iterations line)
                     (scf-opt:bitboard-iterative-deepening
                      bbp max-depth :algorithm algorithm
                                    :on-iteration (lambda (iteration) (push iteration seen)))
                   (let ((last (first (last iterations))))
                     (is-eql score (getf last :score) "~A ~A" name algorithm)
                     (is-eql move (getf last :best-move) "~A ~A" name algorithm)
                     (is-equal line (getf last :pv) "~A ~A" name algorithm)
                     (is-eql total (reduce #'+ iterations :key (lambda (i) (getf i :nodes))))
                     (is-equal iterations (reverse seen) "~A ~A: the callback" name algorithm))
                   (dolist (iteration iterations)
                     (let ((depth (getf iteration :depth)))
                       (multiple-value-bind (d-score d-move d-nodes d-line)
                           (optimized-search bbp depth algorithm)
                         (is-equal (list d-score d-move d-nodes d-line)
                                   (list (getf iteration :score) (getf iteration :best-move)
                                         (getf iteration :nodes) (getf iteration :pv))
                                   "~A ~A depth ~D" name algorithm depth))))
                   (unless (scf-opt:bitboard-mate-score-p score)
                     (is-eql max-depth (length iterations)
                             "~A ~A: every depth without a mate" name algorithm))))))))

(deftest :optimized-search iterative-deepening-mate-stop-equals-the-full-depth-search
  ;; The early stop does not change the result: the score and best move after the stop equal
  ;; those of a direct search at the full depth, with both algorithms. The principal variations
  ;; of the direct search and of the last iteration are replayed by the reference
  ;; (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp).
  (loop for (fen max-depth stop-depth)
          in '(("6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1" 4 2)
               ("7k/8/8/8/8/8/R7/1R2K3 w - - 0 1" 5 4)
               ("7k/1R6/8/8/8/8/R7/4K3 b - - 1 1" 4 3)
               ("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3" 3 1))
        do (dolist (algorithm '(:alpha-beta :negamax))
             (let ((bbp (optimized-position fen))
                   (pos (fen-position fen)))
               (multiple-value-bind (score move total iterations line)
                   (scf-opt:bitboard-iterative-deepening bbp max-depth :algorithm algorithm)
                 (declare (ignore total))
                 (multiple-value-bind (direct-score direct-move direct-nodes direct-line)
                     (optimized-search bbp max-depth algorithm)
                   (declare (ignore direct-nodes))
                   (is-eql stop-depth (length iterations) "~A ~A: stopped at depth ~D"
                           fen algorithm (length iterations))
                   (is-true (scf-opt:bitboard-mate-score-p score) "~A ~A: a mate score"
                            fen algorithm)
                   (is-eql direct-score score "~A ~A: score" fen algorithm)
                   (is-eql direct-move move "~A ~A: best move" fen algorithm)
                   (is-equal '() (principal-variation-problems pos max-depth direct-score
                                                               direct-line
                                                               #'scf-ref:evaluate-classical)
                             "~A ~A: variation of the direct search" fen algorithm)
                   (is-equal '() (principal-variation-problems pos (length iterations) score line
                                                               #'scf-ref:evaluate-classical)
                             "~A ~A: variation of the last iteration" fen algorithm)))))))

(deftest :optimized-search search-arguments-are-checked
  (let ((bbp (optimized-position scf-ref:*start-fen*)))
    (signals type-error (scf-opt:bitboard-alpha-beta-search bbp -1))
    (signals type-error (scf-opt:bitboard-alpha-beta-search bbp 63))
    (signals type-error (scf-opt:bitboard-iterative-deepening bbp 0))
    (signals error (scf-opt:bitboard-search-with-context (scf-opt:make-bitboard-search-context 2)
                                                         bbp 3 :alpha-beta))
    (signals error (scf-opt:bitboard-search bbp 2 :algorithm :minimax))
    (is (and (scf-opt:bitboard-equal-p bbp (optimized-position scf-ref:*start-fen*))
             (zerop (scf-opt:bbp-ply bbp)))
        "the refused calls changed nothing")))

(defparameter *search-allocation-runs*
  '(("startpos" 4) ("kiwipete" 4) ("pos3" 5) ("pos4" 4) ("pos5" 4) ("pos6" 4) ("promo" 5))
  "Searches (standard position, depth) whose allocation is measured: alpha-beta at the depth
and negamax one ply less, each twice. The test prints how many nodes they visit.")

(deftest :optimized-search search-allocates-nothing-after-warm-up
  ;; As for perft (optimized/perft-allocates-nothing-after-warm-up): SB-EXT:GET-BYTES-CONSED moves
  ;; one allocation region at a time, so the run must be long. The searches run twice after a
  ;; warm-up, with alpha-beta and with negamax at one ply less, and visit more than a million
  ;; nodes, each with a move generation or an evaluation: one 16-byte object per node would show
  ;; as at least 16 MB. The bound of 1 MiB means less than one byte per node.
  (let ((context (scf-opt:make-bitboard-search-context 5))
        (runs (loop for (name depth) in *search-allocation-runs*
                    collect (list depth (optimized-position
                                         (scf-ref:standard-position-fen name))))))
    (flet ((run ()
             (let ((nodes 0))
               (loop for (depth bbp) in runs
                     do (dotimes (i 2)
                          (incf nodes (nth-value 2 (scf-opt:bitboard-search-with-context
                                                    context bbp depth :alpha-beta)))
                          (incf nodes (nth-value 2 (scf-opt:bitboard-search-with-context
                                                    context bbp (1- depth) :negamax)))))
               nodes)))
      (run)
      (let* ((before (sb-ext:get-bytes-consed))
             (nodes (run)))
        (let ((consed (- (sb-ext:get-bytes-consed) before)))
          (note "~D nodes searched, ~D bytes consed" nodes consed)
          (is (> nodes 1000000) "enough nodes for the bound to mean something: ~D" nodes)
          (is (<= consed (* 1024 1024)) "~D bytes consed over ~D nodes" consed nodes))))))

;;; --- the search signature --------------------------------------------------------------
;;;
;;; The signature (docs/verifica.md, "Regressione di ricerca") of the optimized engine: for each
;;; position of *SEARCH-SIGNATURE-POSITIONS*, the value, the best move, the node count and the
;;; principal variation at depth *SEARCH-SIGNATURE-DEPTH*, one thread, of two searches: the
;;; baseline alpha-beta of Phase 2 (:ENTRIES, unchanged since Phase 2) and the default search of
;;; Phase 3 (:DEFAULT-ENTRIES; SCF-OPT:*BITBOARD-DEFAULT-SEARCH*, iterative deepening of PVS
;;; with the ordering and a fresh table, here in verification mode; its node count is the sum
;;; over the iterations). It is recorded in tests/search-signature.sexp, which "make
;;; signatures" (tools/signatures.lisp) writes and nothing else does; the test below recomputes
;;; it and compares. The file's header records the revision the working tree was based on, the
;;; policy, the slider implementation, the Lisp and the date of the run that wrote it.

(defparameter *search-signature-depth* 4
  "The depth of the search signature, chosen so that recomputing every entry keeps MAKE TEST
short; the runner prints the seconds the test takes. Changing it changes the signature.")

(defparameter *search-signature-positions*
  (append
   (mapcar (lambda (entry) (list (car entry) (cdr entry))) scf-ref:*standard-positions*)
   ;; Two quiet middlegames and three tactical positions, each reached from the start position
   ;; by the moves in its comment (long algebraic), played and written out by the reference.
   '(;; d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 b8d7: closed centre, no contact
     ;; between the pieces.
     ("quiet-queens-gambit"
      "r1bq1rk1/pppnbppp/4pn2/3p2B1/2PP4/2N1PN2/PP3PPP/R2QKB1R w KQ - 3 7")
     ;; e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d3 d7d6 e1g1 e8g8: symmetric, both sides
     ;; castled.
     ("quiet-italian"
      "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 2 7")
     ;; e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 f6d5: the knight can take on f7, forking
     ;; queen and rook.
     ("tactical-knight-takes-f7"
      "r1bqkb1r/ppp2ppp/2n5/3np1N1/2B5/8/PPPP1PPP/RNBQK2R w KQkq - 0 6")
     ;; e2e4 e7e5 g1f3 d7d6 f1c4 c8g4 b1c3 g7g6: the knight can take on e5, leaving its queen
     ;; to the bishop, with a mate after the queen is taken.
     ("tactical-knight-takes-e5"
      "rn1qkbnr/ppp2p1p/3p2p1/4p3/2B1P1b1/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 0 5")
     ;; e2e4 e7e5 f1c4 b8c6 d1h5 g8f6: mate in one on f7.
     ("tactical-mate-in-one"
      "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")))
  "The positions of the search signature, (name fen): the perft positions of
SCF-REF:*STANDARD-POSITIONS*, then quiet and tactical middlegames reached by the moves written
next to each.")

(defun search-signature-pathname ()
  "tests/search-signature.sexp in the repository."
  (asdf:system-relative-pathname "scacchiforge" "tests/search-signature.sexp"))

(defun search-signature-entry (name fen depth)
  "The signature of the position FEN, called NAME, at DEPTH: a list (NAME FEN :SCORE s
:BEST-MOVE m :NODES n :PV line), the moves in long algebraic form, the best move NIL when there
is none. Alpha-beta of the optimized layer, with a fresh search context."
  (multiple-value-bind (score move nodes line)
      (scf-opt:bitboard-alpha-beta-search (optimized-position fen) depth)
    (list name fen :score score :best-move (if (= move +no-move+) nil (move-to-string move))
                   :nodes nodes :pv (mapcar #'move-to-string line))))

(defun search-signature-entries (&optional (depth *search-signature-depth*))
  "The signature entries of every position of *SEARCH-SIGNATURE-POSITIONS* at DEPTH."
  (loop for (name fen) in *search-signature-positions*
        collect (search-signature-entry name fen depth)))

(defun search-signature-default ()
  "The configuration of the default search the signature records: SCF-OPT:*BITBOARD-DEFAULT-
SEARCH* with the table in verification mode."
  (append scf-opt:*bitboard-default-search* (list :tt-mode :verification)))

(defun search-signature-default-entry (name fen depth)
  "The entry of the default search of Phase 3 (SCF-OPT:BITBOARD-DEFAULT-SEARCH, a fresh table in
verification mode) for the position FEN, called NAME, at DEPTH, in the form of
SEARCH-SIGNATURE-ENTRY; the node count is the sum over the iterations."
  (multiple-value-bind (score move nodes line)
      (scf-opt:bitboard-default-search (optimized-position fen) depth :mode :verification)
    (list name fen :score score :best-move (if (= move +no-move+) nil (move-to-string move))
                   :nodes nodes :pv (mapcar #'move-to-string line))))

(defun search-signature-default-entries (&optional (depth *search-signature-depth*))
  "The entries of the default search of every position of *SEARCH-SIGNATURE-POSITIONS* at DEPTH."
  (loop for (name fen) in *search-signature-positions*
        collect (search-signature-default-entry name fen depth)))

(defun read-search-signature (&optional (pathname (search-signature-pathname)))
  "The property list of the signature file PATHNAME (:FORMAT :ALGORITHM :DEPTH :ENTRIES
:DEFAULT-SEARCH :DEFAULT-ENTRIES), read as data, with no evaluation at read time: keywords,
integers, strings, T and NIL."
  (with-open-file (in pathname :external-format :utf-8)
    (let ((*read-eval* nil)
          (*package* (find-package '#:scacchiforge.test)))
      (read in))))

(defun write-signature-entries (stream entries)
  "Write ENTRIES (as SEARCH-SIGNATURE-ENTRIES returns them) to STREAM as the body of a list."
  (loop for entry in entries
        for first = t then nil
        do (destructuring-bind (name fen &key score best-move nodes pv) entry
             (unless first
               (format stream "~%  "))
             (format stream "(~S~%   ~S~%   :score ~D :best-move ~S :nodes ~D~%   :pv ~S)"
                     name fen score best-move nodes pv))))

(defun write-search-signature (stream header-lines entries default-entries depth)
  "Write the search signature at DEPTH to STREAM, after a comment header made of HEADER-LINES
(strings): ENTRIES, of the baseline alpha-beta, and DEFAULT-ENTRIES, of the default search
(SEARCH-SIGNATURE-DEFAULT), both as SEARCH-SIGNATURE-ENTRIES returns them. Every line stays
within 100 columns."
  (let ((*print-pretty* nil)
        (*print-case* :downcase))
    (format stream ";;;; search-signature.sexp -- the search signature of the optimized engine ~
                    (Phases 2 and 3).~%;;;;~%")
    (dolist (line header-lines)
      (format stream ";;;;~:[ ~A~;~]~%" (string= line "") line))
    (format stream "~%(:format 2~% :algorithm :alpha-beta~% :depth ~D~% :entries~% (" depth)
    (write-signature-entries stream entries)
    (format stream ")~% :default-search~% (~{~S ~S~^~%  ~})~% :default-entries~% ("
            (search-signature-default))
    (write-signature-entries stream default-entries)
    (format stream "))~%")))

(defun write-search-signature-file (header-lines &optional (pathname (search-signature-pathname)))
  "Compute the search signature at *SEARCH-SIGNATURE-DEPTH* and write it to PATHNAME
(tests/search-signature.sexp), with HEADER-LINES as the provenance header. Called by
tools/signatures.lisp (make signatures) only. Returns two values: PATHNAME, and the property
list of what was written (:FORMAT :ALGORITHM :DEPTH :ENTRIES :DEFAULT-SEARCH :DEFAULT-ENTRIES,
as READ-SEARCH-SIGNATURE gives it), which the tool compares with the file read back."
  (let* ((depth *search-signature-depth*)
         (entries (search-signature-entries depth))
         (default-entries (search-signature-default-entries depth)))
    (with-open-file (out pathname :direction :output :if-exists :supersede
                                  :external-format :utf-8)
      (write-search-signature out header-lines entries default-entries depth))
    (values pathname (list :format 2 :algorithm :alpha-beta :depth depth :entries entries
                           :default-search (search-signature-default)
                           :default-entries default-entries))))

(defun check-signature-entries (label entries compute depth)
  "Compare each of ENTRIES, read from the signature file, with what COMPUTE, a function of
(name fen depth) giving an entry, gives now at DEPTH: FEN, value, best move, node count and
principal variation. LABEL names the search in the failure messages."
  (is-equal (mapcar #'first *search-signature-positions*) (mapcar #'first entries)
            "~A: the positions of the file" label)
  (dolist (entry entries)
    (destructuring-bind (name fen &key score best-move nodes pv) entry
      (is-equal (second (assoc name *search-signature-positions* :test #'string=)) fen
                "~A ~A: the FEN" label name)
      (destructuring-bind (&key ((:score new-score)) ((:best-move new-move))
                             ((:nodes new-nodes)) ((:pv new-pv)))
          (cddr (funcall compute name fen depth))
        (is-eql score new-score "~A ~A: value" label name)
        (is-equal best-move new-move "~A ~A: best move" label name)
        (is-eql nodes new-nodes "~A ~A: node count" label name)
        (is-equal pv new-pv "~A ~A: principal variation" label name)))))

(deftest :optimized-search search-signature-is-reproduced
  ;; docs/verifica.md, "Regressione di ricerca": a change that claims [EXACT] must not change any
  ;; of the four parts; a change that is meant to change them regenerates the file with "make
  ;; signatures" and says why. The two searches the file records return the same value at its
  ;; depth: the default search of Phase 3, with the table in verification mode, returns the
  ;; value of alpha-beta.
  (let* ((signature (read-search-signature))
         (depth (getf signature :depth))
         (entries (getf signature :entries))
         (default-entries (getf signature :default-entries)))
    (is-eql 2 (getf signature :format))
    (is-eql :alpha-beta (getf signature :algorithm))
    (is-eql *search-signature-depth* depth "the depth of the file")
    (is-equal (search-signature-default) (getf signature :default-search)
              "the configuration of the default search")
    (check-signature-entries "alpha-beta" entries #'search-signature-entry depth)
    (check-signature-entries "default" default-entries #'search-signature-default-entry depth)
    (is-equal (mapcar (lambda (entry) (getf (cddr entry) :score)) entries)
              (mapcar (lambda (entry) (getf (cddr entry) :score)) default-entries)
              "the default search records the values of alpha-beta")
    (note "~D positions at depth ~D: alpha-beta, and the default search of Phase 3"
          (length entries) depth)))

(deftest :optimized-search principal-variation-leads-to-the-score
  ;; The reference checks the variations of this layer's searches in generation order: on the
  ;; search positions, alpha-beta at depths 0 to 4 and negamax at depths 0 to 3, the depths to
  ;; which alpha-beta-value-does-not-depend-on-the-move-order runs them; on the positions of
  ;; the search signature, alpha-beta at *SEARCH-SIGNATURE-DEPTH*. Each variation is replayed
  ;; through the reference position read from the FEN (PRINCIPAL-VARIATION-PROBLEMS,
  ;; tests/test-search.lisp, with the reference's classical evaluation): legal moves, and the
  ;; score at its end. The permuted searches are checked by
  ;; alpha-beta-value-does-not-depend-on-the-move-order.
  (let ((checked 0)
        (mates 0))
    (flet ((check (name fen depth algorithm)
             (multiple-value-bind (score move nodes line)
                 (optimized-search (optimized-position fen) depth algorithm)
               (declare (ignore nodes))
               (incf checked)
               (when (scf-opt:bitboard-mate-score-p score)
                 (incf mates))
               (is-eql (if line (first line) +no-move+) move
                       "~A ~A depth ~D: the line starts with the move" name algorithm depth)
               (is-equal '() (principal-variation-problems (fen-position fen) depth score line
                                                           #'scf-ref:evaluate-classical)
                         "~A ~A depth ~D" name algorithm depth))))
      (loop for (name . fen) in *search-positions*
            do (loop for depth from 0 to 4
                     do (check name fen depth :alpha-beta)
                        (when (<= depth 3)
                          (check name fen depth :negamax))))
      (loop for (name fen) in *search-signature-positions*
            do (check name fen *search-signature-depth* :alpha-beta))
      ;; The default search of Phase 3, as the signature records it.
      (loop for (name fen) in *search-signature-positions*
            do (multiple-value-bind (score move nodes line)
                   (scf-opt:bitboard-default-search (optimized-position fen)
                                                    *search-signature-depth*
                                                    :mode :verification)
                 (declare (ignore nodes))
                 (incf checked)
                 (when (scf-opt:bitboard-mate-score-p score)
                   (incf mates))
                 (is-eql (if line (first line) +no-move+) move
                         "~A default search: the line starts with the move" name)
                 (is-equal '() (principal-variation-problems (fen-position fen)
                                                             *search-signature-depth* score line
                                                             #'scf-ref:evaluate-classical)
                           "~A default search" name))))
    (note "~D variations checked, ~D of them with a mate score" checked mates)))

;;; --- the comparison with the reference (suite differential) -----------------------------

(defun labelled-problems (label problems)
  "Each string of PROBLEMS preceded by LABEL."
  (mapcar (lambda (problem) (format nil "~A: ~A" label problem)) problems))

(defun search-comparison-problems (pos depth)
  "Compare the values of the reference's alpha-beta on the reference position POS at DEPTH with
the optimized layer's alpha-beta, negamax and default search of Phase 3 (the table in
verification mode) on the converted position, and check the principal variation of each of the
four searches through POS (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp, with the
reference's classical evaluation); return a list of strings describing each difference and each
problem (empty when the values agree and the four variations lead to them)."
  (multiple-value-bind (reference reference-move reference-nodes reference-line)
      (scf-ref:alpha-beta-search pos depth)
    (declare (ignore reference-move reference-nodes))
    (let ((bbp (scf-opt:bitboard-from-reference pos))
          (evaluator #'scf-ref:evaluate-classical))
      (multiple-value-bind (alpha-beta alpha-beta-move alpha-beta-nodes alpha-beta-line)
          (scf-opt:bitboard-alpha-beta-search bbp depth)
        (declare (ignore alpha-beta-move alpha-beta-nodes))
        (multiple-value-bind (negamax negamax-move negamax-nodes negamax-line)
            (scf-opt:bitboard-negamax-search bbp depth)
          (declare (ignore negamax-move negamax-nodes))
          (multiple-value-bind (default default-move default-nodes default-line)
              (scf-opt:bitboard-default-search bbp depth :mode :verification)
            (declare (ignore default-move default-nodes))
            (append (unless (= reference alpha-beta)
                      (list (format nil "alpha-beta ~D, reference ~D" alpha-beta reference)))
                    (unless (= reference negamax)
                      (list (format nil "negamax ~D, reference ~D" negamax reference)))
                    (unless (= reference default)
                      (list (format nil "default search ~D, reference ~D" default reference)))
                    (labelled-problems "reference variation"
                                       (principal-variation-problems pos depth reference
                                                                     reference-line evaluator))
                    (labelled-problems "alpha-beta variation"
                                       (principal-variation-problems pos depth alpha-beta
                                                                     alpha-beta-line evaluator))
                    (labelled-problems "negamax variation"
                                       (principal-variation-problems pos depth negamax
                                                                     negamax-line evaluator))
                    (labelled-problems "default search variation"
                                       (principal-variation-problems pos depth default
                                                                     default-line
                                                                     evaluator)))))))))

(deftest :differential search-values-equal-the-reference
  ;; The gates of Phases 2 and 3: at fixed depth the optimized layer's searches return the
  ;; reference's value, the default search of Phase 3 with its table in verification mode too.
  ;; The best move and the node count of alpha-beta depend on the move order, which differs
  ;; between the layers, and are not compared (file header). The principal variation of each of
  ;; the four searches is replayed by the reference (SEARCH-COMPARISON-PROBLEMS).
  (with-differential-test ()
    (let ((compared 0)
          (deepest (differential-scale 3 4)))
      (loop for (name . fen) in *search-positions*
            do (let ((pos (fen-position fen)))
                 (loop for depth from 1 to deepest
                       do (incf compared)
                          (incf *assertions*)
                          (let ((differences (search-comparison-problems pos depth)))
                            (when differences
                              (differential-failure "~A depth ~D: ~{~A~^; ~}" name depth
                                                    differences))))))
      (let* ((seed 20261007)
             (rng (make-rng seed))
             (count (differential-scale 40 400))
             (depth (differential-scale 2 3)))
        (dotimes (i count)
          (let ((pos (scf-ref:random-legal-position *fuzz-fens* rng 120)))
            (incf compared)
            (incf *assertions*)
            (let ((differences (search-comparison-problems pos depth)))
              (when differences
                (differential-failure "~A depth ~D: ~{~A~^; ~}" (scf-ref:position-to-fen pos)
                                      depth differences)))))
        (note "~D searches compared, with their principal variations: the search positions to ~
               depth ~D, and ~D random positions (seed ~D) at depth ~D"
              compared deepest count seed depth)))))

(deftest :differential random-position-variations-are-checked-by-the-reference
  ;; The principal variation of the optimized layer's alpha-beta, in generation order, on
  ;; seeded random legal positions, at a depth at which the suite does not run the reference's
  ;; search: 3 under MAKE TEST, 5 under MAKE DIFFERENTIAL-DEEP. Each variation is replayed by
  ;; the reference (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp): its moves are legal
  ;; and it leads to the score. The note says how many scores were mates and how many
  ;; variations ended before the depth, in checkmate or stalemate.
  (with-differential-test ()
    (let* ((seed 20261008)
           (rng (make-rng seed))
           (count (differential-scale 40 200))
           (depth (differential-scale 3 5))
           (nodes 0)
           (mates 0)
           (short 0))
      (dotimes (i count)
        (let ((pos (scf-ref:random-legal-position *fuzz-fens* rng 120)))
          (multiple-value-bind (score move searched line)
              (scf-opt:bitboard-alpha-beta-search (scf-opt:bitboard-from-reference pos) depth)
            (declare (ignore move))
            (incf nodes searched)
            (when (scf-opt:bitboard-mate-score-p score)
              (incf mates))
            (when (< (length line) depth)
              (incf short))
            (incf *assertions*)
            (let ((problems (principal-variation-problems pos depth score line
                                                          #'scf-ref:evaluate-classical)))
              (when problems
                (differential-failure "~A depth ~D: ~{~A~^; ~}" (scf-ref:position-to-fen pos)
                                      depth problems))))))
      (note "seed ~D: ~D random positions, alpha-beta at depth ~D, ~D nodes; ~D mate scores, ~
             ~D variations shorter than the depth" seed count depth nodes mates short))))

(defun reference-line-from-text (pos texts)
  "Read the moves TEXTS (long algebraic) with the reference, from the reference position POS
on: each one among the legal moves of the position the moves before it reach
(SCF-REF:PARSE-MOVE). Two values: the moves read, and the first text that is not a legal move
where it is played, or NIL. POS is left as it was."
  (let ((copy (scf-ref:clone-position pos))
        (moves '()))
    (dolist (text texts (values (nreverse moves) nil))
      (let ((move (scf-ref:parse-move copy text)))
        (unless move
          (return (values (nreverse moves) text)))
        (push move moves)
        (scf-ref:make-move copy move)))))

(deftest :differential search-signature-is-judged-by-the-reference
  ;; The search signature (tests/search-signature.sexp) is a regression value of the optimized
  ;; layer; the reference judges it. Under both profiles, each recorded principal variation, of
  ;; the baseline alpha-beta and of the default search of Phase 3, is read by the reference from
  ;; the FEN of its entry and replayed (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp):
  ;; its moves are legal and it leads to the recorded score; the recorded best move is its first
  ;; move. Under the deep profile (MAKE DIFFERENTIAL-DEEP) the reference's alpha-beta also
  ;; searches every entry at the depth of the file: its value must be the two recorded values,
  ;; the value of the optimized layer's alpha-beta and that of its default search, searched
  ;; again here, and its own principal variation must lead to it. Not under MAKE TEST, to bound
  ;; its work: on the twelve positions the reference's alpha-beta at depth 4 visits 897329
  ;; nodes, with the classical evaluation computed term by term at each leaf (the note prints
  ;; the count); the bound is in nodes, not a measured time.
  (with-differential-test ()
    (let* ((signature (read-search-signature))
           (depth (getf signature :depth))
           (entries (getf signature :entries))
           (default-entries (getf signature :default-entries))
           (searched (eq *differential-profile* :deep))
           (reference-nodes 0))
      (loop for entry in entries
            for default-entry in default-entries
            do (destructuring-bind (name fen &key score &allow-other-keys) entry
                 (let ((pos (fen-position fen))
                       (default-score (getf (cddr default-entry) :score)))
                   (dolist (recorded (list entry default-entry))
                     (destructuring-bind (&key score best-move pv &allow-other-keys)
                         (cddr recorded)
                       (incf *assertions*)
                       (multiple-value-bind (line illegal) (reference-line-from-text pos pv)
                         (let ((problems
                                 (if illegal
                                     (list (format nil "~A is not a legal move where it is played"
                                                   illegal))
                                     (principal-variation-problems
                                      pos depth score line #'scf-ref:evaluate-classical))))
                           (when problems
                             (differential-failure "~A: recorded variation~:[~; of the default ~
                                                    search~]: ~{~A~^; ~}"
                                                   name (eq recorded default-entry) problems))))
                       (is-equal (first pv) best-move
                                 "~A: the recorded best move starts the variation" name)))
                   (when searched
                     (multiple-value-bind (reference move searched-nodes reference-line)
                         (scf-ref:alpha-beta-search pos depth)
                       (declare (ignore move))
                       (incf reference-nodes searched-nodes)
                       (let* ((bbp (scf-opt:bitboard-from-reference pos))
                              (optimized (scf-opt:bitboard-alpha-beta-search bbp depth))
                              (default (scf-opt:bitboard-default-search bbp depth
                                                                        :mode :verification))
                              (problems (principal-variation-problems
                                         pos depth reference reference-line
                                         #'scf-ref:evaluate-classical)))
                         (incf *assertions*)
                         (unless (and (= score reference) (= default-score reference)
                                      (= optimized reference) (= default reference)
                                      (null problems))
                           (differential-failure "~A depth ~D: recorded ~D and ~D, optimized ~D ~
                                                  and ~D, reference ~D~@[; reference variation: ~
                                                  ~{~A~^; ~}~]"
                                                 name depth score default-score optimized default
                                                 reference problems))))))))
      (if searched
          (note "~D entries at depth ~D: recorded variations replayed, and values compared with ~
                 the reference's alpha-beta (~D nodes)" (length entries) depth reference-nodes)
          (note "~D entries at depth ~D: recorded variations replayed; their values are compared ~
                 with the reference's search only by make differential-deep"
                (length entries) depth)))))

(deftest :differential negamax-node-counts-equal-the-reference
  ;; The node count of negamax is the size of the tree, which does not depend on the order of
  ;; the moves: the two layers must count the same nodes.
  (with-differential-test ()
    (let ((deepest (differential-scale 2 3)))
      (loop for (name . fen) in *search-positions*
            do (let ((pos (fen-position fen)))
                 (loop for depth from 1 to deepest
                       do (incf *assertions*)
                          (let ((reference (nth-value 2 (scf-ref:negamax-search
                                                         pos depth
                                                         :evaluator #'scf-ref:evaluate-material)))
                                (optimized (nth-value 2 (scf-opt:bitboard-negamax-search
                                                         (scf-opt:bitboard-from-reference pos)
                                                         depth))))
                            (unless (= reference optimized)
                              (differential-failure "~A depth ~D: negamax visits ~D nodes, ~
                                                     ~D in the reference"
                                                    name depth optimized reference)))))))))
