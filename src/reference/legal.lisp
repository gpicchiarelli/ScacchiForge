;;;; legal.lisp -- legality filtering on top of pseudo-legal generation.
;;;;
;;;; A pseudo-legal move is legal when, after it is made, the mover's own king is not
;;;; attacked. The filter literally makes the move, asks the question and takes the move
;;;; back, so pins, discovered checks, double checks, king moves into attack and the
;;;; horizontal pin of an en-passant capture (which removes two pawns from one rank) need no
;;;; special cases.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun generate-legal (pos buffer start)
  "Store the legal moves of POS in BUFFER from index START; return the end index."
  (declare (type chess-position pos) (type move-buffer buffer) (type fixnum start))
  (let ((end (generate-pseudo-legal pos buffer start))
        (kept start)
        (side (pos-side pos)))
    (declare (type fixnum end kept))
    (loop for index from start below end
          do (let ((move (aref buffer index)))
               (make-move pos move)
               (unless (king-attacked-p pos side)
                 (setf (aref buffer kept) move)
                 (incf kept))
               (unmake-move pos)))
    kept))

(defun buffer-moves (buffer start end)
  "The moves stored in BUFFER from START below END, as a fresh list."
  (declare (type move-buffer buffer) (type fixnum start end))
  (loop for index from start below end collect (aref buffer index)))

(defun pseudo-legal-moves (pos)
  "The pseudo-legal moves of POS as a fresh list, in generation order."
  (let ((buffer (make-move-buffer)))
    (buffer-moves buffer 0 (generate-pseudo-legal pos buffer 0))))

(defun legal-moves (pos)
  "The legal moves of POS as a fresh list, in generation order."
  (let ((buffer (make-move-buffer)))
    (buffer-moves buffer 0 (generate-legal pos buffer 0))))

(defun legal-move-count (pos)
  "The number of legal moves of POS."
  (generate-legal pos (make-move-buffer) 0))

(defun parse-move (pos text)
  "The legal move of POS written TEXT in long algebraic form (\"e2e4\", \"e7e8q\"), or NIL."
  (find text (legal-moves pos) :key #'move-to-string :test #'string=))

(defun move-legal-p (pos move)
  "True when MOVE is one of the legal moves of POS."
  (and (member move (legal-moves pos)) t))
