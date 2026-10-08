;;;; test-search.lisp -- material evaluation, negamax, alpha-beta, iterative deepening.
;;;;
;;;; The searches evaluate their leaves with the classical evaluation unless a test passes
;;;; another one: the tests written for the material baseline pass EVALUATE-MATERIAL, and the
;;;; comparisons of alpha-beta with negamax run with both evaluations. The Phase 2 gate checks
;;;; (docs/roadmap.md) are here for the reference: alpha-beta and negamax return the same
;;;; value at depths 1 to 3, the value does not change when the moves of every node are
;;;; permuted with a declared seed, and iterative deepening at depth d returns what the direct
;;;; search at d returns.
;;;;
;;;; PRINCIPAL-VARIATION-PROBLEMS replays a principal variation through a reference position
;;;; with the reference's own legality and checks that it leads to the score; the optimized
;;;; layer's tests (tests/test-optimized-search.lisp) use it too. On the search positions it
;;;; checks every variation of these searches of the reference: alpha-beta at depths 0 to 3
;;;; and negamax at depths 0 to 3 (0 to 2 with the classical evaluation on
;;;; *LARGE-TREE-POSITIONS*), with each evaluation, in generation order
;;;; (principal-variation-leads-to-the-score); alpha-beta at depths 1 to 3 with the seeds of
;;;; *MOVE-ORDER-SEEDS* and negamax at depths 1 and 2 with the first seed, with the classical
;;;; evaluation (alpha-beta-value-does-not-depend-on-the-move-order). It also checks the direct
;;;; search and the last iteration on four positions with a forced mate, to depth 5
;;;; (iterative-deepening-mate-stop-equals-the-full-depth-search).

