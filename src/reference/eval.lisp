;;;; eval.lisp -- material evaluation, the Phase 2 baseline.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(sb-ext:defglobal **material-values**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 100 300 300 500 900 0)))

(defun material-value (type)
  "Centipawn value of piece TYPE (1..6). The king counts 0. Conventional values, not tuned."
  (declare (type (integer 1 6) type))
  (aref **material-values** type))

(defun evaluate-material (pos)
  "Material balance of POS in centipawns from the point of view of the side to move:
positive when the side to move has more material. Baseline only: no positional term.

Classification: [HEURISTIC]
Basis: material approximates the value of a position; it ignores every positional and
tactical factor, so it can rank two positions the wrong way round.
Evidence: none yet."
  (declare (type chess-position pos))
  (let ((balance 0)
        (board (pos-board pos)))
    (declare (type fixnum balance))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (unless (= piece +empty+)
          (let ((value (material-value (piece-type piece))))
            (if (= (piece-colour piece) +white+)
                (incf balance value)
                (decf balance value))))))
    (if (= (pos-side pos) +white+) balance (- balance))))
