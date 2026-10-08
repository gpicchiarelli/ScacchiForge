;;;; support.lisp -- helpers shared by the test suites.

(in-package #:scacchiforge.test)

(defun fen-position (fen)
  "The reference position for FEN."
  (scf-ref:parse-fen fen))

(defun move-strings (moves)
  "The long algebraic text of each move of MOVES."
  (mapcar #'move-to-string moves))

;;; --- the layer under test ---------------------------------------------------------------
;;;
;;; The special-case suite of tests/test-movegen.lisp runs twice, once on each layer
;;; (DEFTEST-MOVEGEN). Its helpers below take a position of either layer and call that
;;; layer's own functions: a reference position goes to the reference model, a bitboard
;;; position to the optimized layer. *LAYER* only decides which kind of position a FEN
;;; becomes. The optimized layer has no FEN code of its own (ADR-0010): a FEN is parsed by the
;;; reference and converted, and a FEN is written from the converted-back position.

(defvar *layer* :reference
  "The layer whose positions LAYER-POSITION builds: :REFERENCE or :OPTIMIZED.")

(defun layer-from-reference (pos)
  "The reference position POS as a position of the layer *LAYER*."
  (ecase *layer*
    (:reference pos)
    (:optimized (scf-opt:bitboard-from-reference pos))))

(defun layer-position (fen)
  "A position of the layer *LAYER* for FEN."
  (layer-from-reference (fen-position fen)))

(defmacro layer-case (pos reference optimized)
  "Evaluate REFERENCE when POS is a reference position, OPTIMIZED when it is a bitboard one."
  `(etypecase ,pos
     (scf-ref:chess-position ,reference)
     (scf-opt:bitboard-position ,optimized)))

(defun layer-legal-moves (pos)
  "The legal moves of POS, computed by the layer POS belongs to."
  (layer-case pos (scf-ref:legal-moves pos) (scf-opt:bitboard-legal-moves pos)))

(defun layer-pseudo-legal-moves (pos)
  "The pseudo-legal moves of POS, computed by the layer POS belongs to."
  (layer-case pos (scf-ref:pseudo-legal-moves pos) (scf-opt:bitboard-pseudo-legal-moves pos)))

(defun layer-legal-move-count (pos)
  "The number of legal moves of POS."
  (layer-case pos (scf-ref:legal-move-count pos) (length (scf-opt:bitboard-legal-moves pos))))

(defun layer-in-check-p (pos)
  "True when the side to move of POS is in check."
  (layer-case pos (scf-ref:in-check-p pos) (scf-opt:bitboard-in-check-p pos)))

(defun layer-game-outcome (pos)
  "NIL when the side to move of POS has a legal move, else :CHECKMATE or :STALEMATE. For a
bitboard position it is worked out here from the optimized layer's legal moves and check."
  (layer-case pos
              (scf-ref:game-outcome pos)
              (cond ((scf-opt:bitboard-legal-moves pos) nil)
                    ((scf-opt:bitboard-in-check-p pos) :checkmate)
                    (t :stalemate))))

(defun layer-checkmate-p (pos)
  "True when the side to move of POS is checkmated."
  (layer-case pos (scf-ref:checkmate-p pos) (eq (layer-game-outcome pos) :checkmate)))

(defun layer-stalemate-p (pos)
  "True when the side to move of POS is stalemated."
  (layer-case pos (scf-ref:stalemate-p pos) (eq (layer-game-outcome pos) :stalemate)))

(defun layer-parse-move (pos text)
  "The legal move of POS written TEXT in long algebraic form, or NIL."
  (layer-case pos
              (scf-ref:parse-move pos text)
              (find text (scf-opt:bitboard-legal-moves pos) :key #'move-to-string
                                                            :test #'string=)))

(defun layer-make-move (pos move)
  "Play MOVE on POS with the make of the layer POS belongs to."
  (layer-case pos (scf-ref:make-move pos move) (scf-opt:bitboard-make-move pos move)))

(defun layer-en-passant (pos)
  "The en-passant square of POS."
  (layer-case pos (scf-ref:pos-en-passant pos) (scf-opt:bbp-en-passant pos)))

(defun layer-piece-at (pos square)
  "The piece code on SQUARE of POS."
  (layer-case pos (scf-ref:piece-at pos square) (aref (scf-opt:bbp-board pos) square)))

(defun layer-fen (pos)
  "The FEN of POS; a bitboard position is converted back to the reference to be written."
  (layer-case pos
              (scf-ref:position-to-fen pos)
              (scf-ref:position-to-fen (scf-opt:bitboard-to-reference pos))))

(defun layer-breakdown (pos)
  "The classical evaluation of POS term by term (the breakdown property list), computed by the
layer POS belongs to."
  (layer-case pos (scf-ref:classical-breakdown pos) (scf-opt:bitboard-classical-breakdown pos)))

(defun layer-evaluate (pos)
  "The classical evaluation of POS from the side to move, computed by the layer POS belongs to:
for a bitboard position the evaluation the search calls, with the incremental state."
  (layer-case pos (scf-ref:evaluate-classical pos) (scf-opt:bitboard-evaluate pos)))

(defun layer-mirror (pos)
  "The colour swap of POS, computed by the layer POS belongs to."
  (layer-case pos (scf-ref:mirror-position pos) (scf-opt:bitboard-mirror pos)))

(defun incremental-evaluation-state-p ()
  "True when the optimized layer is compiled with the incremental evaluation state (the default,
variant A of research/exp-0002-stato-incrementale-della-valutazione.md); false in the build with
SCF_EVAL_STATE=recompute (variant B), where make and unmake do not keep the state, so the tests
of the state do not apply. The evaluations and the searches are tested in both builds."
  (eq (scf-opt::evaluation-state-implementation) :incremental))

(defmacro deftest-evaluation (name &body body)
  "Define the test NAME twice with the same BODY: in suite :EVALUATION on the reference model
and in suite :OPTIMIZED-EVALUATION on the optimized layer, with *LAYER* bound to each."
  `(progn
     (deftest :evaluation ,name
       (let ((*layer* :reference)) ,@body))
     (deftest :optimized-evaluation ,name
       (let ((*layer* :optimized)) ,@body))))

(defmacro deftest-movegen (name &body body)
  "Define the test NAME twice with the same BODY: in suite :MOVEGEN on the reference model and
in suite :OPTIMIZED-MOVEGEN on the optimized layer, with *LAYER* bound to each."
  `(progn
     (deftest :movegen ,name
       (let ((*layer* :reference)) ,@body))
     (deftest :optimized-movegen ,name
       (let ((*layer* :optimized)) ,@body))))

;;; --- moves by name ----------------------------------------------------------------------

(defun legal-strings (position-or-fen)
  "The legal moves of a position (or of a FEN, read as a position of the layer *LAYER*), as
long algebraic strings."
  (let ((pos (if (stringp position-or-fen) (layer-position position-or-fen) position-or-fen)))
    (move-strings (layer-legal-moves pos))))

(defun play (pos &rest texts)
  "Make each move TEXT on POS; signal an error if one of them is not legal. Return POS."
  (dolist (text texts pos)
    (let ((move (layer-parse-move pos text)))
      (unless move
        (error "~A is not legal in ~A" text (layer-fen pos)))
      (layer-make-move pos move))))

(defun fen-after (fen &rest texts)
  "The FEN reached from FEN after playing the moves TEXTS (on the layer *LAYER*)."
  (layer-fen (apply #'play (layer-position fen) texts)))

(defun square-of (name)
  "The square index of the algebraic NAME; an error if NAME is not a square."
  (or (parse-square name) (error "bad square ~S" name)))

(defparameter *fuzz-fens*
  (append (mapcar #'cdr scf-ref:*standard-positions*)
          '("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
            "8/P1k5/K7/8/8/8/8/8 w - - 0 1"
            "3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1"
            "4k3/pppppppp/8/8/8/8/PPPPPPPP/4K3 w - - 0 1"))
  "Start positions of the random playouts: the start position, the perft positions and a few
special ones, among them a position full of pawn contacts that produces en-passant chances.")
