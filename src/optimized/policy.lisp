;;;; policy.lisp -- how the hot path of the optimized layer is built: its compilation policy,
;;;; the implementation of the slider attacks it uses, and whether perft expands its per-node
;;;; functions inline.
;;;;
;;;; One place says how the files of the hot path are compiled; each of them proclaims it with
;;;; (DECLAIM-OPTIMIZED-POLICY) where its hot part begins. What such a file holds outside the
;;;; hot path (macros, whose expanders run at compile time, and functions that allocate for
;;;; callers outside it) comes before that line or after a closing (declaim (optimize (speed 1)
;;;; (safety 2))), the policy of the layer's other files, and says so. The default build of the
;;;; hot path is (speed 3) (safety 1) (debug 0): SBCL keeps the array bounds checks and a
;;;; weakened check of each declared type, so a wrong index or a false declaration signals an
;;;; error instead of corrupting memory. The checked build, with
;;;; the feature :SCACCHIFORGE-CHECKED ("make test-checked"), compiles the same files at
;;;; (speed 1) (safety 3) (debug 2): every declaration is checked in full. The reasons are in
;;;; docs/adr/0014-policy-di-compilazione-del-livello-ottimizzato.md.
;;;;
;;;; SBCL scopes a DECLAIM OPTIMIZE made inside a file to the compilation of that file, so the
;;;; policy reaches only the files that ask for it.
;;;;
;;;; The slider attacks have three implementations (sliders.lisp). Which one the interface
;;;; BISHOP-ATTACKS / ROOK-ATTACKS uses is fixed when the hot path is compiled, from the
;;;; environment variable SCF_SLIDERS, so choosing one costs nothing at run time and needs no
;;;; edit of the code. The reasons are in
;;;; docs/adr/0016-attacchi-dei-pezzi-a-lunga-gittata.md.
;;;;
;;;; Whether make and unmake keep material, piece-square tables and game phase for the
;;;; evaluation is fixed the same way, from the environment variable SCF_EVAL_STATE:
;;;; "incremental" (the default) or "recompute", which leaves the state out of make and unmake
;;;; and computes it at every evaluation. The two give the same evaluation and the same search;
;;;; they are the variants A and B of research/exp-0002-stato-incrementale-della-valutazione.md.
;;;;
;;;; ASDF does not track these choices: a load that is not forced reuses compiled files built
;;;; with another one, and so does a load forced with :FORCE T, which ASDF applies to the named
;;;; system only and not to this one below it. Each compiled hot-path file therefore checks,
;;;; when it is loaded, that it was compiled with the policy, the slider implementation and the
;;;; evaluation state that the image asks for, and signals an error otherwise
;;;; (CHECK-COMPILED-CHOICE). Every make target that loads the system does so through
;;;; SCF-TOOLS:LOAD-STRICT (tools/load.lisp), which recompiles every system of scacchiforge.asd
;;;; that the load reaches, so the check stops only a load made by hand.

