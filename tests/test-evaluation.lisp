;;;; test-evaluation.lisp -- the classical evaluation of the reference (EVALUATE-CLASSICAL,
;;;; CLASSICAL-BREAKDOWN) against its definition, docs/valutazione.md (ADR-0018, Proposta).
;;;;
;;;; The tests defined with DEFTEST-EVALUATION (tests/support.lisp) run twice, on the reference
;;;; in suite evaluation and on the optimized layer in suite optimized-evaluation
;;;; (BITBOARD-CLASSICAL-BREAKDOWN, BITBOARD-EVALUATE, BITBOARD-MIRROR), so that the expected
;;;; values of the document judge both layers from outside, as the document asks ("Verifica").
;;;; A position is read by the reference's FEN reader and, for the optimized layer, converted.
;;;; The tests of the reference's own tables and parameters are reference-only; the optimized
;;;; layer's are in tests/test-optimized-evaluation.lisp.
;;;;
;;;; Provenance of the expected values. None is published; each comes from the definition.
;;;;  - WORKED-EXAMPLES: the "Esempi calcolati" section of docs/valutazione.md. As that section
;;;;    says, its first three positions were computed by hand from the text, the last two by a
;;;;    prototype written from the text outside the repository (the king attack of perft
;;;;    position 4 rechecked by hand).
;;;;  - *HAND-CHECKED-POSITIONS*: tiny positions (bare kings and one or two pieces) computed by
;;;;    hand from the text, term by term and colour by colour, when this file was written. The
;;;;    comment of each position gives the computation and the sections it applies.
;;;;  - The piece-square tables printed in the document ("Piece-square tables") and the table
;;;;    of the mobility parameters ("Mobilità").
;;;; A failure says that the code and the document disagree, not which of the two is wrong.
;;;; Checked as well: the colour swap negates the score from White's point of view (INV-C7),
;;;; term by term; the reflection of the files keeps it (a property of today's definition, not
;;;; an invariant); the score depends only on placement and side to move (INV-C10); its
;;;; magnitude is at most 20000 (INV-C9); the blend truncates toward zero.

(in-package #:scacchiforge.test)

(defparameter *term-names*
  '(:material :piece-square-tables :mobility :king-safety :pawn-structure :passed-pawns
    :space :initiative :threats)
  "The nine terms, in the order of the specification and of the breakdown.")

(defun breakdown-of (fen)
  "The classical breakdown of the position FEN, computed by the layer *LAYER*."
  (layer-breakdown (layer-position fen)))

(defun term-row (breakdown name)
  "(WHITE-MG WHITE-EG BLACK-MG BLACK-EG) of the term NAME in BREAKDOWN."
  (rest (assoc name (getf breakdown :terms))))

(defun term-balance (breakdown name)
  "(MG EG) of the term NAME in BREAKDOWN from White's point of view: White minus Black."
  (destructuring-bind (white-mg white-eg black-mg black-eg) (term-row breakdown name)
    (list (- white-mg black-mg) (- white-eg black-eg))))

(defun check-score (label breakdown mg eg phase white-score score)
  "Assert the totals of BREAKDOWN."
  (is-eql mg (getf breakdown :mg) "~A: MG" label)
  (is-eql eg (getf breakdown :eg) "~A: EG" label)
  (is-eql phase (getf breakdown :phase) "~A: phase" label)
  (is-eql white-score (getf breakdown :white-score) "~A: E_W" label)
  (is-eql score (getf breakdown :score) "~A: E" label))

