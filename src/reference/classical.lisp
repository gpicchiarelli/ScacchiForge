;;;; classical.lisp -- the classical evaluation of Phase 2, read from its definition.
;;;;
;;;; The definition is docs/valutazione.md (ADR-0018, in state Proposta): nine terms, each
;;;; giving a middlegame (mg) and an endgame (eg) integer per colour, summed from White's
;;;; point of view, blended by the phase of the game with a quotient truncated toward zero,
;;;; clamped, and returned from the point of view of the side to move. This file is the
;;;; reference's reading of that document, written to be read next to it: one function per
;;;; term, each walking the board with the reference's own tables (tables.lisp). Nothing is
;;;; incremental: every call computes everything from scratch. The comments name the section
;;;; of the document that each part implements, in quotes.
;;;;
;;;; Every term is [HEURISTIC], and no number is tuned by this repository (EVALUATE-CLASSICAL).
;;;; Each number has a rule written in the document. The six pawn-structure weights replace
;;;; earlier ones of which five equalled constants of Fruit 2.1, by the author's decision on
;;;; QA-18 (docs/valutazione.md, "Struttura pedonale" and "Provenienza").

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

;;; --- parameters ("Riepilogo dei parametri") ---------------------------------------------
;;;
;;; The piece values V are those of MATERIAL-VALUE (eval.lisp): 100, 300, 300, 500, 900, and
;;; 0 for the king ("Notazione"). A table indexed by piece type (1 = pawn ... 6 = king) holds
;;; 0 for the types its parameter does not concern.

(defconstant +phase-max+ 62
  "The phase of the start position: the non-pawn material of both sides, in pawn units.")

(sb-ext:defglobal **phase-weights**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 3 3 5 9 0))
  "Phase weight of each piece type: knight 3, bishop 3, rook 5, queen 9 (the piece values
divided by 100); pawns and kings weigh 0 (\"Fase della partita\").")

(defconstant +pawn-advance-mg+ 3 "Pawn table, mg: per rank advanced and per central file.")
(defconstant +pawn-advance-eg+ 6 "Pawn table, eg: per rank advanced.")

(sb-ext:defglobal **centre-weights-mg**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 8 4 0 2 0))
  "Multiplier of the centrality in the mg tables: knight 8, bishop 4, queen 2.")

(sb-ext:defglobal **centre-weights-eg**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 8 4 0 4 8))
  "Multiplier of the centrality in the eg tables: knight 8, bishop 4, queen 4, king 8.")

(defconstant +rook-seventh+ 20 "Rook on the relative seventh rank, mg and eg.")
(defconstant +king-flank+ 6 "King table, mg: per step of file distance from the centre.")
(defconstant +king-rank+ 10 "King table, mg: per rank away from the own first rank.")

(sb-ext:defglobal **mobility-base**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 4 6 7 13 0))
  "Mobility that scores 0: floor(M / 2), M the most squares the piece reaches on an empty
board (knight 8, bishop 13, rook 14, queen 27) (\"Mobilità\").")

(sb-ext:defglobal **mobility-weights-mg**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 4 2 2 1 0))
  "Value of one square of mobility, mg: round(30 / M).")

(sb-ext:defglobal **mobility-weights-eg**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 5 3 3 1 0))
  "Value of one square of mobility, eg: round(40 / M).")

