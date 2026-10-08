;;;; evaluation-tables.lisp -- the parameters and the precomputed tables of the classical
;;;; evaluation in the optimized layer, and the from-scratch computation of its incremental state.
;;;;
;;;; The definition is docs/valutazione.md (ADR-0018, in state Proposta). This layer reads it on
;;;; its own (ADR-0010, points 3 and 4): the parameters below are this layer's copy, named as in
;;;; the "Riepilogo dei parametri" of the document, and every table is generated here, once at
;;;; load time, from the formulas of the document. The reference model has its own parameters,
;;;; its own geometry and its own code (src/reference/classical.lisp); the tests compare the two
;;;; layers term by term and colour by colour, so a parameter or a table entry that differs
;;;; between them shows as a difference (tests/test-optimized-evaluation.lisp and the suite
;;;; differential). Why each layer keeps its own copy is ADR-0019 (Proposta).
;;;;
;;;; The incremental state (docs/valutazione.md, "Stato incrementale") is three integers that
;;;; make and unmake keep up to date (make.lisp): PSQ-MG and PSQ-EG, the sum over the pieces of
;;;; sigma(c) * (V(t) + pst(t, s')), White's material and piece-square values minus Black's, in
;;;; the middlegame and in the endgame, and PHASE-RAW, the phase before the cap of 62. Make adds
;;;; and subtracts entries of the signed tables **PSQ-MG** and **PSQ-EG**; the from-scratch
;;;; computation below sums the unsigned tables **PST-MG** and **PST-EG** and the piece values
;;;; per colour instead, so that the two do not share a table.
;;;;
;;;; This file is not on the hot path: it is compiled with the policy of the layer's files outside
;;;; it. Its inline functions, where the hot path calls them, are compiled with the hot path's
;;;; policy (src/optimized/policy.lisp).

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

;;; --- parameters ("Riepilogo dei parametri") -------------------------------------------------
;;;
;;; A vector indexed by piece type (1 = pawn ... 6 = king) holds 0 for the types its parameter
;;; does not concern. Each value carries the rule it comes from in the document.

(defmacro define-type-vector (name contents documentation)
  "Define the global NAME as a vector of the 7 CONTENTS, (SIGNED-BYTE 16) integers indexed by
piece type."
  `(progn
     (sb-ext:defglobal ,name
         (make-array 7 :element-type '(signed-byte 16) :initial-contents ',contents)
       ,documentation)
     (declaim (type (simple-array (signed-byte 16) (7)) ,name))))

(define-type-vector **piece-values** (0 100 300 300 500 900 0)
  "V(t): pawn 100, knight 300, bishop 300, rook 500, queen 900, king 0 (\"Notazione\"), the
conventional values the reference model also uses.")

(defconstant +phase-max+ 62
  "The phase of the start position: the non-pawn material of both sides in pawn units, 2 * (3
+ 3 + 3 + 3 + 5 + 5 + 9) (\"Fase della partita\").")

(define-type-vector **phase-weights-by-type** (0 0 3 3 5 9 0)
  "Phase weight of each piece type: the piece value divided by 100 for knight, bishop, rook and
queen; pawns and kings weigh 0 (\"Fase della partita\").")

(defconstant +pawn-advance-mg+ 3 "Pawn table, mg: per rank advanced and per central file.")
(defconstant +pawn-advance-eg+ 6 "Pawn table, eg: per rank advanced.")

(define-type-vector **centre-weights-mg** (0 0 8 4 0 2 0)
  "Multiplier of the centrality in the mg tables: knight 8, bishop 4, queen 2.")

(define-type-vector **centre-weights-eg** (0 0 8 4 0 4 8)
  "Multiplier of the centrality in the eg tables: knight 8, bishop 4, queen 4, king 8.")

(defconstant +rook-seventh+ 20 "Rook on the relative seventh rank, mg and eg.")
(defconstant +king-flank+ 6 "King table, mg: per step of file distance from the centre, up to 2.")
(defconstant +king-rank+ 10 "King table, mg: per rank away from the own first rank.")

(define-type-vector **mobility-base** (0 0 4 6 7 13 0)
  "The mobility that scores 0: floor(M / 2), where M is the most squares the piece attacks on
an empty board, knight 8, bishop 13, rook 14, queen 27 (\"Mobilità\").")

(define-type-vector **mobility-weights-mg** (0 0 4 2 2 1 0)
  "The value of one square of mobility in the middlegame: round(30 / M).")

(define-type-vector **mobility-weights-eg** (0 0 5 3 3 1 0)
  "The value of one square of mobility in the endgame: round(40 / M).")

(define-type-vector **king-attack-units** (0 0 2 2 3 5 0)
  "Units of attack per square of the enemy king zone hit: the piece value divided by 200 and
rounded up; pawns and kings do not attack the king zone (\"Sicurezza del re\").")

(defconstant +king-attack-scale+ 4 "Scale of the king attack: 4 * U * max(n - 1, 0).")
(defconstant +king-attack-cap+ 400 "Largest king attack: four pawns.")
(defconstant +shelter-step+ 10 "Shelter: the cost of one rank between the king and its pawn.")
(defconstant +shelter-max+ 3 "Shelter: the distance counted for a file without shelter.")
(defconstant +doubled-pawn-mg+ 6 "Doubled pawn, mg: one missing support, floor(100 / 16).")
(defconstant +doubled-pawn-eg+ 9 "Doubled pawn, eg: one missing support, floor(3 * 100 / 32).")
(defconstant +isolated-pawn-mg+ 12 "Isolated pawn, mg: two missing supports.")
(defconstant +isolated-pawn-eg+ 18 "Isolated pawn, eg: two missing supports.")
(defconstant +backward-pawn-mg+ 6 "Backward pawn, mg: one missing support.")
(defconstant +backward-pawn-eg+ 9 "Backward pawn, eg: one missing support.")
(defconstant +passed-pawn-mg+ 5 "Passed pawn, mg: per unit of the triangular number T(rr - 1).")
(defconstant +passed-pawn-eg+ 10 "Passed pawn, eg: per unit of the triangular number T(rr - 1).")
(defconstant +space-square+ 2 "Space, mg: per square.")
(defconstant +tempo+ 10 "Initiative: the value of having the move, mg and eg.")
(defconstant +threat-gain-divisor+ 10 "Threats: divisor of the material a capture would gain.")
(defconstant +threat-hanging-divisor+ 20 "Threats: divisor of the value of a hanging piece.")

(defun check-exact-threat-divisions ()
  "Signal an error unless both divisions of the threat term are exact for the piece values of
**PIECE-VALUES**, as \"Divisioni\" and \"Minacce\" of docs/valutazione.md require: (v - a) / 10
for every two pieces other than the king, of values a < v, and v / 20 for each of them. These
five values are every operand the term can meet, so the check is complete; it runs when this
file is loaded, and THREATS (evaluation.lisp) then divides with TRUNCATE, which on these
operands is the exact quotient. A change of a parameter that breaks the exactness stops the
load here, as the reference's EXACT-QUOTIENT stops its evaluation, instead of truncating."
  (loop for target from +pawn+ to +queen+
        for value = (aref **piece-values** target)
        do (unless (zerop (rem value +threat-hanging-divisor+))
             (error "Threats: V(~D) / ~D = ~D / ~D is not exact (docs/valutazione.md, Minacce)"
                    target +threat-hanging-divisor+ value +threat-hanging-divisor+))
           (loop for attacker from +pawn+ to +queen+
                 for cheaper = (aref **piece-values** attacker)
                 do (when (and (< cheaper value)
                               (not (zerop (rem (- value cheaper) +threat-gain-divisor+))))
                      (error "Threats: (V(~D) - V(~D)) / ~D = ~D / ~D is not exact ~
                              (docs/valutazione.md, Minacce)"
                             target attacker +threat-gain-divisor+ (- value cheaper)
                             +threat-gain-divisor+))))
  t)

(check-exact-threat-divisions)
(defconstant +evaluation-limit+ 20000
  "The largest magnitude of the score from White's point of view (INV-C9, \"Limite del
punteggio\").")

;;; --- geometry ("Notazione"), used while the tables are built --------------------------------

(defun colour-relative-rank (colour square)
  "The rank of SQUARE seen by COLOUR: 0 is COLOUR's own first rank."
  (declare (type colour colour) (type square square))
  (if (= colour +white+) (square-rank square) (- 7 (square-rank square))))

(defun distance-from-centre (x)
  "dc(x) = max(3 - x, x - 4) for a file or a rank X: 3 2 1 0 0 1 2 3."
  (declare (type (integer 0 7) x))
  (max (- 3 x) (- x 4)))

(defun square-centrality (square)
  "cent(s) = 3 - dc(file) - dc(rank), from -3 in the corners to 3 on d4, e4, d5 and e5. It does
not change when the board is reflected, so it is the same on a square and on its relative
square."
  (declare (type square square))
  (- 3 (distance-from-centre (square-file square)) (distance-from-centre (square-rank square))))

(defun table-entry (type relative-square)
  "pst_mg and pst_eg (two values) of a piece of TYPE whose relative square, the square seen by
its owner, is RELATIVE-SQUARE (\"Piece-square tables\")."
  (declare (type (integer 1 6) type) (type square relative-square))
  (let ((file (square-file relative-square))
        (rank (square-rank relative-square))
        (centre (square-centrality relative-square)))
    (cond ((= type +pawn+)
           ;; The formulas hold for relative ranks 1 to 6; ranks 0 and 7 hold no pawn.
           (if (<= 1 rank 6)
               (values (* +pawn-advance-mg+ (1- rank) (- 3 (distance-from-centre file)))
                       (* +pawn-advance-eg+ (1- rank)))
               (values 0 0)))
          ((= type +rook+)
           (if (= rank 6) (values +rook-seventh+ +rook-seventh+) (values 0 0)))
          ((= type +king+)
           (values (- (* +king-flank+ (1- (min (distance-from-centre file) 2)))
                      (* +king-rank+ rank))
                   (* (aref **centre-weights-eg** +king+) centre)))
          (t
           (values (* (aref **centre-weights-mg** type) centre)
                   (* (aref **centre-weights-eg** type) centre))))))

;;; --- tables ---------------------------------------------------------------------------------

(defmacro define-piece-square-table (name documentation)
  "Define the global NAME as a zeroed table of 1024 (SIGNED-BYTE 16) entries, indexed by
(PIECE * 64 + SQUARE) for a piece code PIECE (white 1..6, black 9..14)."
  `(progn
     (sb-ext:defglobal ,name
         (make-array 1024 :element-type '(signed-byte 16) :initial-element 0)
       ,documentation)
     (declaim (type (simple-array (signed-byte 16) (1024)) ,name))))

(define-piece-square-table **pst-mg**
  "pst_mg of the piece on the square, read on its relative square, for its owner (not signed):
indexed by (PIECE * 64 + SQUARE).")
(define-piece-square-table **pst-eg**
  "pst_eg of the piece on the square, as **PST-MG**.")
(define-piece-square-table **psq-mg**
  "sigma(c) * (V(t) + pst_mg(t, s')) of the piece on the square: what the piece adds to the
incremental PSQ-MG of the position, +1 for White and -1 for Black. Indexed as **PST-MG**.")
(define-piece-square-table **psq-eg**
  "sigma(c) * (V(t) + pst_eg(t, s')), as **PSQ-MG**.")

(sb-ext:defglobal **phase-weights** (make-array 16 :element-type '(unsigned-byte 8)
                                                   :initial-element 0)
  "The phase weight of each piece code (0 for the empty square and the unused codes).")
(declaim (type (simple-array (unsigned-byte 8) (16)) **phase-weights**))

(defmacro define-mask-table (name size documentation)
  "Define the global NAME as a zeroed vector of SIZE bitboards."
  `(progn
     (sb-ext:defglobal ,name
         (make-array ,size :element-type '(unsigned-byte 64) :initial-element 0)
       ,documentation)
     (declaim (type (simple-array (unsigned-byte 64) (,size)) ,name))))

(define-mask-table **file-masks** 8 "The squares of each file, a to h.")
(define-mask-table **adjacent-file-masks** 8
  "The squares of the files next to each file (one for the a and h files, two otherwise).")
(define-mask-table **front-spans** 128
  "Indexed by (colour * 64 + square): the squares of the same file with a greater relative rank,
seen by that colour.")
(define-mask-table **passed-spans** 128
  "Indexed by (colour * 64 + square): the squares of the same file and of the adjacent files
with a greater relative rank, seen by that colour (\"Pedoni passati\").")
(define-mask-table **ranks-above** 16
  "Indexed by (colour * 8 + rr): the squares whose relative rank, seen by that colour, is
greater than rr.")
(define-mask-table **ranks-up-to** 16
  "Indexed by (colour * 8 + rr): the squares whose relative rank, seen by that colour, is at
most rr.")
(define-mask-table **space-masks** 2
  "S(c) for each colour: files c to f and relative ranks 1 to 3, twelve squares (\"Spazio\").")

(defun initialise-evaluation-tables ()
  "Fill every table of this file from the formulas of docs/valutazione.md. Idempotent.

Classification: [EXACT] (precomputed tables)
Basis: each entry is the value of a formula of the definition at its index (a piece code and a
square, a file, a colour and a rank), computed once at load time and read back instead of being
computed again; the domain is finite and the tests check it whole.
Evidence: tests optimized-evaluation/piece-square-tables-equal-the-printed-tables,
optimized-evaluation/signed-tables-add-the-piece-values and
optimized-evaluation/pawn-masks-follow-their-definitions
(tests/test-optimized-evaluation.lisp), and the evaluation compared with the reference term by
term (suite differential)."
  (fill **pst-mg** 0)
  (fill **pst-eg** 0)
  (fill **psq-mg** 0)
  (fill **psq-eg** 0)
  (fill **phase-weights** 0)
  (dolist (colour (list +white+ +black+))
    (loop for type from 1 to 6
          do (let ((piece (make-piece colour type))
                   (sign (if (= colour +white+) 1 -1))
                   (value (aref **piece-values** type)))
               (setf (aref **phase-weights** piece) (aref **phase-weights-by-type** type))
               (dotimes (square 64)
                 (multiple-value-bind (mg eg)
                     (table-entry type (if (= colour +white+) square (logxor square 56)))
                   (let ((index (+ (* piece 64) square)))
                     (setf (aref **pst-mg** index) mg
                           (aref **pst-eg** index) eg
                           (aref **psq-mg** index) (* sign (+ value mg))
                           (aref **psq-eg** index) (* sign (+ value eg)))))))))
  (dotimes (file 8)
    (setf (aref **file-masks** file)
          (loop for rank below 8 sum (ash 1 (make-square file rank)))))
  (dotimes (file 8)
    (setf (aref **adjacent-file-masks** file)
          (logior (if (> file 0) (aref **file-masks** (1- file)) 0)
                  (if (< file 7) (aref **file-masks** (1+ file)) 0))))
  (dolist (colour (list +white+ +black+))
    (dotimes (rr 8)
      (let ((above 0) (up-to 0))
        (dotimes (square 64)
          (if (> (colour-relative-rank colour square) rr)
              (setf above (logior above (ash 1 square)))
              (setf up-to (logior up-to (ash 1 square)))))
        (setf (aref **ranks-above** (+ (* colour 8) rr)) above
              (aref **ranks-up-to** (+ (* colour 8) rr)) up-to)))
    (dotimes (square 64)
      (let* ((file (square-file square))
             (above (aref **ranks-above** (+ (* colour 8) (colour-relative-rank colour square))))
             (index (+ (* colour 64) square)))
        (setf (aref **front-spans** index) (logand above (aref **file-masks** file))
              (aref **passed-spans** index)
              (logand above (logior (aref **file-masks** file)
                                    (aref **adjacent-file-masks** file))))))
    (setf (aref **space-masks** colour)
          (loop for square below 64
                when (and (<= 2 (square-file square) 5)
                          (<= 1 (colour-relative-rank colour square) 3))
                  sum (ash 1 square))))
  t)

(initialise-evaluation-tables)

;;; --- the incremental state, from scratch ("Stato incrementale") -----------------------------

(declaim (inline material-and-piece-squares raw-phase-of evaluation-state-from-scratch))

(defun material-and-piece-squares (pieces colour)
  "The material of COLOUR and its piece-square values pst_mg and pst_eg, as three values,
summed over the piece bitboards PIECES (indexed by PIECE-INDEX) with the piece values and the
unsigned tables **PST-MG** and **PST-EG**."
  (declare (type (simple-array (unsigned-byte 64) (12)) pieces) (type colour colour))
  (let ((material 0) (mg 0) (eg 0))
    (declare (type (signed-byte 32) material mg eg))
    ;; LOOP steps TYPE to 7 before it stops, so 7 is in its declared type.
    (loop for type of-type (integer 1 7) from 1 to 6
          do (let* ((piece (make-piece colour type))
                    (bits (aref pieces (piece-index piece))))
               (declare (type (unsigned-byte 64) bits))
               (setf material (+ material (* (aref **piece-values** type) (logcount bits))))
               (do-set-bits (square bits)
                 (declare (type square square))
                 (let ((index (+ (ash piece 6) square)))
                   (setf mg (+ mg (aref **pst-mg** index))
                         eg (+ eg (aref **pst-eg** index)))))))
    (values material mg eg)))

(defun raw-phase-of (pieces)
  "The phase before the cap: the phase weights of the knights, bishops, rooks and queens of
both colours in the piece bitboards PIECES, summed."
  (declare (type (simple-array (unsigned-byte 64) (12)) pieces))
  (let ((phase 0))
    (declare (type (unsigned-byte 16) phase))
    (dotimes (index 12)
      (setf phase (+ phase (* (aref **phase-weights-by-type** (1+ (mod index 6)))
                              (logcount (aref pieces index))))))
    phase))

(defun evaluation-state-from-scratch (pieces)
  "PSQ-MG, PSQ-EG and PHASE-RAW of the position whose piece bitboards are PIECES, computed from
scratch: White's material and piece-square values minus Black's in each phase, and the phase
before the cap."
  (declare (type (simple-array (unsigned-byte 64) (12)) pieces))
  (multiple-value-bind (white-material white-mg white-eg)
      (material-and-piece-squares pieces +white+)
    (multiple-value-bind (black-material black-mg black-eg)
        (material-and-piece-squares pieces +black+)
      (values (- (+ white-material white-mg) (+ black-material black-mg))
              (- (+ white-material white-eg) (+ black-material black-eg))
              (raw-phase-of pieces)))))

(declaim (inline piece-square-mg piece-square-eg piece-phase-weight))

(defun piece-square-mg (piece square)
  "What PIECE on SQUARE adds to PSQ-MG: sigma(c) * (V(t) + pst_mg(t, s'))."
  (declare (type piece piece) (type square square))
  (aref **psq-mg** (+ (ash piece 6) square)))

(defun piece-square-eg (piece square)
  "What PIECE on SQUARE adds to PSQ-EG: sigma(c) * (V(t) + pst_eg(t, s'))."
  (declare (type piece piece) (type square square))
  (aref **psq-eg** (+ (ash piece 6) square)))

(defun piece-phase-weight (piece)
  "What PIECE adds to PHASE-RAW: 3, 3, 5, 9 for knight, bishop, rook, queen, else 0."
  (declare (type piece piece))
  (aref **phase-weights** piece))
