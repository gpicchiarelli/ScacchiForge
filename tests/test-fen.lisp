;;;; test-fen.lisp -- FEN parsing and serialisation.

(in-package #:scacchiforge.test)

(defparameter *round-trip-fens*
  (append (mapcar #'cdr scf-ref:*standard-positions*)
          '("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
            "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
            "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
            "r3k2r/8/8/8/8/8/8/R3K2R w Kq - 12 40"
            "4k3/8/8/8/8/8/8/4K3 b - - 99 150"
            "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1"
            "8/8/8/2k5/3Pp3/8/8/4K3 b - d3 0 1"
            "4k3/8/8/8/8/8/8/4K2R w K - 0 1"))
  "Canonical FENs: parsing then serialising must give the same string.")

(deftest :fen parses-the-start-position
  (let ((pos (scf-ref:parse-fen scf-ref:*start-fen*)))
    (is-eql +white+ (scf-ref:pos-side pos))
    (is-eql +castle-all+ (scf-ref:pos-castling pos))
    (is-eql +no-square+ (scf-ref:pos-en-passant pos))
    (is-eql 0 (scf-ref:pos-halfmove pos))
    (is-eql 1 (scf-ref:pos-fullmove pos))
    (is-eql +white-rook+ (scf-ref:piece-at pos +a1+))
    (is-eql +white-king+ (scf-ref:piece-at pos +e1+))
    (is-eql +black-queen+ (scf-ref:piece-at pos +d8+))
    (is-eql +empty+ (scf-ref:piece-at pos +e4+))
    (is-eql +e1+ (scf-ref:king-square pos +white+))
    (is-eql +e8+ (scf-ref:king-square pos +black+))
    (is-equal scf-ref:*start-fen* (scf-ref:position-to-fen pos))
    (is (scf-ref:positions-equal-p pos (scf-ref:start-position)))))

(deftest :fen round-trips-canonical-fens
  (dolist (fen *round-trip-fens*)
    (is-equal fen (scf-ref:position-to-fen (scf-ref:parse-fen fen)) "round trip of ~A" fen)))

(deftest :fen board-is-a-flat-vector-of-small-integers
  (let ((board (scf-ref:pos-board (scf-ref:start-position))))
    (is (typep board '(simple-array (unsigned-byte 8) (64))))
    (is-eql 32 (count-if #'plusp board))))

(deftest :fen reads-every-field
  (let ((pos (fen-position "r3k2r/8/8/8/8/8/8/R3K2R b Kq - 12 40")))
    (is-eql +black+ (scf-ref:pos-side pos))
    (is-eql (logior +castle-white-king+ +castle-black-queen+) (scf-ref:pos-castling pos))
    (is-eql 12 (scf-ref:pos-halfmove pos))
    (is-eql 40 (scf-ref:pos-fullmove pos)))
  (let ((pos (fen-position "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")))
    (is-eql +e3+ (scf-ref:pos-en-passant pos))))

(deftest :fen accepts-four-fields-and-extra-spaces
  (is-equal "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
            (scf-ref:position-to-fen (fen-position "4k3/8/8/8/8/8/8/4K3 w - -")))
  (is-equal "4k3/8/8/8/8/8/8/4K3 w - - 0 1"
            (scf-ref:position-to-fen (fen-position "  4k3/8/8/8/8/8/8/4K3   w  -  -  0   1 "))))

(deftest :fen follows-a-short-game
  (is-equal "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"
            (fen-after scf-ref:*start-fen* "e2e4"))
  (is-equal "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2"
            (fen-after scf-ref:*start-fen* "e2e4" "e7e5"))
  (is-equal "rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2"
            (fen-after scf-ref:*start-fen* "e2e4" "e7e5" "g1f3")))

(defparameter *malformed-fens*
  '(("empty string" . "")
    ("only spaces" . "   ")
    ("one word" . "hello")
    ("too few fields" . "4k3/8/8/8/8/8/8/4K3 w")
    ("five fields" . "4k3/8/8/8/8/8/8/4K3 w - - 0")
    ("seven fields" . "4k3/8/8/8/8/8/8/4K3 w - - 0 1 x")
    ("seven ranks" . "4k3/8/8/8/8/8/4K3 w - - 0 1")
    ("nine ranks" . "4k3/8/8/8/8/8/8/8/4K3 w - - 0 1")
    ("rank of nine files" . "4k4/8/8/8/8/8/8/4K3 w - - 0 1")
    ("rank of seven files" . "3k3/8/8/8/8/8/8/4K3 w - - 0 1")
    ("piece overflowing a rank" . "4k3p/8/8/8/8/8/8/4K3 w - - 0 1")
    ("unknown letter" . "4k3/8/8/8/8/8/8/4X3 w - - 0 1")
    ("adjacent digits" . "4k3/8/8/8/8/8/8/44K1 w - - 0 1")
    ("digit nine" . "4k3/8/8/8/8/8/8/9 w - - 0 1")
    ("digit zero" . "4k3/8/8/8/8/8/8/04K3 w - - 0 1")
    ("empty rank" . "4k3//8/8/8/8/8/4K3 w - - 0 1")
    ("bad side to move" . "4k3/8/8/8/8/8/8/4K3 x - - 0 1")
    ("uppercase side to move" . "4k3/8/8/8/8/8/8/4K3 W - - 0 1")
    ("bad castling letter" . "r3k2r/8/8/8/8/8/8/R3K2R w KQkqX - 0 1")
    ("repeated castling letter" . "r3k2r/8/8/8/8/8/8/R3K2R w KK - 0 1")
    ("castling dash and letter" . "r3k2r/8/8/8/8/8/8/R3K2R w -K - 0 1")
    ("castling without the rook" . "r3k2r/8/8/8/8/8/8/R3K3 w KQkq - 0 1")
    ("castling without the king" . "r3k2r/8/8/8/8/8/8/R2K3R w KQkq - 0 1")
    ("black castling with the king moved" . "r2k3r/8/8/8/8/8/8/R3K2R w kq - 0 1")
    ("en passant off the board" . "4k3/8/8/8/8/8/8/4K3 w - e9 0 1")
    ("en passant not a square" . "4k3/8/8/8/8/8/8/4K3 w - xx 0 1")
    ("en passant on the wrong rank" . "4k3/8/8/8/8/8/8/4K3 w - e3 0 1")
    ("en passant without the pawn" . "4k3/8/8/8/8/8/8/4K3 w - e6 0 1")
    ("en passant with the wrong colour to move"
     . "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e3 0 1")
    ("en passant square occupied" . "4k3/8/4p3/4p3/8/8/8/4K3 w - e6 0 1")
    ("en passant origin square occupied" . "4k3/3p4/8/3pP3/8/8/8/4K3 w - d6 0 1")
    ("en passant origin square occupied, black to move"
     . "4k3/8/8/8/3Pp3/8/3P4/4K3 b - d3 0 1")
    ("negative halfmove clock" . "4k3/8/8/8/8/8/8/4K3 w - - -1 1")
    ("halfmove clock not a number" . "4k3/8/8/8/8/8/8/4K3 w - - x 1")
    ("fullmove number zero" . "4k3/8/8/8/8/8/8/4K3 w - - 0 0")
    ("halfmove clock too long" . "4k3/8/8/8/8/8/8/4K3 w - - 123456789 1")
    ("halfmove clock of eight digits" . "4k3/8/8/8/8/8/8/4K3 w - - 10000000 1")
    ("fullmove number of eight digits" . "4k3/8/8/8/8/8/8/4K3 w - - 0 10000000")
    ("plus sign in a clock" . "4k3/8/8/8/8/8/8/4K3 w - - +5 1")
    ("no white king" . "4k3/8/8/8/8/8/8/8 w - - 0 1")
    ("no black king" . "8/8/8/8/8/8/8/4K3 w - - 0 1")
    ("two white kings" . "4k3/8/8/8/8/8/8/3KK3 w - - 0 1")
    ("two black kings" . "3kk3/8/8/8/8/8/8/4K3 w - - 0 1")
    ("white pawn on the last rank" . "4P1k1/8/8/8/8/8/8/4K3 w - - 0 1")
    ("black pawn on the first rank" . "4k3/8/8/8/8/8/8/4Kp2 w - - 0 1")
    ("white pawn on the first rank" . "4k3/8/8/8/8/8/8/P3K3 w - - 0 1")
    ("side not to move in check" . "4k3/8/8/8/8/8/4R3/4K3 w - - 0 1")
    ("two kings adjacent" . "8/8/8/8/8/8/4k3/4K3 w - - 0 1"))
  "Pairs (description . FEN) that PARSE-FEN must reject with FEN-ERROR.")

(defun with-digits-from (text zero)
  "TEXT with its ASCII digits replaced by the digits of the Unicode block whose zero has the
character code ZERO."
  (map 'string (lambda (char)
                 (if (char<= #\0 char #\9)
                     (code-char (+ zero (- (char-code char) (char-code #\0))))
                     char))
       text))

(defun non-ascii-digit-fens ()
  "Pairs (description . FEN) of valid FENs with one field written in non-ASCII decimal
digits. SBCL's DIGIT-CHAR-P reads such characters as digits; PARSE-FEN must reject them."
  (loop for (block . zero) in '(("fullwidth" . #xFF10) ("Arabic-Indic" . #x0660)
                                ("Devanagari" . #x0966) ("Thai" . #x0E50))
        append (list (cons (format nil "~A digits in the placement" block)
                           (format nil "~A w - - 0 1"
                                   (with-digits-from "4k3/8/8/8/8/8/8/4K3" zero)))
                     (cons (format nil "~A digits in the clocks" block)
                           (format nil "4k3/8/8/8/8/8/8/4K3 w - - ~A ~A"
                                   (with-digits-from "5" zero) (with-digits-from "7" zero)))
                     (cons (format nil "~A digit in the en-passant square" block)
                           (format nil "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR ~
                                        b KQkq e~A 0 1"
                                   (with-digits-from "3" zero))))))

(deftest :fen rejects-malformed-input-with-a-clean-error
  (let ((keys-before (zobrist-key-table-snapshot)))
    (loop for (description . fen) in (append *malformed-fens* (non-ascii-digit-fens))
          do (incf *assertions*)
             (handler-case
                 (progn (scf-ref:parse-fen fen)
                        (record-failure "~A: ~S was accepted" description fen))
               (scf-ref:fen-error () nil)
               (error (condition)
                 (record-failure "~A: ~S signalled ~A instead of FEN-ERROR" description fen
                                 (type-of condition)))))
    (is-equal keys-before (zobrist-key-table-snapshot) "failed parses leave the tables alone")))

(deftest :fen rejects-input-that-is-not-a-string
  (signals scf-ref:fen-error (scf-ref:parse-fen nil))
  (signals scf-ref:fen-error (scf-ref:parse-fen 42))
  (signals scf-ref:fen-error (scf-ref:parse-fen '("4k3/8/8/8/8/8/8/4K3" "w"))))

(defun fen-rejection (fen)
  "The FEN-ERROR that PARSE-FEN signals for FEN, or NIL when it accepts FEN."
  (handler-case (progn (scf-ref:parse-fen fen) nil)
    (scf-ref:fen-error (condition) condition)))

(defun padded (text length)
  "TEXT followed by spaces up to LENGTH characters."
  (concatenate 'string text (make-string (- length (length text)) :initial-element #\Space)))

(deftest :fen rejects-oversized-input-by-its-length
  ;; The length test comes first: an oversized FEN is refused for its length, and the
  ;; condition keeps only its first 40 characters.
  (let ((reason (format nil "longer than ~D characters" scf-ref:*max-fen-length*))
        (valid "4k3/8/8/8/8/8/8/4K3 w - - 0 1"))
    (dolist (fen (list (make-string 1000000 :initial-element #\8)
                       (concatenate 'string "4k3/8/8/8/8/8/8/4K3 w - - "
                                    (make-string 100000 :initial-element #\1) " 1")
                       (padded valid (1+ scf-ref:*max-fen-length*))))
      (let ((condition (fen-rejection fen)))
        (is-equal reason (and condition (scf-ref:position-error-reason condition))
                  "a FEN of ~D characters" (length fen))
        (is (and condition (<= (length (scf-ref:fen-error-fen condition)) 40))
            "the condition holds a prefix, not the whole input")))
    ;; At the limit the length test passes and the FEN is parsed as usual.
    (is-equal valid (scf-ref:position-to-fen
                     (scf-ref:parse-fen (padded valid scf-ref:*max-fen-length*))))))

(deftest :fen error-message-names-the-fen-and-the-reason
  (handler-case (scf-ref:parse-fen "4k3/8/8/8/8/8/8/4K3 x - - 0 1")
    (scf-ref:fen-error (condition)
      (is-equal "4k3/8/8/8/8/8/8/4K3 x - - 0 1" (scf-ref:fen-error-fen condition))
      (let ((text (princ-to-string condition)))
        (is (search "side to move" text) "the message says what is wrong: ~A" text)))))

(deftest :fen en-passant-square-is-kept-as-written
  ;; The FEN field follows the standard (set after every double push); only the Zobrist key
  ;; ignores a square no pawn can use.
  (let ((pos (fen-position "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")))
    (is-eql +e3+ (scf-ref:pos-en-passant pos))
    (is-false (scf-ref:en-passant-capture-available-p pos))))
