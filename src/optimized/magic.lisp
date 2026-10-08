;;;; magic.lisp -- magic-bitboard tables of the slider attacks: the relevant occupancy masks,
;;;; the seeded search for the magic numbers, and the tables built from the committed numbers.
;;;;
;;;; A slider's attacks from a square depend only on the occupancy of its relevant squares: the
;;;; squares of its rays without the last square of each ray, since a piece on the edge of the
;;;; board blocks nothing behind it. A magic number M of a square turns that occupancy into an
;;;; index of a precomputed table,
;;;;
;;;;   index = ((occupancy AND mask) * M mod 2^64) >> (64 - bits),
;;;;
;;;; and M is good when no two blocker sets with different attack sets get the same index (two
;;;; with the same attacks may share one). Two layouts are kept, so that "make bench" can
;;;; measure both (sliders.lisp reads them; ADR-0016):
;;;;
;;;;   :MAGIC        bits = the number of relevant squares of the square (5 to 12): one shift
;;;;                 and one offset per square, a table of 107648 entries;
;;;;   :FIXED-MAGIC  bits = 12 for every rook square and 9 for every bishop square: constant
;;;;                 shifts, offsets computed from the square, a table of 294912 entries.
;;;;
;;;; Where the numbers come from (ADR-0007, ADR-0013, ADR-0016): SEARCH-MAGIC-NUMBERS below,
;;;; run from +MAGIC-SEED+ with the core's splitmix64 generator by tools/generate-magics.lisp
;;;; ("make magics"), which writes src/optimized/magic-numbers.lisp. No number comes from
;;;; another engine. The test committed-magic-numbers-are-the-output-of-the-seeded-search
;;;; (tests/test-optimized.lisp) runs the search again and requires the committed numbers.
;;;;
;;;; Every table entry is a value of the ray attacks of rays.lisp. Building a table walks every
;;;; relevant occupancy of every square, so a committed number that is not magic stops the load
;;;; with an error instead of giving a wrong attack set. "make magics" loads the system without
;;;; building the tables (the feature :SCACCHIFORGE-MAGIC-SEARCH, at the end of this file), so
;;;; that its search does not depend on the committed numbers.
;;;;
;;;; This file is not on the hot path; the lookups are in sliders.lisp.

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(defconstant +magic-seed+ #x4D61676963686521
  "ASCII \"Magiche!\": the seed of the search for the magic numbers.")

