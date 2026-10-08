;;;; test-movegen.lisp -- one test per special case of legal move generation.
;;;;
;;;; The expected move lists were derived by hand from the rules of chess for each position;
;;;; they were not copied from the engine's output. Each docstring-like comment says what the
;;;; position tests.
;;;;
;;;; Every test runs on both layers (DEFTEST-MOVEGEN, tests/support.lisp): in suite MOVEGEN on
;;;; the reference model and in suite OPTIMIZED-MOVEGEN on the optimized layer. The LAYER-
;;;; helpers call the functions of the layer a position belongs to.

(in-package #:scacchiforge.test)

(defun has-move-p (fen text)
  "True when TEXT is a legal move in the position FEN."
  (and (member text (legal-strings fen) :test #'string=) t))

;;; --- the start position -----------------------------------------------------

(deftest-movegen start-position-has-twenty-moves
  (is-set-equal '("a2a3" "a2a4" "b2b3" "b2b4" "c2c3" "c2c4" "d2d3" "d2d4" "e2e3" "e2e4"
                  "f2f3" "f2f4" "g2g3" "g2g4" "h2h3" "h2h4" "b1a3" "b1c3" "g1f3" "g1h3")
                (legal-strings scf-ref:*start-fen*)))

(deftest-movegen pseudo-legal-differs-from-legal-only-by-king-safety
  ;; White king e1, white rook e2, black rook e8: the rook is pinned.
  (let ((pos (layer-position "4r1k1/8/8/8/8/8/4R3/4K3 w - - 0 1")))
    (is (> (length (layer-pseudo-legal-moves pos)) (length (layer-legal-moves pos))))
    (is (subsetp (layer-legal-moves pos) (layer-pseudo-legal-moves pos)))))

;;; --- pins -------------------------------------------------------------------

(deftest-movegen pinned-bishop-cannot-move
  (is-set-equal '("e1d1" "e1f1" "e1d2" "e1f2")
                (legal-strings "4r1k1/8/8/8/8/8/4B3/4K3 w - - 0 1")))

(deftest-movegen pinned-rook-moves-only-along-the-pin
  (is-set-equal '("e2e3" "e2e4" "e2e5" "e2e6" "e2e7" "e2e8" "e1d1" "e1f1" "e1d2" "e1f2")
                (legal-strings "4r1k1/8/8/8/8/8/4R3/4K3 w - - 0 1")))

(deftest-movegen pinned-pawn-cannot-leave-the-diagonal
  ;; Bishop a5 pins the pawn d2 to the king e1: no pawn push is legal.
  (is-set-equal '("e1d1" "e1f1" "e1e2" "e1f2")
                (legal-strings "4k3/8/8/b7/8/8/3P4/4K3 w - - 0 1")))

(deftest-movegen pinned-pawn-may-capture-the-pinning-piece
  ;; Bishop b4 pins the pawn c3 to the king e1; c3xb4 stays on the pin line.
  (is-set-equal '("c3b4" "e1d1" "e1f1" "e1d2" "e1e2" "e1f2")
                (legal-strings "4k3/8/8/8/1b6/2P5/8/4K3 w - - 0 1")))

;;; --- checks -----------------------------------------------------------------

(deftest-movegen discovered-check-leaves-only-evasions
  ;; Black's knight e5 shields the rook e8. After Ng4 the rook gives a discovered check.
  (let ((pos (layer-position "4r1k1/8/8/4n3/8/8/8/4K2R b - - 0 1")))
    (is-false (layer-in-check-p pos))
    (is (has-move-p pos "e5g4"))
    (play pos "e5g4")
    (is-true (layer-in-check-p pos))
    (is-set-equal '("e1d1" "e1d2" "e1f1") (legal-strings pos))))

(deftest-movegen double-check-allows-only-king-moves
  ;; Rook e8 and knight f3 both attack e1. The queen could take the knight or block the file,
  ;; but neither answers both checks.
  (let ((pos (layer-position "4r1k1/8/8/8/8/5n2/8/4K2Q w - - 0 1")))
    (is-true (layer-in-check-p pos))
    (is-set-equal '("e1d1" "e1f1" "e1f2") (legal-strings pos))
    (is (> (length (layer-pseudo-legal-moves pos)) 10)
        "the queen has pseudo-legal moves that the legality filter must remove")))

(deftest-movegen single-check-allows-capture-block-or-king-move
  ;; The rook a1 checks the king h1 along the first rank. Answers: Rxa1, Bxa1, the block
  ;; Bg1, and the king steps to g2 or h2 (g1 stays on the rank).
  (is-set-equal '("a2a1" "d4a1" "d4g1" "h1g2" "h1h2")
                (legal-strings "6k1/8/8/8/3B4/8/R7/r6K w - - 0 1")))

;;; --- en passant -------------------------------------------------------------

(deftest-movegen pinned-en-passant-horizontal-pin
  ;; Taking e5xd6 removes both pawns from the fifth rank and would expose the king a5 to the
  ;; rook h5. The capture is pseudo-legal and illegal.
  (let ((pos (layer-position "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1")))
    (is-set-equal '("a5a4" "a5a6" "a5b4" "a5b5" "a5b6" "e5e6") (legal-strings pos))
    (is (member "e5d6" (move-strings (layer-pseudo-legal-moves pos)) :test #'string=)
        "e5d6 is generated as pseudo-legal")))

(deftest-movegen en-passant-without-the-pin-is-legal
  (let ((pos (layer-position "8/8/8/K2pP3/8/8/8/7k w - d6 0 1")))
    (is-set-equal '("a5a4" "a5a6" "a5b4" "a5b5" "a5b6" "e5e6" "e5d6") (legal-strings pos))
    (let ((move (layer-parse-move pos "e5d6")))
      (is-true (move-en-passant-p move))
      (is-true (move-capture-p move)))))

(deftest-movegen en-passant-can-capture-the-checking-pawn
  ;; White's d4 pawn gives check to the king c5. e4xd3 en passant removes it.
  (let ((pos (layer-position "8/8/8/2k5/3Pp3/8/8/4K3 b - d3 0 1")))
    (is-true (layer-in-check-p pos))
    (is-set-equal '("c5b4" "c5b5" "c5b6" "c5c4" "c5c6" "c5d4" "c5d5" "c5d6" "e4d3")
                  (legal-strings pos))))

(deftest-movegen pinned-pawn-may-capture-en-passant-along-the-pin
  ;; The bishop b8 pins the pawn e5 to the king g3 along the diagonal b8-g3. e5xd6 en passant
  ;; lands on d6, still on that diagonal between the bishop and the king, so it is legal;
  ;; e5e6 leaves the diagonal and is not. The king's eight squares are all free: the pawn e5
  ;; still blocks the bishop's diagonal towards f4 and h2.
  (let ((pos (layer-position "1b2k3/8/8/3pP3/8/6K1/8/8 w - d6 0 1")))
    (is-set-equal '("e5d6" "g3f2" "g3f3" "g3f4" "g3g2" "g3g4" "g3h2" "g3h3" "g3h4")
                  (legal-strings pos))
    (is (member "e5e6" (move-strings (layer-pseudo-legal-moves pos)) :test #'string=)
        "e5e6 is generated as pseudo-legal and removed by the legality test")
    (let ((move (layer-parse-move pos "e5d6")))
      (is-true (and move (move-en-passant-p move)) "e5d6 is the en-passant capture")))
  ;; The same position with the colours exchanged and the board turned upside down: the
  ;; bishop b1 pins the pawn e4 to the king g6, and e4xd3 en passant stays on the diagonal.
  (let ((pos (layer-position "8/8/6k1/8/3Pp3/8/8/1B2K3 b - d3 0 1")))
    (is-set-equal '("e4d3" "g6f7" "g6f6" "g6f5" "g6g7" "g6g5" "g6h7" "g6h6" "g6h5")
                  (legal-strings pos))
    (is (member "e4e3" (move-strings (layer-pseudo-legal-moves pos)) :test #'string=)
        "e4e3 is generated as pseudo-legal and removed by the legality test")))

(deftest-movegen en-passant-square-follows-double-pushes-only
  (let ((pos (layer-position scf-ref:*start-fen*)))
    (play pos "e2e4")
    (is-eql +e3+ (layer-en-passant pos))
    (play pos "g8f6")
    (is-eql +no-square+ (layer-en-passant pos) "cleared by any other move")
    (play pos "e4e5" "d7d5")
    (is-eql +d6+ (layer-en-passant pos) "set by a black double push")
    (is (has-move-p pos "e5d6"))
    (play pos "e5d6")
    (is-eql +empty+ (layer-piece-at pos +d5+) "the pawn captured en passant is removed")
    (is-eql +white-pawn+ (layer-piece-at pos +d6+)))
  (let ((pos (layer-position scf-ref:*start-fen*)))
    (play pos "e2e3")
    (is-eql +no-square+ (layer-en-passant pos) "a single push sets nothing")))

;;; --- castling ---------------------------------------------------------------

(defparameter *two-rooks* "r3k2r/8/8/8/8/8/8/R3K2R")

(deftest-movegen castling-both-sides
  (is (has-move-p (format nil "~A w KQkq - 0 1" *two-rooks*) "e1g1"))
  (is (has-move-p (format nil "~A w KQkq - 0 1" *two-rooks*) "e1c1"))
  (is-eql 26 (length (legal-strings (format nil "~A w KQkq - 0 1" *two-rooks*))))
  (is (has-move-p (format nil "~A b KQkq - 0 1" *two-rooks*) "e8g8"))
  (is (has-move-p (format nil "~A b KQkq - 0 1" *two-rooks*) "e8c8")))

(deftest-movegen castling-needs-the-right
  (let ((kingside-only (format nil "~A w Kq - 0 1" *two-rooks*))
        (queenside-only (format nil "~A w Qk - 0 1" *two-rooks*))
        (none (format nil "~A w - - 0 1" *two-rooks*)))
    (is (has-move-p kingside-only "e1g1"))
    (is-false (has-move-p kingside-only "e1c1"))
    (is (has-move-p queenside-only "e1c1"))
    (is-false (has-move-p queenside-only "e1g1"))
    (is-false (has-move-p none "e1g1"))
    (is-false (has-move-p none "e1c1"))
    (is-eql 25 (length (legal-strings kingside-only)))
    (is-eql 24 (length (legal-strings none)))))

(deftest-movegen castling-needs-empty-squares
  ;; The b-file square must be empty too, although the king never crosses it.
  (is-false (has-move-p "r3k2r/8/8/8/8/8/8/RN2K2R w KQkq - 0 1" "e1c1"))
  (is-false (has-move-p "r3k2r/8/8/8/8/8/8/R2NK2R w KQkq - 0 1" "e1c1"))
  (is-false (has-move-p "r3k2r/8/8/8/8/8/8/R1N1K2R w KQkq - 0 1" "e1c1"))
  (is-false (has-move-p "r3k2r/8/8/8/8/8/8/R3KB1R w KQkq - 0 1" "e1g1"))
  (is-false (has-move-p "r3k2r/8/8/8/8/8/8/R3K1NR w KQkq - 0 1" "e1g1"))
  (is-true (has-move-p "r3k2r/8/8/8/8/8/8/RN2K2R w KQkq - 0 1" "e1g1"))
  (is-false (has-move-p "rn2k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "e8c8")))

(deftest-movegen castling-not-out-of-check
  (is-set-equal '("e1d1" "e1d2" "e1f1" "e1f2")
                (legal-strings "4r1k1/8/8/8/8/8/8/R3K2R w KQ - 0 1")))

(deftest-movegen castling-not-across-an-attacked-square
  ;; The rook f8 attacks f1, which the king would cross going kingside.
  (let ((fen "r3kr2/8/8/8/8/8/8/R3K2R w KQq - 0 1"))
    (is-false (has-move-p fen "e1g1"))
    (is-true (has-move-p fen "e1c1")))
  ;; The rook d8 attacks d1, which the king would cross going queenside.
  (let ((fen "3rk2r/8/8/8/8/8/8/R3K2R w KQk - 0 1"))
    (is-false (has-move-p fen "e1c1"))
    (is-true (has-move-p fen "e1g1"))))

(deftest-movegen castling-not-onto-an-attacked-square
  (let ((fen "r3k1r1/8/8/8/8/8/8/R3K2R w KQq - 0 1"))
    (is-false (has-move-p fen "e1g1") "the rook g8 attacks g1")
    (is-true (has-move-p fen "e1c1")))
  (let ((fen "2r1k2r/8/8/8/8/8/8/R3K2R w KQk - 0 1"))
    (is-false (has-move-p fen "e1c1") "the rook c8 attacks c1")
    (is-true (has-move-p fen "e1g1"))))

(deftest-movegen castling-generation-follows-its-documented-rule
  ;; The generator emits a castling move only when none of the three squares the king uses
  ;; is attacked, so these moves are not even pseudo-legal (the legality filter would also
  ;; remove the last two).
  (flet ((generated-p (fen text)
           (and (member text (move-strings (layer-pseudo-legal-moves (layer-position fen)))
                        :test #'string=)
                t)))
    (is-true (generated-p "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1g1") "control")
    (is-false (generated-p "4r1k1/8/8/8/8/8/8/R3K2R w KQ - 0 1" "e1g1") "out of check")
    (is-false (generated-p "r3kr2/8/8/8/8/8/8/R3K2R w KQq - 0 1" "e1g1") "across f1")
    (is-false (generated-p "r3k1r1/8/8/8/8/8/8/R3K2R w KQq - 0 1" "e1g1") "onto g1")
    (is-false (generated-p "3rk2r/8/8/8/8/8/8/R3K2R w KQk - 0 1" "e1c1") "across d1")
    (is-false (generated-p "2r1k2r/8/8/8/8/8/8/R3K2R w KQk - 0 1" "e1c1") "onto c1")))

(deftest-movegen castling-queenside-may-pass-an-attacked-b-square
  (is-true (has-move-p "1r2k3/8/8/8/8/8/8/R3K3 w Q - 0 1" "e1c1")))

(deftest-movegen castling-needs-the-rook
  ;; PARSE-FEN refuses such a FEN, so build the position from parts: the right is set but
  ;; the rook is missing.
  (signals scf-ref:fen-error (layer-position "r3k2r/8/8/8/8/8/8/R3K3 w KQkq - 0 1"))
  (let ((board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)))
    (setf (aref board +e1+) +white-king+
          (aref board +e8+) +black-king+
          (aref board +a1+) +white-rook+)
    (let ((pos (layer-from-reference
                (scf-ref:make-position-from-parts board +white+ +castle-all+ +no-square+ 0 1))))
      (is-false (member "e1g1" (legal-strings pos) :test #'string=)
                "no rook on h1: no kingside castling")
      (is-true (member "e1c1" (legal-strings pos) :test #'string=)
               "the rook on a1 is there"))))

(deftest-movegen castling-moves-the-rook-and-clears-the-rights
  (is-equal "r3k2r/8/8/8/8/8/8/R4RK1 b kq - 1 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1g1"))
  (is-equal "r3k2r/8/8/8/8/8/8/2KR3R b kq - 1 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1c1"))
  (is-equal "r4rk1/8/8/8/8/8/8/R3K2R w KQ - 1 2"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "e8g8"))
  (is-equal "2kr3r/8/8/8/8/8/8/R3K2R w KQ - 1 2"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "e8c8")))

(deftest-movegen king-or-rook-move-clears-the-castling-rights
  (is-equal "r3k2r/8/8/8/8/8/4K3/R6R b kq - 1 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "e1e2"))
  (is-equal "r3k2r/8/8/8/8/8/8/R3K1R1 b Qkq - 1 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "h1g1"))
  (is-equal "r3k2r/8/8/8/8/8/8/1R2K2R b Kkq - 1 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "a1b1"))
  (is-equal "r3k1r1/8/8/8/8/8/8/R3K2R w KQq - 1 2"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "h8g8"))
  (is-equal "1r2k2r/8/8/8/8/8/8/R3K2R w KQk - 1 2"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1" "a8b8")))

(deftest-movegen rook-captured-on-its-home-square-removes-the-right
  ;; A bishop takes the rook h1: White loses the kingside right.
  (is-equal "r3k2r/8/8/8/8/8/8/R3K2b w Qkq - 0 2"
            (fen-after "r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1" "g2h1"))
  ;; A rook takes the rook h8: Black loses the kingside right, White's rook left h1.
  (is-equal "r3k2R/8/8/8/8/8/8/R3K3 b Qq - 0 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "h1h8"))
  ;; Taking the rook a8 removes the queenside right.
  (is-equal "R3k2r/8/8/8/8/8/8/4K2R b Kk - 0 1"
            (fen-after "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1" "a1a8"))
  ;; The right is gone for good: with the bishop on h1 the king cannot castle kingside.
  (let ((pos (layer-position "r3k2r/8/8/8/8/8/6b1/R3K2R b KQkq - 0 1")))
    (play pos "g2h1")
    (is-true (has-move-p pos "e1c1"))
    (is-false (has-move-p pos "e1g1"))))

;;; --- promotion --------------------------------------------------------------

(defun promotions-of (fen from to)
  "The promotion piece types of the legal moves FROM -> TO in FEN, sorted."
  (sort (loop for move in (layer-legal-moves (layer-position fen))
              when (and (= (move-from move) (square-of from)) (= (move-to move) (square-of to)))
                collect (move-promotion move))
        #'<))

(deftest-movegen promotion-without-capture-makes-four-moves
  (is-set-equal '("a7a8q" "a7a8r" "a7a8b" "a7a8n" "a1a2" "a1b1" "a1b2")
                (legal-strings "8/P6k/8/8/8/8/8/K7 w - - 0 1"))
  (is-equal (list +knight+ +bishop+ +rook+ +queen+)
            (promotions-of "8/P6k/8/8/8/8/8/K7 w - - 0 1" "a7" "a8")))

(deftest-movegen promotion-with-capture-makes-four-more
  (let ((fen "1n5k/P7/8/8/8/8/8/K7 w - - 0 1"))
    (is-set-equal '("a7a8q" "a7a8r" "a7a8b" "a7a8n" "a7b8q" "a7b8r" "a7b8b" "a7b8n"
                    "a1a2" "a1b1" "a1b2")
                  (legal-strings fen))
    (is-equal (list +knight+ +bishop+ +rook+ +queen+) (promotions-of fen "a7" "b8"))
    (dolist (move (layer-legal-moves (layer-position fen)))
      (when (= (move-to move) +b8+)
        (is-true (move-capture-p move) "a promotion onto b8 captures"))
      (when (= (move-to move) +a8+)
        (is-false (move-capture-p move) "a promotion onto a8 does not capture")))))

(deftest-movegen black-promotes-downwards
  (is-set-equal '("a2a1q" "a2a1r" "a2a1b" "a2a1n" "a2b1q" "a2b1r" "a2b1b" "a2b1n"
                  "a8a7" "a8b7" "a8b8")
                (legal-strings "k7/8/8/8/8/8/p6K/1N6 b - - 0 1")))

(deftest-movegen promotion-places-the-chosen-piece
  (let ((fen "1n5k/P7/8/8/8/8/8/K7 w - - 0 1"))
    (is-equal "Qn5k/8/8/8/8/8/8/K7 b - - 0 1" (fen-after fen "a7a8q"))
    (is-equal "1N5k/8/8/8/8/8/8/K7 b - - 0 1" (fen-after fen "a7b8n"))
    (is-equal "1R5k/8/8/8/8/8/8/K7 b - - 0 1" (fen-after fen "a7b8r"))
    (is-equal "1B5k/8/8/8/8/8/8/K7 b - - 0 1" (fen-after fen "a7b8b"))))

;;; --- terminal positions -----------------------------------------------------

(deftest-movegen checkmate-is-detected
  ;; Fool's mate.
  (let ((pos (layer-position "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3")))
    (is-true (layer-in-check-p pos))
    (is-eql 0 (layer-legal-move-count pos))
    (is-eql :checkmate (layer-game-outcome pos))
    (is-true (layer-checkmate-p pos))
    (is-false (layer-stalemate-p pos))))

(deftest-movegen stalemate-is-detected
  (let ((pos (layer-position "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")))
    (is-false (layer-in-check-p pos))
    (is-eql 0 (layer-legal-move-count pos))
    (is-eql :stalemate (layer-game-outcome pos))
    (is-true (layer-stalemate-p pos))
    (is-false (layer-checkmate-p pos))))

(deftest-movegen ongoing-positions-have-no-outcome
  (is-eql nil (layer-game-outcome (layer-position scf-ref:*start-fen*)))
  (is-eql nil (layer-game-outcome (layer-position "4k3/8/8/8/8/8/4R3/4K3 b - - 0 1"))))

(deftest-movegen only-checkmate-and-stalemate-are-detected
  ;; Draws by the fifty-move rule, repetition and insufficient material are NOT implemented:
  ;; a huge halfmove clock changes nothing, in either direction.
  (is-eql nil (layer-game-outcome (layer-position "8/8/8/4k3/8/8/8/4K3 w - - 150 200")))
  (is-eql :checkmate
          (layer-game-outcome
           (layer-position "rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 120 80")))
  (is-eql :stalemate
          (layer-game-outcome (layer-position "7k/5Q2/6K1/8/8/8/8/8 b - - 150 90"))))
