;;;; sliders.lisp -- attacks of the sliding pieces: the one interface the rest of the layer uses,
;;;; and the magic-bitboard lookups behind it.
;;;;
;;;;   (BISHOP-ATTACKS square occupancy)  (ROOK-ATTACKS square occupancy)
;;;;   (QUEEN-ATTACKS square occupancy)
;;;;
;;;; Each returns the squares a piece of that kind on SQUARE attacks when the occupied squares
;;;; are OCCUPANCY: along each ray, every square up to and including the first occupied one.
;;;; The colour of the blocker does not matter here; the caller removes its own pieces.
;;;;
;;;; Three implementations compute the same sets:
;;;;
;;;;   :FIXED-MAGIC  magic bitboards with one shift per kind of piece (FIXED-MAGIC-...-ATTACKS);
;;;;   :MAGIC        magic bitboards with a shift and an offset per square (MAGIC-...-ATTACKS);
;;;;   :RAY          classical ray attacks with a blocker scan (RAY-...-ATTACKS, rays.lisp).
;;;;
;;;; The tables of the two magic layouts are built in magic.lisp. The interface calls the
;;;; implementation named by *SLIDER-IMPLEMENTATION* (policy.lisp) when this file is compiled,
;;;; that is the value of the environment variable SCF_SLIDERS at build time, :FIXED-MAGIC when
;;;; it is unset. Everything is inline, so the choice costs nothing at run time; the callers
;;;; (few: movegen.lisp, attacks.lisp, legal.lisp) are compiled after this file and take the
;;;; chosen body. The three implementations are always compiled and their tables always built,
;;;; so the tests compare all of them and make bench times all of them. Why :FIXED-MAGIC is the
;;;; default, and on which measurement, is ADR-0016.

