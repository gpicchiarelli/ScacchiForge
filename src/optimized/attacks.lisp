;;;; attacks.lisp -- attackers of a square and check, on the bitboards.
;;;;
;;;; Square-centred, like every bitboard engine: the pieces of colour BY that attack SQUARE are
;;;; found by placing each kind of piece on SQUARE and intersecting its attacks with the pieces
;;;; of that kind. A pawn is the one piece whose attack is not symmetric, so the pawns of BY
;;;; that attack SQUARE stand where a pawn of the OTHER colour on SQUARE would attack.

(in-package #:scacchiforge.optimized)

(declaim-optimized-policy)

(declaim (inline piece-bits king-square-of attackers-of attacked-by-p))

(defun piece-bits (bbp colour type)
  "The bitboard of the pieces of COLOUR and TYPE (1..6) in BBP."
  (declare (type bitboard-position bbp) (type colour colour) (type (integer 1 6) type))
  (aref (bbp-pieces bbp) (+ (* colour 6) (1- type))))

(defun king-square-of (bbp colour)
  "The square of the king of COLOUR. BBP must hold exactly one such king."
  (declare (type bitboard-position bbp) (type colour colour))
  (the square (1- (integer-length (piece-bits bbp colour +king+)))))

(defun attackers-of (bbp square by occupancy)
  "The pieces of colour BY that attack SQUARE in BBP when OCCUPANCY is the set of occupied
squares (the sliders look through any square missing from it). Pins are ignored: an attack is
an attack."
  (declare (type bitboard-position bbp) (type square square) (type colour by)
           (type bitboard occupancy))
  (let* ((pieces (bbp-pieces bbp))
         (base (* by 6))
         (queens (aref pieces (+ base 4))))
    (declare (type bitboard queens))
    (logior (logand (pawn-attacks (opposite-colour by) square) (aref pieces base))
            (logand (knight-attacks square) (aref pieces (+ base 1)))
            (logand (king-attacks square) (aref pieces (+ base 5)))
            (logand (bishop-attacks square occupancy) (logior (aref pieces (+ base 2)) queens))
            (logand (rook-attacks square occupancy) (logior (aref pieces (+ base 3)) queens)))))

(defun attacked-by-p (bbp square by occupancy)
  "True when a piece of colour BY attacks SQUARE in BBP, with OCCUPANCY as in ATTACKERS-OF."
  (declare (type bitboard-position bbp) (type square square) (type colour by)
           (type bitboard occupancy))
  (/= 0 (attackers-of bbp square by occupancy)))

(defun bitboard-square-attacked-p (bbp square by)
  "True when a piece of colour BY attacks SQUARE in BBP."
  (declare (type bitboard-position bbp) (type square square) (type colour by))
  (attacked-by-p bbp square by (bbp-occupancy bbp)))

(defun bitboard-checkers (bbp)
  "The pieces that give check to the king of the side to move of BBP, as a bitboard."
  (declare (type bitboard-position bbp))
  (let ((side (bbp-side bbp)))
    (attackers-of bbp (king-square-of bbp side) (opposite-colour side) (bbp-occupancy bbp))))

(defun bitboard-in-check-p (bbp)
  "True when the side to move of BBP is in check."
  (declare (type bitboard-position bbp))
  (let ((side (bbp-side bbp)))
    (attacked-by-p bbp (king-square-of bbp side) (opposite-colour side) (bbp-occupancy bbp))))
