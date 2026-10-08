;;;; rays.lisp -- classical ray attacks of the sliding pieces, with a blocker scan.
;;;;
;;;;   (RAY-BISHOP-ATTACKS square occupancy)  (RAY-ROOK-ATTACKS square occupancy)
;;;;
;;;; Each returns the squares a piece of that kind on SQUARE attacks when the occupied squares
;;;; are OCCUPANCY: along each ray, every square up to and including the first occupied one.
;;;; The colour of the blocker does not matter here; the caller removes its own pieces.
;;;;
;;;; This is one of the three implementations behind the slider interface of sliders.lisp, the
;;;; one whose correctness is easiest to see. It also builds the magic-bitboard tables
;;;; (magic.lisp): every entry of those tables is the value this file computes for one
;;;; occupancy. The tests compare it with a square-by-square walk on every relevant occupancy
;;;; of every square (tests/test-optimized.lisp).

(in-package #:scacchiforge.optimized)

(declaim-optimized-policy)

(declaim (inline positive-ray-attacks negative-ray-attacks
                 ray-bishop-attacks ray-rook-attacks))

(defun positive-ray-attacks (direction square occupancy)
  "The attacked squares along the ray DIRECTION from SQUARE, for a direction towards higher
square indices: the nearest occupied square is the lowest set bit of the ray's blockers."
  (declare (type (integer 0 7) direction) (type square square) (type bitboard occupancy))
  (let* ((ray (aref **rays** (+ (* direction 64) square)))
         (blockers (logand ray occupancy)))
    (declare (type bitboard ray blockers))
    (if (zerop blockers)
        ray
        (let ((nearest (1- (integer-length (logand blockers (ldb (byte 64 0) (- blockers)))))))
          (declare (type square nearest))
          (logxor ray (aref **rays** (+ (* direction 64) nearest)))))))

(defun negative-ray-attacks (direction square occupancy)
  "The attacked squares along the ray DIRECTION from SQUARE, for a direction towards lower
square indices: the nearest occupied square is the highest set bit of the ray's blockers."
  (declare (type (integer 0 7) direction) (type square square) (type bitboard occupancy))
  (let* ((ray (aref **rays** (+ (* direction 64) square)))
         (blockers (logand ray occupancy)))
    (declare (type bitboard ray blockers))
    (if (zerop blockers)
        ray
        (let ((nearest (1- (integer-length blockers))))
          (declare (type square nearest))
          (logxor ray (aref **rays** (+ (* direction 64) nearest)))))))

(defun ray-bishop-attacks (square occupancy)
  "The squares a bishop on SQUARE attacks when OCCUPANCY is the set of occupied squares,
computed ray by ray.

Classification: [EXACT] (classical ray attacks with a blocker scan)
Basis: along a ray the attacked squares are those up to and including the nearest occupied
one. The precomputed ray from SQUARE minus the precomputed ray from that blocker in the same
direction is exactly that set; the nearest blocker is the lowest set bit of the blockers on a
ray towards higher indices and the highest on a ray towards lower ones.
Evidence: tests slider-attacks-match-a-naive-walk and
every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy
(tests/test-optimized.lisp), exhaustive over the occupancies of each square's rays, and perft
(tests/test-optimized-perft.lisp)."
  (declare (type square square) (type bitboard occupancy))
  (logior (positive-ray-attacks +north-east+ square occupancy)
          (positive-ray-attacks +north-west+ square occupancy)
          (negative-ray-attacks +south-east+ square occupancy)
          (negative-ray-attacks +south-west+ square occupancy)))

(defun ray-rook-attacks (square occupancy)
  "The squares a rook on SQUARE attacks when OCCUPANCY is the set of occupied squares,
computed ray by ray.

Classification: [EXACT] (classical ray attacks with a blocker scan)
Basis: as for RAY-BISHOP-ATTACKS, on the four orthogonal rays.
Evidence: as for RAY-BISHOP-ATTACKS."
  (declare (type square square) (type bitboard occupancy))
  (logior (positive-ray-attacks +north+ square occupancy)
          (positive-ray-attacks +east+ square occupancy)
          (negative-ray-attacks +south+ square occupancy)
          (negative-ray-attacks +west+ square occupancy)))
