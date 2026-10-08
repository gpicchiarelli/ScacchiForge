;;;; make.lisp -- make and unmake in place, with a preallocated undo stack and an incremental
;;;; Zobrist key.
;;;;
;;;; BITBOARD-MAKE-MOVE trusts that MOVE is pseudo-legal in the position (it is what the
;;;; generator of movegen.lisp produced). It saves what BITBOARD-UNMAKE-MOVE needs in the undo
;;;; stack, then updates the bitboards, the board of piece codes, the castling rights, the
;;;; en-passant square, the clocks, the key and the incremental state of the classical
;;;; evaluation (PSQ-MG, PSQ-EG and PHASE-RAW: docs/valutazione.md, "Stato incrementale").
;;;; Nothing is allocated and the position is never copied; the stack grows (allocating) only
;;;; when a game outgrows its capacity.
;;;;
;;;; The evaluation state changes by the table entry of every piece that leaves a square or
;;;; arrives on one (evaluation-tables.lisp): the moving piece, the captured piece (on its own
;;;; square for en passant), the promoting pawn and the piece it becomes, the castling rook. Unmake
;;;; reads the three values back from the undo stack. In the build with SCF_EVAL_STATE=recompute
;;;; (policy.lisp) make and unmake leave the three values alone, and BITBOARD-EVALUATE computes
;;;; them at every call: variant B of research/exp-0002-stato-incrementale-della-valutazione.md.
;;;;
;;;; The en-passant part of the key follows the policy written once in src/core/zobrist.lisp:
;;;; the file key is in the key only when a pawn of the side to move attacks the en-passant
;;;; square. This file implements the test with the pawn attack table; bitboard-position.lisp
;;;; implements it again with file arithmetic for the from-scratch key, and the reference has
;;;; its own. The differential tests compare all three.

