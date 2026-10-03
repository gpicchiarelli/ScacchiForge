(in-package :scacchiforge.reference)

(defun make-move-on-position (pos move)
  "Apply move to position, updating all state.
   [EXACT] Position state is maintained correctly.
   Uses destructive update; preserve prior state with copy if needed."
  (let ((from (move-from move))
        (to (move-to move))
        (piece (move-piece move))
        (promoted (move-promoted move))
        (flags (move-flags move)))
    ;; Move piece
    (let ((piece-info (position-piece pos from)))
      (setf (position-piece pos to) piece-info)
      (setf (position-piece pos from) nil))
    ;; Handle captures
    (when (logtest flags +move-flag-capture+)
      (if (logtest flags +move-flag-en-passant+)
          ;; En passant capture
          (let ((captured-sq (- to (if (eq (position-side-to-move pos) +white+) 8 -8))))
            (setf (position-piece pos captured-sq) nil))
          ;; Regular capture (handled above)
          nil))
    ;; Handle promotion
    (when promoted
      (setf (position-piece pos to) (cons (position-color pos to) promoted)))
    ;; Handle castling
    (when (logtest flags +move-flag-castling+)
      (case (- to from)
        (2 ;; Queenside castling
         (let ((rook-from (if (eq (position-side-to-move pos) +white+) 0 56))
               (rook-to (if (eq (position-side-to-move pos) +white+) 3 59)))
           (let ((rook-info (position-piece pos rook-from)))
             (setf (position-piece pos rook-to) rook-info)
             (setf (position-piece pos rook-from) nil))))
        (-2 ;; Kingside castling
         (let ((rook-from (if (eq (position-side-to-move pos) +white+) 7 63))
               (rook-to (if (eq (position-side-to-move pos) +white+) 5 61)))
           (let ((rook-info (position-piece pos rook-from)))
             (setf (position-piece pos rook-to) rook-info)
             (setf (position-piece pos rook-from) nil))))))
    ;; Update castling rights
    (when (eq piece +king+)
      (if (eq (position-side-to-move pos) +white+)
          (setf (aref (position-castling-rights pos) 0) nil
                (aref (position-castling-rights pos) 1) nil)
          (setf (aref (position-castling-rights pos) 2) nil
                (aref (position-castling-rights pos) 3) nil)))
    (when (eq piece +rook+)
      (case from
        (0 (setf (aref (position-castling-rights pos) 1) nil))
        (7 (setf (aref (position-castling-rights pos) 0) nil))
        (56 (setf (aref (position-castling-rights pos) 3) nil))
        (63 (setf (aref (position-castling-rights pos) 2) nil))))
    ;; Update en passant
    (setf (position-en-passant pos)
          (if (logtest flags +move-flag-double-push+)
              (let ((direction (if (eq (position-side-to-move pos) +white+) 1 -1)))
                (+ from (* direction 8)))
              nil))
    ;; Update halfmove clock
    (if (or (eq piece +pawn+) (logtest flags +move-flag-capture+))
        (setf (position-halfmove-clock pos) 0)
        (incf (position-halfmove-clock pos)))
    ;; Update fullmove
    (when (eq (position-side-to-move pos) +black+)
      (incf (position-fullmove pos)))
    ;; Switch side to move
    (setf (position-side-to-move pos)
          (opposite-color (position-side-to-move pos)))
    ;; Update Zobrist (simplified for reference; full implementation later)
    (update-zobrist-hash pos)
    pos))

(defun unmake-move-on-position (pos move prior-state)
  "Undo move on position, restoring prior state.
   [EXACT] Position is restored to prior state.
   Requires prior-state saved before move."
  ;; Copy all state back
  (setf (position-board pos) (copy-seq (position-board prior-state)))
  (setf (position-side-to-move pos) (position-side-to-move prior-state))
  (setf (position-castling-rights pos) (copy-seq (position-castling-rights prior-state)))
  (setf (position-en-passant pos) (position-en-passant prior-state))
  (setf (position-halfmove-clock pos) (position-halfmove-clock prior-state))
  (setf (position-fullmove pos) (position-fullmove prior-state))
  (setf (position-zobrist pos) (position-zobrist prior-state))
  pos)

(defun update-zobrist-hash (pos)
  "Update Zobrist hash incrementally.
   [HEURISTIC] For reference implementation, recompute.
   [TODO] Implement incremental update."
  (compute-zobrist-hash pos))

(defun compute-zobrist-hash (pos)
  "Compute Zobrist hash from scratch.
   [EXACT] Zobrist hash computation."
  (let ((hash 0))
    ;; Hash pieces
    (loop for sq from 0 to 63
          when (position-occupied-p pos sq)
          do (let ((piece-info (position-piece pos sq)))
               (setf hash (logxor hash (piece-zobrist-index sq piece-info)))))
    ;; Hash side to move
    (when (eq (position-side-to-move pos) +black+)
      (setf hash (logxor hash (zobrist-black-hash))))
    ;; Hash castling rights
    (loop for i from 0 to 3
          when (aref (position-castling-rights pos) i)
          do (setf hash (logxor hash (castling-zobrist-index i))))
    ;; Hash en passant
    (when (position-en-passant pos)
      (setf hash (logxor hash (en-passant-zobrist-index (position-en-passant pos)))))
    (setf (position-zobrist pos) hash)
    hash))

(defun piece-zobrist-index (sq piece-info)
  "Zobrist hash component for piece at square.
   [EXACT] Deterministic mapping."
  (let* ((color (car piece-info))
         (piece (cdr piece-info))
         (color-offset (if (eq color +white+) 0 6))
         (piece-offset (case piece
                         (:pawn 0)
                         (:knight 1)
                         (:bishop 2)
                         (:rook 3)
                         (:queen 4)
                         (:king 5))))
    (sxhash (list sq color-offset piece-offset))))

(defun zobrist-black-hash ()
  "Zobrist hash component for black to move."
  (sxhash :black))

(defun castling-zobrist-index (index)
  "Zobrist hash component for castling rights."
  (sxhash (list :castling index)))

(defun en-passant-zobrist-index (sq)
  "Zobrist hash component for en passant."
  (sxhash (list :en-passant sq)))