(in-package #:scacchiforge.test)

(deftest :search material-evaluation
  (is-eql 0 (scf-ref:evaluate-material (scf-ref:start-position)))
  (is-eql 900 (scf-ref:evaluate-material
               (fen-position "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")))
  (is-eql -900 (scf-ref:evaluate-material
                (fen-position "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"))
          "the score is from the side to move")
  (is-eql 500 (scf-ref:evaluate-material (fen-position "4k3/8/8/8/8/8/8/R3K3 w - - 0 1")))
  (is-eql -100 (scf-ref:evaluate-material (fen-position "4k3/4p3/8/8/8/8/8/4K3 w - - 0 1")))
  (is-eql 0 (scf-ref:evaluate-material (fen-position "4k3/8/8/8/8/8/8/4K3 w - - 0 1")))
  (is-equal '(100 300 300 500 900 0)
            (loop for type from 1 to 6 collect (scf-ref:material-value type))))

(deftest :search material-evaluation-is-colour-symmetric
  (loop for (nil fen) in *main-perft-table*
        do (is-eql (scf-ref:evaluate-material (fen-position fen))
                   (scf-ref:evaluate-material (fen-position (mirror-fen fen)))
                   "~A" fen)))

(deftest :search negamax-visits-every-node-of-the-legal-tree
  ;; From the start position no line ends before depth 4, so negamax visits exactly
  ;; perft(0) + perft(1) + ... + perft(depth) nodes.
  (let ((pos (scf-ref:start-position)))
    (is-equal '(1 21 421 9323)
              (loop for depth from 0 to 3
                    collect (nth-value 2 (scf-ref:negamax-search pos depth))))))

(deftest :search search-leaves-the-position-unchanged
  (let* ((pos (fen-position "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"))
         (before (snapshot pos)))
    (scf-ref:negamax-search pos 2)
    (is (same-state-p pos before 0))
    (scf-ref:alpha-beta-search pos 3)
    (is (same-state-p pos before 0))
    (scf-ref:iterative-deepening pos 3)
    (is (same-state-p pos before 0))))

(defparameter *search-positions*
  (append (mapcar (lambda (entry) (cons (car entry) (cdr entry))) scf-ref:*standard-positions*)
          '(("back-rank" . "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")
            ("scholars-mate"
             . "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4")
            ("rook-ladder" . "7k/8/8/8/8/8/R7/1R2K3 w - - 0 1")
            ("stalemate" . "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
            ("fools-mate" . "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")
            ("endgame" . "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 b - - 0 1")
            ("promotion" . "8/P6k/8/8/8/8/p7/K7 w - - 0 1")
            ("en-passant-pin" . "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1")
            ("black-to-move" . "r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1")))
  "Positions on which alpha-beta must agree with negamax.")

(defparameter *search-evaluators*
  (list (cons "classical" #'scf-ref:evaluate-classical)
        (cons "material" #'scf-ref:evaluate-material))
  "The static evaluations the comparisons of alpha-beta with negamax run with.")

(defparameter *large-tree-positions* '("kiwipete" "pos5" "pos6" "scholars-mate")
  "The search positions whose negamax tree at depth 3 has from about 47000 to 100000 nodes.
On these four, make test compares alpha-beta with negamax to depth 3 with the material
evaluation only, and to depth 2 with the classical one, which the reference computes term by
term from scratch at each leaf; the largest negamax tree compared with the classical evaluation
is then one of about 23000 nodes, at depth 3 on another position. The notes of
alpha-beta-equals-negamax-up-to-depth-three print these node counts. The limit bounds the work
of make test in nodes; it is not a measured time.")

(defun deepest-comparison (evaluator-name position-name)
  "The deepest depth at which make test compares alpha-beta with negamax for EVALUATOR-NAME on
the search position POSITION-NAME (see *LARGE-TREE-POSITIONS*)."
  (if (and (string= evaluator-name "classical")
           (member position-name *large-tree-positions* :test #'string=))
      2
      3))

(deftest :search alpha-beta-equals-negamax-up-to-depth-three
  ;; Same score, same best move and same principal variation (both take, at each node, the
  ;; first move reaching the best score), with each evaluation. The notes print the node counts
  ;; that *LARGE-TREE-POSITIONS* cites.
  (let ((compared 0)
        (largest-trees (mapcar (lambda (entry) (cons (car entry) 0)) *search-evaluators*))
        (large-trees '()))
    (loop for (evaluator-name . evaluator) in *search-evaluators*
          do (loop for (name . fen) in *search-positions*
                   do (let ((pos (fen-position fen)))
                        (loop for depth from 0 to (deepest-comparison evaluator-name name)
                              do (multiple-value-bind (nm-score nm-move nm-nodes nm-line)
                                     (scf-ref:negamax-search pos depth :evaluator evaluator)
                                   (multiple-value-bind (ab-score ab-move ab-nodes ab-line)
                                       (scf-ref:alpha-beta-search pos depth :evaluator evaluator)
                                     (incf compared)
                                     (let ((largest (assoc evaluator-name largest-trees
                                                           :test #'string=)))
                                       (setf (cdr largest) (max (cdr largest) nm-nodes)))
                                     (when (and (= depth 3)
                                                (member name *large-tree-positions*
                                                        :test #'string=))
                                       (push (list name nm-nodes) large-trees))
                                     (is-eql nm-score ab-score "~A, ~A depth ~D: score"
                                             evaluator-name name depth)
                                     (is-eql nm-move ab-move "~A, ~A depth ~D: best move"
                                             evaluator-name name depth)
                                     (is-equal nm-line ab-line "~A, ~A depth ~D: variation"
                                               evaluator-name name depth)
                                     (is (<= ab-nodes nm-nodes)
                                         "~A, ~A depth ~D: alpha-beta searched more nodes (~D) ~
                                          than negamax (~D)"
                                         evaluator-name name depth ab-nodes nm-nodes)))))))
    (note "~D evaluation/position/depth triples compared" compared)
    (note "negamax trees at depth 3 of *LARGE-TREE-POSITIONS*:~{ ~{~A ~D~}~^,~} nodes"
          (reverse large-trees))
    (loop for (evaluator-name . nodes) in largest-trees
          do (note "largest negamax tree compared with the ~A evaluation: ~D nodes"
                   evaluator-name nodes))))

(deftest :search alpha-beta-prunes
  ;; With the material evaluation, as when this test was written: the property is one of the
  ;; search, and kiwipete is one of *LARGE-TREE-POSITIONS*, on which make test does not run
  ;; negamax to depth 3 with the classical evaluation.
  (let ((pos (fen-position "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"))
        (material #'scf-ref:evaluate-material))
    (let ((negamax-nodes (nth-value 2 (scf-ref:negamax-search pos 3 :evaluator material)))
          (alpha-beta-nodes (nth-value 2 (scf-ref:alpha-beta-search pos 3 :evaluator material))))
      (note "kiwipete depth 3: negamax ~D nodes, alpha-beta ~D nodes" negamax-nodes
            alpha-beta-nodes)
      (is (< alpha-beta-nodes negamax-nodes)))))

(deftest :search depth-zero-is-the-static-evaluation
  (let ((pos (fen-position "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")))
    (multiple-value-bind (score move nodes line)
        (scf-ref:alpha-beta-search pos 0 :evaluator #'scf-ref:evaluate-material)
      (is-eql 900 score)
      (is-eql +no-move+ move)
      (is-eql 1 nodes)
      (is-eql nil line))
    (dolist (search (list #'scf-ref:alpha-beta-search #'scf-ref:negamax-search))
      (multiple-value-bind (score move nodes line) (funcall search pos 0)
        (is-eql (scf-ref:evaluate-classical pos) score "the classical evaluation by default")
        (is-eql +no-move+ move)
        (is-eql 1 nodes)
        (is-eql nil line))))
  ;; No mate or stalemate check at depth 0: the stalemated side gets its static score.
  (let ((pos (fen-position "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")))
    (is-eql (scf-ref:evaluate-classical pos) (scf-ref:alpha-beta-search pos 0))))

(deftest :search depth-one-is-the-best-negated-child-evaluation
  ;; Worked out from the definition of negamax with the classical evaluation, independently
  ;; of the search code: the value of every legal move is minus the evaluation after it.
  (dolist (fen (mapcar #'cdr scf-ref:*standard-positions*))
    (let* ((pos (fen-position fen))
           (scores (loop for move in (scf-ref:legal-moves pos)
                         collect (progn (scf-ref:make-move pos move)
                                        (prog1 (- (scf-ref:evaluate-classical pos))
                                          (scf-ref:unmake-move pos)))))
           (best (reduce #'max scores)))
      (multiple-value-bind (score move nodes line) (scf-ref:alpha-beta-search pos 1)
        (is-eql best score "~A: score" fen)
        (is-eql (nth (position best scores) (scf-ref:legal-moves pos)) move
                "~A: the first move reaching the best score" fen)
        (is-eql (1+ (length scores)) nodes "~A: the root and every leaf" fen)
        (is-equal (list move) line "~A: variation" fen)))))

(deftest :search mate-scores-are-relative-to-the-ply
  ;; Mate in one: the mated side is to move at ply 1, so the root sees MATE - 1.
  (let ((pos (fen-position "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1")))
    (multiple-value-bind (score move) (scf-ref:alpha-beta-search pos 2)
      (is-eql (- scf-ref:+mate-score+ 1) score)
      (is-equal "a1a8" (move-to-string move)))
    (multiple-value-bind (score move) (scf-ref:negamax-search pos 2)
      (is-eql (- scf-ref:+mate-score+ 1) score)
      (is-equal "a1a8" (move-to-string move)))
    ;; One ply is too shallow: the mate is seen only when the mated side's moves are generated.
    (is-false (scf-ref:mate-score-p (scf-ref:alpha-beta-search pos 1))))
  ;; Scholar's mate.
  (multiple-value-bind (score move)
      (scf-ref:alpha-beta-search
       (fen-position "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4") 2)
    (is-eql (- scf-ref:+mate-score+ 1) score)
    (is-equal "h5f7" (move-to-string move)))
  ;; Mate in two: the mate happens at ply 3.
  (let ((pos (fen-position "7k/8/8/8/8/8/R7/1R2K3 w - - 0 1")))
    (multiple-value-bind (score move) (scf-ref:alpha-beta-search pos 4)
      (is-eql (- scf-ref:+mate-score+ 3) score)
      (is (member (move-to-string move) '("a2a7" "b1b7") :test #'string=)
          "first move of the rook ladder: ~A" (move-to-string move))
      (is-true (scf-ref:mate-score-p score)))))

(deftest :search the-side-to-move-being-mated-scores-minus-mate
  (multiple-value-bind (score move nodes)
      (scf-ref:alpha-beta-search
       (fen-position "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3") 3)
    (is-eql (- scf-ref:+mate-score+) score "checkmated at the root: ply 0")
    (is-eql +no-move+ move)
    (is-eql 1 nodes))
  (multiple-value-bind (score move)
      (scf-ref:alpha-beta-search (fen-position "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1") 3)
    (is-eql 0 score "stalemate scores zero")
    (is-eql +no-move+ move)))

(deftest :search a-loss-is-seen-from-the-losing-side
  ;; Black to move can only play Kg8; then Ra8 mates, so the black score must be the
  ;; negative of the mate.
  (let ((pos (fen-position "7k/8/8/8/8/8/R7/1R2K3 w - - 0 1")))
    (play pos "b1b7")
    (multiple-value-bind (score) (scf-ref:alpha-beta-search pos 3)
      (is-eql (- 2 scf-ref:+mate-score+) score "Black is mated at ply 2 from this root"))))

(deftest :search iterative-deepening-runs-each-depth-and-sums-the-nodes
  (let ((seen '()))
    (multiple-value-bind (score move total iterations)
        (scf-ref:iterative-deepening (scf-ref:start-position) 3
                                     :on-iteration (lambda (iteration) (push iteration seen)))
      (is-eql 3 (length iterations))
      (is-equal '(1 2 3) (mapcar #'scf-ref:iteration-depth iterations))
      (is-eql total (reduce #'+ iterations :key #'scf-ref:iteration-nodes))
      (is-eql 3 (length seen) "the callback ran once per depth")
      (is-eql score (scf-ref:iteration-score (third iterations)))
      (is-eql move (scf-ref:iteration-best-move (third iterations)))
      (is (scf-ref:move-legal-p (scf-ref:start-position) move)))))

(deftest :search iterative-deepening-agrees-with-a-direct-search
  (let ((pos (fen-position "r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1")))
    (multiple-value-bind (score move) (scf-ref:iterative-deepening pos 3)
      (multiple-value-bind (direct-score direct-move) (scf-ref:alpha-beta-search pos 3)
        (is-eql direct-score score)
        (is-eql direct-move move)))
    (multiple-value-bind (score move) (scf-ref:iterative-deepening pos 3 :algorithm :negamax)
      (multiple-value-bind (direct-score direct-move) (scf-ref:negamax-search pos 3)
        (is-eql direct-score score)
        (is-eql direct-move move)))))

(deftest :search iterative-deepening-stops-once-a-mate-is-found
  (multiple-value-bind (score move total iterations)
      (scf-ref:iterative-deepening (fen-position "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1") 6)
    (declare (ignore total))
    (is-eql 2 (length iterations) "depth 1 sees nothing, depth 2 sees the mate, then it stops")
    (is-eql (- scf-ref:+mate-score+ 1) score)
    (is-equal "a1a8" (move-to-string move))))

(deftest :search iterative-deepening-mate-stop-equals-the-full-depth-search
  ;; The early stop must not change the result: the score and best move after the stop
  ;; equal those of a direct search at the full depth, with both algorithms and the material
  ;; evaluation, as when this test was written, and with alpha-beta and the classical one.
  ;; Not negamax with the classical evaluation, by choice, to bound the work of make test: on
  ;; the rook ladder at depth 5 negamax's tree has about 350000 nodes, the largest here (the
  ;; note prints it), and each leaf would compute the nine classical terms. That the two
  ;; algorithms agree with the classical evaluation is tested by
  ;; alpha-beta-equals-negamax-up-to-depth-three. The principal variations of the direct search
  ;; and of the last iteration are checked by PRINCIPAL-VARIATION-PROBLEMS.
  (let ((largest-negamax-tree 0))
    (loop for (fen max-depth stop-depth)
            in '(("6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1" 4 2)
                 ("7k/8/8/8/8/8/R7/1R2K3 w - - 0 1" 5 4)
                 ("7k/1R6/8/8/8/8/R7/4K3 b - - 1 1" 4 3)
                 ("rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3" 3 1))
          do (loop for (algorithm evaluator)
                     in (list (list :alpha-beta #'scf-ref:evaluate-material)
                              (list :negamax #'scf-ref:evaluate-material)
                              (list :alpha-beta #'scf-ref:evaluate-classical))
                   do (let ((pos (fen-position fen))
                            (direct (if (eq algorithm :alpha-beta)
                                        #'scf-ref:alpha-beta-search
                                        #'scf-ref:negamax-search)))
                        (multiple-value-bind (score move total iterations line)
                            (scf-ref:iterative-deepening pos max-depth :algorithm algorithm
                                                                       :evaluator evaluator)
                          (declare (ignore total))
                          (multiple-value-bind (direct-score direct-move direct-nodes direct-line)
                              (funcall direct pos max-depth :evaluator evaluator)
                            (when (eq algorithm :negamax)
                              (setf largest-negamax-tree
                                    (max largest-negamax-tree direct-nodes)))
                            (is-eql stop-depth (length iterations)
                                    "~A ~A: stopped at depth ~D"
                                    fen algorithm (length iterations))
                            (is-true (scf-ref:mate-score-p score) "~A ~A: a mate score"
                                     fen algorithm)
                            (is-eql direct-score score "~A ~A: score" fen algorithm)
                            (is-eql direct-move move "~A ~A: best move" fen algorithm)
                            (is-equal '() (principal-variation-problems
                                           pos max-depth direct-score direct-line evaluator)
                                      "~A ~A: variation of the direct search" fen algorithm)
                            (is-equal '() (principal-variation-problems
                                           pos (length iterations) score line evaluator)
                                      "~A ~A: variation of the last iteration"
                                      fen algorithm))))))
    (note "largest negamax tree of a direct search: ~D nodes" largest-negamax-tree)))

(defun principal-variation-problems (pos depth score line evaluator)
  "The ways in which LINE, a list of moves, fails to be a principal variation of the reference
position POS searched to DEPTH with the root score SCORE, as a list of strings (empty when it
is one). The line is replayed on a copy of POS by the reference: each move must be one of the
legal moves of the reference (SCF-REF:MOVE-LEGAL-P) in the position where it is played, and the
line holds at most DEPTH moves. Then, from the side to move at the root
(docs/valutazione.md, \"Convenzioni per la ricerca\"):
 - a mate score (SCF-REF:MATE-SCORE-P), +MATE-SCORE+ - N or N - +MATE-SCORE+, says a mate at
   ply N: the line must hold exactly N moves, N below DEPTH (a node at depth 0 returns the
   static evaluation without looking for mate), and end in checkmate, of the root's opponent
   when the score is positive (N odd) and of the root's side when it is negative (N even);
 - any other score must be the static evaluation EVALUATOR of the position at the end of a
   line of DEPTH moves, negated when the side to move there is not the root's, or 0 at the end
   of a shorter line that ends in stalemate."
  (let ((copy (scf-ref:clone-position pos))
        (sign 1))
    (dolist (move line)
      (unless (scf-ref:move-legal-p copy move)
        (return-from principal-variation-problems
          (list (format nil "~A is not legal in ~A" (move-to-string move)
                        (scf-ref:position-to-fen copy)))))
      (scf-ref:make-move copy move)
      (setf sign (- sign)))
    (let ((plies (length line))
          (outcome (scf-ref:game-outcome copy)))
      (cond ((> plies depth)
             (list (format nil "~D plies, longer than the depth ~D" plies depth)))
            ((scf-ref:mate-score-p score)
             (let ((mate-ply (- scf-ref:+mate-score+ (abs score))))
               (append
                (unless (= plies mate-ply)
                  (list (format nil "the score ~D says a mate at ply ~D; the line has ~D plies"
                                score mate-ply plies)))
                (unless (< plies depth)
                  (list (format nil "a mate at ply ~D, not below the depth ~D" plies depth)))
                (unless (eq outcome :checkmate)
                  (list (format nil "the line of the mate score ~D ends in ~A, not in checkmate"
                                score (scf-ref:position-to-fen copy))))
                (unless (eq (plusp score) (oddp plies))
                  (list (format nil "the score ~D has the sign of the other side's mate" score))))))
            ((= plies depth)
             (let ((static (* sign (funcall evaluator copy))))
               (unless (= score static)
                 (list (format nil "the score ~D is not ~D, the evaluation at the end of the ~
                                    line seen from the root" score static)))))
            ((not (eq outcome :stalemate))
             (list (format nil "the line ends after ~D of ~D plies in ~A, which is not ~
                                stalemate, with the score ~D"
                           plies depth (scf-ref:position-to-fen copy) score)))
            ((/= score 0)
             (list (format nil "the line ends in stalemate, and the score is ~D, not 0"
                           score)))
            (t '())))))

(deftest :search principal-variation-check-finds-planted-errors
  ;; PRINCIPAL-VARIATION-PROBLEMS must accept true variations and report each kind of false
  ;; one; without this the tests that use it could pass with a check that accepts anything.
  (let* ((mate scf-ref:+mate-score+)
         (back-rank (fen-position "6k1/5ppp/8/8/8/8/8/R3K3 w - - 0 1"))
         (start (scf-ref:start-position))
         (stalemate (fen-position "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"))
         (a1a8 (scf-ref:parse-move back-rank "a1a8"))
         (a1a7 (scf-ref:parse-move back-rank "a1a7"))
         (e2e4 (scf-ref:parse-move start "e2e4"))
         (e7e5 (let ((after-e2e4 (scf-ref:start-position)))
                 (scf-ref:make-move after-e2e4 e2e4)
                 (scf-ref:parse-move after-e2e4 "e7e5")))
         (e2e4-score (progn (scf-ref:make-move start e2e4)
                            (prog1 (- (scf-ref:evaluate-classical start))
                              (scf-ref:unmake-move start)))))
    (flet ((accepted (pos depth score line why)
             (is-equal '() (principal-variation-problems pos depth score line
                                                         #'scf-ref:evaluate-classical)
                       "a true variation is refused: ~A" why))
           (refused (pos depth score line why)
             (is (principal-variation-problems pos depth score line #'scf-ref:evaluate-classical)
                 "a false variation is accepted: ~A" why)))
      (accepted back-rank 2 (- mate 1) (list a1a8) "mate in one")
      (accepted start 1 e2e4-score (list e2e4) "one ply from the start position")
      (accepted stalemate 1 0 '() "stalemated at the root")
      (accepted (fen-position "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3") 3
                (- mate) '() "checkmated at the root")
      (refused back-rank 2 (- mate 1) (list e2e4) "a move that is not legal there")
      (refused start 1 e2e4-score (list e2e4 e7e5) "a line longer than the depth")
      (refused start 1 (1+ e2e4-score) (list e2e4) "a score that is not the evaluation")
      (refused start 2 e2e4-score (list e2e4) "a line that stops at a position with moves")
      (refused stalemate 1 5 '() "a stalemate that does not score 0")
      (refused back-rank 2 (- mate 3) (list a1a8) "a mate at another ply than the score says")
      (refused back-rank 2 (- 1 mate) (list a1a8) "a mate with the sign of the other side")
      (refused back-rank 2 (- mate 1) (list a1a7) "a mate score whose line does not mate")
      (refused back-rank 1 (- mate 1) (list a1a8) "a mate at the depth of the search"))))

(deftest :search principal-variation-leads-to-the-score
  ;; Every variation of the reference's searches in generation order on the search positions,
  ;; at the depths at which alpha-beta-equals-negamax-up-to-depth-three runs them, with each
  ;; evaluation, replayed by PRINCIPAL-VARIATION-PROBLEMS.
  (let ((checked 0))
    (loop for (evaluator-name . evaluator) in *search-evaluators*
          do (loop for (name . fen) in *search-positions*
                   do (let ((pos (fen-position fen)))
                        (loop for depth from 0 to 3
                              do (dolist (search (list #'scf-ref:alpha-beta-search
                                                       #'scf-ref:negamax-search))
                                   ;; Negamax to the depth to which
                                   ;; alpha-beta-equals-negamax-up-to-depth-three runs it.
                                   (when (or (eq search #'scf-ref:alpha-beta-search)
                                             (<= depth (deepest-comparison evaluator-name
                                                                           name)))
                                     (multiple-value-bind (score move nodes line)
                                         (funcall search pos depth :evaluator evaluator)
                                       (declare (ignore nodes))
                                       (incf checked)
                                       (is-eql (if line (first line) +no-move+) move
                                               "~A, ~A depth ~D: the line starts with the move"
                                               evaluator-name name depth)
                                       (is-equal '()
                                                 (principal-variation-problems
                                                  pos depth score line evaluator)
                                                 "~A, ~A depth ~D" evaluator-name name
                                                 depth))))))))
    (note "~D variations checked" checked)))

(defparameter *move-order-seeds* '(1 20261004 977)
  "Seeds of the generators that permute the moves of every node in the move-order tests.")

(deftest :search alpha-beta-value-does-not-depend-on-the-move-order
  ;; "Proprietà di alpha-beta puro" (docs/verifica.md): without a transposition table or any
  ;; pruning but alpha-beta, the full-window value does not depend on the order of the moves.
  ;; The moves of every node are permuted by a seeded generator; the best move and the node
  ;; count may change, the value may not. Negamax is permuted too, to depth 2. On the
  ;; positions of *LARGE-TREE-POSITIONS* depth 3 runs with the first seed only. The principal
  ;; variation of every permuted search is checked by PRINCIPAL-VARIATION-PROBLEMS.
  (let ((compared 0))
    (loop for (name . fen) in *search-positions*
          do (let ((pos (fen-position fen)))
               (loop for depth from 1 to 3
                     do (let ((expected (scf-ref:alpha-beta-search pos depth)))
                          (dolist (seed (if (and (= depth 3)
                                                 (member name *large-tree-positions*
                                                         :test #'string=))
                                            (list (first *move-order-seeds*))
                                            *move-order-seeds*))
                            (multiple-value-bind (score move nodes line)
                                (scf-ref:alpha-beta-search pos depth
                                                           :shuffle-rng (make-rng seed))
                              (declare (ignore nodes))
                              (incf compared)
                              (is-eql expected score "~A depth ~D seed ~D: alpha-beta"
                                      name depth seed)
                              (is-equal '() (principal-variation-problems
                                             pos depth score line
                                             #'scf-ref:evaluate-classical)
                                        "~A depth ~D seed ~D: variation" name depth seed)
                              (is-eql (if line (first line) +no-move+) move)))
                          (when (<= depth 2)
                            (multiple-value-bind (score move nodes line)
                                (scf-ref:negamax-search pos depth
                                                        :shuffle-rng
                                                        (make-rng (first *move-order-seeds*)))
                              (declare (ignore move nodes))
                              (is-eql expected score "~A depth ~D: negamax permuted" name depth)
                              (is-equal '() (principal-variation-problems
                                             pos depth score line
                                             #'scf-ref:evaluate-classical)
                                        "~A depth ~D: negamax permuted, variation"
                                        name depth)))))))
    (note "~D permuted searches compared, seeds ~S" compared *move-order-seeds*)))

(deftest :search a-permutation-really-changes-the-search-order
  ;; Without this the test above could pass with a hook that permutes nothing.
  (let ((pos (fen-position "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")))
    (is (/= (nth-value 2 (scf-ref:alpha-beta-search pos 3))
            (nth-value 2 (scf-ref:alpha-beta-search pos 3 :shuffle-rng (make-rng 1))))
        "the node count of kiwipete at depth 3 is the same after the permutation")))

(deftest :search iterative-deepening-equals-the-direct-search-at-every-depth
  ;; Each iteration is a complete search from scratch: iteration d returns what the direct
  ;; search at d returns, value, best move, node count and variation, with both algorithms.
  (loop for (name . fen) in *search-positions*
        do (let ((pos (fen-position fen)))
             (dolist (algorithm '(:alpha-beta :negamax))
               (let ((direct (if (eq algorithm :alpha-beta)
                                 #'scf-ref:alpha-beta-search
                                 #'scf-ref:negamax-search))
                     (max-depth (if (eq algorithm :alpha-beta) 3 2)))
                 (multiple-value-bind (score move total iterations line)
                     (scf-ref:iterative-deepening pos max-depth :algorithm algorithm)
                   (let ((last (first (last iterations))))
                     (is-eql score (scf-ref:iteration-score last) "~A ~A" name algorithm)
                     (is-eql move (scf-ref:iteration-best-move last) "~A ~A" name algorithm)
                     (is-equal line (scf-ref:iteration-pv last) "~A ~A" name algorithm)
                     (is-eql total (reduce #'+ iterations :key #'scf-ref:iteration-nodes)))
                   (dolist (iteration iterations)
                     (let ((depth (scf-ref:iteration-depth iteration)))
                       (multiple-value-bind (d-score d-move d-nodes d-line)
                           (funcall direct pos depth)
                         (is-eql d-score (scf-ref:iteration-score iteration)
                                 "~A ~A depth ~D: score" name algorithm depth)
                         (is-eql d-move (scf-ref:iteration-best-move iteration)
                                 "~A ~A depth ~D: best move" name algorithm depth)
                         (is-eql d-nodes (scf-ref:iteration-nodes iteration)
                                 "~A ~A depth ~D: nodes" name algorithm depth)
                         (is-equal d-line (scf-ref:iteration-pv iteration)
                                   "~A ~A depth ~D: variation" name algorithm depth))))
                   (unless (scf-ref:mate-score-p score)
                     (is-eql max-depth (length iterations)
                             "~A ~A: every depth without a mate" name algorithm))))))))

(deftest :search search-arguments-are-checked
  (signals type-error (scf-ref:alpha-beta-search (scf-ref:start-position) -1))
  (signals type-error (scf-ref:iterative-deepening (scf-ref:start-position) 0)))
