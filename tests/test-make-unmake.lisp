;;;; test-make-unmake.lisp -- make and unmake restore the exact prior state.

(in-package #:scacchiforge.test)

(defun snapshot (pos)
  "A copy of the full state of POS to compare with after make/unmake."
  (scf-ref:clone-position pos))

(defun same-state-p (pos snapshot ply)
  "True when POS has the state of SNAPSHOT and the undo depth PLY."
  (and (scf-ref:positions-equal-p pos snapshot) (= (scf-ref:pos-ply pos) ply)))

(deftest :make-unmake every-legal-move-is-undone-exactly
  (dolist (fen *fuzz-fens*)
    (let* ((pos (fen-position fen))
           (before (snapshot pos)))
      (dolist (move (scf-ref:legal-moves pos))
        (scf-ref:make-move pos move)
        (is-false (scf-ref:positions-equal-p pos before)
                  "~A: ~A changed nothing" fen (move-to-string move))
        (scf-ref:unmake-move pos)
        (is (same-state-p pos before 0) "~A: unmake of ~A" fen (move-to-string move))))))

(deftest :make-unmake two-levels-deep-are-undone-exactly
  (dolist (fen *fuzz-fens*)
    (let* ((pos (fen-position fen))
           (before (snapshot pos)))
      (dolist (first (scf-ref:legal-moves pos))
        (scf-ref:make-move pos first)
        (let ((middle (snapshot pos)))
          (dolist (second (scf-ref:legal-moves pos))
            (scf-ref:make-move pos second)
            (scf-ref:unmake-move pos)
            (is (same-state-p pos middle 1)
                "~A: ~A ~A" fen (move-to-string first) (move-to-string second))))
        (scf-ref:unmake-move pos))
      (is (same-state-p pos before 0)))))

(deftest :make-unmake special-moves-are-undone
  (dolist (case '(("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1g1")
                  ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1c1")
                  ("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "e8g8")
                  ("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "e8c8")
                  ("8/8/8/K2pP3/8/8/8/7k w - d6 0 1" "e5d6")
                  ("8/8/8/2k5/3Pp3/8/8/4K3 b - d3 0 1" "e4d3")
                  ("1n5k/P7/8/8/8/8/8/K7 w - - 0 1" "a7b8q")
                  ("1n5k/P7/8/8/8/8/8/K7 w - - 0 1" "a7a8n")
                  ("k7/8/8/8/8/8/p6K/1N6 b - - 0 1" "a2b1r")
                  ("r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1" "g2h1")
                  ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "h1h8")
                  ("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" "e2e4")))
    (destructuring-bind (fen text) case
      (let* ((pos (fen-position fen))
             (before (snapshot pos)))
        (play pos text)
        (scf-ref:unmake-move pos)
        (is (same-state-p pos before 0) "~A ~A" fen text)
        (is-equal fen (scf-ref:position-to-fen pos))))))

(deftest :make-unmake clocks-and-move-number
  (let ((pos (scf-ref:start-position)))
    (play pos "g1f3")
    (is-eql 1 (scf-ref:pos-halfmove pos) "a quiet piece move increments the clock")
    (is-eql 1 (scf-ref:pos-fullmove pos) "the number advances after Black's move only")
    (play pos "g8f6")
    (is-eql 2 (scf-ref:pos-halfmove pos))
    (is-eql 2 (scf-ref:pos-fullmove pos))
    (play pos "e2e4")
    (is-eql 0 (scf-ref:pos-halfmove pos) "a pawn move resets the clock")
    (play pos "f6e4")
    (is-eql 0 (scf-ref:pos-halfmove pos) "a capture resets the clock")
    (is-eql 3 (scf-ref:pos-fullmove pos))
    (scf-ref:unmake-move pos)
    (is-eql 2 (scf-ref:pos-fullmove pos) "unmaking Black's move gives back the number")
    (is-eql 0 (scf-ref:pos-halfmove pos) "and the clock after e2e4")))

(deftest :make-unmake clocks-stop-at-the-largest-value-a-fen-can-hold
  ;; PARSE-FEN accepts clocks up to +MAX-CLOCK+ and MAKE-MOVE counts no further, so a move
  ;; from a position at the limit gives a position whose FEN is accepted again, and unmake
  ;; gives back the exact clocks.
  (is-eql 9999999 scf-ref:+max-clock+ "seven digits, the most a FEN clock field may have")
  (loop for (fen move expected)
          in '(("4k3/8/8/8/8/8/8/R3K3 w - - 9999999 5" "a1a2"
                "4k3/8/8/8/8/8/R7/4K3 b - - 9999999 5")
               ("4k3/8/8/8/8/8/8/R3K3 w - - 9999998 5" "a1a2"
                "4k3/8/8/8/8/8/R7/4K3 b - - 9999999 5")
               ("4k3/8/8/8/8/8/8/R3K3 b - - 0 9999999" "e8e7"
                "8/4k3/8/8/8/8/8/R3K3 w - - 1 9999999")
               ("4k3/8/8/8/8/8/8/R3K3 b - - 0 9999998" "e8e7"
                "8/4k3/8/8/8/8/8/R3K3 w - - 1 9999999")
               ("4k3/8/8/8/8/8/8/R3K3 b - - 9999999 9999999" "e8d8"
                "3k4/8/8/8/8/8/8/R3K3 w - - 9999999 9999999"))
        do (let* ((pos (fen-position fen))
                  (before (snapshot pos)))
             (play pos move)
             (let ((after (scf-ref:position-to-fen pos)))
               (is-equal expected after "~A then ~A" fen move)
               (is-equal after (scf-ref:position-to-fen (scf-ref:parse-fen after))
                         "the FEN after ~A is accepted and read back unchanged" move)
               (is-equal '() (scf-ref:position-invariant-violations pos)
                         "invariants after ~A ~A" fen move))
             (scf-ref:unmake-move pos)
             (is (same-state-p pos before 0) "unmake of ~A from ~A" move fen)
             (is-equal fen (scf-ref:position-to-fen pos)))))