(sb-ext:defglobal **king-attack-units**
    (make-array 7 :element-type 'fixnum :initial-contents '(0 0 2 2 3 5 0))
  "Attack units per square of the king zone hit: the piece value divided by 200, rounded up;
pawns and kings are not attackers (\"Sicurezza del re\").")

(defconstant +king-attack-scale+ 4 "Scale of the king attack.")
(defconstant +king-attack-cap+ 400 "Largest king attack: four pawns.")
(defconstant +shelter-step+ 10 "Shelter: cost of one rank of distance.")
(defconstant +shelter-max+ 3 "Shelter: the distance counted for a file with no shelter.")

(defconstant +doubled-pawn-mg+ 6 "Doubled pawn, mg: one missing support, floor(100 / 16).")
(defconstant +doubled-pawn-eg+ 9 "Doubled pawn, eg: one missing support, floor(3 * 100 / 32).")
(defconstant +isolated-pawn-mg+ 12 "Isolated pawn, mg: two missing supports.")
(defconstant +isolated-pawn-eg+ 18 "Isolated pawn, eg: two missing supports.")
(defconstant +backward-pawn-mg+ 6 "Backward pawn, mg: one missing support.")
(defconstant +backward-pawn-eg+ 9 "Backward pawn, eg: one missing support.")
(defconstant +passed-pawn-mg+ 5 "Passed pawn, mg: per unit of the triangular number.")
(defconstant +passed-pawn-eg+ 10 "Passed pawn, eg: per unit of the triangular number.")
(defconstant +space-square+ 2 "Space, mg: per square.")
(defconstant +tempo+ 10 "Initiative: the value of having the move, mg and eg.")
(defconstant +threat-gain-divisor+ 10 "Threats: divisor of the material a capture gains.")
(defconstant +threat-hanging-divisor+ 20 "Threats: divisor of the value of a hanging piece.")
(defconstant +evaluation-limit+ 20000
  "The largest magnitude of the score from White's point of view (INV-C9, \"Limite del
punteggio\"): below +MATE-BOUND+, so no static score reads as a mate.")

;;; --- geometry ("Notazione") -----------------------------------------------------------

(declaim (inline relative-rank relative-square centre-distance centrality))

(defun relative-rank (colour square)
  "The rank of SQUARE seen by COLOUR: 0 is COLOUR's own first rank."
  (declare (type colour colour) (type square square))
  (if (= colour +white+)
      (square-rank square)
      (- 7 (square-rank square))))

(defun relative-square (colour square)
  "SQUARE seen by COLOUR: the same square for White, the rank reflected for Black. The map is
its own inverse."
  (declare (type colour colour) (type square square))
  (if (= colour +white+)
      square
      (logxor square 56)))

(defun centre-distance (x)
  "dc(x) = max(3 - x, x - 4) for a file or rank X: 3 2 1 0 0 1 2 3."
  (declare (type (integer 0 7) x))
  (max (- 3 x) (- x 4)))

(defun centrality (square)
  "cent(s) = 3 - dc(file) - dc(rank): from -3 in the corners to 3 on d4, e4, d5, e5."
  (declare (type square square))
  (- 3 (centre-distance (square-file square)) (centre-distance (square-rank square))))

(defun exact-quotient (dividend divisor)
  "DIVIDEND / DIVISOR, which the definition says is exact (\"Divisioni\"); an error if not."
  (declare (type integer dividend) (type (integer 1) divisor))
  (multiple-value-bind (quotient remainder) (truncate dividend divisor)
    (unless (zerop remainder)
      (error "~D / ~D is not exact, as docs/valutazione.md requires" dividend divisor))
    quotient))

(defun triangular (n)
  "T(n) = n (n + 1) / 2."
  (declare (type (integer 0) n))
  (exact-quotient (* n (1+ n)) 2))

;;; --- attacks ("Attacchi") ---------------------------------------------------------------

(defun slider-attacks (board square first-direction end-direction)
  "The squares a slider on SQUARE attacks along the directions FIRST-DIRECTION below
END-DIRECTION: on each ray, every square up to and including the first occupied one."
  (declare (type board-vector board) (type square square)
           (type (integer 0 8) first-direction end-direction))
  (loop for direction from first-direction below end-direction
        nconc (loop for target across (ray-squares direction square)
                    collect target
                    until (/= (aref board target) +empty+))))

(defun piece-attacks (board square)
  "The attack set A(p) of the piece on SQUARE of BOARD, as a fresh list of squares. A pawn
attacks its two forward diagonal squares, whatever is on them; knight and king their target
squares; a slider each square of its rays up to and including the first occupied one, of
either colour. Pins, check, the side to move and legality do not count; no x-rays."
  (declare (type board-vector board) (type square square))
  (let* ((piece (aref board square))
         (type (piece-type piece)))
    (cond ((= type +pawn+) (coerce (pawn-attack-squares (piece-colour piece) square) 'list))
          ((= type +knight+) (coerce (step-targets **knight-targets** square) 'list))
          ((= type +king+) (coerce (step-targets **king-targets** square) 'list))
          ((= type +bishop+) (slider-attacks board square 4 8))
          ((= type +rook+) (slider-attacks board square 0 4))
          (t (slider-attacks board square 0 8)))))

(defun make-square-set ()
  "An empty set of squares: a bit per square."
  (make-array 64 :element-type 'bit :initial-element 0))

(defstruct (eval-context (:conc-name context-)
                         (:constructor %make-eval-context (pos &aux (board (pos-board pos)))))
  "What the terms read for one evaluation: the position and its board, the squares of the
pieces and of the pawns of each colour, the attack set of the piece on each square, and for
each colour the squares it attacks with all its pieces, Att(c), and with its pawns only,
PAtt(c)."
  (pos nil :type chess-position)
  (board nil :type board-vector)
  (pieces (vector '() '()) :type (simple-vector 2))
  (pawns (vector '() '()) :type (simple-vector 2))
  (attacks (make-array 64 :initial-element nil) :type (simple-vector 64))
  (attacked (vector (make-square-set) (make-square-set)) :type (simple-vector 2))
  (pawn-attacked (vector (make-square-set) (make-square-set)) :type (simple-vector 2)))

(defun make-eval-context (pos)
  "The squares of the pieces and of the pawns of each colour of POS, the attack set of every
piece, and Att and PAtt of both colours."
  (declare (type chess-position pos))
  (let* ((context (%make-eval-context pos))
         (board (context-board context)))
    (loop for square from 63 downto 0
          for piece = (aref board square)
          unless (= piece +empty+)
            do (let ((targets (piece-attacks board square))
                     (colour (piece-colour piece)))
                 (push square (svref (context-pieces context) colour))
                 (when (= (piece-type piece) +pawn+)
                   (push square (svref (context-pawns context) colour)))
                 (setf (svref (context-attacks context) square) targets)
                 (dolist (target targets)
                   (setf (sbit (svref (context-attacked context) colour) target) 1)
                   (when (= (piece-type piece) +pawn+)
                     (setf (sbit (svref (context-pawn-attacked context) colour) target) 1)))))
    context))

(declaim (inline pieces-of pawns-of attacks-from attacked-by-p pawn-attacked-by-p))

(defun pieces-of (context colour)
  "The squares of the pieces of COLOUR, king included, in increasing order."
  (svref (context-pieces context) colour))

(defun pawns-of (context colour)
  "The squares of the pawns of COLOUR, in increasing order."
  (svref (context-pawns context) colour))

(defun attacks-from (context square)
  "A(p) of the piece on SQUARE (NIL for an empty square)."
  (svref (context-attacks context) square))

(defun attacked-by-p (context colour square)
  "True when SQUARE is in Att(COLOUR): a piece of COLOUR, king and pawns included, attacks it."
  (= 1 (sbit (svref (context-attacked context) colour) square)))

(defun pawn-attacked-by-p (context colour square)
  "True when SQUARE is in PAtt(COLOUR): a pawn of COLOUR attacks it."
  (= 1 (sbit (svref (context-pawn-attacked context) colour) square)))

(defun piece-of-p (piece colour)
  "True when PIECE is a piece of COLOUR (not an empty square)."
  (and (/= piece +empty+) (= (piece-colour piece) colour)))

;;; --- the terms ("Termini"), in the order of the specification ---------------------------
;;;
;;; Each term function takes the context and a colour c and returns two values, X_mg(c) and
;;; X_eg(c), computed with the same formula for both colours in coordinates relative to c.

(defun material-term (context colour)
  "\"Materiale\": the sum of the values of the pieces of COLOUR, the same in both phases."
  (let ((board (context-board context))
        (sum 0))
    (dolist (square (pieces-of context colour))
      (incf sum (material-value (piece-type (aref board square)))))
    (values sum sum)))

(defun piece-square-value (type relative-square)
  "\"Piece-square tables\": pst_mg and pst_eg of a piece of TYPE standing on RELATIVE-SQUARE
(the square seen by its owner), as two values."
  (declare (type (integer 1 6) type) (type square relative-square))
  (let ((file (square-file relative-square))
        (rank (square-rank relative-square))
        (centre (centrality relative-square)))
    (cond ((= type +pawn+)
           (if (<= 1 rank 6)
               (values (* +pawn-advance-mg+ (1- rank) (- 3 (centre-distance file)))
                       (* +pawn-advance-eg+ (1- rank)))
               (values 0 0)))
          ((= type +rook+)
           (if (= rank 6)
               (values +rook-seventh+ +rook-seventh+)
               (values 0 0)))
          ((= type +king+)
           (values (- (* +king-flank+ (1- (min (centre-distance file) 2)))
                      (* +king-rank+ rank))
                   (* (aref **centre-weights-eg** type) centre)))
          (t
           (values (* (aref **centre-weights-mg** type) centre)
                   (* (aref **centre-weights-eg** type) centre))))))

(defun piece-square-term (context colour)
  "\"Piece-square tables\": the table values of the pieces of COLOUR, each read on its
relative square."
  (let ((board (context-board context))
        (mg 0)
        (eg 0))
    (dolist (square (pieces-of context colour))
      (multiple-value-bind (piece-mg piece-eg)
          (piece-square-value (piece-type (aref board square)) (relative-square colour square))
        (incf mg piece-mg)
        (incf eg piece-eg)))
    (values mg eg)))

(defun mobility-area-p (context colour square)
  "True when SQUARE is in area(COLOUR): not occupied by a piece of COLOUR and not attacked by
an enemy pawn. A square holding an enemy piece counts."
  (not (or (piece-of-p (aref (context-board context) square) colour)
           (pawn-attacked-by-p context (opposite-colour colour) square))))

(defun mobility-term (context colour)
  "\"Mobilità\": for each knight, bishop, rook and queen of COLOUR, m = the squares of its
attack set in area(COLOUR); it scores weight * (m - base) for its type."
  (let ((board (context-board context))
        (mg 0)
        (eg 0))
    (dolist (square (pieces-of context colour))
      (let ((type (piece-type (aref board square))))
        (when (<= +knight+ type +queen+)
          (let* ((reached (count-if (lambda (target) (mobility-area-p context colour target))
                                    (attacks-from context square)))
                 (excess (- reached (aref **mobility-base** type))))
            (incf mg (* (aref **mobility-weights-mg** type) excess))
            (incf eg (* (aref **mobility-weights-eg** type) excess))))))
    (values mg eg)))

(defun king-zone (context colour)
  "Z(c), as a set of squares: the square of the king of COLOUR and the squares it attacks."
  (let ((king (king-square (context-pos context) colour))
        (zone (make-square-set)))
    (dolist (square (cons king (attacks-from context king)))
      (setf (sbit zone square) 1))
    zone))

(defun king-attack (context colour)
  "\"Sicurezza del re\", attacco(c): for each enemy knight, bishop, rook and queen q,
k(q) = the squares of the zone of COLOUR's king that q attacks. With n the number of pieces
with k(q) > 0 and U the sum of unit(q) * k(q): min(4 * U * max(n - 1, 0), 400)."
  (let ((board (context-board context))
        (enemy (opposite-colour colour))
        (zone (king-zone context colour))
        (attackers 0)
        (units 0))
    (dolist (square (pieces-of context enemy))
      (let ((type (piece-type (aref board square))))
        (when (<= +knight+ type +queen+)
          (let ((hits (count-if (lambda (target) (= 1 (sbit zone target)))
                                (attacks-from context square))))
            (when (plusp hits)
              (incf attackers)
              (incf units (* (aref **king-attack-units** type) hits)))))))
    (min (* +king-attack-scale+ units (max (1- attackers) 0))
         +king-attack-cap+)))

(defun pawn-shelter (context colour)
  "\"Sicurezza del re\", riparo(c): for the file of COLOUR's king and the files next to it
that are on the board, d = min(3, the smallest rr(pawn) - rK - 1 over the pawns of COLOUR on
that file with relative rank above the king's rK), or 3 when there is none; 10 * the sum."
  (let* ((king (king-square (context-pos context) colour))
         (king-file (square-file king))
         (king-rank (relative-rank colour king))
         (pawns (pawns-of context colour))
         (total 0))
    (loop for file from (max 0 (1- king-file)) to (min 7 (1+ king-file))
          do (let ((distance +shelter-max+))
               (dolist (pawn pawns)
                 (when (and (= (square-file pawn) file)
                            (> (relative-rank colour pawn) king-rank))
                   (setf distance (min distance (- (relative-rank colour pawn) king-rank 1)))))
               (incf total distance)))
    (* +shelter-step+ total)))

(defun king-safety-term (context colour)
  "\"Sicurezza del re\": -(attacco + riparo) in the middlegame, 0 in the endgame."
  (values (- (+ (king-attack context colour) (pawn-shelter context colour)))
          0))

(defun stop-square (colour square)
  "The square in front of a pawn of COLOUR on SQUARE."
  (if (= colour +white+) (+ square 8) (- square 8)))

(defun pawn-structure-term (context colour)
  "\"Struttura pedonale\": doubled pawns (k - 1 for each file with k >= 2 pawns of COLOUR),
isolated pawns (no pawn of COLOUR on the adjacent files) and backward pawns (not isolated,
every pawn of COLOUR on the adjacent files further advanced, the stop square attacked by an
enemy pawn), each subtracted with its mg and eg weight."
  (let* ((enemy (opposite-colour colour))
         (pawns (pawns-of context colour))
         (doubled 0)
         (isolated 0)
         (backward 0))
    (dotimes (file 8)
      (incf doubled (max 0 (1- (count file pawns :key #'square-file)))))
    (dolist (square pawns)
      (let ((file (square-file square))
            (rank (relative-rank colour square)))
        (flet ((neighbour-p (other)
                 (= 1 (abs (- (square-file other) file)))))
          (cond ((notany #'neighbour-p pawns)
                 (incf isolated))
                ((and (every (lambda (other)
                               (or (not (neighbour-p other))
                                   (> (relative-rank colour other) rank)))
                             pawns)
                      (pawn-attacked-by-p context enemy (stop-square colour square)))
                 (incf backward))))))
    (values (- (+ (* +doubled-pawn-mg+ doubled) (* +isolated-pawn-mg+ isolated)
                  (* +backward-pawn-mg+ backward)))
            (- (+ (* +doubled-pawn-eg+ doubled) (* +isolated-pawn-eg+ isolated)
                  (* +backward-pawn-eg+ backward))))))

(defun passed-pawn-p (context colour square)
  "\"Pedoni passati\": true when the pawn of COLOUR on SQUARE has no enemy pawn ahead of it
(relative rank, seen by COLOUR, greater than its own) on its file or the adjacent ones, and no
pawn of COLOUR ahead of it on its own file."
  (let ((file (square-file square))
        (rank (relative-rank colour square)))
    (flet ((ahead-within-p (other files)
             (and (<= (abs (- (square-file other) file)) files)
                  (> (relative-rank colour other) rank))))
      (not (or (some (lambda (other) (ahead-within-p other 1))
                     (pawns-of context (opposite-colour colour)))
               (some (lambda (other) (ahead-within-p other 0))
                     (pawns-of context colour)))))))

(defun passed-pawn-term (context colour)
  "\"Pedoni passati\": 5 * T(rr - 1) mg and 10 * T(rr - 1) eg for each passed pawn of COLOUR
on relative rank rr."
  (let ((mg 0)
        (eg 0))
    (dolist (square (pawns-of context colour))
      (when (passed-pawn-p context colour square)
        (let ((steps (triangular (1- (relative-rank colour square)))))
          (incf mg (* +passed-pawn-mg+ steps))
          (incf eg (* +passed-pawn-eg+ steps)))))
    (values mg eg)))

(defun space-term (context colour)
  "\"Spazio\": 2 for each square on files c to f and relative ranks 1 to 3 (12 squares) that
holds no pawn of COLOUR and is not attacked by an enemy pawn; middlegame only."
  (let ((board (context-board context))
        (own-pawn (make-piece colour +pawn+))
        (enemy (opposite-colour colour))
        (count 0))
    (loop for file from 2 to 5
          do (loop for rank from 1 to 3
                   do (let ((square (relative-square colour (make-square file rank))))
                        (unless (or (= (aref board square) own-pawn)
                                    (pawn-attacked-by-p context enemy square))
                          (incf count)))))
    (values (* +space-square+ count) 0)))

(defun initiative-term (context colour)
  "\"Iniziativa\": 10 in both phases for the side to move, 0 for the other side."
  (if (= colour (pos-side (context-pos context)))
      (values +tempo+ +tempo+)
      (values 0 0)))

(defun cheapest-attackers (context colour)
  "A vector of 64: for each square, the smallest value among the pieces of COLOUR other than
the king whose attack set holds it, or NIL when there is none."
  (let ((board (context-board context))
        (cheapest (make-array 64 :initial-element nil)))
    (dolist (square (pieces-of context colour))
      (let ((type (piece-type (aref board square))))
        (unless (= type +king+)
          (let ((value (material-value type)))
            (dolist (target (attacks-from context square))
              (let ((known (svref cheapest target)))
                (when (or (null known) (< value known))
                  (setf (svref cheapest target) value))))))))
    cheapest))

(defun threat-term (context colour)
  "\"Minacce\": for each enemy piece other than the king, of value v on square s, the larger
of r1 = (v - a) / 10, where a < v is the value of the cheapest non-king piece of COLOUR that
attacks s, and r2 = v / 20 when s is in Att(COLOUR) and not in Att(enemy); 0 for a missing
case. The same in both phases."
  (let ((board (context-board context))
        (enemy (opposite-colour colour))
        (cheapest (cheapest-attackers context colour))
        (total 0))
    (dolist (square (pieces-of context enemy))
      (let ((type (piece-type (aref board square))))
        (unless (= type +king+)
          (let* ((value (material-value type))
                 (attacker (svref cheapest square))
                 (gain (if (and attacker (< attacker value))
                           (exact-quotient (- value attacker) +threat-gain-divisor+)
                           0))
                 (hanging (if (and (attacked-by-p context colour square)
                                   (not (attacked-by-p context enemy square)))
                              (exact-quotient value +threat-hanging-divisor+)
                              0)))
            (incf total (max gain hanging))))))
    (values total total)))

(defparameter *classical-terms*
  '((:material . material-term)
    (:piece-square-tables . piece-square-term)
    (:mobility . mobility-term)
    (:king-safety . king-safety-term)
    (:pawn-structure . pawn-structure-term)
    (:passed-pawns . passed-pawn-term)
    (:space . space-term)
    (:initiative . initiative-term)
    (:threats . threat-term))
  "The nine terms, in the order of the specification (\"EVALUATION\"): the name used in the
breakdown and the function computing the term for one colour.")

;;; --- the score ("Struttura del punteggio") ----------------------------------------------

(defun game-phase (pos)
  "\"Fase della partita\": the phase weights of the knights, bishops, rooks and queens of both
colours, summed and capped at 62."
  (declare (type chess-position pos))
  (let ((board (pos-board pos))
        (sum 0))
    (dotimes (square 64)
      (let ((piece (aref board square)))
        (unless (= piece +empty+)
          (incf sum (aref **phase-weights** (piece-type piece))))))
    (min sum +phase-max+)))

(defun blend-phases (mg eg phase)
  "\"Miscela e arrotondamento\": tr((MG * phase + EG * (62 - phase)) / 62), the quotient
truncated toward zero, which is odd: the colour swap negates it exactly."
  (declare (type integer mg eg) (type (integer 0 62) phase))
  (values (truncate (+ (* mg phase) (* eg (- +phase-max+ phase))) +phase-max+)))

(defun clamp-score (score)
  "SCORE limited to [-20000, 20000] (INV-C9)."
  (declare (type integer score))
  (max (- +evaluation-limit+) (min +evaluation-limit+ score)))

(defun classical-terms (pos)
  "The nine terms of POS, in the order of the specification, each as a list
(NAME WHITE-MG WHITE-EG BLACK-MG BLACK-EG)."
  (declare (type chess-position pos))
  (let ((context (make-eval-context pos)))
    (loop for (name . function) in *classical-terms*
          collect (multiple-value-bind (white-mg white-eg) (funcall function context +white+)
                    (multiple-value-bind (black-mg black-eg) (funcall function context +black+)
                      (list name white-mg white-eg black-mg black-eg))))))

(defun classical-breakdown (pos)
  "The classical evaluation of POS term by term, for differential debugging: a property list
with
  :TERMS        the nine terms as lists (NAME WHITE-MG WHITE-EG BLACK-MG BLACK-EG), in the
                order of the specification (names :MATERIAL :PIECE-SQUARE-TABLES :MOBILITY
                :KING-SAFETY :PAWN-STRUCTURE :PASSED-PAWNS :SPACE :INITIATIVE :THREATS);
  :MG :EG       the sums over the terms of WHITE - BLACK;
  :PHASE        the phase, 0 to 62;
  :WHITE-SCORE  E_W, the blended and clamped score from White's point of view;
  :SCORE        E, the score from the point of view of the side to move.
The steps follow \"Punto di vista\": the terms per colour, MG and EG, the phase, the blend
with truncation, the clamp, the point of view."
  (declare (type chess-position pos))
  (let* ((terms (classical-terms pos))
         (mg (loop for (nil white-mg nil black-mg nil) in terms
                   sum (- white-mg black-mg)))
         (eg (loop for (nil nil white-eg nil black-eg) in terms
                   sum (- white-eg black-eg)))
         (phase (game-phase pos))
         (white-score (clamp-score (blend-phases mg eg phase))))
    (list :terms terms :mg mg :eg eg :phase phase :white-score white-score
          :score (if (= (pos-side pos) +white+) white-score (- white-score)))))

(defun evaluate-classical (pos)
  "The classical evaluation of POS (docs/valutazione.md) in centipawns, from the point of view
of the side to move. It depends only on the placement of the pieces and on the side to move
(INV-C10), and its magnitude is at most 20000 (INV-C9).

Classification: [HEURISTIC]
Basis: each of the nine terms approximates part of the value of the position and can rank two
positions the wrong way round. No weight is fitted to data, chosen by a recorded measurement
or validated by an experiment of this repository, so none is [LEARNED] or [EMPIRICAL] here.
Each has a rule stated in docs/valutazione.md; the six pawn-structure weights too, since the
author replaced earlier ones of which five equalled constants of Fruit 2.1 (QA-18). Nothing
here claims that the evaluation plays well; no game has been
played.
Evidence: none yet. The tests (tests/test-evaluation.lisp) check that this code computes the
written definition, not that the definition is good."
  (declare (type chess-position pos))
  (getf (classical-breakdown pos) :score))
