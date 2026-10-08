;;;; bits.lisp -- 64-bit bit utilities.
;;;;
;;;; Each has a plain definition that the tests compare with a deliberately naive loop over
;;;; many random 64-bit values. Bit 0 is the least significant bit. LSB64 and MSB64 return
;;;; -1 for 0. Where two implementations of one operation exist (popcount, lsb) both are
;;;; kept so the microbenchmarks can compare them on a given machine. Every function here is
;;;; inline, so that a caller with declared 64-bit words, such as a microbenchmark kernel,
;;;; neither calls it nor boxes its argument and result.

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(declaim (inline popcount64 popcount64-swar lsb64 msb64 clear-lowest-bit lsb64-debruijn
                 pext64 pdep64))

(defun popcount64 (x)
  "Number of set bits of X."
  (declare (type u64 x))
  (logcount x))

(defun popcount64-swar (x)
  "Number of set bits of X by the SWAR (parallel add) method, no table and no LOGCOUNT.

Classification: [EXACT]
Basis: a bit identity: the partial sums of 2, 4 and 8 bits never overflow their fields, and
the final multiplication adds the eight byte counts into the top byte.
Evidence: test popcount-matches-the-naive-count (tests/test-bits.lisp)."
  (declare (type u64 x))
  (let* ((x (ldb (byte 64 0) (- x (logand (ash x -1) #x5555555555555555))))
         (x (+ (logand x #x3333333333333333) (logand (ash x -2) #x3333333333333333)))
         (x (logand (+ x (ash x -4)) #x0F0F0F0F0F0F0F0F)))
    (declare (type u64 x))
    (ash (ldb (byte 64 0) (* x #x0101010101010101)) -56)))

(defun lsb64 (x)
  "Index of the least significant set bit of X, or -1 when X is 0."
  (declare (type u64 x))
  (1- (integer-length (logand x (ldb (byte 64 0) (- x))))))

(defun msb64 (x)
  "Index of the most significant set bit of X, or -1 when X is 0."
  (declare (type u64 x))
  (1- (integer-length x)))

(defun clear-lowest-bit (x)
  "X with its least significant set bit cleared."
  (declare (type u64 x))
  (logand x (ldb (byte 64 0) (1- x))))

(defconstant +debruijn64+ #x03F79D71B4CB0A89
  "A 64-bit de Bruijn sequence B(2,6), used by LSB64-DEBRUIJN.")

(sb-ext:defglobal **debruijn-index**
    (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0))
(declaim (type (simple-array (unsigned-byte 8) (64)) **debruijn-index**))

(dotimes (i 64)
  (setf (aref **debruijn-index** (ash (ldb (byte 64 0) (* (ash 1 i) +debruijn64+)) -58)) i))

(defun lsb64-debruijn (x)
  "Index of the least significant set bit of X by de Bruijn multiplication, or -1 for 0.

Classification: [EXACT] (de Bruijn multiplication and its precomputed index table)
Basis: multiplying the isolated lowest bit by a de Bruijn sequence B(2,6) puts a different
6-bit pattern in the top bits for each of the 64 bit positions, and **DEBRUIJN-INDEX** maps
each pattern back to its position.
Evidence: tests de-bruijn-constant-gives-a-perfect-index, lsb-and-msb-match-the-naive-scan
and single-bit-edge-cases (tests/test-bits.lisp)."
  (declare (type u64 x))
  (if (zerop x)
      -1
      (let ((isolated (logand x (ldb (byte 64 0) (- x)))))
        (aref **debruijn-index**
              (ash (ldb (byte 64 0) (* isolated +debruijn64+)) -58)))))

(defmacro do-set-bits ((variable bitboard &optional result) &body body)
  "Run BODY with VARIABLE bound to the index of each set bit of BITBOARD, lowest first, then
return the value of RESULT. BITBOARD is evaluated once. As in DOLIST, BODY may start with
declarations: VARIABLE is bound by a LET whose body is BODY. RESULT is evaluated after the
loop, where VARIABLE is not bound."
  (let ((rest (gensym "REST"))
        (index (gensym "INDEX")))
    `(let ((,rest ,bitboard))
       (declare (type u64 ,rest))
       (loop until (zerop ,rest)
             do (let ((,index (lsb64 ,rest)))
                  (setf ,rest (clear-lowest-bit ,rest))
                  (let ((,variable ,index))
                    ,@body)))
       ,result)))

(defun bit-indices (x)
  "The indices of the set bits of X as a fresh list, lowest first."
  (declare (type u64 x))
  (let ((indices '()))
    (do-set-bits (index x)
      (push index indices))
    (nreverse indices)))

(defun pext64 (x mask)
  "Software parallel bit extract: the bits of X at the set positions of MASK, packed into
the low bits of the result, lowest mask bit first (the BMI2 PEXT instruction)."
  (declare (type u64 x mask))
  (let ((result 0)
        (out 0))
    (declare (type u64 result) (type (integer 0 64) out))
    (do-set-bits (index mask)
      (when (logbitp index x)
        (setf result (logior result (ash 1 out))))
      (incf out))
    result))

(defun pdep64 (x mask)
  "Software parallel bit deposit: the low bits of X scattered to the set positions of MASK,
lowest mask bit first (the BMI2 PDEP instruction)."
  (declare (type u64 x mask))
  (let ((result 0)
        (in 0))
    (declare (type u64 result) (type (integer 0 64) in))
    (do-set-bits (index mask)
      (when (logbitp in x)
        (setf result (logior result (ash 1 index))))
      (incf in))
    result))
