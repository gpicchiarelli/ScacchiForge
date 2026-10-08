;;;; invariants.lisp -- what must be true of every position the engine can produce.
;;;;
;;;; The checks are written independently of the FEN parser and of the legality filter, so
;;;; that they can catch a bug in either. In particular the legality filter decides with
;;;; SQUARE-ATTACKED-P (square-centred), and the move-level check decides again with a
;;;; different algorithm: generate the opponent's pseudo-legal captures and look for one that
;;;; lands on the king (piece-centred).

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(define-condition invariant-violation (error)
  ((fen :initarg :fen :reader invariant-violation-fen)
   (problems :initarg :problems :reader invariant-violation-problems))
  (:report (lambda (condition stream)
             (format stream "Position ~S violates ~D invariant~:P:~{~%  - ~A~}"
                     (invariant-violation-fen condition)
                     (length (invariant-violation-problems condition))
                     (invariant-violation-problems condition))))
  (:documentation "Signalled by CHECK-POSITION-INVARIANTS."))

(defun valid-piece-code-p (code)
  "True when CODE is 0 or a valid piece code."
  (or (= code 0) (<= 1 code 6) (<= 9 code 14)))

(defun board-violations (pos)
  "Violations about the board contents of POS, as a list of strings."
  (let ((board (pos-board pos))
        (problems '())
        (kings (list 0 0)))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (cond ((not (valid-piece-code-p piece))
               (push (format nil "invalid piece code ~D on ~A" piece (square-name square))
                     problems))
              ((and (member piece (list +white-pawn+ +black-pawn+))
                    (member (square-rank square) '(0 7)))
               (push (format nil "pawn on ~A" (square-name square)) problems))
              ((= piece +white-king+) (incf (first kings)))
              ((= piece +black-king+) (incf (second kings))))))
    (unless (equal kings '(1 1))
      (push (format nil "king counts (white black) are ~S" kings) problems))
    (when (equal kings '(1 1))
      (dolist (colour (list +white+ +black+))
        (unless (= (aref board (king-square pos colour)) (make-piece colour +king+))
          (push (format nil "cached king square of colour ~D is wrong" colour) problems))))
    problems))

(defun castling-violations (pos)
  "Violations about the castling rights of POS."
  (let ((board (pos-board pos))
        (rights (pos-castling pos))
        (problems '()))
    (loop for (right king-square king rook-square rook) in
          `((,+castle-white-king+ ,+e1+ ,+white-king+ ,+h1+ ,+white-rook+)
            (,+castle-white-queen+ ,+e1+ ,+white-king+ ,+a1+ ,+white-rook+)
            (,+castle-black-king+ ,+e8+ ,+black-king+ ,+h8+ ,+black-rook+)
            (,+castle-black-queen+ ,+e8+ ,+black-king+ ,+a8+ ,+black-rook+))
          do (when (and (logtest rights right)
                        (not (and (= (aref board king-square) king)
                                  (= (aref board rook-square) rook))))
               (push (format nil "castling right ~D without king and rook at home" right)
                     problems)))
    problems))

(defun en-passant-violations (pos)
  "Violations about the en-passant square of POS."
  (let ((target (pos-en-passant pos))
        (board (pos-board pos)))
    (if (= target +no-square+)
        '()
        (let* ((white-to-move (= (pos-side pos) +white+))
               (step (if white-to-move 8 -8))
               (pushed-pawn (if white-to-move +black-pawn+ +white-pawn+)))
          (unless (and (= (square-rank target) (if white-to-move 5 2))
                       (= (aref board (- target step)) pushed-pawn)
                       (= (aref board target) +empty+)
                       (= (aref board (+ target step)) +empty+))
            (list (format nil "inconsistent en-passant square ~A" (square-name target))))))))

(defun structural-violations (pos)
  "Violations that do not need move generation."
  (let ((problems (append (board-violations pos)
                          (castling-violations pos)
                          (en-passant-violations pos))))
    (when (null problems)
      ;; These need a sane board (kings present, pawns not on the end ranks).
      (when (king-attacked-p pos (opposite-colour (pos-side pos)))
        (push "the side not to move is in check" problems))
      (unless (= (pos-key pos) (compute-key pos))
        (push "stored key differs from the recomputed key" problems))
      (unless (>= (pos-halfmove pos) 0)
        (push "negative halfmove clock" problems))
      (unless (>= (pos-fullmove pos) 1)
        (push "fullmove number below 1" problems))
      (handler-case
          (unless (positions-equal-p pos (parse-fen (position-to-fen pos)))
            (push "FEN round trip changes the position" problems))
        (fen-error (condition)
          (push (format nil "own FEN is rejected: ~A" (position-error-reason condition))
                problems))))
    problems))

(defun king-attacked-by-generation-p (pos colour)
  "True when the king of COLOUR is attacked, decided by generating the opponent's
pseudo-legal moves and looking for a capture that lands on the king. This is deliberately
a different algorithm from KING-ATTACKED-P."
  (let* ((buffer (make-move-buffer))
         (king (king-square pos colour))
         (end (generate-pseudo-legal-for pos (opposite-colour colour) +no-square+ buffer 0)))
    (loop for index from 0 below end
          thereis (let ((move (aref buffer index)))
                    (and (move-capture-p move) (= (move-to move) king))))))

(defun move-violations (pos)
  "Violations found by trying every pseudo-legal move of POS. POS is restored."
  (let* ((before (clone-position pos))
         (ply (pos-ply pos))
         (side (pos-side pos))
         (pseudo (pseudo-legal-moves pos))
         (legal (legal-moves pos))
         (problems '()))
    (when (/= (length pseudo) (length (remove-duplicates pseudo)))
      (push "duplicate pseudo-legal moves" problems))
    (unless (subsetp legal pseudo)
      (push "legal moves are not a subset of the pseudo-legal moves" problems))
    (dolist (move pseudo)
      (let ((text (move-to-string move)))
        (make-move pos move)
        (let ((scan (king-attacked-p pos side))
              (generation (king-attacked-by-generation-p pos side))
              (listed (and (member move legal) t)))
          (when (not (eq (and scan t) (and generation t)))
            (push (format nil "~A: the two attack tests disagree" text) problems))
          (when (eq listed (and scan t))
            (push (format nil "~A: legal list disagrees with king safety" text) problems))
          (unless scan
            (let ((child (structural-violations pos)))
              (when child
                (push (format nil "~A: child position invalid: ~{~A~^; ~}" text child)
                      problems)))))
        (unmake-move pos)
        (unless (and (positions-equal-p pos before) (= (pos-ply pos) ply))
          (push (format nil "~A: unmake did not restore the position" text) problems))))
    problems))

(defun position-invariant-violations (pos &key (moves t))
  "A list of strings, one per violated invariant of POS (empty when all hold). With MOVES,
also try every pseudo-legal move: per move a make, two attack tests, the structural checks of
the child when it is legal and an unmake, on top of the structural checks of POS."
  (let ((problems (structural-violations pos)))
    (when (and moves (null problems))
      (setf problems (move-violations pos)))
    (reverse problems)))

(defun check-position-invariants (pos &key (moves t))
  "Return T when POS satisfies every invariant, else signal INVARIANT-VIOLATION."
  (let ((problems (position-invariant-violations pos :moves moves)))
    (when problems
      (error 'invariant-violation :fen (position-to-fen pos) :problems problems))
    t))
