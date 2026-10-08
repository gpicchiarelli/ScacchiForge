;;;; test-mirror.lisp -- the colour swap of the reference model (MIRROR-POSITION, MIRROR-MOVE).
;;;;
;;;; The colour swap m(p) flips the board vertically and exchanges the colours, the side to
;;;; move and the castling rights, and reflects the en-passant square (docs/valutazione.md,
;;;; "Simmetria dei colori"). Chess is symmetric under it, so on every position:
;;;;  - m(m(p)) = p, and m(p) is a legal position;
;;;;  - m(p) is the position of MIRROR-FEN (tests/test-perft.lisp), which swaps the FEN text;
;;;;  - the legal moves of m(p) are the mirrored legal moves of p;
;;;;  - the perft counts of m(p) and p are equal.
;;;; The positions: the perft tables, the special-case suites (their FENs read from the test
;;;; sources, SPECIAL-CASE-FENS in tests/test-differential.lisp), the fuzzer's start positions,
;;;; and random legal positions drawn with the seed declared below. The evaluation's symmetry
;;;; (INV-C7) is checked on the same positions in tests/test-evaluation.lisp.

(in-package #:scacchiforge.test)

(defparameter *symmetry-seed* 20261004
  "Seed of the random legal positions of the colour-swap and evaluation-symmetry tests.")

(defparameter *symmetry-random-positions* 300
  "How many random legal positions those tests draw, each after 0 to 120 random plies.")

(defun symmetry-fens ()
  "The FENs of the colour-swap tests, without duplicates: the perft tables, the special-case
suites, the fuzzer's start positions, then *SYMMETRY-RANDOM-POSITIONS* random legal positions
reached from those start positions with a generator seeded with *SYMMETRY-SEED*."
  (let ((rng (make-rng *symmetry-seed*)))
    (remove-duplicates
     (append (mapcar #'second *main-perft-table*)
             (mapcar #'second *special-perft-table*)
             (special-case-fens)
             *fuzz-fens*
             (loop repeat *symmetry-random-positions*
                   collect (scf-ref:position-to-fen
                            (scf-ref:random-legal-position *fuzz-fens* rng 120))))
     :test #'string= :from-end t)))

(deftest :mirror mirror-move-reflects-both-squares-and-keeps-the-rest
  (let ((move (encode-move +e2+ +e4+ 0 +flag-double-push+)))
    (is-equal "e7e5" (move-to-string (scf-ref:mirror-move move)))
    (is-eql +flag-double-push+ (move-flags (scf-ref:mirror-move move)))
    (is-eql move (scf-ref:mirror-move (scf-ref:mirror-move move))))
  (let ((promotion (encode-move +b7+ +a8+ +queen+ +flag-capture+)))
    (is-equal "b2a1q" (move-to-string (scf-ref:mirror-move promotion)))
    (is-eql +flag-capture+ (move-flags (scf-ref:mirror-move promotion)))))

(deftest :mirror mirror-of-the-start-position-is-the-start-position-with-black-to-move
  (let ((mirror (scf-ref:mirror-position (scf-ref:start-position))))
    (is-equal "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1"
              (scf-ref:position-to-fen mirror))
    (is-eql (scf-ref:compute-key mirror) (scf-ref:pos-key mirror))))

(deftest :mirror mirror-swaps-castling-rights-and-reflects-en-passant
  (is-equal "r3k2r/8/8/8/8/8/8/R3K3 b Qkq - 0 1"
            (scf-ref:position-to-fen
             (scf-ref:mirror-position (fen-position "r3k3/8/8/8/8/8/8/R3K2R w KQq - 0 1"))))
  ;; After e2e4 the en-passant square e3 becomes e6, with White to move.
  (is-equal "4k3/8/8/4p3/3P4/8/8/4K3 w - e6 0 1"
            (scf-ref:position-to-fen
             (scf-ref:mirror-position (fen-position "4k3/8/8/3p4/4P3/8/8/4K3 b - e3 0 1")))))

(deftest :mirror mirror-is-an-involution-and-gives-legal-positions
  (let ((fens (symmetry-fens)))
    (note "~D positions" (length fens))
    (dolist (fen fens)
      (let* ((pos (fen-position fen))
             (before (snapshot pos))
             (mirror (scf-ref:mirror-position pos)))
        (is (same-state-p pos before 0) "~A: mirroring changed the position" fen)
        (is-eql nil (scf-ref:position-invariant-violations mirror :moves nil)
                "~A: the mirror is not a legal position" fen)
        (is-false (scf-ref:positions-equal-p mirror pos) "~A equals its own mirror" fen)
        (is (scf-ref:positions-equal-p pos (scf-ref:mirror-position mirror))
            "~A: mirroring twice does not give the position back" fen)))))

(deftest :mirror mirror-position-agrees-with-the-fen-mirror
  (dolist (fen (symmetry-fens))
    (let ((canonical (scf-ref:position-to-fen (fen-position fen))))
      (is-equal (mirror-fen canonical)
                (scf-ref:position-to-fen (scf-ref:mirror-position (fen-position canonical)))
                "~A" fen))))

(deftest :mirror legal-moves-of-the-mirror-are-the-mirrored-legal-moves
  (dolist (fen (symmetry-fens))
    (let ((pos (fen-position fen)))
      (is-equal (sorted-moves (mapcar #'scf-ref:mirror-move (scf-ref:legal-moves pos)))
                (sorted-moves (scf-ref:legal-moves (scf-ref:mirror-position pos)))
                "~A" fen))))

(deftest :mirror perft-of-the-mirror-is-equal
  (let ((compared 0))
    (dolist (fen (symmetry-fens))
      (let ((pos (fen-position fen)))
        (loop for depth from 1 to 2
              do (incf compared)
                 (is-eql (scf-ref:perft pos depth)
                         (scf-ref:perft (scf-ref:mirror-position pos) depth)
                         "~A at depth ~D" fen depth))))
    (note "~D position/depth pairs compared" compared)))
