;;;; attacks.lisp -- is a square attacked? Is the king in check?
;;;;
;;;; Square-centred: it looks outward from the target square for an attacker of each kind.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun ray-attacker-p (board square by first-direction end-direction type-a type-b)
  "True when walking the rays FIRST-DIRECTION below END-DIRECTION from SQUARE meets, as
the first piece on a ray, a piece of colour BY and type TYPE-A or TYPE-B."
  (declare (type board-vector board) (type square square) (type colour by)
           (type (integer 0 8) first-direction end-direction)
           (type (integer 1 6) type-a type-b))
  (let ((piece-a (make-piece by type-a))
        (piece-b (make-piece by type-b)))
    (loop for direction from first-direction below end-direction
          do (loop for target across (ray-squares direction square)
                   for piece = (aref board target)
                   do (unless (= piece +empty+)
                        (when (or (= piece piece-a) (= piece piece-b))
                          (return-from ray-attacker-p t))
                        (return))))
    nil))

(defun step-attacker-p (board squares piece)
  "True when PIECE stands on one of SQUARES."
  (declare (type board-vector board) (type square-vector squares) (type piece piece))
  (loop for target across squares
        thereis (= (aref board target) piece)))

(defun square-attacked-p (pos square by)
  "True when a piece of colour BY attacks SQUARE in POS (pins are ignored: an attack is
an attack)."
  (declare (type chess-position pos) (type square square) (type colour by))
  (let ((board (pos-board pos)))
    (or (step-attacker-p board (pawn-attack-squares (opposite-colour by) square)
                         (make-piece by +pawn+))
        (step-attacker-p board (step-targets **knight-targets** square)
                         (make-piece by +knight+))
        (step-attacker-p board (step-targets **king-targets** square)
                         (make-piece by +king+))
        (ray-attacker-p board square by 0 4 +rook+ +queen+)
        (ray-attacker-p board square by 4 8 +bishop+ +queen+))))

(defun king-attacked-p (pos colour)
  "True when the king of COLOUR is attacked by the opposite colour."
  (declare (type chess-position pos) (type colour colour))
  (square-attacked-p pos (king-square pos colour) (opposite-colour colour)))

(defun in-check-p (pos)
  "True when the side to move is in check."
  (declare (type chess-position pos))
  (king-attacked-p pos (pos-side pos)))

(defun en-passant-capture-available-p (pos)
  "True when POS has an en-passant square and a pawn of the side to move attacks it.
Pins are not considered (see the en-passant policy in core/zobrist.lisp)."
  (declare (type chess-position pos))
  (let ((target (pos-en-passant pos)))
    (and (/= target +no-square+)
         (step-attacker-p (pos-board pos)
                          (pawn-attack-squares (opposite-colour (pos-side pos)) target)
                          (make-piece (pos-side pos) +pawn+)))))