(in-package #:scacchiforge.optimized)

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defparameter *default-policy* '((speed 3) (safety 1) (debug 0))
    "The OPTIMIZE qualities of the hot path in the default build.")
  (defparameter *checked-policy* '((speed 1) (safety 3) (debug 2))
    "The OPTIMIZE qualities of the hot path in the checked build (\"make test-checked\").")
  (defparameter *optimized-policy*
    (if (member :scacchiforge-checked *features*) *checked-policy* *default-policy*)
    "The OPTIMIZE qualities the hot-path files of the optimized layer are compiled with: the
checked policy when the feature :SCACCHIFORGE-CHECKED is present, the default one otherwise.
It is computed again whenever this file is loaded, so that a hot-path file compiled with
another policy refuses to load (CHECK-COMPILED-CHOICE). The build and the bench environment
record print it.")
  (defvar *show-efficiency-notes* nil
    "When true while a hot-path file is compiled, SBCL's efficiency notes are printed instead
of muffled. tools/hot-path.lisp binds it to read them.")
  (defparameter *inline-node-functions* t
    "When true while perft.lisp is compiled, PERFT-NODE expands the legal-move generation
(BITBOARD-GENERATE-PSEUDO-LEGAL and the legality filter), BITBOARD-MAKE-MOVE and
BITBOARD-UNMAKE-MOVE inline; when false it calls BITBOARD-GENERATE-LEGAL, BITBOARD-MAKE-MOVE and
BITBOARD-UNMAKE-MOVE. Every other caller calls them. The build leaves it true;
tools/hot-path.lisp binds it to NIL while it compiles the hot path for one more timed variant,
so that \"make hot-path\" shows what the calls cost.")
  (defparameter *hot-path-files* '("rays" "sliders" "attacks" "make" "movegen" "legal" "perft"
                                   "evaluation" "search")
    "The files of src/optimized/ that proclaim the layer's policy, in load order. A tool that
recompiles the hot path with another policy or another slider implementation (make hot-path,
make bench) compiles these, in this order.")
  (defparameter *slider-implementations* '(:fixed-magic :magic :ray)
    "The implementations of the slider attacks (sliders.lisp), the default first: :FIXED-MAGIC,
magic bitboards with one shift per kind of piece; :MAGIC, magic bitboards with a shift per
square; :RAY, classical ray attacks with a blocker scan. The default was chosen by measurement
(make bench) on one machine; ADR-0016 records the measurement and when to repeat it.")
  (defun parse-slider-implementation (text)
    "The slider implementation named by TEXT, the value of SCF_SLIDERS: \"fixed-magic\",
\"magic\" or \"ray\", in any case. NIL or an empty string gives the default, the first
of *SLIDER-IMPLEMENTATIONS*. Any other text signals an error, so that a misspelt name never
builds the default silently."
    (if (or (null text) (string= text ""))
        (first *slider-implementations*)
        (or (find text *slider-implementations* :test #'string-equal)
            (error "SCF_SLIDERS is ~S; it must be one of~{ ~(~A~)~^,~}, or unset"
                   text *slider-implementations*))))
  (defparameter *slider-implementation*
    (parse-slider-implementation (sb-ext:posix-getenv "SCF_SLIDERS"))
    "The implementation the slider interface of sliders.lisp is compiled with, read from the
environment variable SCF_SLIDERS when this file is loaded. A tool may bind it while it
recompiles the hot path (make bench does, to time each implementation).")
  (defparameter *evaluation-states* '(:incremental :recompute)
    "How the optimized layer obtains material, piece-square tables and game phase for the
evaluation, the default first: :INCREMENTAL, kept by make and unmake and read by
BITBOARD-EVALUATE (variant A of EXP-0002); :RECOMPUTE, left out of make and unmake and computed
from the piece bitboards at every evaluation (variant B, the baseline of EXP-0002). The two
give the same evaluation and the same search.")
  (defun parse-evaluation-state (text)
    "The evaluation state named by TEXT, the value of SCF_EVAL_STATE: \"incremental\" or
\"recompute\", in any case. NIL or an empty string gives the default, the first of
*EVALUATION-STATES*. Any other text signals an error."
    (if (or (null text) (string= text ""))
        (first *evaluation-states*)
        (or (find text *evaluation-states* :test #'string-equal)
            (error "SCF_EVAL_STATE is ~S; it must be one of~{ ~(~A~)~^,~}, or unset"
                   text *evaluation-states*))))
  (defparameter *evaluation-state*
    (parse-evaluation-state (sb-ext:posix-getenv "SCF_EVAL_STATE"))
    "The evaluation state the hot path is compiled with, read from the environment variable
SCF_EVAL_STATE when this file is loaded. A tool may bind it while it recompiles the hot path
(make bench does, to time each variant)."))

(defun check-compiled-choice (choice compiled requested)
  "Signal an error unless COMPILED, the value of CHOICE (a string naming it) fixed when a file
of the hot path was compiled, equals REQUESTED, the value that this image asks for while the
file is loaded. Return NIL.

The slider implementation (SCF_SLIDERS) and the policy (the feature :SCACCHIFORGE-CHECKED) are
fixed when the hot path is compiled, and ASDF does not know about them: a load that is not
forced reuses compiled files built with another choice, and so does (asdf:load-system
\"scacchiforge/test\" :force t), since :FORCE T recompiles the named system only. The hot-path
files call this when they are loaded, so that such a load stops with this error instead of
running code that does not match *SLIDER-IMPLEMENTATION* or *OPTIMIZED-POLICY*. Every make
target that loads the system calls SCF-TOOLS:LOAD-STRICT (tools/load.lisp), which recompiles
every system of scacchiforge.asd that the load reaches, and so never meets it."
  (unless (equal compiled requested)
    (flet ((text (value)
             (let ((*print-pretty* nil))
               (prin1-to-string value))))
      (error "The hot path of the optimized layer was compiled with the ~A ~A, but this image ~
              asks for ~A. ASDF does not notice this choice. Compile the systems again as every ~
              make target does: (load \"tools/load.lisp\") and (scf-tools:load-strict SYSTEM), ~
              which recompiles every system of scacchiforge.asd that SYSTEM needs. ~
              (asdf:load-system SYSTEM :force t) is not enough unless SYSTEM is \"scacchiforge\": ~
              it recompiles the named system only."
             choice (text compiled) (text requested))))
  nil)

(defmacro when-incremental-evaluation (&body body)
  "BODY when the hot path is compiled with the incremental evaluation state (*EVALUATION-STATE*
is :INCREMENTAL), nothing otherwise. Make and unmake wrap in it every read and write of the
evaluation state, so that the :RECOMPUTE build does not touch the state."
  (when (eq *evaluation-state* :incremental)
    `(progn ,@body)))

(defmacro if-incremental-evaluation (incremental recompute)
  "INCREMENTAL when the hot path is compiled with the incremental evaluation state, RECOMPUTE
otherwise."
  (if (eq *evaluation-state* :incremental) incremental recompute))

(defmacro compiled-evaluation-state ()
  "The evaluation state the file being compiled is compiled with, as a constant."
  `',*evaluation-state*)

(defmacro declaim-optimized-policy ()
  "Proclaim *OPTIMIZED-POLICY* for the rest of the file being compiled. SBCL's efficiency
notes are muffled there unless *SHOW-EFFICIENCY-NOTES* is true: \"make hot-path\" prints them
with the disassembly and the bytes consed of the hot path. When the compiled file is loaded,
CHECK-COMPILED-CHOICE compares the policy it was compiled with and *OPTIMIZED-POLICY*, and the
evaluation state it was compiled with and *EVALUATION-STATE*."
  `(progn
     (declaim (optimize ,@*optimized-policy*))
     ,@(unless *show-efficiency-notes*
         '((declaim (sb-ext:muffle-conditions sb-ext:compiler-note))))
     (check-compiled-choice "compilation policy" ',*optimized-policy* *optimized-policy*)
     (check-compiled-choice "evaluation state" ',*evaluation-state* *evaluation-state*)))
