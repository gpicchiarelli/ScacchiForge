;;;; test-optimized-evaluation.lisp -- the classical evaluation of the optimized layer
;;;; (BITBOARD-EVALUATE, BITBOARD-EVALUATE-FROM-SCRATCH, BITBOARD-CLASSICAL-BREAKDOWN), its
;;;; tables, its incremental state and its colour swap; and the comparison of the evaluation with
;;;; the reference (suite differential).
;;;;
;;;; Suite optimized-evaluation. The expected values of the document (worked examples, positions
;;;; computed by hand, colour swap, clamp, INV-C10) judge this layer through the tests that
;;;; tests/test-evaluation.lisp defines with DEFTEST-EVALUATION, which run on both layers. This
;;;; file adds the checks of the optimized layer's own parts: its piece-square tables against
;;;; the tables printed in docs/valutazione.md, its signed tables and pawn masks against their
;;;; definitions, its parameters against their rules, the blend, the threat term with changed
;;;; piece values and the load-time check of its divisions, the two evaluations against
;;;; each other and against the breakdown, the colour swap BITBOARD-MIRROR against the
;;;; reference's MIRROR-POSITION, the consistency check of the evaluation state, and allocation.
;;;;
;;;; Suite differential (INV-C1, INV-C8). On every position compared, the breakdown of the
;;;; optimized layer must equal the reference's, term by term and colour by colour, and
;;;; BITBOARD-EVALUATE and BITBOARD-EVALUATE-FROM-SCRATCH must give the reference's
;;;; EVALUATE-CLASSICAL. The positions: the trees of the perft tables and of the special-case
;;;; positions (their FENs read from the test sources, as in tests/test-differential.lisp),
;;;; seeded random legal positions, and lockstep random playouts in which, after every make and
;;;; every unmake, the incremental state equals the from-scratch one and the reference's
;;;; material and piece-square sums. MAKE TEST runs the :STANDARD profile, thousands of
;;;; positions; MAKE DIFFERENTIAL-DEEP the :DEEP one. The seeds are declared here.