(deftest-evaluation the-breakdown-lists-the-nine-terms-in-the-order-of-the-specification
  (let ((breakdown (breakdown-of scf-ref:*start-fen*)))
    (is-equal *term-names* (mapcar #'first (getf breakdown :terms)))
    (is-eql (getf breakdown :score) (layer-evaluate (layer-position scf-ref:*start-fen*)))))

;;; --- the worked examples of the document ("Esempi calcolati") -----------------------------

(defun check-balances (label breakdown balances)
  "Assert the White-minus-Black (MG EG) of every term of BREAKDOWN: those in the property list
BALANCES (term name, then (MG EG)), and (0 0) for the terms it does not name."
  (dolist (name *term-names*)
    (is-equal (or (getf balances name) '(0 0)) (term-balance breakdown name)
              "~A: ~(~A~), White minus Black" label name)))

(deftest-evaluation worked-examples-of-the-definition
  ;; "Posizione iniziale": every term but the initiative is equal for the two colours; the
  ;; mobility is -81 in the middlegame for each.
  (let ((breakdown (breakdown-of scf-ref:*start-fen*)))
    (check-balances "start" breakdown '(:initiative (10 10)))
    (is-equal '(-81 -81) (list (first (term-row breakdown :mobility))
                               (third (term-row breakdown :mobility))))
    (check-score "start" breakdown 10 10 62 10 10))
  ;; "Re e pedone contro re", both sides to move.
  (let ((breakdown (breakdown-of "4k3/8/8/8/8/8/4P3/4K3 w - - 0 1")))
    (check-balances "KP v K, White to move" breakdown
                    '(:material (100 100) :king-safety (30 0) :pawn-structure (-12 -18)
                      :space (-2 0) :initiative (10 10)))
    (is-equal '(-60 0 -90 0) (term-row breakdown :king-safety) "shelter 60 against 90")
    (check-score "KP v K, White to move" breakdown 126 92 0 92 92))
  (let ((breakdown (breakdown-of "4k3/8/8/8/8/8/4P3/4K3 b - - 0 1")))
    (check-score "KP v K, Black to move" breakdown 106 72 0 72 -72))
  ;; "Posizione 3 della tabella di perft": x = -1302 = -21 * 62, an exact quotient.
  (let ((breakdown (breakdown-of (scf-ref:standard-position-fen "pos3"))))
    (check-balances "pos3" breakdown
                    '(:piece-square-tables (-18 -6) :mobility (-2 -3) :pawn-structure (-18 -27)
                      :space (2 0) :threats (5 5) :initiative (10 10)))
    (is-equal '(-60 0 -60 0) (term-row breakdown :king-safety) "shelter 60 for each king")
    (check-score "pos3" breakdown -21 -21 10 -21 -21))
  ;; "Kiwipete" (computed by the prototype, as the document says).
  (let ((breakdown (breakdown-of (scf-ref:standard-position-fen "kiwipete"))))
    (check-balances "kiwipete" breakdown
                    '(:piece-square-tables (64 16) :mobility (7 8) :king-safety (-40 0)
                      :space (6 0) :threats (-5 -5) :initiative (10 10)))
    (check-score "kiwipete" breakdown 42 29 62 42 42))
  ;; "Posizione 4 della tabella di perft" (computed by the prototype; the king attack rechecked
  ;; by hand: Bb4 on e7 and f8, Nh6 on f7, U = 6, n = 2, so 4 * 6 * 1 = 24 against Black).
  (let ((breakdown (breakdown-of (scf-ref:standard-position-fen "pos4"))))
    (check-balances "pos4" breakdown
                    '(:material (100 100) :piece-square-tables (34 26) :mobility (15 18)
                      :king-safety (24 0) :space (6 0) :threats (-30 -30)
                      :initiative (10 10)))
    (check-score "pos4" breakdown 159 124 62 159 159)))

;;; --- tiny positions computed by hand -----------------------------------------------------

(defparameter *hand-checked-positions*
  ;; Each entry: (label fen terms mg eg phase white-score score), where TERMS lists every term
  ;; as (name white-mg white-eg black-mg black-eg). "Space" is "Spazio": 12 squares, 2 each.
  ;; Every king without pawns has the full shelter, 3 files * 3 * 10 = 90 ("Sicurezza del re",
  ;; riparo), except on the a and h files.
  '(;; Bare kings, White to move. King e1 and king e8 (relative e1): pst_mg = 6 * (min(dc(4), 2)
    ;; - 1) - 10 * 0 = -6, pst_eg = 8 * cent(e1) = 8 * (3 - 0 - 3) = 0 ("Piece-square
    ;; tables"). No pawn: every space square counts. Initiative to White ("Iniziativa").
    ;; MG = EG = 10, phase 0, E_W = 10. The two kings are equally central here; elsewhere bare
    ;; kings score otherwise ("Patte per regola", test bare-kings-score-the-initiative-and-the-
    ;; endgame-king-table).
    ("bare kings, White to move" "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
     ((:material 0 0 0 0) (:piece-square-tables -6 0 -6 0) (:mobility 0 0 0 0)
      (:king-safety -90 0 -90 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     10 10 0 10 10)
    ;; The same with Black to move: E_W = -10, and E = 10 for the side to move.
    ("bare kings, Black to move" "4k3/8/8/8/8/8/8/4K3 b - - 0 1"
     ((:material 0 0 0 0) (:piece-square-tables -6 0 -6 0) (:mobility 0 0 0 0)
      (:king-safety -90 0 -90 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 0 0 10 10) (:threats 0 0 0 0))
     -10 -10 0 -10 10)
    ;; Knight d4. Pst: 8 * cent(d4) = 8 * 3 = 24 in both phases, plus the king's -6 / 0.
    ;; Mobility: c2 e2 b3 f3 b5 f5 c6 e6, m = 8: mg 4 * (8 - 4) = 16, eg 5 * 4 = 20
    ;; ("Mobilità"). The knight hits no square of the black king's zone (d7..f8). d4 counts as
    ;; space: a piece that is not a pawn does not remove a square ("Spazio"). Phase 3:
    ;; E_W = tr((350 * 3 + 354 * 59) / 62) = tr(21936 / 62) = 353.
    ("knight d4" "4k3/8/8/8/3N4/8/8/4K3 w - - 0 1"
     ((:material 300 300 0 0) (:piece-square-tables 18 24 -6 0) (:mobility 16 20 0 0)
      (:king-safety -90 0 -90 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     350 354 3 353 353)
    ;; Rook a7, Black to move. Pst: 20 on the relative seventh rank, both phases. Mobility:
    ;; a8, a6..a1 and b7..h7, m = 14: mg 2 * (14 - 7) = 14, eg 3 * 7 = 21. The rook hits d7,
    ;; e7 and f7 of the black king's zone, but it is alone: n = 1, so the attack is
    ;; 4 * U * max(n - 1, 0) = 0 ("Sicurezza del re", attacco). Initiative to Black. Phase 5:
    ;; E_W = tr((524 * 5 + 531 * 57) / 62) = tr(32887 / 62) = 530, E = -530.
    ("rook on the seventh, Black to move" "4k3/R7/8/8/8/8/8/4K3 b - - 0 1"
     ((:material 500 500 0 0) (:piece-square-tables 14 20 -6 0) (:mobility 14 21 0 0)
      (:king-safety -90 0 -90 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 0 0 10 10) (:threats 0 0 0 0))
     524 531 5 530 -530)
    ;; Pawn e4 against knight d5. Pst: e4 (rr 3, file e) 3 * 2 * 3 = 18 / 6 * 2 = 12; the
    ;; black knight on d5 reads d4: 24 / 24. Mobility of the knight: e7 f6 f4 e3 c3 b4 b6 c7,
    ;; none attacked by the pawn (which attacks d5 and f5): 16 / 20. White shelter: e4 is
    ;; 3 - 0 - 1 = 2 ranks in front of the king, d and f have none: 10 * (2 + 3 + 3) = 80.
    ;; e4 is isolated (12 / 18) and passed, rr 3: 5 * T(2) = 15, 10 * T(2) = 30. Space:
    ;; White 11 (e4 holds a white pawn), Black 10 (d5 and f5 attacked by e4). Threats: the
    ;; knight is attacked by a pawn, r1 = (300 - 100) / 10 = 20, and undefended,
    ;; r2 = 300 / 20 = 15; the larger is 20 ("Minacce"). Phase 3:
    ;; E_W = tr((-177 * 3 - 190 * 59) / 62) = tr(-11741 / 62) = -189 (floor gives -190).
    ("pawn e4 against knight d5" "4k3/8/8/3n4/4P3/8/8/4K3 w - - 0 1"
     ((:material 100 100 300 300) (:piece-square-tables 12 12 18 24) (:mobility 0 0 16 20)
      (:king-safety -80 0 -90 0) (:pawn-structure -12 -18 0 0) (:passed-pawns 15 30 0 0)
      (:space 22 0 20 0) (:initiative 10 10 0 0) (:threats 20 20 0 0))
     -177 -190 3 -189 -189)
    ;; Doubled pawns e2 and e3. Pst: e2 (rr 1) 0 / 0, e3 (rr 2) 3 * 1 * 3 = 9 / 6. Shelter:
    ;; e2 is right in front of the king, d = 0: 10 * (3 + 0 + 3) = 60. Structure: one doubled
    ;; pawn (6 / 9) and two isolated ones (2 * 12 / 2 * 18) ("Struttura pedonale"). Only
    ;; the front pawn of a file can be passed: e3, rr 2, 5 * T(1) = 5 / 10 ("Pedoni passati").
    ;; e2 would score T(0) = 0 if it were counted, so this case cannot judge that rule; the
    ;; next one does. Space: White 10 (e2 and e3 hold white pawns). Phase 0: E_W = EG = 181.
    ("doubled pawns e2 e3" "4k3/8/8/8/8/4P3/4P3/4K3 w - - 0 1"
     ((:material 200 200 0 0) (:piece-square-tables 3 6 -6 0) (:mobility 0 0 0 0)
      (:king-safety -60 0 -90 0) (:pawn-structure -30 -45 0 0) (:passed-pawns 5 10 0 0)
      (:space 20 0 24 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     220 181 0 181 181)
    ;; Doubled pawns e4 and e5: the same rule where the rear pawn would score. Pst: e4 (rr 3)
    ;; 3 * 2 * 3 = 18 / 12, e5 (rr 4) 3 * 3 * 3 = 27 / 18, with the king's -6 / 0. Shelter: the
    ;; nearest pawn on e is e4, 3 - 0 - 1 = 2: 10 * (3 + 2 + 3) = 80. Structure: one doubled
    ;; pawn and two isolated ones. Passed: only e5, the front pawn of the file, rr 4,
    ;; 5 * T(3) = 30 / 10 * T(3) = 60; e4 has the own pawn e5 ahead of it on its file, so it is
    ;; not passed, although no black pawn stops it (counting it would add 5 * T(2) = 15 /
    ;; 10 * T(2) = 30) ("Pedoni passati"). Space: White 11 (e4 holds a white pawn; e5 is outside
    ;; S), Black 8 (d5 and f5 attacked by e4, d6 and f6 by e5). Phase 0: E_W = EG = 255.
    ("doubled pawns e4 e5" "4k3/8/8/4P3/4P3/8/8/4K3 w - - 0 1"
     ((:material 200 200 0 0) (:piece-square-tables 39 30 -6 0) (:mobility 0 0 0 0)
      (:king-safety -80 0 -90 0) (:pawn-structure -30 -45 0 0) (:passed-pawns 30 60 0 0)
      (:space 22 0 16 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     271 255 0 255 255)
    ;; Backward pawn c3: its neighbour d4 is further advanced and its stop square c4 is
    ;; attacked by the black pawn d5 (6 / 9). d4 is not backward (c3 is behind it); d5 is
    ;; isolated (12 / 18). No pawn is passed: c3 and d4 have d5 ahead, d5 has c3 ahead.
    ;; Pst: c3 (rr 2, file c) 3 * 1 * 2 = 6 / 6, d4 18 / 12, d5 (rr 3 for Black) 18 / 12.
    ;; Shelter: each king has a pawn on the d file 2 ranks ahead: 10 * (2 + 3 + 3) = 80.
    ;; Space: White 8 (c3, d4 own pawns; c4, e4 attacked by d5), Black 9 (d5 own pawn; c5, e5
    ;; attacked by d4). Phase 0: E_W = EG = 125.
    ("backward pawn c3" "4k3/8/8/3p4/3P4/2P5/8/4K3 w - - 0 1"
     ((:material 200 200 100 100) (:piece-square-tables 18 18 12 12) (:mobility 0 0 0 0)
      (:king-safety -80 0 -80 0) (:pawn-structure -6 -9 -12 -18) (:passed-pawns 0 0 0 0)
      (:space 16 0 18 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     120 125 0 125 125)
    ;; Knight g5 and queen h5 against the king g8. Pst: Ng5 8 * cent(g5) = 8 / 8, Qh5
    ;; cent 0; the black king on g8 reads g1: 6 * (2 - 1) - 0 = 6, eg 8 * cent(g1) = -16.
    ;; Mobility: the knight reaches h7 h3 f3 e4 e6 f7, 4 * (6 - 4) = 8 / 5 * 2 = 10; the
    ;; queen h6 h7 h8 h4 h3 h2 h1 g6 f7 e8 g4 f3 e2 d1 (g5 is White's), 1 * (14 - 13) = 1 / 1.
    ;; King attack on Black: the knight hits f7 and h7, the queen h7, h8 and f7: n = 2,
    ;; U = 2 * 2 + 5 * 3 = 19, 4 * 19 * 1 = 76; with the shelter of 90, -166. Phase 12:
    ;; E_W = tr((1291 * 12 + 1245 * 50) / 62) = tr(77742 / 62) = 1253.
    ("knight and queen on the king" "6k1/8/8/6NQ/8/8/8/4K3 w - - 0 1"
     ((:material 1200 1200 0 0) (:piece-square-tables 2 8 6 -16) (:mobility 9 11 0 0)
      (:king-safety -90 0 -166 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 10 10 0 0) (:threats 0 0 0 0))
     1291 1245 12 1253 1253)
    ;; Rook g1 checking the king g8, knight h5, Black to move. The zone of the black king is
    ;; Z = {g8} + its king's attacks = g8 f8 h8 f7 g7 h7: the king's own square belongs to it
    ;; ("Sicurezza del re", attacco). The rook hits g7 and g8 (k = 2), the knight g7 (k = 1):
    ;; n = 2, U = 3 * 2 + 2 * 1 = 8, 4 * 8 * 1 = 32; with the shelter of 90, -122. (Without g8
    ;; in the zone U would be 5 and the attack 20.) Pst: Rg1 0, Nh5 8 * cent(h5) = 0, Ke1 -6 /
    ;; 0; the black king on g8 reads g1: 6 / -16. Mobility: the rook reaches g2..g8, h1, f1
    ;; and e1 (its own king, outside the area), m = 9: 2 * (9 - 7) = 4 / 3 * 2 = 6; the knight
    ;; g7 f6 f4 g3, m = 4: 0 / 0. The black king attacks neither white piece: no threat.
    ;; Initiative to Black. Phase 8: E_W = tr((814 * 8 + 812 * 54) / 62) = tr(50360 / 62) =
    ;; 812, E = -812.
    ("rook checking the king, knight on the zone" "6k1/8/8/7N/8/8/8/4K1R1 b - - 0 1"
     ((:material 800 800 0 0) (:piece-square-tables -6 0 6 -16) (:mobility 4 6 0 0)
      (:king-safety -90 0 -122 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 0 0 10 10) (:threats 0 0 0 0))
     814 812 8 812 -812)
    ;; Black rook d2 next to the white king. Pst: d2 is the relative seventh rank for Black,
    ;; 20 / 20. Mobility: d3..d8, d1, e2..h2, c2..a2, m = 14: 14 / 21. The rook hits d1, e2
    ;; and f2 of the white king's zone, alone: no attack. Threats: the rook is attacked by the
    ;; white king and defended by nothing, r2 = 500 / 20 = 25; the king counts for r2, not for
    ;; r1 ("Minacce"). Phase 5: E_W = tr((-499 * 5 - 506 * 57) / 62) = tr(-31337 / 62) = -505.
    ("rook hanging next to the king" "4k3/8/8/8/8/8/3r4/4K3 w - - 0 1"
     ((:material 0 0 500 500) (:piece-square-tables -6 0 14 20) (:mobility 0 0 14 21)
      (:king-safety -90 0 -90 0) (:pawn-structure 0 0 0 0) (:passed-pawns 0 0 0 0)
      (:space 24 0 24 0) (:initiative 10 10 0 0) (:threats 25 25 0 0))
     -499 -506 5 -505 -505))
  "Positions whose every term was computed by hand from docs/valutazione.md.")

(deftest-evaluation hand-checked-tiny-positions
  (loop for (label fen terms mg eg phase white-score score) in *hand-checked-positions*
        do (let ((breakdown (breakdown-of fen)))
             (loop for (name . expected) in terms
                   do (is-equal expected (term-row breakdown name) "~A: ~(~A~)" label name))
             (is-equal *term-names* (mapcar #'first terms) "~A: all nine terms listed" label)
             (check-score label breakdown mg eg phase white-score score)
             (is-eql score (layer-evaluate (layer-position fen)) "~A" label))))

;;; --- the tables of the document ---------------------------------------------------------

(defparameter *document-centrality*
  '((-3 -2 -1 0 0 -1 -2 -3) (-2 -1 0 1 1 0 -1 -2) (-1 0 1 2 2 1 0 -1) (0 1 2 3 3 2 1 0)
    (0 1 2 3 3 2 1 0) (-1 0 1 2 2 1 0 -1) (-2 -1 0 1 1 0 -1 -2) (-3 -2 -1 0 0 -1 -2 -3))
  "cent(s) as printed in docs/valutazione.md, rank 8 first, files a to h.")

(defparameter *document-pawn-mg*
  '((0 0 0 0 0 0 0 0) (0 15 30 45 45 30 15 0) (0 12 24 36 36 24 12 0) (0 9 18 27 27 18 9 0)
    (0 6 12 18 18 12 6 0) (0 3 6 9 9 6 3 0) (0 0 0 0 0 0 0 0) (0 0 0 0 0 0 0 0))
  "The pawn table, middlegame, as printed in docs/valutazione.md, rank 8 first.")

(defparameter *document-king-mg*
  '((-64 -64 -70 -76 -76 -70 -64 -64) (-54 -54 -60 -66 -66 -60 -54 -54)
    (-44 -44 -50 -56 -56 -50 -44 -44) (-34 -34 -40 -46 -46 -40 -34 -34)
    (-24 -24 -30 -36 -36 -30 -24 -24) (-14 -14 -20 -26 -26 -20 -14 -14)
    (-4 -4 -10 -16 -16 -10 -4 -4) (6 6 0 -6 -6 0 6 6))
  "The king table, middlegame, as printed in docs/valutazione.md, rank 8 first.")

(defun document-entry (table square)
  "The entry of a printed TABLE (rank 8 first) for SQUARE."
  (nth (square-file square) (nth (- 7 (square-rank square)) table)))

(deftest :evaluation piece-square-values-equal-the-printed-tables
  (dotimes (square 64)
    (let ((cent (document-entry *document-centrality* square))
          (rank (square-rank square)))
      (flet ((value (type) (multiple-value-list (scf-ref::piece-square-value type square))))
        (is-equal (list (* 8 cent) (* 8 cent)) (value +knight+) "knight ~A" (square-name square))
        (is-equal (list (* 4 cent) (* 4 cent)) (value +bishop+) "bishop ~A" (square-name square))
        (is-equal (list (* 2 cent) (* 4 cent)) (value +queen+) "queen ~A" (square-name square))
        (is-equal (if (= rank 6) '(20 20) '(0 0)) (value +rook+) "rook ~A" (square-name square))
        (is-equal (list (document-entry *document-king-mg* square) (* 8 cent)) (value +king+)
                  "king ~A" (square-name square))
        ;; Pawn, endgame: 0, 6, 12, 18, 24, 30 on ranks 2 to 7; 0 on ranks 1 and 8.
        (is-equal (list (document-entry *document-pawn-mg* square)
                        (if (<= 1 rank 6) (* 6 (1- rank)) 0))
                  (value +pawn+) "pawn ~A" (square-name square))))))

(deftest-evaluation bare-kings-score-the-initiative-and-the-endgame-king-table
  ;; "Patte per regola": king against king is not 0 and depends on where the kings stand. The
  ;; phase is 0, so E_W = EG, and in the endgame only the initiative (10 to the side to move)
  ;; and the king's table (8 * cent, "Piece-square tables") are not 0: E_W = +-10 + 8 *
  ;; (cent(white king) - cent(black king)), with cent read from the printed table. Every
  ;; placement of the two kings on squares that do not touch, each side to move: 3612 * 2.
  (let ((positions 0))
    (dotimes (white-king 64)
      (dotimes (black-king 64)
        (when (> (max (abs (- (square-file white-king) (square-file black-king)))
                      (abs (- (square-rank white-king) (square-rank black-king))))
                 1)
          (dolist (side (list +white+ +black+))
            (let ((board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0))
                  (tables (* 8 (- (document-entry *document-centrality* white-king)
                                  (document-entry *document-centrality* black-king)))))
              (setf (aref board white-king) (make-piece +white+ +king+)
                    (aref board black-king) (make-piece +black+ +king+))
              (let* ((pos (layer-from-reference
                           (scf-ref:make-position-from-parts board side 0 +no-square+ 0 1)))
                     (white-score (if (= side +white+) (+ 10 tables) (- tables 10))))
                (incf positions)
                (is-eql (if (= side +white+) white-score (- white-score)) (layer-evaluate pos)
                        "kings ~A and ~A, ~:[Black~;White~] to move" (square-name white-king)
                        (square-name black-king) (= side +white+))))))))
    (is-eql 7224 positions "every legal placement of two bare kings, each side to move")))

(deftest :evaluation mobility-parameters-follow-their-rule
  ;; "Mobilità": M is the largest attack set of the piece on an empty board; base = floor(M/2),
  ;; the weights round(30 / M) and round(40 / M). The document prints 8, 13, 14, 27; 4, 6, 7,
  ;; 13; 4, 2, 2, 1; 5, 3, 3, 1.
  (flet ((largest-attack-set (type)
           (loop for square from 0 below 64
                 maximize (let ((board (make-array 64 :element-type '(unsigned-byte 8)
                                                      :initial-element 0)))
                            (setf (aref board square) (make-piece +white+ type))
                            (length (scf-ref::piece-attacks board square))))))
    (loop for type in (list +knight+ +bishop+ +rook+ +queen+)
          for printed-maximum in '(8 13 14 27)
          for printed-base in '(4 6 7 13)
          for printed-mg in '(4 2 2 1)
          for printed-eg in '(5 3 3 1)
          do (let ((maximum (largest-attack-set type)))
               (is-eql printed-maximum maximum "type ~D: M" type)
               (is-eql printed-base (floor maximum 2) "type ~D: base by the rule" type)
               (is-eql printed-mg (round 30 maximum) "type ~D: mg weight by the rule" type)
               (is-eql printed-eg (round 40 maximum) "type ~D: eg weight by the rule" type)
               (is-eql printed-base (aref scf-ref::**mobility-base** type) "type ~D: base" type)
               (is-eql printed-mg (aref scf-ref::**mobility-weights-mg** type) "type ~D" type)
               (is-eql printed-eg (aref scf-ref::**mobility-weights-eg** type) "type ~D" type)))))

(deftest :evaluation blend-truncates-toward-zero
  ;; "Miscela e arrotondamento", on synthetic values: MG -15, EG -14 at phase 10 give x = -878,
  ;; truncated to -14, and +878 to +14; floor would give -15 for the first.
  (is-eql -14 (scf-ref::blend-phases -15 -14 10))
  (is-eql 14 (scf-ref::blend-phases 15 14 10))
  (is-eql -15 (floor -878 62) "the floor that the definition rejects")
  (is-eql 10 (scf-ref::blend-phases 10 -500 62) "phase 62 is the middlegame score")
  (is-eql -500 (scf-ref::blend-phases 10 -500 0) "phase 0 is the endgame score"))

;;; --- properties on many positions ---------------------------------------------------------

(defun swapped-row (row)
  "A term row (WHITE-MG WHITE-EG BLACK-MG BLACK-EG) with the two colours exchanged."
  (destructuring-bind (white-mg white-eg black-mg black-eg) row
    (list black-mg black-eg white-mg white-eg)))

(deftest-evaluation colour-swap-negates-the-white-score
  ;; INV-C7: E_W(m(p)) = -E_W(p) and E(m(p)) = E(p), term by term: X(c) on m(p) equals X(not c)
  ;; on p. The positions are those of tests/test-mirror.lisp (seed *SYMMETRY-SEED*). Each layer
  ;; swaps the colours with its own code (MIRROR-POSITION, BITBOARD-MIRROR).
  (let ((fens (symmetry-fens)))
    (note "~D positions" (length fens))
    (dolist (fen fens)
      (let* ((pos (layer-position fen))
             (mirror (layer-mirror pos))
             (original (layer-breakdown pos))
             (swapped (layer-breakdown mirror)))
        (is-eql (layer-evaluate pos) (layer-evaluate mirror)
                "~A: E differs from its mirror" fen)
        (is-eql (- (getf original :white-score)) (getf swapped :white-score) "~A: E_W" fen)
        (is-eql (- (getf original :mg)) (getf swapped :mg) "~A: MG" fen)
        (is-eql (- (getf original :eg)) (getf swapped :eg) "~A: EG" fen)
        (is-eql (getf original :phase) (getf swapped :phase) "~A: phase" fen)
        (dolist (name *term-names*)
          (is-equal (swapped-row (term-row original name)) (term-row swapped name)
                    "~A: ~(~A~) is not swapped with the colours" fen name))))))

(defun file-reflection (pos)
  "A new position with the pieces of POS reflected between the a and h files, the same side to
move, no castling right and no en-passant square (neither enters the evaluation, INV-C10)."
  (let ((board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)))
    (dotimes (square 64)
      (setf (aref board (logxor square 7)) (scf-ref:piece-at pos square)))
    (scf-ref:make-position-from-parts board (scf-ref:pos-side pos) 0 +no-square+
                                      (scf-ref:pos-halfmove pos) (scf-ref:pos-fullmove pos))))

(deftest-evaluation file-reflection-keeps-the-white-score
  ;; "Simmetria dei colori": today's definition uses the files only through dc(f) and the
  ;; adjacent files, so reflecting a with h keeps E_W. A property of the definition, not an
  ;; invariant: a future term may lose it. The reflected position is built by the reference and,
  ;; for the optimized layer, converted.
  (dolist (fen (symmetry-fens))
    (let ((pos (fen-position fen)))
      (is-eql (getf (layer-breakdown (layer-from-reference pos)) :white-score)
              (getf (layer-breakdown (layer-from-reference (file-reflection pos))) :white-score)
              "~A" fen))))

(deftest-evaluation the-score-depends-only-on-placement-and-side-to-move
  ;; INV-C10: clocks, castling rights and the en-passant square do not enter.
  (loop for (fen . variants)
          in '(("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
                "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w - - 0 1"
                "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w Kq - 37 90")
               ("rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3"
                "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 3"
                "rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w - - 12 40"))
        do (let ((expected (layer-evaluate (layer-position fen))))
             (dolist (variant variants)
               (is-eql expected (layer-evaluate (layer-position variant))
                       "~A against ~A" variant fen)))))

(deftest-evaluation the-white-score-stays-within-the-limit
  ;; INV-C9: |E_W| <= 20000 on every position of the symmetry tests, and a position that the
  ;; FEN reader accepts with 47 queens reaches the clamp exactly ("Limite del punteggio").
  (dolist (fen (symmetry-fens))
    (is (<= (abs (getf (breakdown-of fen) :white-score)) 20000) "~A" fen))
  (let ((breakdown
          (breakdown-of "k7/8/QQQQQQQQ/QQQQQQQQ/QQQQQQQQ/QQQQQQQQ/QQQQQQQQ/QQQQQQQK b - - 0 1")))
    (is (> (getf breakdown :mg) 20000) "the sum before the clamp is larger than the limit")
    (is-eql 20000 (getf breakdown :white-score))
    (is-eql -20000 (getf breakdown :score) "Black to move")
    (is-false (scf-ref:mate-score-p (getf breakdown :score)) "no static score reads as mate")))

(deftest :evaluation evaluation-leaves-the-position-unchanged
  (dolist (fen (mapcar #'second *main-perft-table*))
    (let* ((pos (fen-position fen))
           (before (snapshot pos)))
      (scf-ref:evaluate-classical pos)
      (scf-ref:classical-breakdown pos)
      (is (same-state-p pos before 0) "~A" fen))))