(in-package #:scacchiforge.optimized)

;;; The macro that writes the interface is not on the hot path: its expander is compiled with
;;; the policy of the layer's files outside the hot path. The hot path starts after it.

(declaim (optimize (speed 1) (safety 2)))

(defmacro define-slider-interface ()
  "Define BISHOP-ATTACKS and ROOK-ATTACKS as calls of the implementation named by
*SLIDER-IMPLEMENTATION* at macroexpansion time, and SLIDER-INTERFACE-IMPLEMENTATION to report
it. The DEFUNs come out at top level, so their inline expansions are the chosen bodies. When the
compiled file is loaded, CHECK-COMPILED-CHOICE (policy.lisp) compares the implementation it was
compiled with and *SLIDER-IMPLEMENTATION*: a load of files compiled with another SCF_SLIDERS
stops with an error."
  (let ((implementation *slider-implementation*))
    (destructuring-bind (bishop rook)
        (ecase implementation
          (:magic '(magic-bishop-attacks magic-rook-attacks))
          (:fixed-magic '(fixed-magic-bishop-attacks fixed-magic-rook-attacks))
          (:ray '(ray-bishop-attacks ray-rook-attacks)))
      `(progn
         (defun bishop-attacks (square occupancy)
           "The squares a bishop on SQUARE attacks when OCCUPANCY is the set of occupied
squares, by the implementation chosen when the hot path was compiled
(SLIDER-INTERFACE-IMPLEMENTATION).

Classification: [EXACT] (each implementation is; see its docstring)
Basis: the three implementations compute the same set for every square and occupancy.
Evidence: tests slider-attacks-match-a-naive-walk,
every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy and
slider-implementations-agree-on-random-occupancies (tests/test-optimized.lisp), and perft
(tests/test-optimized-perft.lisp)."
           (declare (type square square) (type bitboard occupancy))
           (,bishop square occupancy))
         (defun rook-attacks (square occupancy)
           "The squares a rook on SQUARE attacks when OCCUPANCY is the set of occupied squares,
by the implementation chosen when the hot path was compiled (SLIDER-INTERFACE-IMPLEMENTATION).

Classification: [EXACT] (each implementation is; see its docstring)
Basis: as for BISHOP-ATTACKS.
Evidence: as for BISHOP-ATTACKS."
           (declare (type square square) (type bitboard occupancy))
           (,rook square occupancy))
         (defun slider-interface-implementation ()
           "The slider implementation BISHOP-ATTACKS and ROOK-ATTACKS were compiled with:
:MAGIC, :FIXED-MAGIC or :RAY."
           ,implementation)
         (check-compiled-choice "slider implementation" ,implementation
                                *slider-implementation*)))))

(declaim-optimized-policy)

(declaim (inline magic-slot-attacks magic-bishop-attacks magic-rook-attacks
                 fixed-magic-bishop-attacks fixed-magic-rook-attacks
                 bishop-attacks rook-attacks queen-attacks))

(defun magic-slot-attacks (slot occupancy)
  "The attacks of the slider of SLOT (a rook square, or 64 + a bishop square) when OCCUPANCY
is the set of occupied squares, from the :MAGIC tables of magic.lisp. The declared ranges of
the shift and the offset are those INITIALISE-MAGIC-TABLES writes; the policy of the hot path
checks them, and the bounds check of the table guards the read."
  (declare (type (integer 0 127) slot) (type bitboard occupancy))
  (let* ((entries **magic-entries**)
         (base (* 4 slot))
         (shift (aref entries (+ base 2)))
         (offset (aref entries (+ base 3))))
    (declare (type (integer 52 59) shift) (type (integer 0 107647) offset))
    (aref **magic-attacks**
          (+ offset (ash (ldb (byte 64 0) (* (logand occupancy (aref entries base))
                                             (aref entries (+ base 1))))
                         (- shift))))))

(defun magic-bishop-attacks (square occupancy)
  "The squares a bishop on SQUARE attacks when OCCUPANCY is the set of occupied squares, by a
magic-bitboard lookup with a shift per square.

Classification: [EXACT] (magic-bitboard lookup)
Basis: the table entry at the magic index of the relevant occupancy is the ray attack of that
occupancy (INITIALISE-MAGIC-TABLES, magic.lisp), and squares outside the relevant ones do not
change the attacks.
Evidence: tests every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy
and slider-implementations-agree-on-random-occupancies (tests/test-optimized.lisp)."
  (declare (type square square) (type bitboard occupancy))
  (magic-slot-attacks (+ 64 square) occupancy))

(defun magic-rook-attacks (square occupancy)
  "The squares a rook on SQUARE attacks when OCCUPANCY is the set of occupied squares, by a
magic-bitboard lookup with a shift per square.

Classification: [EXACT] (magic-bitboard lookup)
Basis: as for MAGIC-BISHOP-ATTACKS.
Evidence: as for MAGIC-BISHOP-ATTACKS."
  (declare (type square square) (type bitboard occupancy))
  (magic-slot-attacks square occupancy))

(defun fixed-magic-bishop-attacks (square occupancy)
  "The squares a bishop on SQUARE attacks when OCCUPANCY is the set of occupied squares, by a
magic-bitboard lookup with 9 index bits on every square: the shift is a constant and the
offset is computed from the square.

Classification: [EXACT] (magic-bitboard lookup)
Basis: as for MAGIC-BISHOP-ATTACKS.
Evidence: as for MAGIC-BISHOP-ATTACKS."
  (declare (type square square) (type bitboard occupancy))
  (let ((entries **fixed-magic-entries**)
        (base (* 2 (+ 64 square))))
    (aref **fixed-magic-attacks**
          (+ +fixed-magic-bishop-base+
             (ash square 9)
             (ash (ldb (byte 64 0) (* (logand occupancy (aref entries base))
                                      (aref entries (+ base 1))))
                  -55)))))

(defun fixed-magic-rook-attacks (square occupancy)
  "The squares a rook on SQUARE attacks when OCCUPANCY is the set of occupied squares, by a
magic-bitboard lookup with 12 index bits on every square: the shift is a constant and the
offset is computed from the square.

Classification: [EXACT] (magic-bitboard lookup)
Basis: as for MAGIC-BISHOP-ATTACKS.
Evidence: as for MAGIC-BISHOP-ATTACKS."
  (declare (type square square) (type bitboard occupancy))
  (let ((entries **fixed-magic-entries**)
        (base (* 2 square)))
    (aref **fixed-magic-attacks**
          (+ (ash square 12)
             (ash (ldb (byte 64 0) (* (logand occupancy (aref entries base))
                                      (aref entries (+ base 1))))
                  -52)))))

(define-slider-interface)

(defun queen-attacks (square occupancy)
  "The squares a queen on SQUARE attacks when OCCUPANCY is the set of occupied squares."
  (declare (type square square) (type bitboard occupancy))
  (logior (bishop-attacks square occupancy) (rook-attacks square occupancy)))
