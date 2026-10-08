;;;; movegen.lisp -- pseudo-legal move generation.
;;;;
;;;; A pseudo-legal move obeys the movement rules of the piece but may leave the mover's own
;;;; king attacked (pins, moving into check, an unanswered check). Legality is a separate
;;;; step: see legal.lisp. Castling is the one exception: it is generated only when the
;;;; right is held, the king and rook are at home, the squares between them are empty and
;;;; none of the three squares the king uses (start, crossed, landing) is attacked.
;;;;
;;;; Moves are written into a preallocated buffer of fixnums; no object is allocated per move.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(deftype move-buffer () '(simple-array fixnum (*)))

(defconstant +move-stride+ 1024
  "Slots reserved per ply when one buffer serves a whole search or perft.")

(defun make-move-buffer (&optional (plies 1))
  "A buffer that holds the moves of PLIES plies of +MOVE-STRIDE+ slots each."
  (make-array (* plies +move-stride+) :element-type 'fixnum :initial-element 0))

(defmacro push-move (buffer index move)
  "Store MOVE at INDEX of BUFFER and advance INDEX."
  `(progn (setf (aref ,buffer ,index) ,move)
          (incf ,index)))

(defun push-promotions (buffer index from to flags)
  "Store the four promotions of a pawn move FROM -> TO; return the new index."
  (declare (type move-buffer buffer) (type fixnum index) (type square from to)
           (type (integer 0 31) flags))
  ;; Piece types 5, 4, 3, 2: queen, rook, bishop, knight.
  (dolist (type '(5 4 3 2))
    (push-move buffer index (encode-move from to type flags)))
  index)

(defun enemy-piece-p (piece side)
  "True when PIECE is a non-empty piece of the colour opposing SIDE."
  (declare (type piece piece) (type colour side))
  (and (/= piece +empty+) (/= (piece-colour piece) side)))

(defun gen-pawn-moves (board square side en-passant buffer index)
  "Store the pseudo-legal moves of the pawn of SIDE on SQUARE; return the new index."
  (declare (type board-vector board) (type square square) (type colour side)
           (type (integer 0 64) en-passant) (type move-buffer buffer) (type fixnum index))
  (let* ((white (= side +white+))
         (up (if white 8 -8))
         (start-rank (if white 1 6))
         (promotion-rank (if white 7 0))
         (one (+ square up)))
    (when (= (aref board one) +empty+)
      (if (= (square-rank one) promotion-rank)
          (setf index (push-promotions buffer index square one 0))
          (progn
            (push-move buffer index (encode-move square one 0 0))
            (when (and (= (square-rank square) start-rank)
                       (= (aref board (+ one up)) +empty+))
              (push-move buffer index
                         (encode-move square (+ one up) 0 +flag-double-push+))))))
    (loop for target across (pawn-attack-squares side square)
          do (cond ((enemy-piece-p (aref board target) side)
                    (if (= (square-rank target) promotion-rank)
                        (setf index (push-promotions buffer index square target +flag-capture+))
                        (push-move buffer index
                                   (encode-move square target 0 +flag-capture+))))
                   ((= target en-passant)
                    (push-move buffer index
                               (encode-move square target 0
                                            (logior +flag-capture+ +flag-en-passant+))))))
    index))

(defun gen-step-moves (board square side targets buffer index)
  "Store the moves of a knight or king on SQUARE to the squares in TARGETS."
  (declare (type board-vector board) (type square square) (type colour side)
           (type square-vector targets) (type move-buffer buffer) (type fixnum index))
  (loop for target across targets
        for occupant = (aref board target)
        do (cond ((= occupant +empty+)
                  (push-move buffer index (encode-move square target 0 0)))
                 ((enemy-piece-p occupant side)
                  (push-move buffer index (encode-move square target 0 +flag-capture+)))))
  index)

(defun gen-slider-moves (board square side first-direction end-direction buffer index)
  "Store the moves of a slider on SQUARE along the directions FIRST-DIRECTION below
END-DIRECTION (0..4 rook, 4..8 bishop, 0..8 queen)."
  (declare (type board-vector board) (type square square) (type colour side)
           (type (integer 0 8) first-direction end-direction)
           (type move-buffer buffer) (type fixnum index))
  (loop for direction from first-direction below end-direction
        do (loop for target across (ray-squares direction square)
                 for occupant = (aref board target)
                 do (cond ((= occupant +empty+)
                           (push-move buffer index (encode-move square target 0 0)))
                          (t (when (enemy-piece-p occupant side)
                               (push-move buffer index
                                          (encode-move square target 0 +flag-capture+)))
                             (return)))))
  index)

(defun gen-castling-moves (pos side buffer index)
  "Store the castling moves of SIDE that satisfy the rule in the file header."
  (declare (type chess-position pos) (type colour side) (type move-buffer buffer)
           (type fixnum index))
  (let* ((board (pos-board pos))
         (rights (pos-castling pos))
         (white (= side +white+))
         (base (if white 0 56))
         (other (opposite-colour side))
         (king-right (if white +castle-white-king+ +castle-black-king+))
         (queen-right (if white +castle-white-queen+ +castle-black-queen+))
         (rook (make-piece side +rook+))
         (king-home (+ base 4)))
    (when (and (logtest rights (logior king-right queen-right))
               (= (aref board king-home) (make-piece side +king+))
               (not (square-attacked-p pos king-home other)))
      (when (and (logtest rights king-right)
                 (= (aref board (+ base 7)) rook)
                 (= (aref board (+ base 5)) +empty+)
                 (= (aref board (+ base 6)) +empty+)
                 (not (square-attacked-p pos (+ base 5) other))
                 (not (square-attacked-p pos (+ base 6) other)))
        (push-move buffer index (encode-move king-home (+ base 6) 0 +flag-castle-king+)))
      (when (and (logtest rights queen-right)
                 (= (aref board base) rook)
                 (= (aref board (+ base 1)) +empty+)
                 (= (aref board (+ base 2)) +empty+)
                 (= (aref board (+ base 3)) +empty+)
                 (not (square-attacked-p pos (+ base 3) other))
                 (not (square-attacked-p pos (+ base 2) other)))
        (push-move buffer index (encode-move king-home (+ base 2) 0 +flag-castle-queen+))))
    index))

(defun generate-pseudo-legal-for (pos side en-passant buffer start)
  "Store the pseudo-legal moves of SIDE (not necessarily the side to move of POS) in
BUFFER from index START, using EN-PASSANT as the en-passant target. Return the end index."
  (declare (type chess-position pos) (type colour side) (type (integer 0 64) en-passant)
           (type move-buffer buffer) (type fixnum start))
  (let ((board (pos-board pos))
        (index start))
    (declare (type fixnum index))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (when (and (/= piece +empty+) (= (piece-colour piece) side))
          (let ((type (piece-type piece)))
            (cond ((= type +pawn+)
                   (setf index (gen-pawn-moves board square side en-passant buffer index)))
                  ((= type +knight+)
                   (setf index (gen-step-moves board square side
                                               (step-targets **knight-targets** square)
                                               buffer index)))
                  ((= type +king+)
                   (setf index (gen-step-moves board square side
                                               (step-targets **king-targets** square)
                                               buffer index)))
                  ((= type +bishop+)
                   (setf index (gen-slider-moves board square side 4 8 buffer index)))
                  ((= type +rook+)
                   (setf index (gen-slider-moves board square side 0 4 buffer index)))
                  (t
                   (setf index (gen-slider-moves board square side 0 8 buffer index))))))))
    (gen-castling-moves pos side buffer index)))

(defun generate-pseudo-legal (pos buffer start)
  "Store the pseudo-legal moves of the side to move of POS in BUFFER from index START.
Return the index after the last move."
  (declare (type chess-position pos) (type move-buffer buffer) (type fixnum start))
  (generate-pseudo-legal-for pos (pos-side pos) (pos-en-passant pos) buffer start))
