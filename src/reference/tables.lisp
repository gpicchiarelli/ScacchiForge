;;;; tables.lisp -- small precomputed step and ray tables for the reference model.
;;;;
;;;; These are plain lists of target squares, built once at load time. They are the
;;;; reference's own data: the optimized layer will have its own bitboard attack tables.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(deftype square-vector () '(simple-array (unsigned-byte 8) (*)))

;;; Ray directions. 0..3 are the rook directions, 4..7 the bishop directions.
(defconstant +dir-north+ 0)
(defconstant +dir-south+ 1)
(defconstant +dir-east+ 2)
(defconstant +dir-west+ 3)
(defconstant +dir-north-east+ 4)
(defconstant +dir-north-west+ 5)
(defconstant +dir-south-east+ 6)
(defconstant +dir-south-west+ 7)

(defparameter *direction-steps*
  ;; (file-delta . rank-delta) for each direction constant above.
  '((0 . 1) (0 . -1) (1 . 0) (-1 . 0) (1 . 1) (-1 . 1) (1 . -1) (-1 . -1)))

(sb-ext:defglobal **knight-targets** (make-array 64 :initial-element nil))
(sb-ext:defglobal **king-targets** (make-array 64 :initial-element nil))
;; Indexed by (colour * 64 + square): squares a pawn of that colour attacks from there.
(sb-ext:defglobal **pawn-attacks** (make-array 128 :initial-element nil))
;; Indexed by (direction * 64 + square): the squares along the ray, nearest first.
(sb-ext:defglobal **rays** (make-array 512 :initial-element nil))
;; Castling rights that survive a move touching the square (from or to).
(sb-ext:defglobal **castle-mask**
    (make-array 64 :element-type '(unsigned-byte 8) :initial-element 15))

(declaim (type (simple-vector 64) **knight-targets** **king-targets**)
         (type (simple-vector 128) **pawn-attacks**)
         (type (simple-vector 512) **rays**)
         (type (simple-array (unsigned-byte 8) (64)) **castle-mask**))

(defun square-vector (squares)
  "Pack the list SQUARES into a vector of bytes."
  (make-array (length squares) :element-type '(unsigned-byte 8) :initial-contents squares))

(defun offsets-from (square deltas)
  "Squares reached from SQUARE by each (file . rank) delta in DELTAS that stay on the board."
  (let ((file (square-file square))
        (rank (square-rank square)))
    (loop for (df . dr) in deltas
          for f = (+ file df)
          for r = (+ rank dr)
          when (and (<= 0 f 7) (<= 0 r 7))
            collect (make-square f r))))

(defun ray-from (square direction)
  "Squares met walking from SQUARE in DIRECTION, nearest first."
  (destructuring-bind (df . dr) (nth direction *direction-steps*)
    (loop for f = (+ (square-file square) df) then (+ f df)
          for r = (+ (square-rank square) dr) then (+ r dr)
          while (and (<= 0 f 7) (<= 0 r 7))
          collect (make-square f r))))

(defun initialise-tables ()
  "Fill all the tables above. Idempotent.

Classification: [EXACT] (precomputed tables)
Basis: each entry is the value of a pure function of its index (OFFSETS-FROM, RAY-FROM, the
castling rule), computed once at load time and read back instead of being computed again.
A lookup returns what the computation would.
Evidence: perft against published counts (tests/test-perft.lisp), which uses every table
through move generation and attack detection."
  (let ((knight-deltas '((1 . 2) (2 . 1) (2 . -1) (1 . -2) (-1 . -2) (-2 . -1) (-2 . 1) (-1 . 2)))
        (king-deltas '((0 . 1) (0 . -1) (1 . 0) (-1 . 0) (1 . 1) (-1 . 1) (1 . -1) (-1 . -1))))
    (dotimes (sq 64)
      (setf (svref **knight-targets** sq) (square-vector (offsets-from sq knight-deltas))
            (svref **king-targets** sq) (square-vector (offsets-from sq king-deltas))
            (svref **pawn-attacks** sq)
            (square-vector (offsets-from sq '((-1 . 1) (1 . 1))))
            (svref **pawn-attacks** (+ 64 sq))
            (square-vector (offsets-from sq '((-1 . -1) (1 . -1)))))
      (dotimes (direction 8)
        (setf (svref **rays** (+ (* direction 64) sq)) (square-vector (ray-from sq direction))))))
  (fill **castle-mask** 15)
  (setf (aref **castle-mask** +a1+) (logandc2 15 +castle-white-queen+)
        (aref **castle-mask** +h1+) (logandc2 15 +castle-white-king+)
        (aref **castle-mask** +e1+) (logandc2 15 (logior +castle-white-king+ +castle-white-queen+))
        (aref **castle-mask** +a8+) (logandc2 15 +castle-black-queen+)
        (aref **castle-mask** +h8+) (logandc2 15 +castle-black-king+)
        (aref **castle-mask** +e8+) (logandc2 15 (logior +castle-black-king+ +castle-black-queen+)))
  t)

(initialise-tables)

(declaim (inline step-targets ray-squares pawn-attack-squares))

(defun step-targets (table square)
  "The target vector of SQUARE in TABLE (**KNIGHT-TARGETS** or **KING-TARGETS**)."
  (declare (type (simple-vector 64) table) (type square square))
  (the square-vector (svref table square)))

(defun ray-squares (direction square)
  "The squares of the ray from SQUARE in DIRECTION, nearest first."
  (declare (type (integer 0 7) direction) (type square square))
  (the square-vector (svref **rays** (+ (* direction 64) square))))

(defun pawn-attack-squares (colour square)
  "The squares a pawn of COLOUR standing on SQUARE attacks."
  (declare (type colour colour) (type square square))
  (the square-vector (svref **pawn-attacks** (+ (* colour 64) square))))
