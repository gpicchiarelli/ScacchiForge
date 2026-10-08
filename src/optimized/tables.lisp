;;;; tables.lisp -- precomputed bitboard tables of the optimized layer.
;;;;
;;;; Every table is a typed vector of (UNSIGNED-BYTE 64) filled once at load time from the
;;;; geometry of the board. They are this layer's own data: the reference has its own lists of
;;;; target squares (src/reference/tables.lisp), and the tests compare each table with a naive
;;;; computation (tests/test-optimized.lisp).

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(deftype bitboard () '(unsigned-byte 64))

(defmacro do-squares ((square bitboard) &body body)
  "Run BODY with SQUARE bound to the index of each set bit of BITBOARD, lowest first. The hot
path's version of DO-SET-BITS: SQUARE is declared a SQUARE, which it is, since the bitboard is
not zero when its lowest bit is taken. BITBOARD is evaluated once. As in DOLIST, BODY may start
with declarations: SQUARE is bound by a LET whose body is BODY."
  (let ((rest (gensym "REST"))
        (index (gensym "INDEX")))
    `(let ((,rest ,bitboard))
       (declare (type bitboard ,rest))
       (loop until (zerop ,rest)
             do (let ((,index (1- (integer-length (logand ,rest (ldb (byte 64 0) (- ,rest)))))))
                  (declare (type square ,index))
                  (setf ,rest (logand ,rest (ldb (byte 64 0) (1- ,rest))))
                  (let ((,square ,index))
                    (declare (type square ,square))
                    ,@body))))))

;;; Ray directions as (file-delta . rank-delta). 0..3 are the rook directions, 4..7 the bishop
;;; directions. A ray is "positive" when it goes towards higher square indices (north, east,
;;; north-east, north-west): its nearest square is its lowest set bit.
(defparameter *ray-steps*
  '((0 . 1) (1 . 0) (0 . -1) (-1 . 0) (1 . 1) (-1 . 1) (1 . -1) (-1 . -1))
  "North, east, south, west, north-east, north-west, south-east, south-west.")

(defconstant +north+ 0)
(defconstant +east+ 1)
(defconstant +south+ 2)
(defconstant +west+ 3)
(defconstant +north-east+ 4)
(defconstant +north-west+ 5)
(defconstant +south-east+ 6)
(defconstant +south-west+ 7)

(defmacro define-table (name size documentation)
  "Define the global NAME as a zeroed (UNSIGNED-BYTE 64) vector of SIZE entries."
  `(progn
     (sb-ext:defglobal ,name
         (make-array ,size :element-type '(unsigned-byte 64) :initial-element 0)
       ,documentation)
     (declaim (type (simple-array (unsigned-byte 64) (,size)) ,name))))

(define-table **knight-attacks** 64 "Squares a knight attacks from each square.")
(define-table **king-attacks** 64 "Squares a king attacks from each square.")
(define-table **pawn-attacks** 128
  "Indexed by (colour * 64 + square): the squares a pawn of that colour attacks from there.")
(define-table **rays** 512
  "Indexed by (direction * 64 + square): the squares of the ray from the square, the square
itself excluded, up to the edge of the board.")
(define-table **bishop-rays** 64 "The four bishop rays of each square on an empty board.")
(define-table **rook-rays** 64 "The four rook rays of each square on an empty board.")
(define-table **between** 4096
  "Indexed by (a * 64 + b): the squares strictly between A and B when they share a rank, file
or diagonal, else 0.")
(define-table **line** 4096
  "Indexed by (a * 64 + b): every square of the rank, file or diagonal through A and B, both
included, when they share one and differ, else 0.")

(sb-ext:defglobal **castle-mask**
    (make-array 64 :element-type '(unsigned-byte 8) :initial-element 15)
  "Castling rights that survive a move whose from or to square is the index.")
(declaim (type (simple-array (unsigned-byte 8) (64)) **castle-mask**))

(defun on-board-square (square file-delta rank-delta)
  "The square FILE-DELTA files and RANK-DELTA ranks from SQUARE, or NIL off the board."
  (let ((file (+ (square-file square) file-delta))
        (rank (+ (square-rank square) rank-delta)))
    (and (<= 0 file 7) (<= 0 rank 7) (make-square file rank))))

(defun squares-bitboard (squares)
  "The bitboard with the bits of the list SQUARES (NIL entries ignored)."
  (let ((bits 0))
    (dolist (square squares bits)
      (when square
        (setf bits (logior bits (ash 1 square)))))))

(defun ray-bitboard (square direction)
  "The squares met walking from SQUARE in DIRECTION, the square excluded."
  (destructuring-bind (df . dr) (nth direction *ray-steps*)
    (squares-bitboard (loop for step from 1
                            for target = (on-board-square square (* step df) (* step dr))
                            while target
                            collect target))))

(defun initialise-tables ()
  "Fill every table of this file. Idempotent.

Classification: [EXACT] (precomputed tables)
Basis: each entry is the value of a pure function of its index (the moves of a knight, king
or pawn, the rays, the squares between two aligned squares, the castling rule), computed once
at load time and read back instead of being computed again. A lookup returns what the
computation would.
Evidence: tests leaper-tables-match-the-board-geometry, between-and-line-match-a-naive-walk
(tests/test-optimized.lisp), and perft (tests/test-optimized-perft.lisp)."
  (dotimes (square 64)
    (flet ((steps (deltas)
             (squares-bitboard (loop for (df . dr) in deltas
                                     collect (on-board-square square df dr)))))
      (setf (aref **knight-attacks** square)
            (steps '((1 . 2) (2 . 1) (2 . -1) (1 . -2) (-1 . -2) (-2 . -1) (-2 . 1) (-1 . 2)))
            (aref **king-attacks** square)
            (steps '((0 . 1) (1 . 1) (1 . 0) (1 . -1) (0 . -1) (-1 . -1) (-1 . 0) (-1 . 1)))
            (aref **pawn-attacks** (+ (* +white+ 64) square)) (steps '((-1 . 1) (1 . 1)))
            (aref **pawn-attacks** (+ (* +black+ 64) square)) (steps '((-1 . -1) (1 . -1)))))
    (dotimes (direction 8)
      (setf (aref **rays** (+ (* direction 64) square)) (ray-bitboard square direction)))
    (flet ((union-of-rays (first-direction end-direction)
             (let ((bits 0))
               (loop for direction from first-direction below end-direction
                     do (setf bits (logior bits (aref **rays** (+ (* direction 64) square)))))
               bits)))
      (setf (aref **rook-rays** square) (union-of-rays 0 4)
            (aref **bishop-rays** square) (union-of-rays 4 8))))
  ;; Between and line: for each square A and each direction, walk outwards; every square B
  ;; met is aligned with A, the squares walked before it are between them, and the line is
  ;; the ray in this direction, the opposite ray and A itself.
  (fill **between** 0)
  (fill **line** 0)
  (dotimes (a 64)
    (dotimes (direction 8)
      (destructuring-bind (df . dr) (nth direction *ray-steps*)
        (let* ((opposite (position (cons (- df) (- dr)) *ray-steps* :test #'equal))
               (line (logior (ash 1 a)
                             (aref **rays** (+ (* direction 64) a))
                             (aref **rays** (+ (* opposite 64) a))))
               (walked 0))
          (loop for step from 1
                for b = (on-board-square a (* step df) (* step dr))
                while b
                do (setf (aref **between** (+ (* a 64) b)) walked
                         (aref **line** (+ (* a 64) b)) line
                         walked (logior walked (ash 1 b))))))))
  (fill **castle-mask** 15)
  (setf (aref **castle-mask** +a1+) (logandc2 15 +castle-white-queen+)
        (aref **castle-mask** +h1+) (logandc2 15 +castle-white-king+)
        (aref **castle-mask** +e1+) (logandc2 15 (logior +castle-white-king+
                                                         +castle-white-queen+))
        (aref **castle-mask** +a8+) (logandc2 15 +castle-black-queen+)
        (aref **castle-mask** +h8+) (logandc2 15 +castle-black-king+)
        (aref **castle-mask** +e8+) (logandc2 15 (logior +castle-black-king+
                                                         +castle-black-queen+)))
  t)

(initialise-tables)

(declaim (inline knight-attacks king-attacks pawn-attacks between-squares line-through))

(defun knight-attacks (square)
  "The squares a knight on SQUARE attacks."
  (declare (type square square))
  (aref **knight-attacks** square))

(defun king-attacks (square)
  "The squares a king on SQUARE attacks."
  (declare (type square square))
  (aref **king-attacks** square))

(defun pawn-attacks (colour square)
  "The squares a pawn of COLOUR on SQUARE attacks. Read the other way round, the pawns of
COLOUR that attack SQUARE stand on (PAWN-ATTACKS (OPPOSITE-COLOUR COLOUR) SQUARE)."
  (declare (type colour colour) (type square square))
  (aref **pawn-attacks** (+ (* colour 64) square)))

(defun between-squares (a b)
  "The squares strictly between A and B when they share a rank, file or diagonal, else 0."
  (declare (type square a b))
  (aref **between** (+ (* a 64) b)))

(defun line-through (a b)
  "Every square of the rank, file or diagonal through the different squares A and B, both
included, when they share one, else 0."
  (declare (type square a b))
  (aref **line** (+ (* a 64) b)))