(in-package #:scacchiforge.test)

;;; --- the tables of the optimized layer ------------------------------------------------------

(defun optimized-table-entry (table colour type square)
  "The entry of the optimized layer's TABLE (a 1024-entry table indexed by piece code and square)
for a piece of COLOUR and TYPE on SQUARE."
  (aref table (+ (* 64 (make-piece colour type)) square)))

(deftest :optimized-evaluation piece-square-tables-equal-the-printed-tables
  ;; "Piece-square tables": the tables printed in docs/valutazione.md, from White's point of view;
  ;; a black piece reads its relative square, the square with its rank reflected.
  (dotimes (square 64)
    (let ((cent (document-entry *document-centrality* square))
          (rank (square-rank square)))
      (dolist (colour (list +white+ +black+))
        (let ((square-of-colour (if (= colour +white+) square (logxor square 56))))
          (flet ((value (type)
                   (list (optimized-table-entry scf-opt::**pst-mg** colour type square-of-colour)
                         (optimized-table-entry scf-opt::**pst-eg** colour type square-of-colour))))
            (is-equal (list (* 8 cent) (* 8 cent)) (value +knight+)
                      "knight ~A, colour ~D" (square-name square) colour)
            (is-equal (list (* 4 cent) (* 4 cent)) (value +bishop+)
                      "bishop ~A, colour ~D" (square-name square) colour)
            (is-equal (list (* 2 cent) (* 4 cent)) (value +queen+)
                      "queen ~A, colour ~D" (square-name square) colour)
            (is-equal (if (= rank 6) '(20 20) '(0 0)) (value +rook+)
                      "rook ~A, colour ~D" (square-name square) colour)
            (is-equal (list (document-entry *document-king-mg* square) (* 8 cent)) (value +king+)
                      "king ~A, colour ~D" (square-name square) colour)
            (is-equal (list (document-entry *document-pawn-mg* square)
                            (if (<= 1 rank 6) (* 6 (1- rank)) 0))
                      (value +pawn+) "pawn ~A, colour ~D" (square-name square) colour)))))))

(deftest :optimized-evaluation signed-tables-add-the-piece-values
  ;; "Stato incrementale": what a piece adds to PSQ-MG and PSQ-EG is sigma(c) * (V(t) + pst), and
  ;; what it adds to PHASE-RAW its phase weight.
  (let ((values '(100 300 300 500 900 0))
        (weights '(0 3 3 5 9 0)))
    (dolist (colour (list +white+ +black+))
      (loop for type from 1 to 6
            for value in values
            for weight in weights
            do (let ((sign (if (= colour +white+) 1 -1))
                     (piece (make-piece colour type)))
                 (is-eql weight (aref scf-opt::**phase-weights** piece)
                         "phase weight of piece ~D" piece)
                 (dotimes (square 64)
                   (is-eql (* sign (+ value (optimized-table-entry scf-opt::**pst-mg**
                                                                   colour type square)))
                           (optimized-table-entry scf-opt::**psq-mg** colour type square)
                           "psq-mg of piece ~D on ~A" piece (square-name square))
                   (is-eql (* sign (+ value (optimized-table-entry scf-opt::**pst-eg**
                                                                   colour type square)))
                           (optimized-table-entry scf-opt::**psq-eg** colour type square)
                           "psq-eg of piece ~D on ~A" piece (square-name square))))))
    (is-equal '(0 0 0 0) (loop for piece in '(0 7 8 15)
                               collect (aref scf-opt::**phase-weights** piece))
              "the empty square and the unused codes weigh nothing")))

(defun relative-rank-of-square (colour square)
  "The rank of SQUARE seen by COLOUR, worked out here."
  (if (= colour +white+) (square-rank square) (- 7 (square-rank square))))

(defun squares-where (predicate)
  "The bitboard of the squares that satisfy PREDICATE."
  (loop for square below 64
        when (funcall predicate square)
          sum (ash 1 square)))

(deftest :optimized-evaluation pawn-masks-follow-their-definitions
  ;; The sets of squares the pawn terms read, against their definitions in docs/valutazione.md
  ;; ("Struttura pedonale", "Pedoni passati", "Spazio", "Sicurezza del re"), square by square.
  (dotimes (file 8)
    (is-eql (squares-where (lambda (s) (= (square-file s) file)))
            (aref scf-opt::**file-masks** file) "file ~D" file)
    (is-eql (squares-where (lambda (s) (= 1 (abs (- (square-file s) file)))))
            (aref scf-opt::**adjacent-file-masks** file) "files next to ~D" file))
  (dolist (colour (list +white+ +black+))
    (dotimes (rr 8)
      (is-eql (squares-where (lambda (s) (> (relative-rank-of-square colour s) rr)))
              (aref scf-opt::**ranks-above** (+ (* colour 8) rr)) "above ~D, colour ~D" rr colour)
      (is-eql (squares-where (lambda (s) (<= (relative-rank-of-square colour s) rr)))
              (aref scf-opt::**ranks-up-to** (+ (* colour 8) rr)) "up to ~D, colour ~D" rr colour))
    (dotimes (square 64)
      (let ((rank (relative-rank-of-square colour square))
            (file (square-file square))
            (index (+ (* colour 64) square)))
        (is-eql (squares-where (lambda (s) (and (= (square-file s) file)
                                                (> (relative-rank-of-square colour s) rank))))
                (aref scf-opt::**front-spans** index) "front span of ~A, colour ~D"
                (square-name square) colour)
        (is-eql (squares-where (lambda (s) (and (<= (abs (- (square-file s) file)) 1)
                                                (> (relative-rank-of-square colour s) rank))))
                (aref scf-opt::**passed-spans** index) "passed span of ~A, colour ~D"
                (square-name square) colour)))
    (is-eql (squares-where (lambda (s) (and (<= 2 (square-file s) 5)
                                            (<= 1 (relative-rank-of-square colour s) 3))))
            (aref scf-opt::**space-masks** colour) "space of colour ~D" colour)
    (is-eql 12 (logcount (aref scf-opt::**space-masks** colour)))))

(deftest :optimized-evaluation mobility-and-king-attack-parameters-follow-their-rules
  ;; "Mobilità": M is the largest attack set of the piece on an empty board, found here with this
  ;; layer's attack functions; base = floor(M / 2), the weights round(30 / M) and round(40 / M).
  ;; "Sicurezza del re": the unit is the piece value divided by 200, rounded up.
  (flet ((largest-attack-set (type)
           (loop for square below 64
                 maximize (logcount
                           (cond ((= type +knight+) (scf-opt:knight-attacks square))
                                 ((= type +bishop+) (scf-opt:bishop-attacks square 0))
                                 ((= type +rook+) (scf-opt:rook-attacks square 0))
                                 (t (scf-opt:queen-attacks square 0)))))))
    (loop for type in (list +knight+ +bishop+ +rook+ +queen+)
          for printed-maximum in '(8 13 14 27)
          for value in '(300 300 500 900)
          do (let ((maximum (largest-attack-set type)))
               (is-eql printed-maximum maximum "type ~D: M" type)
               (is-eql (floor maximum 2) (aref scf-opt::**mobility-base** type) "type ~D" type)
               (is-eql (round 30 maximum) (aref scf-opt::**mobility-weights-mg** type)
                       "type ~D" type)
               (is-eql (round 40 maximum) (aref scf-opt::**mobility-weights-eg** type)
                       "type ~D" type)
               (is-eql (ceiling value 200) (aref scf-opt::**king-attack-units** type)
                       "type ~D" type)
               (is-eql value (aref scf-opt::**piece-values** type) "type ~D" type)))))

(deftest :optimized-evaluation blend-truncates-toward-zero
  ;; "Miscela e arrotondamento", on synthetic values: x = -878 at phase 10 gives -14, and +878
  ;; gives +14 (floor would give -15 for the first); a raw phase above 62 counts as 62; the
  ;; clamp is +-20000.
  (is-eql -14 (scf-opt::blend-and-clamp -15 -14 10))
  (is-eql 14 (scf-opt::blend-and-clamp 15 14 10))
  (is-eql 10 (scf-opt::blend-and-clamp 10 -500 62) "phase 62 is the middlegame score")
  (is-eql 10 (scf-opt::blend-and-clamp 10 -500 423) "the phase is capped at 62")
  (is-eql -500 (scf-opt::blend-and-clamp 10 -500 0) "phase 0 is the endgame score")
  (is-eql 20000 (scf-opt::blend-and-clamp 30000 30000 31))
  (is-eql -20000 (scf-opt::blend-and-clamp -30000 -30000 31)))

(deftest :optimized-evaluation threat-term-follows-the-piece-values
  ;; "Minacce" and INV-X7 (a parameter changes without a change of code): the cheapest attacker
  ;; is the smallest value among the attacking pieces, whatever the values are, and the two
  ;; divisions must be exact ("Divisioni"). The knight c3 and the bishop f3 attack the rook d5,
  ;; which the pawn c6 defends, so only r1 counts: (500 - 300) / 10 = 20 with today's values.
  ;; With a bishop, or a knight, of 200 that piece is the cheapest attacker and r1 = (500 - 200)
  ;; / 10 = 30. The load-time check of the divisions passes with today's values and stops on a
  ;; bishop of 325 ((325 - 300) / 10) or of 310 (310 / 20). Every value is restored.
  (let* ((values scf-opt::**piece-values**)
         (saved (copy-seq values))
         (bbp (scf-opt:bitboard-from-reference
               (fen-position "4k3/8/2p5/3r4/8/2N2B2/8/4K3 w - - 0 1"))))
    (flet ((threat-row ()
             (rest (assoc :threats (getf (scf-opt:bitboard-classical-breakdown bbp) :terms)))))
      (unwind-protect
           (progn
             (is-equal '(20 20 0 0) (threat-row) "today's values")
             (is-true (scf-opt::check-exact-threat-divisions) "today's values divide exactly")
             (setf (aref values +bishop+) 200)
             (is-equal '(30 30 0 0) (threat-row) "a bishop of 200")
             (replace values saved)
             (setf (aref values +knight+) 200)
             (is-equal '(30 30 0 0) (threat-row) "a knight of 200")
             (replace values saved)
             (setf (aref values +bishop+) 325)
             (signals error (scf-opt::check-exact-threat-divisions))
             (setf (aref values +bishop+) 310)
             (signals error (scf-opt::check-exact-threat-divisions)))
        (replace values saved)))
    (is-equal '(0 100 300 300 500 900 0) (coerce scf-opt::**piece-values** 'list)
              "the values are restored")))

;;; --- the two evaluations, the breakdown and the state ---------------------------------------

(deftest :optimized-evaluation the-two-evaluations-and-the-breakdown-agree
  ;; BITBOARD-EVALUATE reads material, piece-square tables and phase from the incremental state;
  ;; BITBOARD-EVALUATE-FROM-SCRATCH and the breakdown compute them from the bitboards.
  (let ((fens (symmetry-fens)))
    (note "~D positions" (length fens))
    (dolist (fen fens)
      (let ((bbp (scf-opt:bitboard-from-reference (fen-position fen))))
        (is-eql (scf-opt:bitboard-evaluate bbp) (scf-opt:bitboard-evaluate-from-scratch bbp)
                "~A: incremental and from scratch" fen)
        (is-eql (scf-opt:bitboard-evaluate bbp)
                (getf (scf-opt:bitboard-classical-breakdown bbp) :score)
                "~A: evaluation and breakdown" fen)
        (is-equal (multiple-value-list (scf-opt:bitboard-compute-evaluation-state bbp))
                  (list (scf-opt:bbp-psq-mg bbp) (scf-opt:bbp-psq-eg bbp)
                        (scf-opt:bbp-phase-raw bbp))
                  "~A: the state of the converted position" fen)))))

(deftest :optimized-evaluation evaluation-leaves-the-position-unchanged
  (dolist (fen (mapcar #'second *main-perft-table*))
    (let* ((bbp (scf-opt:bitboard-from-reference (fen-position fen)))
           (before (scf-opt:bitboard-clone bbp)))
      (scf-opt:bitboard-evaluate bbp)
      (scf-opt:bitboard-evaluate-from-scratch bbp)
      (scf-opt:bitboard-classical-breakdown bbp)
      (is (and (scf-opt:bitboard-equal-p bbp before) (zerop (scf-opt:bbp-ply bbp))) "~A" fen))))

(deftest :optimized-evaluation consistency-check-catches-a-wrong-evaluation-state
  ;; With SCF_EVAL_STATE=recompute make and unmake do not keep the state, and the check does
  ;; not read it: a wrong state is then not a problem.
  (flet ((fresh () (scf-opt:bitboard-from-reference (scf-ref:start-position)))
         (problems-of (bbp) (nth-value 1 (scf-opt:bitboard-consistent-p bbp))))
    (is-false (problems-of (fresh)))
    (if (incremental-evaluation-state-p)
        (progn
          (let ((bbp (fresh)))
            (incf (scf-opt:bbp-psq-mg bbp))
            (is (problems-of bbp) "a wrong psq-mg"))
          (let ((bbp (fresh)))
            (decf (scf-opt:bbp-psq-eg bbp) 100)
            (is (problems-of bbp) "a wrong psq-eg"))
          (let ((bbp (fresh)))
            (incf (scf-opt:bbp-phase-raw bbp) 3)
            (is (problems-of bbp) "a wrong raw phase")))
        (let ((bbp (fresh)))
          (incf (scf-opt:bbp-psq-mg bbp))
          (is-false (problems-of bbp) "recompute build: the state is not checked")))))

(deftest :optimized-evaluation the-evaluation-state-follows-the-build
  ;; EXP-0002: in the default build make keeps the state, and 1.e4 changes it (the pawn's
  ;; piece-square entry); with SCF_EVAL_STATE=recompute make leaves it as the conversion set it.
  ;; The evaluation is the same in both.
  (let* ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position)))
         (before (list (scf-opt:bbp-psq-mg bbp) (scf-opt:bbp-psq-eg bbp)
                       (scf-opt:bbp-phase-raw bbp))))
    (scf-opt:bitboard-make-move bbp (layer-parse-move bbp "e2e4"))
    (let ((after (list (scf-opt:bbp-psq-mg bbp) (scf-opt:bbp-psq-eg bbp)
                       (scf-opt:bbp-phase-raw bbp))))
      (if (incremental-evaluation-state-p)
          (is (not (equal before after)) "incremental build: make updates the state")
          (is-equal before after "recompute build: make leaves the state alone")))
    (is-eql (scf-opt:bitboard-evaluate-from-scratch bbp) (scf-opt:bitboard-evaluate bbp)
            "the two evaluations agree in either build")))

(deftest :optimized-evaluation make-and-unmake-keep-the-evaluation-state
  ;; INV-C8 and INV-C2 on every legal move of the fuzzer's start positions, two plies deep; the
  ;; differential suite does the same on many more positions.
  (let ((moves 0))
    (dolist (fen *fuzz-fens*)
      (let* ((bbp (scf-opt:bitboard-from-reference (fen-position fen)))
             (before (scf-opt:bitboard-clone bbp)))
        (dolist (first (scf-opt:bitboard-legal-moves bbp))
          (scf-opt:bitboard-make-move bbp first)
          (let ((middle (scf-opt:bitboard-clone bbp)))
            (dolist (second (scf-opt:bitboard-legal-moves bbp))
              (scf-opt:bitboard-make-move bbp second)
              (incf moves)
              (when (incremental-evaluation-state-p)
                (is-equal (multiple-value-list (scf-opt:bitboard-compute-evaluation-state bbp))
                          (list (scf-opt:bbp-psq-mg bbp) (scf-opt:bbp-psq-eg bbp)
                                (scf-opt:bbp-phase-raw bbp))
                          "~A: after ~A ~A" fen (move-to-string first) (move-to-string second)))
              (scf-opt:bitboard-unmake-move bbp)
              (is (scf-opt:bitboard-equal-p bbp middle) "~A: unmake of ~A after ~A" fen
                  (move-to-string second) (move-to-string first))))
          (scf-opt:bitboard-unmake-move bbp)
          (is (scf-opt:bitboard-equal-p bbp before) "~A: unmake of ~A" fen
              (move-to-string first)))))
    (note "~D moves made and unmade" moves)))

;;; --- the colour swap ------------------------------------------------------------------------

(deftest :optimized-evaluation bitboard-mirror-equals-the-reference-mirror
  ;; BITBOARD-MIRROR is this layer's own code; the converted reference mirror judges it.
  (let ((fens (symmetry-fens)))
    (dolist (fen fens)
      (let* ((pos (fen-position fen))
             (bbp (scf-opt:bitboard-from-reference pos))
             (before (scf-opt:bitboard-clone bbp))
             (mirror (scf-opt:bitboard-mirror bbp)))
        (is (scf-opt:bitboard-equal-p bbp before) "~A: mirroring changed the position" fen)
        (is (scf-opt:bitboard-equal-p mirror (scf-opt:bitboard-from-reference
                                              (scf-ref:mirror-position pos)))
            "~A: the bitboard mirror differs from the reference mirror" fen)
        (is (scf-opt:bitboard-consistent-p mirror) "~A: the mirror is not consistent" fen)
        (is (scf-opt:bitboard-equal-p bbp (scf-opt:bitboard-mirror mirror))
            "~A: mirroring twice does not give the position back" fen)))))

;;; --- allocation -----------------------------------------------------------------------------

(deftest :optimized-evaluation evaluation-allocates-nothing-after-warm-up
  ;; As for perft (test optimized/perft-allocates-nothing-after-warm-up): SB-EXT:GET-BYTES-CONSED
  ;; moves one allocation region at a time, so the calls are many. Over 400000 calls of each
  ;; evaluation, one 16-byte object per call would show as at least 6 MB; the bound of 1 MiB
  ;; means less than 3 bytes per call.
  (let* ((positions (map 'vector (lambda (entry)
                                   (scf-opt:bitboard-from-reference (fen-position (cdr entry))))
                         scf-ref:*standard-positions*))
         (rounds (ceiling 400000 (length positions)))
         (sum 0))
    (flet ((run ()
             (dotimes (round rounds)
               (loop for bbp across positions
                     do (incf sum (scf-opt:bitboard-evaluate bbp))
                        (incf sum (scf-opt:bitboard-evaluate-from-scratch bbp))))))
      (run)
      (let ((before (sb-ext:get-bytes-consed)))
        (run)
        (let ((consed (- (sb-ext:get-bytes-consed) before))
              (calls (* 2 rounds (length positions))))
          (note "~D evaluations, ~D bytes consed" calls consed)
          (is (<= consed (* 1024 1024)) "~D bytes consed over ~D evaluations" consed calls))))
    (is (integerp sum))))

;;; --- the comparison with the reference (suite differential) ---------------------------------

(defun breakdown-differences (reference optimized)
  "The parts on which the breakdown property lists REFERENCE and OPTIMIZED differ: the name of
each term whose row differs, then each total that differs, as a list of strings."
  (append (loop for (name . row) in (getf reference :terms)
                for other = (rest (assoc name (getf optimized :terms)))
                unless (equal row other)
                  collect (format nil "~(~A~) ~S against ~S" name row other))
          (loop for key in '(:mg :eg :phase :white-score :score)
                unless (eql (getf reference key) (getf optimized key))
                  collect (format nil "~(~A~) ~S against ~S" key (getf reference key)
                                  (getf optimized key)))))

(defun check-evaluation-agrees (pos bbp)
  "Compare the classical evaluation of the reference position POS and of the bitboard position
BBP, which hold the same position: the breakdown term by term, and the two evaluations of the
optimized layer with the reference's score. Record a difference with DIFFERENTIAL-FAILURE.
Returns the reference's breakdown."
  (let* ((reference (scf-ref:classical-breakdown pos))
         (optimized (scf-opt:bitboard-classical-breakdown bbp))
         (differences (breakdown-differences reference optimized))
         (score (getf reference :score)))
    (incf *assertions* 3)
    (when differences
      (differential-failure "~A: the evaluations differ: ~{~A~^; ~}"
                            (scf-ref:position-to-fen pos) differences))
    (unless (= score (scf-opt:bitboard-evaluate bbp))
      (differential-failure "~A: BITBOARD-EVALUATE gives ~D, the reference ~D"
                            (scf-ref:position-to-fen pos) (scf-opt:bitboard-evaluate bbp) score))
    (unless (= score (scf-opt:bitboard-evaluate-from-scratch bbp))
      (differential-failure "~A: BITBOARD-EVALUATE-FROM-SCRATCH gives ~D, the reference ~D"
                            (scf-ref:position-to-fen pos)
                            (scf-opt:bitboard-evaluate-from-scratch bbp) score))
    reference))

(defun check-evaluation-tree (pos bbp depth)
  "CHECK-EVALUATION-AGREES on POS / BBP and on every position reachable from it in fewer than
DEPTH plies, the moves made on both layers. Returns the number of positions compared."
  (check-evaluation-agrees pos bbp)
  (let ((positions 1))
    (when (> depth 1)
      (dolist (move (scf-ref:legal-moves pos))
        (scf-ref:make-move pos move)
        (scf-opt:bitboard-make-move bbp move)
        (incf positions (check-evaluation-tree pos bbp (1- depth)))
        (scf-ref:unmake-move pos)
        (scf-opt:bitboard-unmake-move bbp)))
    positions))

(deftest :differential evaluation-agrees-on-the-perft-and-special-case-positions
  (with-differential-test ()
    (let ((depth (differential-scale 2 3))
          (positions 0))
      (dolist (fen (append (mapcar #'second (append *main-perft-table* *special-perft-table*))
                           (special-case-fens) *round-trip-fens* *fuzz-fens*))
        (let ((pos (fen-position fen)))
          (incf positions (check-evaluation-tree pos (scf-opt:bitboard-from-reference pos)
                                                 depth))))
      (note "~D positions within ~D plies of the perft and special-case positions" positions
            (1- depth))
      (is (plusp positions)))))

(deftest :differential evaluation-agrees-on-random-positions
  (with-differential-test ()
    (let* ((seed 20261005)
           (rng (make-rng seed))
           (count (differential-scale 2000 100000)))
      (dotimes (i count)
        (let ((pos (scf-ref:random-legal-position *fuzz-fens* rng 120)))
          (check-evaluation-agrees pos (scf-opt:bitboard-from-reference pos))))
      (note "seed ~D: ~D random legal positions" seed count))))

(defun reference-material-and-pst (breakdown)
  "The material plus piece-square terms of the reference's BREAKDOWN of a position, White minus
Black, in the middlegame and in the endgame, and its phase (capped), as three values: what the
incremental state of the optimized layer holds."
  (let* ((material (rest (assoc :material (getf breakdown :terms))))
         (pst (rest (assoc :piece-square-tables (getf breakdown :terms)))))
    (destructuring-bind (wm-mg wm-eg bm-mg bm-eg) material
      (destructuring-bind (wp-mg wp-eg bp-mg bp-eg) pst
        (values (- (+ wm-mg wp-mg) (+ bm-mg bp-mg))
                (- (+ wm-eg wp-eg) (+ bm-eg bp-eg))
                (getf breakdown :phase))))))

(defun evaluation-state-problems (bbp)
  "The ways in which the evaluation state of BBP differs from the one computed from scratch; none
in the build with SCF_EVAL_STATE=recompute, which does not keep the state."
  (when (incremental-evaluation-state-p)
    (evaluation-state-differences bbp)))

(defun evaluation-state-differences (bbp)
  "The ways in which the evaluation state of BBP differs from the one computed from scratch."
  (multiple-value-bind (mg eg phase) (scf-opt:bitboard-compute-evaluation-state bbp)
    (unless (and (= mg (scf-opt:bbp-psq-mg bbp)) (= eg (scf-opt:bbp-psq-eg bbp))
                 (= phase (scf-opt:bbp-phase-raw bbp)))
      (list (format nil "incremental state ~D ~D ~D, from scratch ~D ~D ~D"
                    (scf-opt:bbp-psq-mg bbp) (scf-opt:bbp-psq-eg bbp)
                    (scf-opt:bbp-phase-raw bbp) mg eg phase)))))

(deftest :differential evaluation-in-lockstep-playouts
  ;; INV-C8: seeded random games played on both layers. At every position the evaluations are
  ;; compared (CHECK-EVALUATION-AGREES) and the incremental state of the optimized layer against
  ;; its from-scratch computation and against the reference's material and piece-square sums;
  ;; then every legal move is made and unmade on the optimized layer, with the state compared
  ;; after the make and after the unmake. At the end of a game every move is unmade.
  (with-differential-test ()
    (let* ((seed 20261006)
           (rng (make-rng seed))
           (games (differential-scale 6 120))
           (positions 0)
           (moves 0))
      (dolist (fen *fuzz-fens*)
        (dotimes (game games)
          (let* ((pos (fen-position fen))
                 (bbp (scf-opt:bitboard-from-reference pos))
                 (initial (scf-opt:bitboard-clone bbp))
                 (plies 0))
            (loop
              (incf positions)
              (incf *assertions* 2)
              (multiple-value-bind (mg eg phase)
                  (reference-material-and-pst (check-evaluation-agrees pos bbp))
                (unless (or (not (incremental-evaluation-state-p))
                            (and (= mg (scf-opt:bbp-psq-mg bbp)) (= eg (scf-opt:bbp-psq-eg bbp))
                                 (= phase (min 62 (scf-opt:bbp-phase-raw bbp)))))
                  (differential-failure "~A: incremental state ~D ~D ~D, reference ~D ~D ~D"
                                        (scf-ref:position-to-fen pos) (scf-opt:bbp-psq-mg bbp)
                                        (scf-opt:bbp-psq-eg bbp) (scf-opt:bbp-phase-raw bbp)
                                        mg eg phase)))
              (let ((problems (evaluation-state-problems bbp)))
                (when problems
                  (differential-failure "~A: ~{~A~^; ~}" (scf-ref:position-to-fen pos) problems)))
              (let ((legal (scf-opt:bitboard-legal-moves bbp))
                    (snapshot (scf-opt:bitboard-clone bbp)))
                (dolist (move legal)
                  (scf-opt:bitboard-make-move bbp move)
                  (incf moves)
                  (incf *assertions* 2)
                  (let ((problems (evaluation-state-problems bbp)))
                    (when problems
                      (differential-failure "~A, after ~A: ~{~A~^; ~}"
                                            (scf-ref:position-to-fen pos) (move-to-string move)
                                            problems)))
                  (scf-opt:bitboard-unmake-move bbp)
                  (unless (scf-opt:bitboard-equal-p bbp snapshot)
                    (differential-failure "~A: unmake of ~A did not restore the state"
                                          (scf-ref:position-to-fen pos) (move-to-string move))))
                (when (or (null legal) (>= plies 120))
                  (return))
                (let ((move (rng-pick rng legal)))
                  (scf-ref:make-move pos move)
                  (scf-opt:bitboard-make-move bbp move)
                  (incf plies))))
            (dotimes (i plies)
              (scf-opt:bitboard-unmake-move bbp))
            (incf *assertions*)
            (unless (and (scf-opt:bitboard-equal-p bbp initial) (zerop (scf-opt:bbp-ply bbp)))
              (differential-failure "~A: unmaking a whole game of ~D plies did not restore it"
                                    fen plies)))))
      (note "seed ~D: ~D positions compared with the reference, ~D moves made and unmade"
            seed positions moves)
      (is (> positions (differential-scale 5000 100000)) "~D positions" positions))))
