(in-package :scacchiforge-tests)

(def-suite perft-suite
  :description "PERFT correctness tests"
  :in scacchiforge-tests)

(in-suite perft-suite)

(defun perft (pos depth)
  "Count leaf nodes at given depth.
   [EXACT] Correct leaf count for position at depth."
  (if (zerop depth)
      1
      (let ((count 0))
        (dolist (move (filter-legal-moves pos (generate-pseudo-legal-moves pos)))
          (let ((prior-state (copy-position pos)))
            (make-move-on-position pos move)
            (incf count (perft pos (- depth 1)))
            (unmake-move-on-position pos move prior-state)))
        count)))

;; PERFT test data
;; Position: starting position
(test starting-position-perft
  "Test PERFT on starting position"
  (let ((pos (make-position)))
    ;; Depth 1: 20 moves
    (is (= (perft pos 1) 20))
    ;; Depth 2: 400 moves
    (is (= (perft pos 2) 400))
    ;; Depth 3: 5,362 moves
    (is (= (perft pos 3) 5362))))

(defun fen->position (fen-string)
  "Parse FEN string and create position.
   [TODO] Implement FEN parser."
  nil)

(test perft-kiwipete
  "Test PERFT on Kiwipete position (famous test position)
   Kiwipete: r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
  :skip "FEN parser not yet implemented"
  (let ((pos (fen->position "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -")))
    ;; Depth 1: 48 moves
    (is (= (perft pos 1) 48))
    ;; Depth 2: 2039 moves
    (is (= (perft pos 2) 2039))
    ;; Depth 3: 97,862 moves
    (is (= (perft pos 3) 97862))))
