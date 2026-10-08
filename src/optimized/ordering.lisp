;;;; ordering.lisp -- the move ordering of Phase 3 in the optimized layer.
;;;;
;;;; The legal moves of a node, as the generator wrote them (movegen.lisp, legal.lisp), are put in
;;;; this order before the search tries them:
;;;;  1. the move of the transposition-table entry of the position, when it is among the legal
;;;;     moves (the TT move);
;;;;  2. the move the previous iteration of iterative deepening played at this node, when the node
;;;;     lies on the previous principal variation (the PV move);
;;;;  3. the captures, en passant included, by the most valuable victim first and, among equal
;;;;     victims, the least valuable attacker first: the victims ranked by type, queen, rook,
;;;;     bishop, knight, pawn; the attackers ranked by type, pawn first and king last;
;;;;  4. the promotions that capture nothing, the queen first, then rook, bishop and knight;
;;;;  5. every other move.
;;;; Moves of the same rank keep the generator's order: the sort is a stable insertion sort on an
;;;; integer key (MOVE-ORDER-KEY), in a key array of the search context parallel to the move
;;;; buffer. There are no killer moves, no history and no static exchange evaluation: those are
;;;; Phase 4 (docs/roadmap.md).
;;;;
;;;; A move read from a table is used only if it is one of the legal moves of the node: the sort
;;;; places a move only where it already is in the buffer, so a TT move that is not legal in the
;;;; position (a false hit of the key) takes no place in the order and is never played (INV-C6).

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(defconstant +order-key-tt-move+ 4000 "Order key of the TT move: the first.")
(defconstant +order-key-pv-move+ 3000 "Order key of the PV move: after the TT move.")
(defconstant +order-key-capture+ 2000
  "Base of the order keys of the captures: 2000 + 8 x victim type - attacker type, from 2002 to
2039, above every promotion that captures nothing.")
(defconstant +order-key-promotion+ 1000
  "Base of the order keys of the promotions that capture nothing: 1000 + the promoted type.")

;;; --- the hot path ---------------------------------------------------------------------------

(declaim-optimized-policy)

(declaim (inline move-order-key))

(defun move-order-key (board move tt-move pv-move)
  "The order key of MOVE in the position whose board of piece codes is BOARD, given the TT move
and the PV move of the node (+NO-MOVE+ when there is none): higher keys are searched first."
  (declare (type (simple-array (unsigned-byte 8) (64)) board) (type move move tt-move pv-move))
  (cond ((= move tt-move) +order-key-tt-move+)
        ((= move pv-move) +order-key-pv-move+)
        ((move-capture-p move)
         (let ((victim (if (move-en-passant-p move)
                           +pawn+
                           (logand (aref board (move-to move)) 7)))
               (attacker (logand (aref board (move-from move)) 7)))
           (+ +order-key-capture+ (* 8 victim) (- attacker))))
        ((move-promotion-p move) (+ +order-key-promotion+ (move-promotion move)))
        (t 0)))

(defun order-node-moves (bbp buffer keys start end tt-move pv-move)
  "Put the moves of BUFFER from START below END, the legal moves of BBP, in the order of Phase 3
(file header), using KEYS from START below END for their order keys. TT-MOVE and PV-MOVE are
the TT move and the PV move of the node, +NO-MOVE+ when there is none. Stable: moves of equal
key keep their order. Allocates nothing; returns NIL.

Classification: [EXACT] on the value of pure alpha-beta
Basis: the order of the moves does not change the value of alpha-beta at full width without
other pruning (Knuth and Moore, 1975); it changes the nodes searched, and among moves of equal
value the best move and the principal variation. The sort only permutes the moves already in
the buffer.
Evidence: tests optimized-pvs/ordering-does-not-change-the-value and
optimized-pvs/the-tt-move-and-the-pv-move-come-first (tests/test-optimized-pvs.lisp)."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer keys)
           (type fixnum start end) (type move tt-move pv-move))
  (let ((board (bbp-board bbp)))
    (loop for index of-type fixnum from start below end
          do (let* ((move (aref buffer index))
                    (key (move-order-key board move tt-move pv-move))
                    (slot index))
               (declare (type fixnum key slot))
               (loop while (and (> slot start) (< (aref keys (1- slot)) key))
                     do (setf (aref buffer slot) (aref buffer (1- slot))
                              (aref keys slot) (aref keys (1- slot)))
                        (decf slot))
               (setf (aref buffer slot) move
                     (aref keys slot) key))))
  nil)

;;; The hot path of this file ends here.

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-ordered-moves (bbp &key (tt-move +no-move+) (pv-move +no-move+))
  "The legal moves of BBP as a fresh list, in the order of Phase 3 with TT-MOVE and PV-MOVE as
the TT move and the PV move (ORDER-NODE-MOVES, the function the search calls). For tests."
  (declare (type bitboard-position bbp))
  (let* ((buffer (make-bitboard-move-buffer))
         (keys (make-bitboard-move-buffer))
         (end (bitboard-generate-legal bbp buffer 0)))
    (order-node-moves bbp buffer keys 0 end tt-move pv-move)
    (loop for index from 0 below end
          collect (aref buffer index))))