(in-package #:scacchiforge.optimized)

(declaim-optimized-policy)

(defun evaluation-state-implementation ()
  "The evaluation state the hot path was compiled with: :INCREMENTAL, kept by make and unmake,
or :RECOMPUTE, left out of them (SCF_EVAL_STATE, policy.lisp)."
  (compiled-evaluation-state))

(declaim (inline xor-piece en-passant-key-part))

(defun xor-piece (bbp piece mask)
  "XOR MASK into the bitboard of PIECE, the occupancy of its colour and the total occupancy
of BBP: with one bit it puts PIECE on an empty square or takes it off its square; with the
from and to bits it moves PIECE. The board of piece codes is the caller's job."
  (declare (type bitboard-position bbp) (type piece piece) (type bitboard mask))
  (let ((pieces (bbp-pieces bbp))
        (colours (bbp-colour-occupancy bbp))
        (index (piece-index piece))
        (colour (piece-colour piece)))
    (setf (aref pieces index) (logxor (aref pieces index) mask)
          (aref colours colour) (logxor (aref colours colour) mask)
          (bbp-occupancy bbp) (logxor (bbp-occupancy bbp) mask))
    nil))

(defun en-passant-key-part (bbp)
  "The en-passant part of the key of BBP: the file key of the en-passant square when a pawn of
the side to move attacks that square, else 0. The pawns of the side to move that attack the
square stand where a pawn of the other colour on the square would attack."
  (declare (type bitboard-position bbp))
  (let ((target (bbp-en-passant bbp))
        (side (bbp-side bbp)))
    (if (and (/= target +no-square+)
             (logtest (pawn-attacks (opposite-colour side) target)
                      (aref (bbp-pieces bbp) (* side 6))))
        (zobrist-en-passant-key (square-file target))
        0)))

(declaim (inline bitboard-make-move bitboard-unmake-move))

(defun bitboard-make-move (bbp move)
  "Play MOVE on BBP in place and push what BITBOARD-UNMAKE-MOVE needs to take it back. Returns
BBP.

Classification: [EXACT] (the incremental updates)
Basis: the Zobrist key changes by XOR with the keys of exactly the pieces, rights, side and
en-passant file that the move changes, and XOR is its own inverse, so the updated key equals
the key computed from scratch (BITBOARD-COMPUTE-KEY). Each bitboard, occupancy and board entry
changes by exactly the squares the move empties or fills. The castling rights lose, through
the precomputed **CASTLE-MASK**, exactly the rights tied to the squares the move leaves or
reaches. PSQ-MG, PSQ-EG and PHASE-RAW are sums over the pieces of a term that depends only on
the piece and its square, so they change by the terms of exactly the pieces the move takes off
a square or puts on one, and equal the sums computed from scratch
(BITBOARD-COMPUTE-EVALUATION-STATE, INV-C8).
Evidence: the differential tests (tests/test-differential.lisp) compare, after every legal
move of every position they visit, the full state with the reference, the incremental key
with BITBOARD-COMPUTE-KEY and with the reference key, and the bitboards, the key and the
evaluation state with BITBOARD-CONSISTENT-P; test
differential/evaluation-in-lockstep-playouts compares the evaluation state after every make
and unmake with the from-scratch one and with the reference's material and piece-square
terms; and perft (tests/test-optimized-perft.lisp)."
  (declare (type bitboard-position bbp) (type move move))
  (let ((ply (bbp-ply bbp)))
    (declare (type fixnum ply))
    (when (>= ply (length (bbp-undo-moves bbp)))
      (grow-undo-stack bbp))
    (let* ((board (bbp-board bbp))
           (from (move-from move))
           (to (move-to move))
           (promotion (move-promotion move))
           (flags (move-flags move))
           (side (bbp-side bbp))
           (piece (aref board from))
           (captured +empty+)
           (castling (bbp-castling bbp))
           (key (bbp-key bbp))
           (psq-mg (if-incremental-evaluation (bbp-psq-mg bbp) 0))
           (psq-eg (if-incremental-evaluation (bbp-psq-eg bbp) 0))
           (phase (if-incremental-evaluation (bbp-phase-raw bbp) 0)))
      (declare (type bitboard key) (type (unsigned-byte 8) piece captured)
               (type (signed-byte 32) psq-mg psq-eg) (type (unsigned-byte 16) phase)
               (ignorable psq-mg psq-eg phase))
      (when (= piece +empty+)
        (error "bitboard-make-move: no piece on ~A" (square-name from)))
      ;; The undo record: everything make changes that unmake cannot work out from the move.
      (setf (aref (bbp-undo-moves bbp) ply) move
            (aref (bbp-undo-castling bbp) ply) castling
            (aref (bbp-undo-en-passant bbp) ply) (bbp-en-passant bbp)
            (aref (bbp-undo-halfmove bbp) ply) (bbp-halfmove bbp)
            (aref (bbp-undo-fullmove bbp) ply) (bbp-fullmove bbp)
            (aref (bbp-undo-keys bbp) ply) key)
      (when-incremental-evaluation
        (setf (aref (bbp-undo-psq-mg bbp) ply) psq-mg
              (aref (bbp-undo-psq-eg bbp) ply) psq-eg
              (aref (bbp-undo-phase-raw bbp) ply) phase))
      ;; Take out the parts of the key that this move changes (the new parts go in below).
      (setf key (logxor key (en-passant-key-part bbp) (zobrist-castling-key castling)))
      ;; Capture.
      (if (logtest flags +flag-en-passant+)
          (let ((victim (if (= side +white+) (- to 8) (+ to 8))))
            (declare (type square victim))
            (setf captured (aref board victim))
            (xor-piece bbp captured (ash 1 victim))
            (setf (aref board victim) +empty+
                  key (logxor key (zobrist-piece-key captured victim)))
            (when-incremental-evaluation
              (setf psq-mg (- psq-mg (piece-square-mg captured victim))
                    psq-eg (- psq-eg (piece-square-eg captured victim)))))
          (progn
            (setf captured (aref board to))
            (unless (= captured +empty+)
              (xor-piece bbp captured (ash 1 to))
              (setf key (logxor key (zobrist-piece-key captured to)))
              (when-incremental-evaluation
                (setf psq-mg (- psq-mg (piece-square-mg captured to))
                      psq-eg (- psq-eg (piece-square-eg captured to))
                      phase (- phase (piece-phase-weight captured)))))))
      (setf (aref (bbp-undo-captured bbp) ply) captured)
      ;; Move the piece, promoting if asked.
      (if (zerop promotion)
          (xor-piece bbp piece (logior (ash 1 from) (ash 1 to)))
          (let ((promoted (make-piece side promotion)))
            (xor-piece bbp piece (ash 1 from))
            (xor-piece bbp promoted (ash 1 to))))
      (let ((placed (if (zerop promotion) piece (make-piece side promotion))))
        (setf (aref board from) +empty+
              (aref board to) placed
              key (logxor key (zobrist-piece-key piece from) (zobrist-piece-key placed to)))
        (when-incremental-evaluation
          (setf psq-mg (+ (- psq-mg (piece-square-mg piece from)) (piece-square-mg placed to))
                psq-eg (+ (- psq-eg (piece-square-eg piece from)) (piece-square-eg placed to))
                phase (+ (- phase (piece-phase-weight piece)) (piece-phase-weight placed)))))
      ;; Castling also moves the rook.
      (when (logtest flags (logior +flag-castle-king+ +flag-castle-queen+))
        (let* ((king-side (logtest flags +flag-castle-king+))
               (rook-from (if king-side (+ to 1) (- to 2)))
               (rook-to (if king-side (- to 1) (+ to 1)))
               (rook (aref board rook-from)))
          (declare (type square rook-from rook-to))
          (xor-piece bbp rook (logior (ash 1 rook-from) (ash 1 rook-to)))
          (setf (aref board rook-from) +empty+
                (aref board rook-to) rook
                key (logxor key (zobrist-piece-key rook rook-from)
                            (zobrist-piece-key rook rook-to)))
          (when-incremental-evaluation
            (setf psq-mg (+ (- psq-mg (piece-square-mg rook rook-from))
                            (piece-square-mg rook rook-to))
                  psq-eg (+ (- psq-eg (piece-square-eg rook rook-from))
                            (piece-square-eg rook rook-to))))))
      ;; Rights, en-passant square, clocks, side.
      (let ((rights (logand castling (aref **castle-mask** from) (aref **castle-mask** to))))
        (setf (bbp-castling bbp) rights
              key (logxor key (zobrist-castling-key rights))))
      (setf (bbp-en-passant bbp) (if (logtest flags +flag-double-push+)
                                     (ash (+ from to) -1)
                                     +no-square+)
            (bbp-halfmove bbp) (if (or (= (piece-type piece) +pawn+) (/= captured +empty+))
                                   0
                                   (min (1+ (bbp-halfmove bbp)) +clock-limit+))
            (bbp-side bbp) (opposite-colour side))
      (when (= side +black+)
        (setf (bbp-fullmove bbp) (min (1+ (bbp-fullmove bbp)) +clock-limit+)))
      (setf (bbp-ply bbp) (1+ ply))
      (when-incremental-evaluation
        (setf (bbp-psq-mg bbp) psq-mg
              (bbp-psq-eg bbp) psq-eg
              (bbp-phase-raw bbp) phase))
      ;; The en-passant part depends on the NEW side to move, square and pawns.
      (setf (bbp-key bbp) (logxor key (zobrist-side-key) (en-passant-key-part bbp)))
      bbp)))

(defun bitboard-unmake-move (bbp)
  "Take back the last move made on BBP, restoring every field exactly, key included. Returns
BBP.

Classification: [EXACT] (the undo record)
Basis: the key, the rights, the en-passant square, the clocks and the evaluation state are
read back from the record that make saved before changing them, instead of being recomputed;
the bitboards and the board are put back by the same XORs that make applied, which are their
own inverse.
Evidence: the differential tests (tests/test-differential.lisp) require the state after
make and unmake to equal the state before, field by field, for every legal move of every
position they visit, and after whole playouts."
  (declare (type bitboard-position bbp))
  (let ((ply (1- (bbp-ply bbp))))
    (declare (type fixnum ply))
    (when (< ply 0)
      (error "bitboard-unmake-move: no move to unmake"))
    (let* ((board (bbp-board bbp))
           (move (aref (bbp-undo-moves bbp) ply))
           (captured (aref (bbp-undo-captured bbp) ply))
           (from (move-from move))
           (to (move-to move))
           (flags (move-flags move))
           (side (opposite-colour (bbp-side bbp)))
           (placed (aref board to))
           (piece (if (move-promotion-p move) (make-piece side +pawn+) placed)))
      (declare (type move move) (type (unsigned-byte 8) captured placed piece))
      (if (= piece placed)
          (xor-piece bbp piece (logior (ash 1 from) (ash 1 to)))
          (progn
            (xor-piece bbp placed (ash 1 to))
            (xor-piece bbp piece (ash 1 from))))
      (setf (aref board to) +empty+
            (aref board from) piece)
      (unless (= captured +empty+)
        (let ((square (if (logtest flags +flag-en-passant+)
                          (if (= side +white+) (- to 8) (+ to 8))
                          to)))
          (declare (type square square))
          (xor-piece bbp captured (ash 1 square))
          (setf (aref board square) captured)))
      (when (logtest flags (logior +flag-castle-king+ +flag-castle-queen+))
        (let* ((king-side (logtest flags +flag-castle-king+))
               (rook-from (if king-side (+ to 1) (- to 2)))
               (rook-to (if king-side (- to 1) (+ to 1)))
               (rook (aref board rook-to)))
          (declare (type square rook-from rook-to))
          (xor-piece bbp rook (logior (ash 1 rook-from) (ash 1 rook-to)))
          (setf (aref board rook-to) +empty+
                (aref board rook-from) rook)))
      (setf (bbp-castling bbp) (aref (bbp-undo-castling bbp) ply)
            (bbp-en-passant bbp) (aref (bbp-undo-en-passant bbp) ply)
            (bbp-halfmove bbp) (aref (bbp-undo-halfmove bbp) ply)
            (bbp-fullmove bbp) (aref (bbp-undo-fullmove bbp) ply)
            (bbp-key bbp) (aref (bbp-undo-keys bbp) ply)
            (bbp-side bbp) side
            (bbp-ply bbp) ply)
      (when-incremental-evaluation
        (setf (bbp-psq-mg bbp) (aref (bbp-undo-psq-mg bbp) ply)
              (bbp-psq-eg bbp) (aref (bbp-undo-psq-eg bbp) ply)
              (bbp-phase-raw bbp) (aref (bbp-undo-phase-raw bbp) ply)))
      bbp)))

;;; The two functions above are proclaimed inline only while they are defined, so that SBCL
;;; keeps their inline expansions; every caller calls them, except PERFT-NODE (perft.lisp),
;;; which asks for the expansions with a local INLINE declaration.
(declaim (notinline bitboard-make-move bitboard-unmake-move))
