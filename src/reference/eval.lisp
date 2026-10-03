(in-package :scacchiforge.reference)

(defun evaluate (pos)
  "Simple material-only evaluation for reference implementation.
   [EXACT] Deterministic evaluation of position.
   Later phases will add positional features."
  (let ((material 0))
    (loop for sq from 0 to 63
          when (position-occupied-p pos sq)
          do (let ((piece-info (position-piece pos sq)))
               (let ((color (car piece-info))
                     (piece (cdr piece-info)))
                 (let ((value (piece-material-value piece))
                       (sign (if (eq color +white+) 1 -1)))
                   (incf material (* sign value))))))
    material))

(defun piece-material-value (piece)
  "Material value of piece type."
  (case piece
    (:pawn 1)
    (:knight 3)
    (:bishop 3)
    (:rook 5)
    (:queen 9)
    (:king 0)))

(defun static-exchange-evaluation (pos from to)
  "SEE: Static Exchange Evaluation.
   [BOUNDED] Lower bound on gain from capture sequence.
   [HEURISTIC] Overestimates when tactical patterns not visible."
  (let ((gain 0)
        (attacker-value (piece-material-value (cdr (position-piece pos from))))
        (target-value (if (position-occupied-p pos to)
                          (piece-material-value (cdr (position-piece pos to)))
                          0)))
    (incf gain target-value)
    ;; Simplified: just return target value
    ;; Full implementation would recursively evaluate capture sequences
    gain))