(defconstant +magic-table-size+ 107648
  "Entries of the :MAGIC attack table: the sum over the 64 rook and the 64 bishop squares of 2
to the number of relevant squares (102400 for the rooks, 5248 for the bishops).")

(defconstant +fixed-magic-bishop-base+ (* 64 4096)
  "Where the bishop part of the :FIXED-MAGIC attack table starts: after 4096 rook entries for
each square.")

(defconstant +fixed-magic-table-size+ (+ (* 64 4096) (* 64 512))
  "Entries of the :FIXED-MAGIC attack table: 4096 per rook square and 512 per bishop square.")

;;; Slots: the rook of square S is slot S, the bishop of square S is slot 64 + S.

(define-table **magic-entries** 512
  "The :MAGIC layout, four words per slot from 4 * slot: mask, magic number, shift (64 minus
the number of relevant squares) and offset of the slot's block in **MAGIC-ATTACKS**.")
(define-table **magic-attacks** 107648
  "The :MAGIC attack table, in blocks of 2^bits entries per slot, in slot order.")
(define-table **fixed-magic-entries** 256
  "The :FIXED-MAGIC layout, two words per slot from 2 * slot: mask and magic number.")
(define-table **fixed-magic-attacks** 294912
  "The :FIXED-MAGIC attack table: 4096 entries for each rook square, from 4096 * square, then
512 for each bishop square, from +FIXED-MAGIC-BISHOP-BASE+ + 512 * square.")

(defun slot-rook-p (slot)
  "True when SLOT is a rook slot."
  (< slot 64))

(defun slot-square (slot)
  "The square of SLOT."
  (mod slot 64))

(defun relevant-occupancy-mask (slot)
  "The relevant squares of SLOT: the squares of the slider's four rays from its square, without
the last square of each ray."
  (let ((mask 0))
    (dolist (direction (if (slot-rook-p slot)
                           (list +north+ +east+ +south+ +west+)
                           (list +north-east+ +north-west+ +south-east+ +south-west+))
                       mask)
      (let ((ray (aref **rays** (+ (* direction 64) (slot-square slot)))))
        (unless (zerop ray)
          ;; The last square of a ray towards higher indices is its highest bit, and of a ray
          ;; towards lower indices its lowest.
          (let ((last (if (member direction (list +north+ +east+ +north-east+ +north-west+))
                          (1- (integer-length ray))
                          (1- (integer-length (logand ray (- ray)))))))
            (setf mask (logior mask (logandc2 ray (ash 1 last))))))))))

(defun slot-attacks (slot occupancy)
  "The attacks of the slider of SLOT with OCCUPANCY, by the ray attacks of rays.lisp."
  (if (slot-rook-p slot)
      (ray-rook-attacks (slot-square slot) occupancy)
      (ray-bishop-attacks (slot-square slot) occupancy)))

(defun magic-index-bits (layout slot)
  "The number of index bits of SLOT in LAYOUT (:MAGIC or :FIXED-MAGIC)."
  (ecase layout
    (:magic (logcount (relevant-occupancy-mask slot)))
    (:fixed-magic (if (slot-rook-p slot) 12 9))))

(defun slot-occupancies (slot)
  "Two vectors of (UNSIGNED-BYTE 64): every subset of the relevant squares of SLOT, the empty
set first, and the attacks of the slider for each. The subsets are enumerated by the carry
rule: the subset after S is ((S - mask) AND mask), and the one after the full mask is empty."
  (let* ((mask (relevant-occupancy-mask slot))
         (count (ash 1 (logcount mask)))
         (subsets (make-array count :element-type '(unsigned-byte 64)))
         (attacks (make-array count :element-type '(unsigned-byte 64)))
         (subset 0))
    (declare (type bitboard mask subset))
    (dotimes (index count)
      (setf (aref subsets index) subset
            (aref attacks index) (slot-attacks slot subset)
            subset (logand (ldb (byte 64 0) (- subset mask)) mask)))
    (values subsets attacks)))

;;; --- the search -------------------------------------------------------------------------

(defun magic-number-p (magic subsets attacks bits seen stored stamp)
  "True when MAGIC maps the blocker sets SUBSETS to indices of BITS bits without two of them
with different ATTACKS sharing an index. SEEN and STORED are scratch vectors of 2^BITS
entries: an index is in use in this trial when its SEEN entry is STAMP, and then STORED holds
the attacks put there, so the vectors need no clearing between trials."
  (declare (type bitboard magic) (type (simple-array (unsigned-byte 64) (*)) subsets attacks)
           (type (integer 1 12) bits) (type (simple-array fixnum (*)) seen)
           (type (simple-array (unsigned-byte 64) (*)) stored) (type fixnum stamp))
  (let ((shift (- 64 bits)))
    (declare (type (integer 52 63) shift))
    (dotimes (k (length subsets) t)
      (let ((index (ash (ldb (byte 64 0) (* (aref subsets k) magic)) (- shift))))
        (declare (type (integer 0 4095) index))
        (cond ((/= (aref seen index) stamp)
               (setf (aref seen index) stamp
                     (aref stored index) (aref attacks k)))
              ((/= (aref stored index) (aref attacks k))
               (return nil)))))))

(defun find-magic-number (slot bits rng)
  "The first magic number of SLOT with BITS index bits among the candidates drawn from RNG, and
the number of candidates drawn.

Classification: [EXACT] (every number returned is magic); [HEURISTIC] (the quick rejection)
Basis: a candidate is returned only after MAGIC-NUMBER-P has checked every blocker set of the
slot, so the number returned is magic whatever the search did to find it; how many candidates
it takes is an observation, not a guarantee. A candidate is the AND of three draws of the
generator, so that about one bit in eight is set: sparse candidates turn out to be magic more
often (a published observation: Chess Programming Wiki, \"Looking for Magics\"). A candidate
whose product with the mask has fewer than six set bits among its top eight is rejected
without the full check. The rejection is a heuristic: it may skip a candidate that was magic,
which changes which number is found, never whether it is magic.
Evidence: test committed-magic-numbers-are-the-output-of-the-seeded-search and the exhaustive
slider tests (tests/test-optimized.lisp); building the tables checks every blocker set
again (INITIALISE-MAGIC-TABLES)."
  (multiple-value-bind (subsets attacks) (slot-occupancies slot)
    (let ((mask (relevant-occupancy-mask slot))
          (seen (make-array (ash 1 bits) :element-type 'fixnum :initial-element 0))
          (stored (make-array (ash 1 bits) :element-type '(unsigned-byte 64))))
      (loop for candidates of-type fixnum from 1
            do (let ((magic (logand (rng-next-u64 rng) (rng-next-u64 rng) (rng-next-u64 rng))))
                 (declare (type bitboard magic))
                 (when (and (>= (logcount (ldb (byte 8 56) (ldb (byte 64 0) (* mask magic)))) 6)
                            (magic-number-p magic subsets attacks bits seen stored candidates))
                   (return (values magic candidates))))))))

(defun search-magic-numbers (&optional (seed +magic-seed+))
  "Search the magic numbers of both layouts from SEED. Each layout draws from its own
generator, (MAKE-RNG SEED), slot by slot: the rook squares a1 to h8, then the bishop squares
a1 to h8. Return a property list (:SEED seed :MAGIC numbers :FIXED-MAGIC numbers :CANDIDATES
(drawn-for-magic drawn-for-fixed-magic)), each NUMBERS a list of 128 integers in slot order.
This is what tools/generate-magics.lisp writes to src/optimized/magic-numbers.lisp."
  (let ((result (list :seed seed))
        (candidates '()))
    (dolist (layout '(:magic :fixed-magic))
      (let ((rng (make-rng seed))
            (drawn 0)
            (numbers '()))
        (dotimes (slot 128)
          (multiple-value-bind (magic count)
              (find-magic-number slot (magic-index-bits layout slot) rng)
            (push magic numbers)
            (incf drawn count)))
        (setf result (append result (list layout (nreverse numbers))))
        (push drawn candidates)))
    (append result (list :candidates (nreverse candidates)))))

;;; --- the tables -------------------------------------------------------------------------

(defun fill-magic-block (table slot magic bits offset)
  "Store, for every blocker set of SLOT, its attacks at OFFSET plus its index under MAGIC with
BITS bits in TABLE, whose block must be zero. Signal an error when two blocker sets with
different attacks meet at one index: MAGIC is then not a magic number of SLOT."
  (multiple-value-bind (subsets attacks) (slot-occupancies slot)
    (dotimes (k (length subsets))
      (let ((index (+ offset (ash (ldb (byte 64 0) (* (aref subsets k) magic)) (- bits 64))))
            (value (aref attacks k)))
        (cond ((zerop (aref table index))
               ;; No slider attacks nothing: a rook attacks at least two squares and a bishop
               ;; at least one, so zero marks a free entry.
               (setf (aref table index) value))
              ((/= (aref table index) value)
               (error "~X is not a magic number of the ~:[bishop~;rook~] on ~A with ~D bits; ~
                       src/optimized/magic-numbers.lisp must be written by make magics"
                      magic (slot-rook-p slot) (square-name (slot-square slot)) bits)))))))

(defun initialise-magic-tables (&optional (numbers *committed-magic-numbers*))
  "Fill the entries and the attack tables of both layouts from NUMBERS, a property list as made by
SEARCH-MAGIC-NUMBERS. Idempotent. Every blocker set of every slot is stored, so the build
signals an error if a number is not magic (FILL-MAGIC-BLOCK).

Classification: [EXACT] (magic-bitboard tables)
Basis: every relevant occupancy of every slot is enumerated and its ray attacks stored at
its magic index, and no two occupancies with different attacks share an index; an occupancy
outside the relevant squares does not change the attacks and is masked away by the lookup.
So the lookup of sliders.lisp returns, for any occupancy, what the ray attacks return.
Evidence: tests every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy
and slider-implementations-agree-on-random-occupancies (tests/test-optimized.lisp), perft
(tests/test-optimized-perft.lisp) and the differential tests (tests/test-differential.lisp)."
  (fill **magic-attacks** 0)
  (fill **fixed-magic-attacks** 0)
  (let ((offset 0))
    (loop for slot from 0 below 128
          for magic in (getf numbers :magic)
          for fixed-magic in (getf numbers :fixed-magic)
          do (let ((mask (relevant-occupancy-mask slot))
                   (bits (magic-index-bits :magic slot)))
               (setf (aref **magic-entries** (* 4 slot)) mask
                     (aref **magic-entries** (+ (* 4 slot) 1)) magic
                     (aref **magic-entries** (+ (* 4 slot) 2)) (- 64 bits)
                     (aref **magic-entries** (+ (* 4 slot) 3)) offset
                     (aref **fixed-magic-entries** (* 2 slot)) mask
                     (aref **fixed-magic-entries** (+ (* 2 slot) 1)) fixed-magic)
               (fill-magic-block **magic-attacks** slot magic bits offset)
               (fill-magic-block **fixed-magic-attacks** slot fixed-magic
                                 (magic-index-bits :fixed-magic slot)
                                 (if (slot-rook-p slot)
                                     (* 4096 slot)
                                     (+ +fixed-magic-bishop-base+ (* 512 (- slot 64)))))
               (incf offset (ash 1 bits))))
    (unless (and (= offset +magic-table-size+)
                 (= 128 (length (getf numbers :magic)) (length (getf numbers :fixed-magic))))
      (error "The magic tables do not have the expected shape: ~D entries, ~D and ~D numbers"
             offset (length (getf numbers :magic)) (length (getf numbers :fixed-magic)))))
  t)

;;; The tables are built from the committed numbers when this file is loaded, unless the feature
;;; :SCACCHIFORGE-MAGIC-SEARCH is present. tools/generate-magics.lisp ("make magics") binds
;;; *FEATURES* with it while it loads the system before the search, so that the search never
;;; depends on the numbers it is about to replace: a committed file whose numbers are not magic
;;; for the masks and index bits above does not stop it. The feature is read when the file is
;;; loaded, not when it is compiled, so the compiled file is the same with or without it.

(unless (member :scacchiforge-magic-search *features*)
  (initialise-magic-tables))
