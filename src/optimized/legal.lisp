;;;; legal.lisp -- legality filtering on top of pseudo-legal generation, with check and pin
;;;; masks instead of making each move.
;;;;
;;;; The filter is computed once per position: the pieces giving check, the pieces of the side
;;;; to move pinned to their king, and the squares a non-king move may reach to answer a check.
;;;; Then each pseudo-legal move is kept or dropped by a few bit tests. Two kinds of move are
;;;; tested in full instead: a king move (is the destination attacked once the king has left
;;;; its square?) and an en-passant capture, which empties two squares of one rank and can
;;;; uncover an attack no pin mask describes.

(in-package #:scacchiforge.optimized)

(declaim-optimized-policy)

(defconstant +all-squares+ #xFFFFFFFFFFFFFFFF "Every square.")

(declaim (inline pinned-pieces en-passant-legal-p filter-legal))

(defun pinned-pieces (bbp side king occupancy)
  "The pieces of SIDE pinned to their king on KING: each is the only piece between the king
and an enemy rook, bishop or queen that moves along their common line."
  (declare (type bitboard-position bbp) (type colour side) (type square king)
           (type bitboard occupancy))
  (let* ((other (opposite-colour side))
         (own (aref (bbp-colour-occupancy bbp) side))
         (queens (piece-bits bbp other +queen+))
         (snipers (logior (logand (aref **rook-rays** king)
                                  (logior (piece-bits bbp other +rook+) queens))
                          (logand (aref **bishop-rays** king)
                                  (logior (piece-bits bbp other +bishop+) queens))))
         (pinned 0))
    (declare (type bitboard own queens snipers pinned))
    (do-squares (sniper snipers)
      (let ((blockers (logand (between-squares king sniper) occupancy)))
        (declare (type bitboard blockers))
        (when (and (/= blockers 0)
                   (zerop (logand blockers (ldb (byte 64 0) (1- blockers))))
                   (logtest blockers own))
          (setf pinned (logior pinned blockers)))))
    pinned))

(defun en-passant-legal-p (bbp side king from to occupancy)
  "True when the en-passant capture FROM -> TO of SIDE leaves the king on KING unattacked:
the attackers are looked for on the board as it will be, with the capturing pawn moved and the
captured pawn gone (the captured pawn, still in the bitboards, is masked out)."
  (declare (type bitboard-position bbp) (type colour side) (type square king from to)
           (type bitboard occupancy))
  (let* ((victim (if (= side +white+) (- to 8) (+ to 8)))
         (victim-bit (ash 1 victim))
         (after (logior (logandc2 occupancy (logior (ash 1 from) victim-bit)) (ash 1 to))))
    (declare (type square victim) (type bitboard victim-bit after))
    (zerop (logandc2 (attackers-of bbp king (opposite-colour side) after) victim-bit))))

(defun filter-legal (bbp buffer start end)
  "Keep, in place from START, the moves of BUFFER from START below END that are legal in BBP;
return the index after the last one kept. The moves must be pseudo-legal in BBP.

Classification: [EXACT] (legality from check and pin masks)
Basis: a pseudo-legal move is legal when the mover's king is not attacked after it. For a
move that is neither a king move nor en passant, the king stays where it is, and the attackers
after the move are those before it, minus a checker captured on the destination or cut off by
a piece put between it and the king, plus a slider uncovered behind the moved piece. A slider
is uncovered only when the moved piece was pinned and leaves the line of the pin. So the move
is legal exactly when (a) there is no check, or one check whose checker is captured or blocked
by the destination (two checks cannot both be answered by one such move), and (b) the piece is
not pinned or stays on the line through its king and its square. A king move is legal when its
destination is not attacked with the king removed from the occupancy, so that a slider giving
check also attacks the squares behind the king. An en-passant capture is tested on the board
as it will be (EN-PASSANT-LEGAL-P). Castling is generated only when legal (movegen.lisp).
Evidence: the move-set differential tests (tests/test-differential.lisp), the special-case
suite run on this layer (tests/test-movegen.lisp, suite optimized-movegen) and perft
(tests/test-optimized-perft.lisp)."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer)
           (type fixnum start end))
  (let* ((side (bbp-side bbp))
         (other (opposite-colour side))
         (king (king-square-of bbp side))
         (king-bit (ash 1 king))
         (occupancy (bbp-occupancy bbp))
         (checkers (attackers-of bbp king other occupancy))
         (pinned (pinned-pieces bbp side king occupancy))
         (evasions (cond ((zerop checkers) +all-squares+)
                         ((zerop (logand checkers (ldb (byte 64 0) (1- checkers))))
                          (logior checkers
                                  (between-squares king (1- (integer-length checkers)))))
                         (t 0)))
         (kept start))
    (declare (type bitboard king-bit occupancy checkers pinned evasions) (type fixnum kept))
    (loop for index of-type fixnum from start below end
          do (let* ((move (aref buffer index))
                    (from (move-from move))
                    (to (move-to move))
                    (flags (move-flags move)))
               (when (cond ((= from king)
                            (or (logtest flags (logior +flag-castle-king+ +flag-castle-queen+))
                                (not (attacked-by-p bbp to other
                                                    (logxor occupancy king-bit)))))
                           ((logtest flags +flag-en-passant+)
                            (en-passant-legal-p bbp side king from to occupancy))
                           (t
                            (and (logbitp to evasions)
                                 (or (not (logbitp from pinned))
                                     (logbitp to (line-through king from))))))
                 (setf (aref buffer kept) move)
                 (incf kept))))
    kept))

(defun bitboard-generate-legal (bbp buffer start)
  "Store the legal moves of the side to move of BBP in BUFFER from index START; return the
index after the last one. Two separate steps: pseudo-legal generation, then the legality
filter, in place."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer) (type fixnum start))
  (filter-legal bbp buffer start (bitboard-generate-pseudo-legal bbp buffer start)))

;;; The hot path of this file ends here. The two functions below allocate a list for callers
;;; outside it (tests, tools); they are compiled with the policy of the layer's files outside
;;; the hot path.

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-pseudo-legal-moves (bbp)
  "The pseudo-legal moves of BBP as a fresh list, in generation order."
  (declare (type bitboard-position bbp))
  (let ((buffer (make-bitboard-move-buffer)))
    (declare (type bitboard-move-buffer buffer))
    (loop for index of-type fixnum from 0 below (bitboard-generate-pseudo-legal bbp buffer 0)
          collect (aref buffer index))))

(defun bitboard-legal-moves (bbp)
  "The legal moves of BBP as a fresh list, in generation order."
  (declare (type bitboard-position bbp))
  (let ((buffer (make-bitboard-move-buffer)))
    (declare (type bitboard-move-buffer buffer))
    (loop for index of-type fixnum from 0 below (bitboard-generate-legal bbp buffer 0)
          collect (aref buffer index))))
