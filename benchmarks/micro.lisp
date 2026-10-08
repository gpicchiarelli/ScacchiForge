;;;; micro.lisp -- microbenchmarks of the bit utilities and of the slider attacks.
;;;;
;;;; Each kernel loops over a fixed vector of seeded random 64-bit values and adds up the
;;;; results, so the work cannot be optimised away and two implementations of the same
;;;; operation can be checked to compute the same thing before they are timed. Every function a
;;;; kernel times is inline (the bit utilities of src/optimized/bits.lisp and NAIVE-POPCOUNT
;;;; below), so that a row times the operation, not a call and the boxing of its 64-bit
;;;; argument and result; the consed column of the report shows whether anything is boxed.
;;;;
;;;; The slider kernels time the three implementations of the optimized layer's slider attacks
;;;; (src/optimized/sliders.lisp) on the same seeded (square, occupancy) pairs. They are
;;;; compiled with the hot-path policy of that layer, so that the lookups are expanded inline
;;;; as the move generator expands them. The lookup of a magic table is timed against the
;;;; computation it replaces, the ray scan, as docs/misure.md asks.

(in-package #:scacchiforge.bench)

(deftype word-vector () '(simple-array (unsigned-byte 64) (*)))

(defconstant +micro-values+ 65536 "Size of the input vectors.")

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *kernel-optimization* '((speed 1) (safety 1))
    "The OPTIMIZE qualities declared inside every kernel. The environment record prints
them."))

(defparameter *input-seeds* '((:random . 1) (:masks . 2) (:lsb . 3) (:msb . 4)
                               (:occupancy . 5) (:evaluation . 6) (:tt-lookup . 7)
                               (:tt-miss . 8))
  "The MAKE-RNG seed of each input, by kind: the input vectors of the microbenchmarks, the
random legal positions of the evaluation rows (:EVALUATION, search-bench.lisp) and those of the
lookup rows of the transposition table (:TT-LOOKUP, stored, and :TT-MISS, not stored;
search-variants-bench.lisp). The environment record prints them.")

(defun input-seed (kind)
  "The seed of the input vector of KIND."
  (or (cdr (assoc kind *input-seeds*))
      (error "No seed for the input vector ~S" kind)))

(defun random-word-vector (seed kind)
  "A vector of +MICRO-VALUES+ pseudo-random 64-bit words from SEED.
KIND :RANDOM gives uniform words. KIND :LSB gives non-zero words whose lowest set bit is
uniformly spread over 0..63, and KIND :MSB the same for the highest set bit, so that the
lsb and msb kernels do not see one constant answer. KIND :OCCUPANCY gives the AND of two
uniform words: a board with 16 occupied squares on average."
  (let ((rng (make-rng seed))
        (vector (make-array +micro-values+ :element-type '(unsigned-byte 64))))
    (dotimes (i +micro-values+ vector)
      (let ((word (rng-next-u64 rng))
            (position (rng-below rng 64)))
        (setf (aref vector i)
              (ecase kind
                (:random word)
                (:lsb (logior (logandc2 word (1- (ash 1 position))) (ash 1 position)))
                (:msb (logior (ldb (byte position 0) word) (ash 1 position)))
                (:occupancy (logand word (rng-next-u64 rng)))))))))

(defmacro define-kernel (name (value mask) form)
  "Define NAME as a function of (VALUES MASKS LOOPS) that returns the wrapped sum of FORM
over the vectors, repeated LOOPS times."
  `(defun ,name (values masks loops)
     (declare (type word-vector values masks) (type fixnum loops)
              (optimize ,@*kernel-optimization*))
     (let ((sum 0))
       (declare (type (unsigned-byte 64) sum))
       (dotimes (pass loops)
         (dotimes (index (length values))
           (let ((,value (aref values index))
                 (,mask (aref masks index)))
             (declare (ignorable ,value ,mask))
             (setf sum (ldb (byte 64 0) (+ sum ,form))))))
       sum)))

(declaim (inline naive-popcount))

(defun naive-popcount (x)
  "Count the bits of X one by one: the slowest honest baseline. Inline, as the bit utilities of
the optimized layer are, so that its kernel times the loop and neither a call nor the boxing of
a 64-bit argument."
  (declare (type (unsigned-byte 64) x))
  (let ((count 0))
    (declare (type (integer 0 64) count))
    (dotimes (index 64 count)
      (when (logbitp index x)
        (incf count)))))

(define-kernel kernel-popcount-logcount (x m) (scf-opt:popcount64 x))
(define-kernel kernel-popcount-swar (x m) (scf-opt:popcount64-swar x))
(define-kernel kernel-popcount-naive (x m) (naive-popcount x))
(define-kernel kernel-lsb-integer-length (x m) (scf-opt:lsb64 x))
(define-kernel kernel-lsb-debruijn (x m) (scf-opt:lsb64-debruijn x))
(define-kernel kernel-msb-integer-length (x m) (scf-opt:msb64 x))
(define-kernel kernel-pext-software (x m) (scf-opt:pext64 x m))
(define-kernel kernel-pdep-software (x m) (scf-opt:pdep64 x m))

(defparameter *micro-benchmarks*
  '(("popcount64 (LOGCOUNT)" kernel-popcount-logcount popcount :random)
    ("popcount64-swar" kernel-popcount-swar popcount :random)
    ("naive popcount loop" kernel-popcount-naive popcount :random)
    ("lsb64 (INTEGER-LENGTH)" kernel-lsb-integer-length lsb :lsb)
    ("lsb64-debruijn" kernel-lsb-debruijn lsb :lsb)
    ("msb64 (INTEGER-LENGTH)" kernel-msb-integer-length msb :msb)
    ("pext64 (software)" kernel-pext-software pext :random)
    ("pdep64 (software)" kernel-pdep-software pdep :random))
  "(label kernel-function equivalence-group input-kind). Kernels of one group get the same
input and must compute the same sum.")

(defun benchmark-inputs ()
  "The input vectors by kind, as an association list; every kernel also gets a mask vector."
  (loop for kind in '(:random :lsb :msb)
        collect (cons kind (random-word-vector (input-seed kind) kind))))

(defun check-equivalent-kernels (inputs masks)
  "Signal an error unless the kernels of each group return the same sum on one pass."
  (let ((sums (make-hash-table)))
    (loop for (label kernel group input) in *micro-benchmarks*
          do (let ((sum (funcall kernel (cdr (assoc input inputs)) masks 1))
                   (previous (gethash group sums)))
               (when (and previous (/= previous sum))
                 (error "Kernels of group ~A disagree (~A): ~D versus ~D"
                        group label previous sum))
               (setf (gethash group sums) sum)))))

(defun calibrate-loops (kernel values masks)
  "How many passes over VALUES make one timed call last about 30 ms of wall-clock time. The
calibration pass is also the untimed warm-up call."
  (let* ((start (get-internal-real-time))
         (ignored (funcall kernel values masks 1))
         (one-pass (max 1d-6 (seconds-since start))))
    (declare (ignore ignored))
    (max 1 (ceiling 0.03d0 one-pass))))

(defun run-micro-benchmark (label kernel values masks repetitions)
  "Time KERNEL REPETITIONS times; return a plist of the observations for the report."
  (let* ((loops (calibrate-loops kernel values masks))
         (operations (* loops (length values)))
         (samples (measure (lambda () (funcall kernel values masks loops)) repetitions)))
    (multiple-value-bind (median minimum maximum) (spread samples :cpu)
      (flet ((nanoseconds (seconds) (* 1d9 (/ seconds operations))))
        (list :label label
              :operations operations
              :median-ns (nanoseconds median)
              :min-ns (nanoseconds minimum)
              :max-ns (nanoseconds maximum)
              :consed-bytes (total samples :consed)
              :gc-seconds (total samples :gc)
              ;; The sum over ONE pass, so rows computing the same quantity show equal values.
              :checksum (funcall kernel values masks 1))))))

(defun run-micro-benchmarks (repetitions)
  "Run every microbenchmark; return the list of result plists."
  (let ((inputs (benchmark-inputs))
        (masks (random-word-vector (input-seed :masks) :random)))
    (check-equivalent-kernels inputs masks)
    (loop for (label kernel nil input) in *micro-benchmarks*
          collect (run-micro-benchmark label kernel (cdr (assoc input inputs)) masks
                                       repetitions))))

;;; --- slider attacks ---------------------------------------------------------------------

(defmacro define-slider-kernel (name function)
  "Define NAME as a function of (OCCUPANCIES SQUARES LOOPS) that returns the wrapped sum of
(FUNCTION square occupancy) over the vectors, repeated LOOPS times; the square is the low six
bits of the SQUARES word. It is compiled with the hot-path policy of the optimized layer."
  `(defun ,name (occupancies squares loops)
     (declare (type word-vector occupancies squares) (type fixnum loops)
              (optimize ,@scf-opt:*optimized-policy*)
              ;; As in the hot path, SBCL's efficiency notes are not printed by the build.
              (sb-ext:muffle-conditions sb-ext:compiler-note))
     (let ((sum 0))
       (declare (type (unsigned-byte 64) sum))
       (dotimes (pass loops)
         (dotimes (index (length occupancies))
           (setf sum (ldb (byte 64 0)
                          (+ sum (,function (ldb (byte 6 0) (aref squares index))
                                            (aref occupancies index)))))))
       sum)))

(define-slider-kernel kernel-rook-magic scf-opt:magic-rook-attacks)
(define-slider-kernel kernel-rook-fixed-magic scf-opt:fixed-magic-rook-attacks)
(define-slider-kernel kernel-rook-ray scf-opt:ray-rook-attacks)
(define-slider-kernel kernel-bishop-magic scf-opt:magic-bishop-attacks)
(define-slider-kernel kernel-bishop-fixed-magic scf-opt:fixed-magic-bishop-attacks)
(define-slider-kernel kernel-bishop-ray scf-opt:ray-bishop-attacks)

(defparameter *slider-benchmarks*
  '(("rook, fixed-magic" kernel-rook-fixed-magic rook)
    ("rook, magic" kernel-rook-magic rook)
    ("rook, ray" kernel-rook-ray rook)
    ("bishop, fixed-magic" kernel-bishop-fixed-magic bishop)
    ("bishop, magic" kernel-bishop-magic bishop)
    ("bishop, ray" kernel-bishop-ray bishop))
  "(label kernel-function equivalence-group) of each slider kernel. The kernels of a group
compute the same attacks and must return the same sum. The label names the implementation as
SCF_SLIDERS does.")

(defun run-slider-benchmarks (repetitions)
  "Run every slider kernel on the seeded :OCCUPANCY words, with the squares taken from the
:MASKS words; return the list of result plists. Signal an error first unless the kernels of
each group agree."
  (let ((occupancies (random-word-vector (input-seed :occupancy) :occupancy))
        (squares (random-word-vector (input-seed :masks) :random))
        (sums (make-hash-table)))
    (loop for (label kernel group) in *slider-benchmarks*
          do (let ((sum (funcall kernel occupancies squares 1))
                   (previous (gethash group sums)))
               (when (and previous (/= previous sum))
                 (error "Slider kernels of group ~A disagree (~A): ~D versus ~D"
                        group label previous sum))
               (setf (gethash group sums) sum)))
    (loop for (label kernel) in *slider-benchmarks*
          collect (run-micro-benchmark label kernel occupancies squares repetitions))))
