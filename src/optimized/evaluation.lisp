;;;; evaluation.lisp -- the classical evaluation of the optimized layer, on bitboards.
;;;;
;;;; The definition is docs/valutazione.md (ADR-0018, in state Proposta); the section of the
;;;; document that each part implements is named in quotes. This file is the optimized layer's
;;;; own reading of it (ADR-0010): attacks come from this layer's tables and slider interface,
;;;; sets of squares are bitboards, and the terms that depend on the attacks are computed from
;;;; them on every call. Material and piece-square tables are not: BITBOARD-EVALUATE reads
;;;; them, with the phase, from the incremental state that make and unmake keep in the position
;;;; (evaluation-tables.lisp, make.lisp). BITBOARD-EVALUATE-FROM-SCRATCH computes the same score
;;;; with that state recomputed from the piece bitboards, and BITBOARD-CLASSICAL-BREAKDOWN gives
;;;; it term by term and colour by colour, in the form of the reference's CLASSICAL-BREAKDOWN.
;;;; The three expand the same inline functions, so the breakdown shows the terms of the code
;;;; the search runs.
;;;;
;;;; Every term is [HEURISTIC] and untuned (BITBOARD-EVALUATE). The two evaluations allocate
;;;; nothing; the breakdown, outside the hot path, allocates its lists.