(deftest :make-unmake king-squares-follow-the-kings
  (let ((pos (fen-position "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")))
    (play pos "e1g1")
    (is-eql +g1+ (scf-ref:king-square pos +white+))
    (scf-ref:unmake-move pos)
    (is-eql +e1+ (scf-ref:king-square pos +white+))
    (play pos "e1e2" "e8d8")
    (is-eql +e2+ (scf-ref:king-square pos +white+))
    (is-eql +d8+ (scf-ref:king-square pos +black+))))

(deftest :make-unmake the-undo-stack-grows-past-its-initial-capacity
  ;; 400 plies of two kings and a rook shuffling: far beyond the 64 slots a position starts
  ;; with. The rook moves keep the position repeating, which is fine: repetition is not a rule here.
  (let* ((pos (fen-position "4k3/8/8/8/8/8/8/R3K3 w - - 0 1"))
         (before (snapshot pos)))
    (dotimes (i 100)
      (play pos "a1a2" "e8e7" "a2a1" "e7e8"))
    (is-eql 400 (scf-ref:pos-ply pos))
    (is (= (scf-ref:pos-key pos) (scf-ref:compute-key pos)))
    (dotimes (i 400)
      (scf-ref:unmake-move pos))
    (is (same-state-p pos before 0) "400 plies unmade")))

(deftest :make-unmake misuse-is-refused-with-a-clean-error
  (let ((pos (scf-ref:start-position)))
    (signals scf-ref:position-error (scf-ref:unmake-move pos))
    (signals scf-ref:position-error
      (scf-ref:make-move pos (encode-move +e4+ +e5+ 0 0)))
    (is (same-state-p pos (scf-ref:start-position) 0) "the failed calls changed nothing")))

(deftest :make-unmake clone-is-independent
  (let* ((pos (scf-ref:start-position))
         (copy (scf-ref:clone-position pos)))
    (is (scf-ref:positions-equal-p pos copy))
    (play copy "e2e4")
    (is-equal scf-ref:*start-fen* (scf-ref:position-to-fen pos) "the original is untouched")
    (is-eql 0 (scf-ref:pos-ply (scf-ref:clone-position copy)) "a clone starts with an empty stack")
    (is-false (scf-ref:positions-equal-p pos copy))))

;;; --- random playouts ----------------------------------------------------------------------

