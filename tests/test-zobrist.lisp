;;;; test-zobrist.lisp -- incremental and from-scratch position keys.

(in-package #:scacchiforge.test)

(defun key-of (fen)
  "The stored key of the position parsed from FEN."
  (scf-ref:pos-key (fen-position fen)))

(deftest :zobrist position-keys-have-golden-values
  ;; This implementation's own keys, recorded so that a change of the key scheme or of the
  ;; tables is noticed. The scheme is this project's, so there is no published value.
  (is-eql #x3BD8F6F0BAD3D2A1 (key-of scf-ref:*start-fen*))
  (is-eql #xF18D1D19F4613BD0
          (key-of "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"))
  (is-eql #xA2C6D7EFF04BD3A6 (key-of "4k3/8/8/8/8/8/8/4K3 w - - 0 1"))
  (is-eql #xFB8E4FB2C18E2006
          (key-of "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"))
  (is-eql #xCAFCC7E85FA510C9 (key-of "8/8/8/K2pP3/8/8/8/7k w - d6 0 1"))
  (is-eql #x347A025FEA7142CA (key-of "8/8/8/K2pP3/8/8/8/7k w - - 0 1")))

(deftest :zobrist incremental-key-equals-recomputed-key-along-playouts
  (let ((rng (make-rng 555)))
    (dolist (fen *fuzz-fens*)
      (let ((pos (fen-position fen)))
        (dotimes (ply 150)
          (let ((legal (scf-ref:legal-moves pos)))
            (when (null legal)
              (return))
            (scf-ref:make-move pos (rng-pick rng legal))
            (is-eql (scf-ref:compute-key pos) (scf-ref:pos-key pos)
                    "after ~D plies from ~A" (1+ ply) fen)))))))

(deftest :zobrist key-after-a-quiet-move-changes-by-exactly-the-expected-keys
  (let* ((pos (scf-ref:start-position))
         (before (scf-ref:pos-key pos)))
    (play pos "g1f3")
    (is-eql (logxor before
                    (zobrist-piece-key +white-knight+ +g1+)
                    (zobrist-piece-key +white-knight+ +f3+)
                    (zobrist-side-key))
            (scf-ref:pos-key pos))))

(deftest :zobrist transpositions-reach-equal-keys
  (let ((a (play (scf-ref:start-position) "g1f3" "g8f6" "b1c3" "b8c6"))
        (b (play (scf-ref:start-position) "b1c3" "b8c6" "g1f3" "g8f6")))
    (is-eql (scf-ref:pos-key a) (scf-ref:pos-key b))
    (is (scf-ref:positions-equal-p a b)))
  ;; A transposition that leaves different clocks and a different, unusable, en-passant
  ;; square: the positions are not identical records, yet the keys must agree.
  (let ((a (play (scf-ref:start-position) "e2e4" "e7e5" "g1f3" "b8c6"))
        (b (play (scf-ref:start-position) "g1f3" "b8c6" "e2e4" "e7e5")))
    (is-false (scf-ref:positions-equal-p a b) "clocks and the en-passant square differ")
    (is-eql (scf-ref:pos-key a) (scf-ref:pos-key b))
    (is-eql (scf-ref:compute-key a) (scf-ref:compute-key b))))

(deftest :zobrist moving-back-and-forth-restores-the-key-but-not-the-rights
  (let ((pos (fen-position "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1")))
    (play pos "e1e2" "e8e7" "e2e1" "e7e8")
    (is-eql (key-of "r3k2r/8/8/8/8/8/8/R3K2R w - - 4 3") (scf-ref:pos-key pos)
            "same board, castling rights gone: the key is that of the position without rights")
    (is-false (= (key-of "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1") (scf-ref:pos-key pos)))))

(deftest :zobrist en-passant-key-is-used-only-when-a-capture-is-available
  ;; Available: the pawn e5 attacks d6.
  (is-false (= (key-of "8/8/8/K2pP3/8/8/8/7k w - d6 0 1")
               (key-of "8/8/8/K2pP3/8/8/8/7k w - - 0 1")))
  ;; Not available: no black pawn stands beside e4.
  (is-eql (key-of "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
          (key-of "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"))
  ;; Pseudo-legal availability: the capture e5xd6 is illegal (horizontal pin) but a pawn
  ;; attacks the square, so the file key is included. This documents the policy.
  (is-false (= (key-of "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1")
               (key-of "8/8/8/K2pP2r/8/8/8/7k w - - 0 1")))
  ;; Different files give different keys.
  (is-false (= (key-of "8/8/8/K2pP3/8/8/8/7k w - d6 0 1")
               (key-of "8/8/8/K1p1P3/8/8/8/7k w - c6 0 1"))))

(deftest :zobrist key-depends-on-side-castling-and-placement-but-not-on-clocks
  (let ((base "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"))
    (is-false (= (key-of base) (key-of "r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1")) "side")
    (is-false (= (key-of base) (key-of "r3k2r/8/8/8/8/8/8/R3K2R w KQk - 0 1")) "rights")
    (is-false (= (key-of base) (key-of "r3k2r/8/8/8/8/8/8/R3K1R1 w Qkq - 0 1")) "placement")
    (is-eql (key-of base) (key-of "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 37 90") "clocks")))

(defun position-identity (pos)
  "What the key is meant to identify: board, side, castling rights and a USABLE en-passant
square."
  (let ((fields (split-on-spaces (scf-ref:position-to-fen pos))))
    (format nil "~A ~A ~A ~A" (first fields) (second fields) (third fields)
            (if (scf-ref:en-passant-capture-available-p pos) (fourth fields) "-"))))

(deftest :zobrist distinct-positions-reached-by-play-do-not-share-a-key
  ;; [PROBABILISTIC] A collision is possible in principle. For this seeded sample none is
  ;; expected, and one would be worth investigating.
  (let ((rng (make-rng 2718))
        (identity-of-key (make-hash-table))
        (distinct 0)
        (collisions 0))
    (dotimes (i 3000)
      (let* ((pos (scf-ref:random-legal-position *fuzz-fens* rng 80))
             (identity (position-identity pos))
             (previous (gethash (scf-ref:pos-key pos) identity-of-key)))
        (cond ((null previous)
               (incf distinct)
               (setf (gethash (scf-ref:pos-key pos) identity-of-key) identity))
              ((string/= previous identity)
               (incf collisions)))))
    (note "~D distinct position identities seen" distinct)
    (is (> distinct 1000))
    (is-eql 0 collisions "distinct positions sharing a key")))
