;;;; mirror.lisp -- the colour swap of a bitboard position.
;;;;
;;;; The colour swap m(p) (docs/valutazione.md, "Simmetria dei colori") puts every piece of colour
;;;; c and type t on square s onto square s XOR 56 with the other colour and the same type, swaps
;;;; the side to move and the castling rights (K with k, Q with q), reflects the en-passant square
;;;; and keeps the clocks. On bitboards the reflection of the ranks is a reversal of the eight
;;;; bytes of each bitboard, and the colour swap exchanges the bitboards of the two colours. The
;;;; tests use it to check the colour symmetry of the evaluation of this layer (INV-C7) without
;;;; going through the reference, and compare it with the reference's MIRROR-POSITION.
;;;;
;;;; Not on the hot path: it allocates the new position.

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(defun flip-ranks (bits)
  "BITS with its ranks reflected: the byte of rank r moved to rank 7 - r, the files kept."
  (declare (type bitboard bits))
  (let ((flipped 0))
    (declare (type bitboard flipped))
    (dotimes (rank 8 flipped)
      (setf flipped (logior flipped (ash (ldb (byte 8 (* 8 rank)) bits) (* 8 (- 7 rank))))))))

(defun swap-castling-rights (rights)
  "The castling RIGHTS with White's and Black's exchanged: K with k, Q with q."
  (declare (type (integer 0 15) rights))
  (logior (if (logtest rights +castle-white-king+) +castle-black-king+ 0)
          (if (logtest rights +castle-white-queen+) +castle-black-queen+ 0)
          (if (logtest rights +castle-black-king+) +castle-white-king+ 0)
          (if (logtest rights +castle-black-queen+) +castle-white-queen+ 0)))

(defun bitboard-mirror (bbp)
  "A new bitboard position, the colour swap of BBP: the pieces of each colour moved to the
reflected squares with the other colour, the side to move and the castling rights swapped, the
en-passant square reflected, the clocks kept. The key and the evaluation state are computed from
scratch; the undo stack is empty. BBP is not changed. Applied twice it gives back a position
equal to BBP (BITBOARD-EQUAL-P)."
  (declare (type bitboard-position bbp))
  (let ((mirror (%make-bitboard-position))
        (en-passant (bbp-en-passant bbp)))
    (dotimes (index 12)
      ;; Index c * 6 + t - 1 takes the bitboard of the other colour, same type.
      (setf (aref (bbp-pieces mirror) (mod (+ index 6) 12))
            (flip-ranks (aref (bbp-pieces bbp) index))))
    (dotimes (colour 2)
      (setf (aref (bbp-colour-occupancy mirror) (opposite-colour colour))
            (flip-ranks (aref (bbp-colour-occupancy bbp) colour))))
    (setf (bbp-occupancy mirror) (flip-ranks (bbp-occupancy bbp)))
    (dotimes (square 64)
      (let ((piece (aref (bbp-board bbp) square)))
        (setf (aref (bbp-board mirror) (logxor square 56))
              (if (= piece +empty+)
                  +empty+
                  (make-piece (opposite-colour (piece-colour piece)) (piece-type piece))))))
    (setf (bbp-side mirror) (opposite-colour (bbp-side bbp))
          (bbp-castling mirror) (swap-castling-rights (bbp-castling bbp))
          (bbp-en-passant mirror) (if (= en-passant +no-square+)
                                      +no-square+
                                      (logxor en-passant 56))
          (bbp-halfmove mirror) (bbp-halfmove bbp)
          (bbp-fullmove mirror) (bbp-fullmove bbp))
    (setf (bbp-key mirror) (bitboard-compute-key mirror))
    (set-evaluation-state-from-scratch mirror)))
