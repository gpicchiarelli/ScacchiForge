;;;; prng.lisp -- deterministic pseudo-random numbers (splitmix64).
;;;;
;;;; Used for the Zobrist keys and for every seeded test, fuzz and benchmark input. The
;;;; sequence depends only on the seed, never on the platform or the run (unlike SXHASH or
;;;; the built-in RANDOM state).

(in-package #:scacchiforge.core)

(defstruct (rng (:constructor %make-rng (state)) (:copier copy-rng))
  "A splitmix64 generator. Copy it with COPY-RNG to replay a sequence."
  (state 0 :type (unsigned-byte 64)))

(defun make-rng (seed)
  "A generator for the integer SEED (reduced modulo 2^64)."
  (%make-rng (ldb (byte 64 0) seed)))

(defun rng-next-u64 (rng)
  "The next 64-bit value of RNG (splitmix64)."
  (declare (type rng rng))
  (let ((state (ldb (byte 64 0) (+ (rng-state rng) #x9E3779B97F4A7C15))))
    (declare (type (unsigned-byte 64) state))
    (setf (rng-state rng) state)
    (let* ((z state)
           (z (ldb (byte 64 0) (* (logxor z (ash z -30)) #xBF58476D1CE4E5B9)))
           (z (ldb (byte 64 0) (* (logxor z (ash z -27)) #x94D049BB133111EB))))
      (declare (type (unsigned-byte 64) z))
      (logxor z (ash z -31)))))

(defun rng-below (rng n)
  "A uniformly distributed integer in [0, N), by rejection sampling. N is from 1 to 2^64:
one 64-bit draw cannot cover a larger range, so a larger N signals a TYPE-ERROR."
  (declare (type rng rng))
  (check-type n (integer 1 #x10000000000000000))
  (let ((limit (- (ash 1 64) (mod (ash 1 64) n))))
    (loop
      (let ((x (rng-next-u64 rng)))
        (when (< x limit)
          (return (mod x n)))))))

(defun rng-pick (rng sequence)
  "A uniformly chosen element of the non-empty SEQUENCE."
  (elt sequence (rng-below rng (length sequence))))
