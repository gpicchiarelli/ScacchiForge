;;;; position.lisp -- the reference position.
;;;;
;;;; The board is one flat vector of 64 bytes (a piece code per square, 0 = empty): no cons
;;;; cell per piece. The undo stack is a set of preallocated parallel vectors, so make/unmake
;;;; never copies a position. The structure is named CHESS-POSITION because POSITION is a
;;;; COMMON-LISP symbol and may not be redefined.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(deftype board-vector () '(simple-array (unsigned-byte 8) (64)))

(define-condition position-error (error)
  ((reason :initarg :reason :reader position-error-reason))
  (:report (lambda (condition stream)
             (format stream "Invalid position: ~A" (position-error-reason condition))))
  (:documentation "Signalled when a position cannot be built or is structurally unusable."))

(defconstant +initial-undo-capacity+ 64)

(defconstant +max-clock+ 9999999
  "The largest halfmove clock and fullmove number. PARSE-FEN accepts no larger value (seven
digits) and MAKE-MOVE counts no further, so the FEN of every position reached by play is one
that PARSE-FEN accepts. No rule depends on a clock this large.")

(defstruct (chess-position (:conc-name pos-) (:constructor %make-chess-position)
                           (:copier nil))
  "A chess position with its undo stack. Build one with PARSE-FEN or START-POSITION."
  (board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)
   :type board-vector)
  (side +white+ :type colour)
  (castling 0 :type (integer 0 15))
  (en-passant +no-square+ :type (integer 0 64))
  (halfmove 0 :type fixnum)
  (fullmove 1 :type fixnum)
  (key 0 :type (unsigned-byte 64))
  (kings (make-array 2 :element-type '(unsigned-byte 8) :initial-element 0)
   :type (simple-array (unsigned-byte 8) (2)))
  ;; Undo stack: slot PLY is the number of moves made and not yet unmade.
  (ply 0 :type fixnum)
  (undo-moves (make-array +initial-undo-capacity+ :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-captured (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                     :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-castling (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                     :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-en-passant (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                       :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-halfmove (make-array +initial-undo-capacity+ :element-type 'fixnum
                                                     :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-fullmove (make-array +initial-undo-capacity+ :element-type 'fixnum
                                                     :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-keys (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 64)
                                                 :initial-element 0)
   :type (simple-array (unsigned-byte 64) (*))))

(declaim (inline piece-at king-square))

(defun piece-at (pos square)
  "Piece code on SQUARE of POS (0 when empty)."
  (declare (type chess-position pos) (type square square))
  (aref (pos-board pos) square))

(defun king-square (pos colour)
  "Square of the king of COLOUR."
  (declare (type chess-position pos) (type colour colour))
  (aref (pos-kings pos) colour))

(defun grow-undo-stack (pos)
  "Double the capacity of the undo stack of POS, keeping its contents."
  (declare (type chess-position pos))
  (flet ((grown (old)
           (let ((new (make-array (* 2 (length old)) :element-type (array-element-type old)
                                                      :initial-element 0)))
             (replace new old)
             new)))
    (setf (pos-undo-moves pos) (grown (pos-undo-moves pos))
          (pos-undo-captured pos) (grown (pos-undo-captured pos))
          (pos-undo-castling pos) (grown (pos-undo-castling pos))
          (pos-undo-en-passant pos) (grown (pos-undo-en-passant pos))
          (pos-undo-halfmove pos) (grown (pos-undo-halfmove pos))
          (pos-undo-fullmove pos) (grown (pos-undo-fullmove pos))
          (pos-undo-keys pos) (grown (pos-undo-keys pos))))
  pos)

(defun clone-position (pos)
  "A copy of the state of POS with an EMPTY undo stack (it cannot unmake earlier moves)."
  (declare (type chess-position pos))
  (let ((copy (%make-chess-position)))
    (replace (pos-board copy) (pos-board pos))
    (replace (pos-kings copy) (pos-kings pos))
    (setf (pos-side copy) (pos-side pos)
          (pos-castling copy) (pos-castling pos)
          (pos-en-passant copy) (pos-en-passant pos)
          (pos-halfmove copy) (pos-halfmove pos)
          (pos-fullmove copy) (pos-fullmove pos)
          (pos-key copy) (pos-key pos))
    copy))

(defun positions-equal-p (a b)
  "True when A and B hold the same board, side, castling, en passant, clocks and key.
The undo stacks are not compared."
  (declare (type chess-position a b))
  (and (equalp (pos-board a) (pos-board b))
       (= (pos-side a) (pos-side b))
       (= (pos-castling a) (pos-castling b))
       (= (pos-en-passant a) (pos-en-passant b))
       (= (pos-halfmove a) (pos-halfmove b))
       (= (pos-fullmove a) (pos-fullmove b))
       (= (pos-key a) (pos-key b))
       (equalp (pos-kings a) (pos-kings b))))
