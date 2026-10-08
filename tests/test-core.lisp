;;;; test-core.lisp -- constants, packed moves, the PRNG and the Zobrist key tables.

(in-package #:scacchiforge.test)

;;; --- PRNG ---------------------------------------------------------------------

(deftest :core prng-known-vectors
  ;; Published values: the first five of the fifty in the test "reference" of rand_xoshiro
  ;; (https://github.com/rust-random/rngs, rand_xoshiro/src/splitmix64.rs, read on
  ;; 2026-10-04), which says they come from Vigna's reference splitmix64.c.
  (let ((rng (make-rng 1477776061723855037)))
    (dolist (expected '(1985237415132408290 2979275885539914483 13511426838097143398
                        8488337342461049707 15141737807933549159))
      (is-eql expected (rng-next-u64 rng))))
  ;; This implementation's own values for two more seeds, recorded so that a change of the
  ;; sequence is noticed. They are not published values.
  (let ((rng (make-rng 0)))
    (is-eql #xE220A8397B1DCDAF (rng-next-u64 rng))
    (is-eql #x6E789E6AA1B965F4 (rng-next-u64 rng))
    (is-eql #x06C45D188009454F (rng-next-u64 rng))
    (is-eql #xF88BB8A8724C81EC (rng-next-u64 rng)))
  (let ((rng (make-rng 1234567)))
    (is-eql #x599ED017FB08FC85 (rng-next-u64 rng))
    (is-eql #x2C73F08458540FA5 (rng-next-u64 rng))
    (is-eql #x883EBCE5A3F27C77 (rng-next-u64 rng))))

(deftest :core prng-is-deterministic-and-replayable
  (let ((a (make-rng 42))
        (b (make-rng 42)))
    (dotimes (i 100)
      (is-eql (rng-next-u64 a) (rng-next-u64 b)))
    (let* ((copy (copy-rng a))
           (from-a (loop repeat 10 collect (rng-next-u64 a)))
           (from-copy (loop repeat 10 collect (rng-next-u64 copy))))
      (is-equal from-a from-copy "a copy replays the same sequence")))
  (is (/= (rng-next-u64 (make-rng 1)) (rng-next-u64 (make-rng 2)))
      "different seeds give different sequences"))

(deftest :core prng-below-stays-in-range-and-covers-it
  (let ((rng (make-rng 7))
        (seen (make-array 10 :initial-element 0)))
    (dotimes (i 2000)
      (let ((value (rng-below rng 10)))
        (is (<= 0 value 9) "rng-below 10 returned ~D" value)
        (incf (aref seen value))))
    (is (every #'plusp seen) "every residue 0..9 appears: ~S" seen)
    (is-eql 0 (rng-below rng 1))))

(deftest :core prng-below-accepts-ranges-up-to-two-to-the-64
  ;; With N = 2^64 every draw is accepted, so the value is the next 64-bit draw itself.
  (is-eql (rng-next-u64 (make-rng 3)) (rng-below (make-rng 3) (ash 1 64)))
  ;; A larger N cannot be covered by one draw: it is refused instead of looping for ever.
  ;; The timeout turns a return of that endless loop into a test failure instead of a hang.
  (sb-ext:with-timeout 10
    (signals type-error (rng-below (make-rng 3) (1+ (ash 1 64))))
    (signals type-error (rng-below (make-rng 3) (ash 1 70))))
  (signals type-error (rng-below (make-rng 3) 0)))

;;; --- squares, colours, pieces ----------------------------------------------------

(deftest :core square-arithmetic-and-names
  (dotimes (square 64)
    (is-eql square (make-square (square-file square) (square-rank square)))
    (is-eql square (parse-square (square-name square))))
  (is-eql 0 +a1+)
  (is-eql 7 +h1+)
  (is-eql 28 +e4+)
  (is-eql 63 +h8+)
  (is-equal "e4" (square-name +e4+))
  (dolist (bad '("" "i1" "a9" "e44" "E4" "e" "4e" "--"))
    (is-false (parse-square bad) "~S is not a square" bad))
  (is-false (parse-square nil)))

(deftest :core piece-codes
  (dolist (colour (list +white+ +black+))
    (loop for type from 1 to 6
          do (let ((piece (make-piece colour type)))
               (is-eql colour (piece-colour piece))
               (is-eql type (piece-type piece))
               (is-eql piece (char-piece (piece-char piece))))))
  (is-eql +white-pawn+ (make-piece +white+ +pawn+))
  (is-eql +black-king+ (make-piece +black+ +king+))
  (is-equal (loop for index below 12 collect index)
            (sort (loop for colour in (list +white+ +black+)
                        append (loop for type from 1 to 6
                                     collect (piece-index (make-piece colour type))))
                  #'<)
            "piece-index is a bijection onto 0..11")
  (is-equal "PNBRQKpnbrqk"
            (coerce (mapcar #'piece-char
                            (list +white-pawn+ +white-knight+ +white-bishop+ +white-rook+
                                  +white-queen+ +white-king+ +black-pawn+ +black-knight+
                                  +black-bishop+ +black-rook+ +black-queen+ +black-king+))
                    'string))
  (is-false (char-piece #\x))
  (is-false (char-piece #\1)))

;;; --- packed moves ----------------------------------------------------------------

(deftest :move encode-decode-round-trip-exhaustively
  (let ((seen (make-hash-table)))
    (dotimes (from 64)
      (dotimes (to 64)
        (dolist (promotion '(0 2 3 4 5))
          (dotimes (flags 32)
            (let ((move (encode-move from to promotion flags)))
              (unless (and (= from (move-from move))
                           (= to (move-to move))
                           (= promotion (move-promotion move))
                           (= flags (move-flags move)))
                (record-failure "move ~D does not decode to ~D ~D ~D ~D" move from to
                                promotion flags))
              (setf (gethash move seen) t))))))
    (incf *assertions*)
    (is-eql (* 64 64 5 32) (hash-table-count seen) "every parameter set has its own encoding")))

(deftest :move moves-are-fixnums-and-no-move-is-zero
  (is (typep (encode-move 63 63 5 31) 'fixnum))
  (is (< (encode-move 63 63 5 31) (ash 1 20)))
  (is-eql 0 +no-move+)
  (is-eql +no-move+ (encode-move +a1+ +a1+ 0 0)))

(deftest :move flag-predicates
  (let ((quiet (encode-move +e2+ +e3+ 0 0))
        (capture (encode-move +e4+ +d5+ 0 +flag-capture+))
        (en-passant (encode-move +e5+ +d6+ 0 (logior +flag-capture+ +flag-en-passant+)))
        (double (encode-move +e2+ +e4+ 0 +flag-double-push+))
        (castle-king (encode-move +e1+ +g1+ 0 +flag-castle-king+))
        (castle-queen (encode-move +e1+ +c1+ 0 +flag-castle-queen+))
        (promotion (encode-move +a7+ +a8+ +queen+ 0)))
    (is-false (move-capture-p quiet))
    (is-true (move-capture-p capture))
    (is-true (and (move-capture-p en-passant) (move-en-passant-p en-passant)))
    (is-false (move-en-passant-p capture))
    (is-true (move-double-push-p double))
    (is-false (move-double-push-p quiet))
    (is-true (move-castle-p castle-king))
    (is-true (move-castle-p castle-queen))
    (is-false (move-castle-p quiet))
    (is-true (move-promotion-p promotion))
    (is-false (move-promotion-p capture))))

(deftest :move move-text
  (is-equal "e2e4" (move-to-string (encode-move +e2+ +e4+ 0 +flag-double-push+)))
  (is-equal "e7e8q" (move-to-string (encode-move +e7+ +e8+ +queen+ 0)))
  (is-equal "a7b8n" (move-to-string (encode-move +a7+ +b8+ +knight+ +flag-capture+)))
  (is-equal "h2h1r" (move-to-string (encode-move +h2+ +h1+ +rook+ 0)))
  (is-equal "c7c8b" (move-to-string (encode-move +c7+ +c8+ +bishop+ 0))))

;;; --- Zobrist key tables ------------------------------------------------------------

(deftest :zobrist key-tables-have-golden-values
  ;; This implementation's own keys from the fixed seed (the generator is checked against
  ;; published values in prng-known-vectors). Not published values. If these change, every
  ;; recorded key changes with them.
  (is-eql #x1B555E426F146E94 (zobrist-piece-key +white-pawn+ +a1+))
  (is-eql #xD8C0D779404A2DF9 (zobrist-piece-key +white-pawn+ +b1+))
  (is-eql #x44A6E08DB15AA5F5 (zobrist-piece-key +black-king+ +h8+))
  (is-eql #x69FBDAA70E539303 (zobrist-side-key))
  (is-eql #xCC3C50DCB3BB1BE5 (zobrist-castling-key +castle-white-king+))
  (is-eql #xB1DC7C464E1BCF9D (zobrist-castling-key +castle-black-queen+))
  (is-eql #x8A631C50A1D79D03 (zobrist-en-passant-key 0))
  (is-eql #x474546E676DC4480 (zobrist-en-passant-key 7)))

(deftest :zobrist key-tables-are-distinct-and-reproducible
  (let ((before (zobrist-key-table-snapshot)))
    (is-eql 781 (length before))
    (is-eql 781 (length (remove-duplicates before)) "all 781 base keys are distinct")
    (is (notany #'zerop before) "no key is zero")
    (is-eql 781 (regenerate-zobrist-keys))
    (is-equal before (zobrist-key-table-snapshot) "regenerating gives identical tables")))

(deftest :zobrist castling-key-is-the-xor-of-its-rights
  (is-eql 0 (zobrist-castling-key 0))
  (dotimes (rights 16)
    (let ((expected 0))
      (dolist (right (list +castle-white-king+ +castle-white-queen+
                           +castle-black-king+ +castle-black-queen+))
        (when (logtest rights right)
          (setf expected (logxor expected (zobrist-castling-key right)))))
      (is-eql expected (zobrist-castling-key rights) "rights set ~D" rights))))
