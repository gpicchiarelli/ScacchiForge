;;;; transposition.lisp -- the transposition table of the optimized layer (Phase 3).
;;;;
;;;; A preallocated table of compact entries in typed arrays, indexed by the Zobrist key of the
;;;; position (make.lisp keeps it incrementally). Each slot holds two 64-bit words: the full key,
;;;; compared on every probe, and a data word packing the best move, the score relative to the
;;;; node, the depth, the bound type (exact, lower, upper; 0 marks an empty slot) and the
;;;; generation of the search that stored it. The number of slots (a power of two) and the
;;;; replacement policy are arguments of MAKE-BITBOARD-TRANSPOSITION-TABLE, so neither is fixed in
;;;; the code:
;;;;  - :ALWAYS, one slot per bucket, always replaced;
;;;;  - :DEPTH-PREFERRED, one slot per bucket, replaced when it is empty, when it holds the same
;;;;    position, when it was stored by an earlier search (another generation) or when the new
;;;;    entry is at least as deep; otherwise the new entry is not stored;
;;;;  - :TWO-SLOT, two slots per bucket: the first replaced as by :DEPTH-PREFERRED, the second
;;;;    taking every entry the first refuses.
;;;; A slot that holds the same position is always the one written.
;;;;
;;;; The table has two modes. :NORMAL is the one a game would use: a search may cut on an entry
;;;; at least as deep as the node. :VERIFICATION is the mode of docs/verifica.md ("Modalità di
;;;; verifica della TT"), used by the tests and never by play: a search cuts only on an entry of
;;;; exactly the node's depth (TT-1), and each slot also keeps an independent check of its
;;;; position (the six piece-type bitboards, the two colour occupancies and a word with the side
;;;; to move, the castling rights and the en-passant square the key counts), so that a slot whose
;;;; key matches but whose position differs is a false hit: it is discarded and counted (TT-3).
;;;; The scores are stored relative to the node (search.lisp converts mate scores in both
;;;; directions) and no score depends on the path (TT-2: the search detects no repetition and no
;;;; fifty-move rule, and the clocks are not in the key); with no pruning other than alpha-beta
;;;; (TT-4), a search with the table in this mode returns the value of the search without it.
;;;;
;;;; KEY-MASK, all ones unless a test sets it, is ANDed into the key before it indexes the table
;;;; and before it is stored and compared: a narrow mask forces many positions onto the same key,
;;;; so that a test can force false hits and show that they are discarded and counted, and that a
;;;; move read from another position's entry is never played (INV-C6, search.lisp).
;;;;
;;;; Probe and store are on the hot path and allocate nothing. The constructor, the statistics and
;;;; the inspection functions are outside it.

(in-package #:scacchiforge.optimized)

;;; The table structure, the constants and the constructor are not on the hot path: they are
;;; compiled with the policy of the layer's files outside it.

(declaim (optimize (speed 1) (safety 2)))

(defconstant +bitboard-tt-exact+ 1 "Bound type of an entry whose score is the value of the node.")
(defconstant +bitboard-tt-lower+ 2
  "Bound type of an entry whose score is a lower bound of the value (the node failed high).")
(defconstant +bitboard-tt-upper+ 3
  "Bound type of an entry whose score is an upper bound of the value (the node failed low).")

(defconstant +tt-check-words+ 9
  "Words of the independent check of a slot in verification mode: six piece-type bitboards, two
colour occupancies, one word of side, castling rights and en-passant square.")

(defconstant +tt-all-key-bits+ #xFFFFFFFFFFFFFFFF "The key mask that keeps every bit.")

(defconstant +tt-maximum-entries+ 1073741824 "The largest table, in slots: 2^30.")

(defconstant +bitboard-tt-default-entries+ 65536
  "The number of slots of a table made without :ENTRIES: 1 MiB of keys and data words (16 bytes
a slot), and 4.5 MiB more of checks in verification mode (72 bytes a slot).")

(defparameter *bitboard-tt-policies* '(:two-slot :depth-preferred :always)
  "The replacement policies of the transposition table, the default first.")

(defparameter *bitboard-tt-modes* '(:normal :verification)
  "The modes of the transposition table, the default first.")

(defstruct (bitboard-transposition-table (:conc-name tt-)
                                         (:constructor %make-bitboard-transposition-table)
                                         (:copier nil))
  "A transposition table: KEYS and DATA hold one 64-bit word each per slot; CHECKS holds
+TT-CHECK-WORDS+ words per slot in verification mode and nothing otherwise. A bucket is SLOTS
consecutive slots (two for :TWO-SLOT, else one), and the bucket of a key is its low bits under
BUCKET-MASK. The counters below GENERATION are statistics: probes made; hits (key equal and,
in verification mode, check equal); false hits (key equal, check different: discarded); hits
with a depth the search may cut on; cutoffs; stores made and refused; stores that replaced
another position; and, counted by the search, TT moves tried first and TT moves found not
legal in the position."
  (keys (make-array 0 :element-type '(unsigned-byte 64))
   :type (simple-array (unsigned-byte 64) (*)))
  (data (make-array 0 :element-type '(unsigned-byte 64))
   :type (simple-array (unsigned-byte 64) (*)))
  (checks (make-array 0 :element-type '(unsigned-byte 64))
   :type (simple-array (unsigned-byte 64) (*)))
  (entries 2 :type fixnum)
  (bucket-mask 0 :type (unsigned-byte 31))
  (slots 1 :type (integer 1 2))
  (policy :two-slot :type keyword)
  (policy-code 2 :type (integer 0 2))
  (verification nil :type boolean)
  (key-mask +tt-all-key-bits+ :type (unsigned-byte 64))
  (generation 0 :type (unsigned-byte 8))
  (probes 0 :type fixnum)
  (hits 0 :type fixnum)
  (false-hits 0 :type fixnum)
  (usable-hits 0 :type fixnum)
  (cutoffs 0 :type fixnum)
  (stores 0 :type fixnum)
  (refused-stores 0 :type fixnum)
  (overwrites 0 :type fixnum)
  (move-first 0 :type fixnum)
  (rejected-moves 0 :type fixnum))

(defun make-bitboard-transposition-table (&key (entries +bitboard-tt-default-entries+)
                                            (policy (first *bitboard-tt-policies*))
                                            (mode (first *bitboard-tt-modes*))
                                            (key-mask +tt-all-key-bits+))
  "A cleared transposition table of ENTRIES slots (a power of two, at least 2), with the
replacement POLICY (one of *BITBOARD-TT-POLICIES*) and the MODE :NORMAL or :VERIFICATION
(*BITBOARD-TT-MODES*). KEY-MASK, a test hook, is ANDed into every key before it is used; all
ones by default. Memory: 16 bytes a slot, and 72 more in verification mode."
  (check-type entries (integer 2 1073741824))
  (unless (= 1 (logcount entries))
    (error "a transposition table has a power of two of slots, not ~D" entries))
  (unless (member policy *bitboard-tt-policies*)
    (error "the replacement policy ~S is not one of~{ ~S~}" policy *bitboard-tt-policies*))
  (unless (member mode *bitboard-tt-modes*)
    (error "the mode ~S is not one of~{ ~S~}" mode *bitboard-tt-modes*))
  (check-type key-mask (unsigned-byte 64))
  (let* ((slots (if (eq policy :two-slot) 2 1))
         (verification (eq mode :verification)))
    (%make-bitboard-transposition-table
     :keys (make-array entries :element-type '(unsigned-byte 64) :initial-element 0)
     :data (make-array entries :element-type '(unsigned-byte 64) :initial-element 0)
     :checks (make-array (if verification (* +tt-check-words+ entries) 0)
                         :element-type '(unsigned-byte 64) :initial-element 0)
     :entries entries
     :bucket-mask (1- (floor entries slots))
     :slots slots
     :policy policy
     :policy-code (ecase policy (:always 0) (:depth-preferred 1) (:two-slot 2))
     :verification verification
     :key-mask key-mask)))

;;; --- the hot path ---------------------------------------------------------------------------

(declaim-optimized-policy)

(declaim (inline pack-tt-word tt-word-move tt-word-score tt-word-depth tt-word-bound
                 tt-word-generation en-passant-check-square position-check-word
                 check-matches-p write-check))

;;; The data word: bits 0-19 the move, 20-35 the score plus 32768, 36-42 the depth, 43-44 the
;;; bound type (0: empty slot), 45-52 the generation. It fits in 53 bits.

(defun pack-tt-word (move score depth bound generation)
  "The data word of an entry."
  (declare (type move move) (type (integer -32768 32767) score) (type (integer 0 127) depth)
           (type (integer 1 3) bound) (type (unsigned-byte 8) generation))
  (logior move (ash (+ score 32768) 20) (ash depth 36) (ash bound 43) (ash generation 45)))

(defun tt-word-move (word)
  "The move of the data word WORD."
  (declare (type (unsigned-byte 64) word))
  (ldb (byte 20 0) word))

(defun tt-word-score (word)
  "The score, relative to the node, of the data word WORD."
  (declare (type (unsigned-byte 64) word))
  (- (ldb (byte 16 20) word) 32768))

(defun tt-word-depth (word)
  "The depth of the data word WORD."
  (declare (type (unsigned-byte 64) word))
  (ldb (byte 7 36) word))

(defun tt-word-bound (word)
  "The bound type of the data word WORD, 0 for an empty slot."
  (declare (type (unsigned-byte 64) word))
  (ldb (byte 2 43) word))

(defun tt-word-generation (word)
  "The generation of the data word WORD."
  (declare (type (unsigned-byte 64) word))
  (ldb (byte 8 45) word))

(defun en-passant-check-square (bbp)
  "The en-passant square of BBP when a pawn of the side to move attacks it, else +NO-SQUARE+:
the en-passant part of the position as the key counts it (src/core/zobrist.lisp)."
  (declare (type bitboard-position bbp))
  (let ((target (bbp-en-passant bbp))
        (side (bbp-side bbp)))
    (if (and (/= target +no-square+)
             (logtest (pawn-attacks (opposite-colour side) (the square target))
                      (aref (bbp-pieces bbp) (* side 6))))
        target
        +no-square+)))

(defun position-check-word (bbp)
  "Side to move, castling rights and the en-passant square the key counts, in one word."
  (declare (type bitboard-position bbp))
  (logior (bbp-side bbp) (ash (bbp-castling bbp) 1) (ash (en-passant-check-square bbp) 5)))

(defun check-matches-p (table slot bbp)
  "True when the independent check of SLOT of TABLE describes BBP."
  (declare (type bitboard-transposition-table table) (type fixnum slot)
           (type bitboard-position bbp))
  (let ((checks (tt-checks table))
        (pieces (bbp-pieces bbp))
        (colours (bbp-colour-occupancy bbp))
        (base (* slot +tt-check-words+)))
    (declare (type fixnum base))
    (and (loop for type of-type fixnum from 0 below 6
               always (= (aref checks (+ base type))
                         (logior (aref pieces type) (aref pieces (+ type 6)))))
         (= (aref checks (+ base 6)) (aref colours 0))
         (= (aref checks (+ base 7)) (aref colours 1))
         ;; A word against a small integer: compared by XOR, which SBCL keeps in a register,
         ;; where = would compile a path that boxes the word.
         (zerop (logxor (aref checks (+ base 8)) (position-check-word bbp))))))

(defun write-check (table slot bbp)
  "Write the independent check of BBP into SLOT of TABLE."
  (declare (type bitboard-transposition-table table) (type fixnum slot)
           (type bitboard-position bbp))
  (let ((checks (tt-checks table))
        (pieces (bbp-pieces bbp))
        (colours (bbp-colour-occupancy bbp))
        (base (* slot +tt-check-words+)))
    (declare (type fixnum base))
    (dotimes (type 6)
      (setf (aref checks (+ base type)) (logior (aref pieces type) (aref pieces (+ type 6)))))
    (setf (aref checks (+ base 6)) (aref colours 0)
          (aref checks (+ base 7)) (aref colours 1)
          (aref checks (+ base 8)) (position-check-word bbp))
    nil))

(declaim (ftype (function (bitboard-transposition-table bitboard-position)
                          (values (integer -1 1073741824) &optional))
                bitboard-tt-probe))

(defun bitboard-tt-probe (table bbp)
  "The slot of TABLE that holds the position BBP, or -1. A slot holds BBP when it is not empty
and its key equals the key of BBP (under the key mask) and, in verification mode, its
independent check describes BBP; a slot whose key matches and whose check does not is a false
hit, counted and skipped. Counts the probe and the hit. Allocates nothing.

Classification: [PROBABILISTIC] in normal mode; [EXACT] in verification mode
Basis: in normal mode a hit is a slot with the same 64-bit key, and two positions that differ
in what the key covers share a key with probability 2^-64 under the model of ADR-0005 (more
often under a narrower key mask): a false hit is possible, and the search guards against its
move (INV-C6, search.lisp). In verification mode a hit also needs the same piece-type
bitboards, colour occupancies, side, castling rights and en-passant square as the key counts
them: the same position for the search's value (TT-3), whatever the key.
Evidence: tests optimized-tt/forced-false-hits-are-discarded-and-counted and
optimized-tt/verification-mode-equals-the-search-without-table
(tests/test-optimized-tt.lisp)."
  (declare (type bitboard-transposition-table table) (type bitboard-position bbp))
  (let* ((key (logand (bbp-key bbp) (tt-key-mask table)))
         (slots (tt-slots table))
         (first-slot (* (logand key (tt-bucket-mask table)) slots))
         (keys (tt-keys table))
         (data (tt-data table)))
    (declare (type (unsigned-byte 64) key) (type fixnum first-slot))
    (incf (tt-probes table))
    (loop for slot of-type fixnum from first-slot below (+ first-slot slots)
          do (when (and (/= 0 (tt-word-bound (aref data slot)))
                        (= (aref keys slot) key))
               (if (or (not (tt-verification table)) (check-matches-p table slot bbp))
                   (progn (incf (tt-hits table))
                          (return slot))
                   (incf (tt-false-hits table))))
          finally (return -1))))

(defun bitboard-tt-store (table bbp depth score bound move)
  "Store in TABLE an entry for the position BBP: DEPTH, SCORE (relative to the node: a mate
score counts its plies from BBP), BOUND (+BITBOARD-TT-EXACT+, +BITBOARD-TT-LOWER+ or
+BITBOARD-TT-UPPER+) and MOVE (+NO-MOVE+ when none). The slot is the one that holds BBP, if
any, else the one the replacement policy chooses; the policy may refuse the store. Allocates
nothing; returns NIL.

Classification: [EXACT] under TT-1...TT-4 (the replacement policy)
Basis: under TT-1, TT-2 and TT-4 an entry states a bound on the value of (position, depth),
true whenever and wherever it is read; keeping or losing one changes the work, not the value
the search returns (INV-C5).
Evidence: tests optimized-tt/verification-mode-equals-the-search-without-table and
optimized-tt/tiny-tables-force-replacement (tests/test-optimized-tt.lisp)."
  (declare (type bitboard-transposition-table table) (type bitboard-position bbp)
           (type (integer 0 127) depth) (type (integer -32768 32767) score)
           (type (integer 1 3) bound) (type move move))
  (let* ((key (logand (bbp-key bbp) (tt-key-mask table)))
         (slots (tt-slots table))
         (first-slot (* (logand key (tt-bucket-mask table)) slots))
         (keys (tt-keys table))
         (data (tt-data table))
         (generation (tt-generation table))
         (verification (tt-verification table))
         (target -1))
    (declare (type (unsigned-byte 64) key) (type fixnum first-slot target))
    ;; The slot that holds the same position, if any.
    (loop for slot of-type fixnum from first-slot below (+ first-slot slots)
          do (when (and (/= 0 (tt-word-bound (aref data slot)))
                        (= (aref keys slot) key)
                        (or (not verification) (check-matches-p table slot bbp)))
               (setf target slot)
               (return)))
    ;; Otherwise the replacement policy.
    (when (< target 0)
      (let ((word (aref data first-slot)))
        (setf target
              (cond ((= (tt-policy-code table) 0) first-slot)
                    ((or (= 0 (tt-word-bound word))
                         (/= (tt-word-generation word) generation)
                         (>= depth (tt-word-depth word)))
                     first-slot)
                    ((= slots 2) (1+ first-slot))
                    (t -1)))
        (when (and (>= target 0) (/= 0 (tt-word-bound (aref data target))))
          (incf (tt-overwrites table)))))
    (if (< target 0)
        (incf (tt-refused-stores table))
        (progn
          (incf (tt-stores table))
          (setf (aref keys target) key
                (aref data target) (pack-tt-word move score depth bound generation))
          (when verification
            (write-check table target bbp))))
    nil))

;;; The hot path of this file ends here. What follows inspects or resets a table for callers
;;; outside it (the search entry points, the tests, the benchmarks).

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-tt-size (table)
  "The number of slots of TABLE."
  (tt-entries table))

(defun bitboard-tt-policy (table)
  "The replacement policy of TABLE."
  (tt-policy table))

(defun bitboard-tt-mode (table)
  "The mode of TABLE: :NORMAL or :VERIFICATION."
  (if (tt-verification table) :verification :normal))

(defun bitboard-tt-reset-statistics (table)
  "Set every statistics counter of TABLE to zero. Returns TABLE."
  (setf (tt-probes table) 0 (tt-hits table) 0 (tt-false-hits table) 0
        (tt-usable-hits table) 0 (tt-cutoffs table) 0 (tt-stores table) 0
        (tt-refused-stores table) 0 (tt-overwrites table) 0 (tt-move-first table) 0
        (tt-rejected-moves table) 0)
  table)

(defun bitboard-tt-clear (table)
  "Empty every slot of TABLE, set its generation and its statistics to zero. Returns TABLE."
  (fill (tt-keys table) 0)
  (fill (tt-data table) 0)
  (fill (tt-checks table) 0)
  (setf (tt-generation table) 0)
  (bitboard-tt-reset-statistics table))

(defun bitboard-tt-new-search (table)
  "Start a new generation in TABLE: the entries stored before are older, and the depth-preferred
slots give way to new entries. Returns the new generation."
  (setf (tt-generation table) (logand (1+ (tt-generation table)) 255)))

(defun bitboard-tt-occupancy (table)
  "The number of slots of TABLE that hold an entry."
  (count-if (lambda (word) (/= 0 (tt-word-bound word))) (tt-data table)))

(defun bitboard-tt-statistics (table)
  "The statistics counters of TABLE as a property list, with its size, policy and mode. It reads
the counters only (the number of occupied slots, which scans the table, is
BITBOARD-TT-OCCUPANCY)."
  (list :entries (tt-entries table) :policy (tt-policy table) :mode (bitboard-tt-mode table)
        :probes (tt-probes table) :hits (tt-hits table) :false-hits (tt-false-hits table)
        :usable-hits (tt-usable-hits table) :cutoffs (tt-cutoffs table)
        :stores (tt-stores table) :refused-stores (tt-refused-stores table)
        :overwrites (tt-overwrites table) :move-first (tt-move-first table)
        :rejected-moves (tt-rejected-moves table)))

(defun bitboard-tt-entry (table bbp)
  "The entry of TABLE for the position BBP as a property list (:MOVE :SCORE :DEPTH :BOUND
:GENERATION), the score relative to the node, or NIL when TABLE holds none. For tests: the
statistics are left as they were."
  (let ((probes (tt-probes table))
        (hits (tt-hits table))
        (false-hits (tt-false-hits table)))
    (let ((slot (bitboard-tt-probe table bbp)))
      (setf (tt-probes table) probes
            (tt-hits table) hits
            (tt-false-hits table) false-hits)
      (when (>= slot 0)
        (let ((word (aref (tt-data table) slot)))
          (list :move (tt-word-move word) :score (tt-word-score word)
                :depth (tt-word-depth word)
                :bound (let ((bound (tt-word-bound word)))
                         (cond ((= bound +bitboard-tt-exact+) :exact)
                               ((= bound +bitboard-tt-lower+) :lower)
                               (t :upper)))
                :generation (tt-word-generation word)))))))
