;;;; mirror.lisp -- the colour swap of a position and of a move.
;;;;
;;;; The colour swap m(p) (docs/valutazione.md, "Simmetria dei colori") puts every piece of
;;;; colour c and type t on square s onto square s XOR 56 with the other colour and the same
;;;; type: the board is flipped vertically and the colours exchanged. It also swaps the side
;;;; to move and the castling rights (K with k, Q with q), reflects the en-passant square and
;;;; keeps the clocks. Chess is symmetric under it: the legal moves of m(p) are the mirrored
;;;; legal moves of p, perft counts are equal, and the evaluation seen by the side to move is
;;;; the same (INV-C7). The tests use it to check all three.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun mirror-square (square)
  "SQUARE reflected vertically: the same file, rank r becomes rank 7 - r."
  (declare (type square square))
  (logxor square 56))

(defun mirror-piece (piece)
  "PIECE with the other colour and the same type; an empty square stays empty."
  (declare (type piece piece))
  (if (= piece +empty+)
      +empty+
      (make-piece (opposite-colour (piece-colour piece)) (piece-type piece))))

(defun mirror-castling (rights)
  "The castling RIGHTS with White's and Black's exchanged: K with k, Q with q."
  (declare (type (integer 0 15) rights))
  (let ((mirrored 0))
    (loop for (right . swapped) in `((,+castle-white-king+ . ,+castle-black-king+)
                                     (,+castle-white-queen+ . ,+castle-black-queen+)
                                     (,+castle-black-king+ . ,+castle-white-king+)
                                     (,+castle-black-queen+ . ,+castle-white-queen+))
          when (logtest rights right)
            do (setf mirrored (logior mirrored swapped)))
    mirrored))

(defun mirror-move (move)
  "MOVE as played in the colour-swapped position: both squares reflected, the promotion type
and the flags kept."
  (declare (type move move))
  (encode-move (mirror-square (move-from move)) (mirror-square (move-to move))
               (move-promotion move) (move-flags move)))

(defun mirror-position (pos)
  "A new position, the colour swap of POS: every piece moved to the reflected square with the
other colour, the side to move and the castling rights swapped, the en-passant square
reflected, the clocks kept. The key is computed from scratch; the undo stack is empty. POS is
not changed. Applied twice it gives back a position equal to POS."
  (declare (type chess-position pos))
  (let ((board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0))
        (en-passant (pos-en-passant pos)))
    (dotimes (square 64)
      (setf (aref board (mirror-square square)) (mirror-piece (piece-at pos square))))
    (make-position-from-parts board
                              (opposite-colour (pos-side pos))
                              (mirror-castling (pos-castling pos))
                              (if (= en-passant +no-square+)
                                  +no-square+
                                  (mirror-square en-passant))
                              (pos-halfmove pos)
                              (pos-fullmove pos))))
