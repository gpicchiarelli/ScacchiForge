;;;; zobrist.lisp -- Zobrist key tables, generated from a fixed seed.
;;;;
;;;; The keys come from splitmix64 with a fixed seed (see prng.lisp), so a given source
;;;; revision produces the same keys on every run and every platform. SXHASH is not used:
;;;; it is not reproducible across runs and platforms.
;;;;
;;;; A position key is the XOR of:
;;;;   - one piece key for every piece on the board,
;;;;   - the side key when Black is to move,
;;;;   - the castling key of the current castling-rights set,
;;;;   - the en-passant file key, ONLY when an en-passant capture is available.
;;;;
;;;; En-passant policy: the file key is included only when a pawn of the side to move
;;;; attacks the en-passant square (pseudo-legal availability; pins are NOT considered, so
;;;; the key stays a pure function of the board layout). Two positions that differ only by
;;;; an en-passant square nobody can use therefore have equal keys, which is what makes
;;;; transpositions reach equal keys. The FEN en-passant field is kept as written; only
;;;; the key ignores an unusable square.
;;;;
;;;; [PROBABILISTIC] Equal keys do not prove equal positions: two different positions can
;;;; collide. Nothing in the reference layer relies on key equality for correctness.

(in-package #:scacchiforge.core)

(defconstant +zobrist-seed+ #x5363616363686946
  "ASCII \"ScacchiF\": the fixed seed of the key tables.")

;; DEFGLOBAL only evaluates the initial value when the variable is not bound yet, so
;; loading the system twice in one image is safe; REGENERATE-ZOBRIST-KEYS refills the
;; tables from the seed and gives the same values every time.
(sb-ext:defglobal **zobrist-pieces**
    (make-array 768 :element-type '(unsigned-byte 64) :initial-element 0))
(sb-ext:defglobal **zobrist-castling**
    (make-array 16 :element-type '(unsigned-byte 64) :initial-element 0))
(sb-ext:defglobal **zobrist-ep-files**
    (make-array 8 :element-type '(unsigned-byte 64) :initial-element 0))
(sb-ext:defglobal **zobrist-side** 0)

(declaim (type (simple-array (unsigned-byte 64) (768)) **zobrist-pieces**)
         (type (simple-array (unsigned-byte 64) (16)) **zobrist-castling**)
         (type (simple-array (unsigned-byte 64) (8)) **zobrist-ep-files**)
         (type (unsigned-byte 64) **zobrist-side**))

(defun regenerate-zobrist-keys ()
  "Fill the key tables from +ZOBRIST-SEED+. Idempotent. Returns the number of base keys."
  (let ((rng (make-rng +zobrist-seed+)))
    (dotimes (i 768)
      (setf (aref **zobrist-pieces** i) (rng-next-u64 rng)))
    (setf **zobrist-side** (rng-next-u64 rng))
    (let ((base (list (rng-next-u64 rng) (rng-next-u64 rng)
                      (rng-next-u64 rng) (rng-next-u64 rng))))
      (dotimes (rights 16)
        (let ((key 0))
          (dotimes (bit 4)
            (when (logbitp bit rights)
              (setf key (logxor key (nth bit base)))))
          (setf (aref **zobrist-castling** rights) key))))
    (dotimes (file 8)
      (setf (aref **zobrist-ep-files** file) (rng-next-u64 rng))))
  781)

(regenerate-zobrist-keys)

(declaim (inline zobrist-piece-key zobrist-side-key zobrist-castling-key
                 zobrist-en-passant-key))

(defun zobrist-piece-key (piece square)
  "Key of PIECE (a non-empty piece code) standing on SQUARE."
  (declare (type piece piece) (type square square))
  (aref **zobrist-pieces** (+ (* 64 (piece-index piece)) square)))

(defun zobrist-side-key ()
  "Key XORed into the position key when Black is to move."
  **zobrist-side**)

(defun zobrist-castling-key (rights)
  "Key of the castling-rights set RIGHTS (0..15): the XOR of one key per right."
  (declare (type (integer 0 15) rights))
  (aref **zobrist-castling** rights))

(defun zobrist-en-passant-key (file)
  "Key of an available en-passant capture on FILE (0..7). See the policy above."
  (declare (type (integer 0 7) file))
  (aref **zobrist-ep-files** file))

(defun zobrist-key-table-snapshot ()
  "A fresh list of the 781 base keys: 768 piece-square, side, 4 castling, 8 en-passant."
  (append (coerce **zobrist-pieces** 'list)
          (list **zobrist-side**)
          (loop for bit in '(1 2 4 8) collect (aref **zobrist-castling** bit))
          (coerce **zobrist-ep-files** 'list)))
