(in-package :scacchiforge.reference)

(defstruct search-result
  "Result of a search."
  (value 0 :type integer)
  (best-move nil :type (or null move))
  (depth 0 :type integer)
  (nodes 0 :type integer)
  (time-ms 0 :type integer))

(defun negamax (pos depth)
  "Negamax: minimax with sign convention.
   [EXACT] Correct evaluation under negamax model.
   [THEOREM] Equivalent to minimax."
  (if (zerop depth)
      (evaluate pos)
      (let ((best-value most-negative-fixnum))
        (dolist (move (filter-legal-moves pos (generate-pseudo-legal-moves pos)))
          (let ((prior-state (copy-position pos)))
            (make-move-on-position pos move)
            (let ((value (- (negamax pos (- depth 1)))))
              (when (> value best-value)
                (setf best-value value)))
            (unmake-move-on-position pos move prior-state)))
        best-value)))

(defun alpha-beta (pos depth alpha beta)
  "Alpha-Beta pruning: minimax with cutoffs.
   [THEOREM] Produces minimax value with fewer evaluations.
   [EXACT] Pruning is safe."
  (if (zerop depth)
      (evaluate pos)
      (dolist (move (filter-legal-moves pos (generate-pseudo-legal-moves pos)))
        (let ((prior-state (copy-position pos)))
          (make-move-on-position pos move)
          (let ((value (- (alpha-beta pos (- depth 1) (- beta) (- alpha)))))
            (unmake-move-on-position pos move prior-state)
            (when (>= value beta)
              (return-from alpha-beta beta))
            (when (> value alpha)
              (setf alpha value))))
        finally (return-from alpha-beta alpha))))

(defun iterative-deepening-search (pos max-depth)
  "Iterative deepening: search from depth 1 to max-depth.
   [EXACT] Finds best move, depth-limited.
   [THEOREM] Asymptotically optimal with good move ordering."
  (let ((best-move nil)
        (best-value most-negative-fixnum))
    (loop for d from 1 to max-depth
          do (multiple-value-bind (move value)
                 (search-at-depth pos d)
               (when (> value best-value)
                 (setf best-value value)
                 (setf best-move move))))
    (values best-move best-value)))

(defun search-at-depth (pos depth)
  "Search at specific depth, return (move . value)."
  (let ((moves (filter-legal-moves pos (generate-pseudo-legal-moves pos)))
        (best-move nil)
        (best-value most-negative-fixnum))
    (dolist (move moves)
      (let ((prior-state (copy-position pos)))
        (make-move-on-position pos move)
        (let ((value (- (negamax pos (- depth 1)))))
          (unmake-move-on-position pos move prior-state)
          (when (> value best-value)
            (setf best-value value)
            (setf best-move move)))))
    (values best-move best-value)))
