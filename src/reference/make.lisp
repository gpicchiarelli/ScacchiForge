;;;; make.lisp -- make and unmake, with an undo stack instead of position copies.
;;;;
;;;; MAKE-MOVE trusts that MOVE is (pseudo-)legal for the position. It updates the board,
;;;; castling rights, en-passant square, clocks, king squares and the Zobrist key
;;;; incrementally, after saving what UNMAKE-MOVE needs. UNMAKE-MOVE restores the exact
;;;; previous state, key included, from that saved record. Both clocks stop at +MAX-CLOCK+.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun make-move (pos move)
  "Play MOVE on POS and push the information needed to take it back.

Classification: [EXACT] (the incremental updates)
Basis: the Zobrist key changes by XOR with the keys of exactly the pieces, rights, side and
en-passant file that the move changes, and XOR is its own inverse, so the updated key equals
COMPUTE-KEY of the new position. The king squares come from the move, not from a scan of
the board, and equal what the scan would find. The castling rights lose, through the
precomputed **CASTLE-MASK**, exactly the rights tied to the squares the move leaves or
reaches.
Evidence: tests incremental-key-equals-recomputed-key-along-playouts
(tests/test-zobrist.lisp), king-squares-follow-the-kings and
invariants-hold-along-seeded-random-playouts (tests/test-make-unmake.lisp),
king-or-rook-move-clears-the-castling-rights and
rook-captured-on-its-home-square-removes-the-right (tests/test-movegen.lisp), and perft."
  (declare (type chess-position pos) (type move move))
  (when (>= (pos-ply pos) (length (pos-undo-moves pos)))
    (grow-undo-stack pos))
  (let* ((board (pos-board pos))
         (from (move-from move))
         (to (move-to move))
         (promotion (move-promotion move))
         (flags (move-flags move))
         (side (pos-side pos))
         (piece (aref board from))
         (ply (pos-ply pos))
         (captured +empty+)
         (key (pos-key pos)))
    (declare (type (unsigned-byte 64) key) (type piece piece captured))
    (when (= piece +empty+)
      (error 'position-error :reason (format nil "no piece on ~A" (square-name from))))
    ;; Take out the parts of the key that this move changes (the new parts go in below).
    (setf key (logxor key (en-passant-key-component pos)
                      (zobrist-castling-key (pos-castling pos))))
    ;; Capture.
    (cond ((logtest flags +flag-en-passant+)
           (let ((victim-square (if (= side +white+) (- to 8) (+ to 8))))
             (setf captured (aref board victim-square)
                   (aref board victim-square) +empty+
                   key (logxor key (zobrist-piece-key captured victim-square)))))
          ((/= (aref board to) +empty+)
           (setf captured (aref board to)
                 key (logxor key (zobrist-piece-key captured to)))))
    ;; Save the undo record.
    (setf (aref (pos-undo-moves pos) ply) move
          (aref (pos-undo-captured pos) ply) captured
          (aref (pos-undo-castling pos) ply) (pos-castling pos)
          (aref (pos-undo-en-passant pos) ply) (pos-en-passant pos)
          (aref (pos-undo-halfmove pos) ply) (pos-halfmove pos)
          (aref (pos-undo-fullmove pos) ply) (pos-fullmove pos)
          (aref (pos-undo-keys pos) ply) (pos-key pos)
          (pos-ply pos) (1+ ply))
    ;; Move the piece, promoting if asked.
    (let ((placed (if (zerop promotion) piece (make-piece side promotion))))
      (setf (aref board from) +empty+
            (aref board to) placed
            key (logxor key (zobrist-piece-key piece from) (zobrist-piece-key placed to))))
    (when (= (piece-type piece) +king+)
      (setf (aref (pos-kings pos) side) to))
    ;; Castling also moves the rook.
    (when (logtest flags (logior +flag-castle-king+ +flag-castle-queen+))
      (let* ((rook-from (if (logtest flags +flag-castle-king+) (+ to 1) (- to 2)))
             (rook-to (if (logtest flags +flag-castle-king+) (- to 1) (+ to 1)))
             (rook (aref board rook-from)))
        (setf (aref board rook-from) +empty+
              (aref board rook-to) rook
              key (logxor key (zobrist-piece-key rook rook-from)
                          (zobrist-piece-key rook rook-to)))))
    ;; Rights, en-passant square, clocks, side.
    (let ((castling (logand (pos-castling pos)
                            (aref **castle-mask** from)
                            (aref **castle-mask** to))))
      (setf (pos-castling pos) castling
            key (logxor key (zobrist-castling-key castling))))
    (setf (pos-en-passant pos) (if (logtest flags +flag-double-push+)
                                   (ash (+ from to) -1)
                                   +no-square+)
          (pos-halfmove pos) (if (or (= (piece-type piece) +pawn+) (/= captured +empty+))
                                 0
                                 (min (1+ (pos-halfmove pos)) +max-clock+))
          (pos-side pos) (opposite-colour side))
    (when (= side +black+)
      (setf (pos-fullmove pos) (min (1+ (pos-fullmove pos)) +max-clock+)))
    (setf key (logxor key (zobrist-side-key)))
    ;; The en-passant part depends on the NEW side to move and square.
    (setf (pos-key pos) (logxor key (en-passant-key-component pos)))
    pos))

(defun unmake-move (pos)
  "Take back the last move made on POS, restoring every field exactly, key included.

Classification: [EXACT] (the undo record)
Basis: the key, the rights, the en-passant square and the clocks are read back from the
record MAKE-MOVE saved before changing them, instead of being recomputed; the board is put
back square by square. The restored state is the saved state.
Evidence: tests every-legal-move-is-undone-exactly, two-levels-deep-are-undone-exactly and
special-moves-are-undone (tests/test-make-unmake.lisp)."
  (declare (type chess-position pos))
  (when (zerop (pos-ply pos))
    (error 'position-error :reason "no move to unmake"))
  (let* ((ply (1- (pos-ply pos)))
         (board (pos-board pos))
         (move (aref (pos-undo-moves pos) ply))
         (captured (aref (pos-undo-captured pos) ply))
         (from (move-from move))
         (to (move-to move))
         (flags (move-flags move))
         (side (opposite-colour (pos-side pos)))
         (placed (aref board to))
         (piece (if (move-promotion-p move) (make-piece side +pawn+) placed)))
    (setf (pos-ply pos) ply
          (aref board from) piece
          (aref board to) +empty+)
    (if (logtest flags +flag-en-passant+)
        (setf (aref board (if (= side +white+) (- to 8) (+ to 8))) captured)
        (setf (aref board to) captured))
    (when (= (piece-type piece) +king+)
      (setf (aref (pos-kings pos) side) from))
    (when (logtest flags (logior +flag-castle-king+ +flag-castle-queen+))
      (let* ((rook-from (if (logtest flags +flag-castle-king+) (+ to 1) (- to 2)))
             (rook-to (if (logtest flags +flag-castle-king+) (- to 1) (+ to 1))))
        (setf (aref board rook-from) (aref board rook-to)
              (aref board rook-to) +empty+)))
    (setf (pos-castling pos) (aref (pos-undo-castling pos) ply)
          (pos-en-passant pos) (aref (pos-undo-en-passant pos) ply)
          (pos-halfmove pos) (aref (pos-undo-halfmove pos) ply)
          (pos-fullmove pos) (aref (pos-undo-fullmove pos) ply)
          (pos-key pos) (aref (pos-undo-keys pos) ply)
          (pos-side pos) side)
    pos))