(deftest :make-unmake invariants-hold-along-seeded-random-playouts
  (let ((result (scf-ref:fuzz-playouts *fuzz-fens* 20241003 :games 25 :max-plies 120)))
    (note "~D playouts, ~D positions checked, ~D checkmates, ~D stalemates"
          (getf result :games) (getf result :positions)
          (getf result :checkmates) (getf result :stalemates))
    (is-eql (* 25 (length *fuzz-fens*)) (getf result :games))
    (is (> (getf result :positions) 10000))))

(deftest :make-unmake move-level-invariants-hold-along-random-playouts
  ;; DEEP checks every pseudo-legal move of every position, more work per position than the
  ;; structural checks alone, so fewer playouts.
  (let ((result (scf-ref:fuzz-playouts *fuzz-fens* 7 :games 3 :max-plies 60 :deep t)))
    (note "~D playouts, ~D positions checked move by move" (getf result :games)
          (getf result :positions))
    (is (> (getf result :positions) 1000))))

(deftest :make-unmake playouts-are-reproducible-from-the-seed
  (flet ((run (seed)
           (let ((rng (make-rng seed)))
             (multiple-value-bind (final plies outcome moves)
                 (scf-ref:random-playout (scf-ref:start-position) rng 80)
               (list (scf-ref:position-to-fen final) plies outcome moves)))))
    (is-equal (run 99) (run 99) "the same seed gives the same game")
    (is-false (equal (run 99) (run 100)) "another seed gives another game")))

(deftest :make-unmake the-fuzzer-reaches-terminal-positions
  ;; From a nearly finished position random play must end in mate or stalemate sometimes.
  (let ((result (scf-ref:fuzz-playouts '("7k/5Q2/8/8/8/8/8/K7 w - - 0 1"
                                         "6k1/5ppp/8/8/8/8/5PPP/R3K3 w - - 0 1")
                                       5 :games 60 :max-plies 80)))
    (is (plusp (+ (getf result :checkmates) (getf result :stalemates)))
        "no game ended in checkmate or stalemate: ~S" result)))

(deftest :make-unmake the-invariant-checker-catches-corruption
  ;; A test of the tester: damaged positions must be reported, not accepted.
  (flet ((violations (pos) (scf-ref:position-invariant-violations pos :moves nil))
         (fresh () (fen-position "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")))
    (is-false (violations (fresh)) "the undamaged position is clean")
    (let ((pos (fresh)))
      (setf (aref (scf-ref:pos-board pos) +a1+) +empty+)
      (is (violations pos) "a rook removed behind the castling right"))
    (let ((pos (fresh)))
      (setf (scf-ref:pos-key pos) (logxor (scf-ref:pos-key pos) 1))
      (is (violations pos) "a wrong key"))
    (let ((pos (fresh)))
      (setf (aref (scf-ref:pos-board pos) +e4+) +white-pawn+
            (aref (scf-ref:pos-board pos) +e1+) +empty+
            (aref (scf-ref:pos-board pos) +e3+) +white-king+)
      (is (violations pos) "the cached king square no longer matches the board"))
    (let ((pos (fresh)))
      (setf (aref (scf-ref:pos-board pos) +a8+) +white-pawn+)
      (is (violations pos) "a pawn on the last rank"))
    (let ((pos (fresh)))
      (setf (aref (scf-ref:pos-board pos) +e5+) +white-rook+)
      (setf (scf-ref:pos-key pos) (scf-ref:compute-key pos))
      (is (violations pos) "the black king is in check while White is to move"))
    (signals scf-ref:invariant-violation
      (let ((pos (fresh)))
        (setf (scf-ref:pos-castling pos) 0
              (scf-ref:pos-en-passant pos) +e3+)
        (scf-ref:check-position-invariants pos :moves nil)))))

(deftest :make-unmake attack-test-and-generation-test-agree
  ;; Two different algorithms decide whether a king is attacked; they must never disagree.
  (let ((rng (make-rng 31337)))
    (dotimes (i 300)
      (let ((pos (scf-ref:random-legal-position *fuzz-fens* rng 60)))
        (dolist (colour (list +white+ +black+))
          (is-eql (and (scf-ref:king-attacked-p pos colour) t)
                  (and (scf-ref:king-attacked-by-generation-p pos colour) t)
                  "~A, colour ~D" (scf-ref:position-to-fen pos) colour))))))
