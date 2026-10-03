(in-package :scacchiforge-tests)

(def-suite movegen-suite
  :description "Move generation tests"
  :in scacchiforge-tests)

(in-suite movegen-suite)

(test pawn-moves-starting-position
  "Test pawn moves from starting position"
  (let ((pos (make-position)))
    (let ((pawn-moves (loop for sq from 8 to 15
                            append (piece-pseudo-legal-moves pos sq))))
      ;; 8 pawns × 2 moves each (single and double push) = 16 moves
      (is (= (length pawn-moves) 16)))))

(test knight-moves-starting-position
  "Test knight moves from starting position"
  (let ((pos (make-position)))
    ;; Knights at 1 and 6
    (let ((knight-1-moves (piece-pseudo-legal-moves pos 1))
          (knight-6-moves (piece-pseudo-legal-moves pos 6)))
      ;; Each knight has 2 moves
      (is (= (length knight-1-moves) 2))
      (is (= (length knight-6-moves) 2)))))

(test legal-move-filter
  "Test that legal move filter removes illegal moves"
  (let ((pos (make-position)))
    (let ((pseudo-legal (generate-pseudo-legal-moves pos))
          (legal (filter-legal-moves pos (generate-pseudo-legal-moves pos))))
      ;; All moves from starting position are legal
      (is (= (length pseudo-legal) (length legal)))
      ;; Should be 20 moves
      (is (= (length legal) 20)))))
