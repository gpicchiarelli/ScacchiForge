;;;; key.lisp -- the from-scratch Zobrist key, and construction of a position from parts.
;;;;
;;;; COMPUTE-KEY is the definition of the key. MAKE-MOVE updates the key incrementally and
;;;; the tests require both to agree on every position they reach.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(declaim (inline en-passant-key-component))

(defun en-passant-key-component (pos)
  "The en-passant part of the key of POS: the file key when a capture is available, else 0."
  (declare (type chess-position pos))
  (if (en-passant-capture-available-p pos)
      (zobrist-en-passant-key (square-file (pos-en-passant pos)))
      0))

(defun compute-key (pos)
  "The Zobrist key of POS computed from scratch, ignoring the stored key."
  (declare (type chess-position pos))
  (let ((key 0)
        (board (pos-board pos)))
    (declare (type (unsigned-byte 64) key))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (unless (= piece +empty+)
          (setf key (logxor key (zobrist-piece-key piece square))))))
    (when (= (pos-side pos) +black+)
      (setf key (logxor key (zobrist-side-key))))
    (setf key (logxor key (zobrist-castling-key (pos-castling pos))))
    (logxor key (en-passant-key-component pos))))

(defun find-kings (board)
  "The squares of the white and the black king on BOARD, as two values.
Signals POSITION-ERROR unless each colour has exactly one king."
  (declare (type board-vector board))
  (let ((white '()) (black '()))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (cond ((= piece +white-king+) (push square white))
              ((= piece +black-king+) (push square black)))))
    (unless (and white (null (rest white)) black (null (rest black)))
      (error 'position-error :reason "each side needs exactly one king"))
    (values (first white) (first black))))

(defun make-position-from-parts (board side castling en-passant halfmove fullmove)
  "A new position from raw parts. BOARD is copied. The key is computed from scratch.
This only locates the kings; it does NOT check that the position is legal (PARSE-FEN
and CHECK-POSITION-INVARIANTS do that)."
  (declare (type (simple-array (unsigned-byte 8) (*)) board))
  (unless (= (length board) 64)
    (error 'position-error :reason "the board vector needs 64 entries"))
  (let ((pos (%make-chess-position)))
    (replace (pos-board pos) board)
    (multiple-value-bind (white-king black-king) (find-kings (pos-board pos))
      (setf (aref (pos-kings pos) +white+) white-king
            (aref (pos-kings pos) +black+) black-king))
    (setf (pos-side pos) side
          (pos-castling pos) castling
          (pos-en-passant pos) en-passant
          (pos-halfmove pos) halfmove
          (pos-fullmove pos) fullmove)
    (setf (pos-key pos) (compute-key pos))
    pos))