(in-package #:scacchiforge.optimized)

;;; The two types below are not on the hot path; it starts at (DECLAIM-OPTIMIZED-POLICY). They
;;; bound the counters of the king attack from the board: at most 62 pieces other than the kings
;;; attack, each hitting at most the 9 squares of a zone with at most 5 units per square.
;;; Declaring them keeps 4 * U * (n - 1) within a word, so that no generic arithmetic is needed.

(declaim (optimize (speed 1) (safety 2)))

(deftype attack-units () '(integer 0 4096))
(deftype attacker-count () '(integer 0 64))

(declaim-optimized-policy)

(declaim (inline pawn-attack-set relative-rank-of add-activity piece-activity
                 king-attack-penalty pawn-shelter pawn-structure passed-pawns space-count
                 cheaper-attacker threats positional-terms blend-and-clamp classical-score))

;;; --- attacks ("Attacchi") -------------------------------------------------------------------

(defun pawn-attack-set (colour pawns)
  "PAtt(COLOUR): the squares the pawns PAWNS of COLOUR attack, the two forward diagonal squares
of each on the board, whatever stands on them. A whole set at a time, by shifting PAWNS."
  (declare (type colour colour) (type bitboard pawns))
  (if (= colour +white+)
      (logior (ldb (byte 64 0) (ash (logandc2 pawns +file-a+) 7))
              (ldb (byte 64 0) (ash (logandc2 pawns +file-h+) 9)))
      (logior (ash (logandc2 pawns +file-a+) -9)
              (ash (logandc2 pawns +file-h+) -7))))

(defun relative-rank-of (colour square)
  "The rank of SQUARE seen by COLOUR: 0 is COLOUR's own first rank."
  (declare (type colour colour) (type square square))
  (if (= colour +white+) (ash square -3) (- 7 (ash square -3))))

(defun add-activity (targets type area zone mobility-mg mobility-eg units attackers)
  "MOBILITY-MG, MOBILITY-EG, UNITS and ATTACKERS, as four values, after adding a piece of TYPE
(knight to queen) whose attack set is TARGETS: its mobility weight * (|TARGETS & AREA| - base),
in each phase, and, when it hits a square of ZONE, its attack units per square hit and one
attacker."
  (declare (type bitboard targets area zone) (type (integer 2 5) type)
           (type (signed-byte 32) mobility-mg mobility-eg)
           (type attack-units units) (type attacker-count attackers))
  (let ((excess (- (logcount (logand targets area)) (aref **mobility-base** type)))
        (hits (logcount (logand targets zone))))
    (values (+ mobility-mg (* (aref **mobility-weights-mg** type) excess))
            (+ mobility-eg (* (aref **mobility-weights-eg** type) excess))
            (+ units (* (aref **king-attack-units** type) hits))
            (if (plusp hits) (1+ attackers) attackers))))

(defun piece-activity (bbp colour occupancy area zone)
  "What the knights, bishops, rooks and queens of COLOUR do, from the attack set A(p) of each
with the occupancy OCCUPANCY of both colours (\"Attacchi\"). Nine values:
  the union of their attack sets;
  the squares attacked by a knight, by a bishop, by a rook, by a queen (for the threats);
  Mob_mg(c) and Mob_eg(c): weight * (|A(p) & AREA| - base) for each piece, AREA being area(c)
    (\"Mobilità\");
  U and n of the attack on the enemy king, ZONE being the zone of that king: the sum of
    unit * |A(p) & ZONE| and the number of pieces with |A(p) & ZONE| > 0 (\"Sicurezza del re\")."
  (declare (type bitboard-position bbp) (type colour colour)
           (type bitboard occupancy area zone))
  (let ((pieces (bbp-pieces bbp))
        (base (* colour 6))
        (attacks 0) (knights 0) (bishops 0) (rooks 0) (queens 0)
        (mobility-mg 0) (mobility-eg 0) (units 0) (attackers 0))
    (declare (type bitboard attacks knights bishops rooks queens)
             (type (signed-byte 32) mobility-mg mobility-eg)
             (type attack-units units) (type attacker-count attackers))
    (do-squares (square (aref pieces (+ base 1)))
      (let ((targets (knight-attacks square)))
        (setf knights (logior knights targets)
              attacks (logior attacks targets))
        (multiple-value-setq (mobility-mg mobility-eg units attackers)
          (add-activity targets +knight+ area zone mobility-mg mobility-eg units attackers))))
    (do-squares (square (aref pieces (+ base 2)))
      (let ((targets (bishop-attacks square occupancy)))
        (setf bishops (logior bishops targets)
              attacks (logior attacks targets))
        (multiple-value-setq (mobility-mg mobility-eg units attackers)
          (add-activity targets +bishop+ area zone mobility-mg mobility-eg units attackers))))
    (do-squares (square (aref pieces (+ base 3)))
      (let ((targets (rook-attacks square occupancy)))
        (setf rooks (logior rooks targets)
              attacks (logior attacks targets))
        (multiple-value-setq (mobility-mg mobility-eg units attackers)
          (add-activity targets +rook+ area zone mobility-mg mobility-eg units attackers))))
    (do-squares (square (aref pieces (+ base 4)))
      (let ((targets (queen-attacks square occupancy)))
        (setf queens (logior queens targets)
              attacks (logior attacks targets))
        (multiple-value-setq (mobility-mg mobility-eg units attackers)
          (add-activity targets +queen+ area zone mobility-mg mobility-eg units attackers))))
    (values attacks knights bishops rooks queens mobility-mg mobility-eg units attackers)))

;;; --- the terms ("Termini") ------------------------------------------------------------------
;;;
;;; Each is computed for one colour c with the same formula for both colours, in coordinates
;;; relative to c ("Simmetria dei colori").

(defun king-attack-penalty (units attackers)
  "\"Sicurezza del re\", attacco(c): min(4 * U * max(n - 1, 0), 400), from the units U and the
number n of the enemy pieces that hit the zone of the king of c."
  (declare (type attack-units units) (type attacker-count attackers))
  (min (* +king-attack-scale+ units (max (1- attackers) 0)) +king-attack-cap+))

(defun pawn-shelter (colour king pawns)
  "\"Sicurezza del re\", riparo(c): for the file of the king of COLOUR on KING and the files
next to it on the board, d = min(3, rr(pawn) - rK - 1) for the nearest pawn of PAWNS (the pawns
of COLOUR) on that file with a relative rank above the king's rK, or 3 when there is none; 10
times the sum."
  (declare (type colour colour) (type square king) (type bitboard pawns))
  (let* ((file (square-file king))
         (rank (relative-rank-of colour king))
         (ahead (logand pawns (aref **ranks-above** (+ (* colour 8) rank))))
         (total 0))
    (declare (type bitboard ahead) (type (integer 0 9) total))
    ;; LOOP steps X to 8 before it stops after the h file, so 8 is in its declared type.
    (loop for x of-type (integer 0 8) from (max 0 (1- file)) to (min 7 (1+ file))
          do (let ((front (logand ahead (aref **file-masks** x))))
               (declare (type bitboard front))
               (setf total
                     (+ total
                        (if (zerop front)
                            +shelter-max+
                            ;; The nearest pawn in front: the lowest square for White, the
                            ;; highest for Black.
                            (let ((nearest (if (= colour +white+)
                                               (1- (integer-length (logand front (- front))))
                                               (1- (integer-length front)))))
                              (declare (type square nearest))
                              (min +shelter-max+
                                   (- (relative-rank-of colour nearest) rank 1))))))))
    (* +shelter-step+ total)))

(defun pawn-structure (colour pawns enemy-pawn-attacks)
  "\"Struttura pedonale\": PS_mg(c) and PS_eg(c) for the pawns PAWNS of COLOUR. Doubled: k - 1
for each file with k >= 2 pawns. Isolated: no pawn of COLOUR on the adjacent files. Backward:
not isolated, every pawn of COLOUR on the adjacent files has a greater relative rank, and the
square in front is in ENEMY-PAWN-ATTACKS, PAtt of the other colour."
  (declare (type colour colour) (type bitboard pawns enemy-pawn-attacks))
  (let ((doubled 0) (isolated 0) (backward 0))
    (declare (type (integer 0 64) doubled isolated backward))
    (dotimes (file 8)
      (let ((count (logcount (logand pawns (aref **file-masks** file)))))
        (when (> count 1)
          (setf doubled (+ doubled (1- count))))))
    (do-squares (square pawns)
      (let ((neighbours (logand pawns (aref **adjacent-file-masks** (square-file square)))))
        (declare (type bitboard neighbours))
        (cond ((zerop neighbours)
               (setf isolated (1+ isolated)))
              ((and (zerop (logand neighbours
                                   (aref **ranks-up-to**
                                         (+ (* colour 8) (relative-rank-of colour square)))))
                    (logbitp (if (= colour +white+) (+ square 8) (- square 8))
                             enemy-pawn-attacks))
               (setf backward (1+ backward))))))
    (values (- (+ (* +doubled-pawn-mg+ doubled) (* +isolated-pawn-mg+ isolated)
                  (* +backward-pawn-mg+ backward)))
            (- (+ (* +doubled-pawn-eg+ doubled) (* +isolated-pawn-eg+ isolated)
                  (* +backward-pawn-eg+ backward))))))

(defun passed-pawns (colour pawns enemy-pawns)
  "\"Pedoni passati\": Pass_mg(c) and Pass_eg(c), 5 * T(rr - 1) and 10 * T(rr - 1) for each
pawn of PAWNS (the pawns of COLOUR) with no pawn of ENEMY-PAWNS ahead of it, seen by COLOUR, on
its file or the adjacent ones, and no pawn of COLOUR ahead of it on its own file."
  (declare (type colour colour) (type bitboard pawns enemy-pawns))
  (let ((mg 0) (eg 0))
    (declare (type (signed-byte 32) mg eg))
    (do-squares (square pawns)
      (let ((index (+ (* colour 64) square)))
        (when (and (zerop (logand enemy-pawns (aref **passed-spans** index)))
                   (zerop (logand pawns (aref **front-spans** index))))
          (let* ((steps (max 0 (1- (relative-rank-of colour square))))
                 (triangular (ash (* steps (1+ steps)) -1)))
            (setf mg (+ mg (* +passed-pawn-mg+ triangular))
                  eg (+ eg (* +passed-pawn-eg+ triangular)))))))
    (values mg eg)))

(defun space-count (colour pawns enemy-pawn-attacks)
  "\"Spazio\": the squares of S(COLOUR) (files c to f, relative ranks 1 to 3) that hold no pawn
of PAWNS (the pawns of COLOUR) and are not in ENEMY-PAWN-ATTACKS."
  (declare (type colour colour) (type bitboard pawns enemy-pawn-attacks))
  (logcount (logandc2 (aref **space-masks** colour) (logior pawns enemy-pawn-attacks))))

(defun cheaper-attacker (cheapest square set type)
  "CHEAPEST, the smallest value found so far among the attackers of SQUARE (-1 when none has been
found), updated with the pieces of TYPE: their value V(TYPE) when SET, the squares they attack,
holds SQUARE and V(TYPE) is smaller."
  (declare (type (signed-byte 16) cheapest) (type square square) (type bitboard set)
           (type (integer 1 5) type))
  (let ((value (aref **piece-values** type)))
    (if (and (logbitp square set) (or (minusp cheapest) (< value cheapest)))
        value
        cheapest)))

(defun threats (bbp colour pawn-attacks knights bishops rooks queens own-attacks enemy-attacks)
  "\"Minacce\": Min(c) for COLOUR. For each enemy piece other than the king, of value v on s:
the larger of r1 = (v - a) / 10, where a < v is the value of the cheapest non-king piece of
COLOUR whose attack set holds s (from PAWN-ATTACKS, KNIGHTS, BISHOPS, ROOKS and QUEENS, the
squares its pawns, knights, bishops, rooks and queens attack), and r2 = v / 20 when s is in
OWN-ATTACKS, Att(c), and not in ENEMY-ATTACKS, Att of the other colour; 0 for a missing case.
The cheapest attacker is the minimum of the values in **PIECE-VALUES** of the types that attack
s, whatever those values are; the two divisions are exact for every value the term can meet,
which CHECK-EXACT-THREAT-DIVISIONS (evaluation-tables.lisp) proves when the parameters are
loaded, so TRUNCATE gives the exact quotient of the definition."
  (declare (type bitboard-position bbp) (type colour colour)
           (type bitboard pawn-attacks knights bishops rooks queens own-attacks enemy-attacks))
  (let* ((enemy (opposite-colour colour))
         (board (bbp-board bbp))
         (targets (logandc2 (aref (bbp-colour-occupancy bbp) enemy)
                            (aref (bbp-pieces bbp) (+ (* enemy 6) 5))))
         (hanging (logandc2 own-attacks enemy-attacks))
         (total 0))
    (declare (type bitboard targets hanging) (type (signed-byte 32) total))
    (do-squares (square targets)
      (let* ((value (aref **piece-values** (piece-type (aref board square))))
             ;; The value of the cheapest non-king attacker, -1 when there is none.
             (cheapest (cheaper-attacker
                        (cheaper-attacker
                         (cheaper-attacker
                          (cheaper-attacker
                           (cheaper-attacker -1 square pawn-attacks +pawn+)
                           square knights +knight+)
                          square bishops +bishop+)
                         square rooks +rook+)
                        square queens +queen+))
             (gain (if (and (not (minusp cheapest)) (< cheapest value))
                       (values (truncate (- value cheapest) +threat-gain-divisor+))
                       0))
             (loose (if (logbitp square hanging)
                        (values (truncate value +threat-hanging-divisor+))
                        0)))
        (declare (type (signed-byte 16) value cheapest gain loose))
        (setf total (+ total (max gain loose)))))
    total))

(defun positional-terms (bbp)
  "The terms that depend on the attacks and on the pawns, computed from the bitboards of BBP.
Eighteen values, nine for White and then the same nine for Black: Mob_mg, Mob_eg, KS_mg
(-(attacco + riparo); KS_eg is 0), PS_mg, PS_eg, Pass_mg, Pass_eg, Spazio_mg (Spazio_eg is
0) and Min (the same in both phases). Material, piece-square tables and initiative are not
among them."
  (declare (type bitboard-position bbp))
  (let* ((pieces (bbp-pieces bbp))
         (occupancy (bbp-occupancy bbp))
         (white-occupancy (aref (bbp-colour-occupancy bbp) +white+))
         (black-occupancy (aref (bbp-colour-occupancy bbp) +black+))
         (white-pawns (aref pieces 0))
         (black-pawns (aref pieces 6))
         (white-king (king-square-of bbp +white+))
         (black-king (king-square-of bbp +black+))
         (white-pawn-attacks (pawn-attack-set +white+ white-pawns))
         (black-pawn-attacks (pawn-attack-set +black+ black-pawns))
         (white-zone (logior (ash 1 white-king) (king-attacks white-king)))
         (black-zone (logior (ash 1 black-king) (king-attacks black-king)))
         ;; area(c): every square but those of the own pieces and those enemy pawns attack.
         (white-area (ldb (byte 64 0) (lognot (logior white-occupancy black-pawn-attacks))))
         (black-area (ldb (byte 64 0) (lognot (logior black-occupancy white-pawn-attacks)))))
    (declare (type bitboard occupancy white-occupancy black-occupancy white-pawns black-pawns
                   white-pawn-attacks black-pawn-attacks white-zone black-zone white-area
                   black-area))
    (multiple-value-bind (white-attacks white-knights white-bishops white-rooks white-queens
                          white-mobility-mg white-mobility-eg white-units white-attackers)
        ;; WHITE-UNITS and WHITE-ATTACKERS are White's attack on the black king's zone.
        (piece-activity bbp +white+ occupancy white-area black-zone)
      (multiple-value-bind (black-attacks black-knights black-bishops black-rooks black-queens
                            black-mobility-mg black-mobility-eg black-units black-attackers)
          (piece-activity bbp +black+ occupancy black-area white-zone)
        (let ((white-all (logior white-attacks white-pawn-attacks (king-attacks white-king)))
              (black-all (logior black-attacks black-pawn-attacks (king-attacks black-king))))
          (declare (type bitboard white-all black-all))
          (multiple-value-bind (white-structure-mg white-structure-eg)
              (pawn-structure +white+ white-pawns black-pawn-attacks)
            (multiple-value-bind (black-structure-mg black-structure-eg)
                (pawn-structure +black+ black-pawns white-pawn-attacks)
              (multiple-value-bind (white-passed-mg white-passed-eg)
                  (passed-pawns +white+ white-pawns black-pawns)
                (multiple-value-bind (black-passed-mg black-passed-eg)
                    (passed-pawns +black+ black-pawns white-pawns)
                  (values
                   white-mobility-mg
                   white-mobility-eg
                   (- (+ (king-attack-penalty black-units black-attackers)
                         (pawn-shelter +white+ white-king white-pawns)))
                   white-structure-mg
                   white-structure-eg
                   white-passed-mg
                   white-passed-eg
                   (* +space-square+ (space-count +white+ white-pawns black-pawn-attacks))
                   (threats bbp +white+ white-pawn-attacks white-knights white-bishops
                            white-rooks white-queens white-all black-all)
                   black-mobility-mg
                   black-mobility-eg
                   (- (+ (king-attack-penalty white-units white-attackers)
                         (pawn-shelter +black+ black-king black-pawns)))
                   black-structure-mg
                   black-structure-eg
                   black-passed-mg
                   black-passed-eg
                   (* +space-square+ (space-count +black+ black-pawns white-pawn-attacks))
                   (threats bbp +black+ black-pawn-attacks black-knights black-bishops
                            black-rooks black-queens black-all white-all)))))))))))

;;; --- the score ("Struttura del punteggio") --------------------------------------------------

(defun blend-and-clamp (mg eg raw-phase)
  "E_W from MG and EG: the phase min(RAW-PHASE, 62), the blend
tr((MG * phase + EG * (62 - phase)) / 62) with the quotient truncated toward zero (\"Miscela e
arrotondamento\"), then the clamp to [-20000, 20000] (INV-C9)."
  (declare (type (signed-byte 32) mg eg) (type (unsigned-byte 16) raw-phase))
  (let* ((phase (min raw-phase +phase-max+))
         (blended (values (truncate (+ (* mg phase) (* eg (- +phase-max+ phase)))
                                    +phase-max+))))
    (max (- +evaluation-limit+) (min +evaluation-limit+ blended))))

(defun classical-score (bbp psq-mg psq-eg raw-phase)
  "The classical score of BBP from the side to move, with PSQ-MG, PSQ-EG and RAW-PHASE as its
material and piece-square sums and its phase before the cap. The steps of \"Punto di vista\":
the terms per colour, MG and EG, the phase, the blend with truncation, the clamp, the point of
view."
  (declare (type bitboard-position bbp) (type (signed-byte 32) psq-mg psq-eg)
           (type (unsigned-byte 16) raw-phase))
  (multiple-value-bind (wmob-mg wmob-eg wks wps-mg wps-eg wpass-mg wpass-eg wspace wthreats
                        bmob-mg bmob-eg bks bps-mg bps-eg bpass-mg bpass-eg bspace bthreats)
      (positional-terms bbp)
    (let* ((white-to-move (= (bbp-side bbp) +white+))
           ;; "Iniziativa": 10 in both phases for the side to move.
           (tempo (if white-to-move +tempo+ (- +tempo+)))
           (mg (+ psq-mg (- wmob-mg bmob-mg) (- wks bks) (- wps-mg bps-mg)
                  (- wpass-mg bpass-mg) (- wspace bspace) tempo (- wthreats bthreats)))
           (eg (+ psq-eg (- wmob-eg bmob-eg) (- wps-eg bps-eg) (- wpass-eg bpass-eg) tempo
                  (- wthreats bthreats)))
           (white-score (blend-and-clamp mg eg raw-phase)))
      (if white-to-move white-score (- white-score)))))

(declaim (ftype (function (bitboard-position) (values (integer -20000 20000) &optional))
                bitboard-evaluate bitboard-evaluate-from-scratch))

(defun bitboard-evaluate (bbp)
  "The classical evaluation of BBP (docs/valutazione.md) in centipawns, from the point of view
of the side to move. Material, piece-square tables and phase come from the incremental state of
BBP, or, in the build with SCF_EVAL_STATE=recompute (policy.lisp), from the piece bitboards as in
BITBOARD-EVALUATE-FROM-SCRATCH; every other term is computed from the bitboards. It depends
only on the placement of the pieces and on the side to move (INV-C10), its magnitude is at most
20000 (INV-C9), and it allocates nothing.

Classification: [HEURISTIC]
Basis: each of the nine terms approximates part of the value of the position and can rank two
positions the wrong way round. No weight is fitted to data, chosen by a recorded measurement
or validated by an experiment of this repository, so none is [LEARNED] or [EMPIRICAL] here.
Each has a rule stated in docs/valutazione.md; the six pawn-structure weights too, since the
author replaced earlier ones of which five equalled constants of Fruit 2.1 (QA-18). Nothing
here claims that the evaluation plays well; no game has been
played. Reading material, piece-square tables and phase from the incremental state is [EXACT]
(INV-C8, BITBOARD-MAKE-MOVE).
Evidence: none for the heuristic. That this code computes the written definition: the tests of
suite optimized-evaluation (the examples and tables of the document, the colour swap) and the
comparison with the reference, term by term, in suite differential."
  (declare (type bitboard-position bbp))
  (if-incremental-evaluation
   (classical-score bbp (bbp-psq-mg bbp) (bbp-psq-eg bbp) (bbp-phase-raw bbp))
   (multiple-value-bind (psq-mg psq-eg raw-phase) (evaluation-state-from-scratch (bbp-pieces bbp))
     (classical-score bbp psq-mg psq-eg raw-phase))))

(defun bitboard-evaluate-from-scratch (bbp)
  "The score of BITBOARD-EVALUATE with material, piece-square tables and phase computed from the
piece bitboards of BBP instead of read from its incremental state. Allocates nothing."
  (declare (type bitboard-position bbp))
  (multiple-value-bind (psq-mg psq-eg raw-phase) (evaluation-state-from-scratch (bbp-pieces bbp))
    (classical-score bbp psq-mg psq-eg raw-phase)))

;;; The hot path of this file ends here. The breakdown allocates its lists for callers outside it
;;; (tests, tools); it is compiled with the policy of the layer's files outside the hot path, and
;;; expands the same inline functions as the two evaluations above.

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-classical-breakdown (bbp)
  "The classical evaluation of BBP term by term, in the form of the reference's
CLASSICAL-BREAKDOWN, for differential debugging: a property list with
  :TERMS        the nine terms as lists (NAME WHITE-MG WHITE-EG BLACK-MG BLACK-EG), in the
                order of the specification (names :MATERIAL :PIECE-SQUARE-TABLES :MOBILITY
                :KING-SAFETY :PAWN-STRUCTURE :PASSED-PAWNS :SPACE :INITIATIVE :THREATS);
  :MG :EG       the sums over the terms of WHITE - BLACK;
  :PHASE        the phase, 0 to 62;
  :WHITE-SCORE  E_W, the blended and clamped score from White's point of view;
  :SCORE        E, the score from the point of view of the side to move.
Material and piece-square tables are computed from the piece bitboards, colour by colour."
  (declare (type bitboard-position bbp))
  (let ((pieces (bbp-pieces bbp))
        (white-tempo (if (= (bbp-side bbp) +white+) +tempo+ 0))
        (black-tempo (if (= (bbp-side bbp) +black+) +tempo+ 0)))
    (multiple-value-bind (white-material white-pst-mg white-pst-eg)
        (material-and-piece-squares pieces +white+)
      (multiple-value-bind (black-material black-pst-mg black-pst-eg)
          (material-and-piece-squares pieces +black+)
        (multiple-value-bind (wmob-mg wmob-eg wks wps-mg wps-eg wpass-mg wpass-eg wspace wthreats
                              bmob-mg bmob-eg bks bps-mg bps-eg bpass-mg bpass-eg bspace bthreats)
            (positional-terms bbp)
          (let* ((terms
                   (list (list :material white-material white-material
                               black-material black-material)
                         (list :piece-square-tables white-pst-mg white-pst-eg
                               black-pst-mg black-pst-eg)
                         (list :mobility wmob-mg wmob-eg bmob-mg bmob-eg)
                         (list :king-safety wks 0 bks 0)
                         (list :pawn-structure wps-mg wps-eg bps-mg bps-eg)
                         (list :passed-pawns wpass-mg wpass-eg bpass-mg bpass-eg)
                         (list :space wspace 0 bspace 0)
                         (list :initiative white-tempo white-tempo black-tempo black-tempo)
                         (list :threats wthreats wthreats bthreats bthreats)))
                 (mg (loop for (nil white-mg nil black-mg nil) in terms
                           sum (- white-mg black-mg)))
                 (eg (loop for (nil nil white-eg nil black-eg) in terms
                           sum (- white-eg black-eg)))
                 (raw-phase (raw-phase-of pieces))
                 (white-score (blend-and-clamp mg eg raw-phase)))
            (list :terms terms :mg mg :eg eg :phase (min raw-phase +phase-max+)
                  :white-score white-score
                  :score (if (= (bbp-side bbp) +white+) white-score (- white-score)))))))))
