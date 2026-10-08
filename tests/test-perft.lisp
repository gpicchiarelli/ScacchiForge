;;;; test-perft.lisp -- perft against published counts (see the provenance below).
;;;;
;;;; Never change an expected number to make a test pass. A wrong expected count would be
;;;; reported, with a proof, not edited.
;;;;
;;;; Provenance of the numbers. The three sources named below were read on 2026-10-04, and
;;;; every count called published here was compared with its source on that day.
;;;;  - *MAIN-PERFT-TABLE*: every count is published.
;;;;    startpos, kiwipete, pos3, pos4, pos5 and pos6 are the six positions of the Chess
;;;;    Programming Wiki page "Perft Results" (https://www.chessprogramming.org/Perft_Results),
;;;;    with that page's counts. The page writes the kiwipete FEN without its two clock fields;
;;;;    "0 1" is added here.
;;;;    "promo" is not on that page. Its FEN and its six counts come from the file
;;;;    src/perft/standard.epd of the Ethereal engine (https://github.com/AndyGrant/Ethereal,
;;;;    branch master).
;;;;  - *SPECIAL-PERFT-TABLE*: hand-picked edge cases. The third field lists the depths whose
;;;;    count is published. "castling-both-sides" and its four counts come from the Ethereal
;;;;    file named above. Every other position, with the count at its one published depth,
;;;;    comes from Peter Ellis Jones's list of perft test positions (GitHub gist
;;;;    8c46c28141c162d1d8a0f0badbc9cff9).
;;;;    The remaining counts of this table are this engine's own output, recorded so that a
;;;;    change of behaviour shows up at a shallow depth. They are not published values and
;;;;    do not check the move generator on their own: the published count does.

(in-package #:scacchiforge.test)

(defvar *perft-profile* :standard
  "Either :STANDARD (what MAKE TEST runs) or :DEEP (what MAKE PERFT-DEEP runs).")

(defparameter *main-perft-table*
  '(("startpos" "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
     ((1 20) (2 400) (3 8902) (4 197281) (5 4865609))
     ((6 119060324)))
    ("kiwipete" "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
     ((1 48) (2 2039) (3 97862) (4 4085603))
     ((5 193690690)))
    ("pos3" "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
     ((1 14) (2 191) (3 2812) (4 43238) (5 674624))
     ((6 11030083)))
    ("pos4" "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
     ((1 6) (2 264) (3 9467) (4 422333))
     ((5 15833292)))
    ("pos5" "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"
     ((1 44) (2 1486) (3 62379) (4 2103487))
     ((5 89941194)))
    ("pos6" "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"
     ((1 46) (2 2079) (3 89890) (4 3894594))
     ((5 164075551)))
    ("promo" "n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1"
     ((1 24) (2 496) (3 9483) (4 182838))
     ((5 3605103) (6 71179139))))
  "(name fen standard-counts deep-only-counts); counts are (depth nodes).")

(defun main-perft-count (name depth)
  "The count of the position NAME of *MAIN-PERFT-TABLE* at DEPTH, among its standard and its
deep counts; an error when the table has none. The benchmarks (benchmarks/perft-bench.lisp)
and tools/hot-path.lisp take their expected counts from here, so that each count is written
once, in this file, under the provenance stated in its header."
  (let ((entry (find name *main-perft-table* :key #'first :test #'string=)))
    (or (second (assoc depth (append (third entry) (fourth entry))))
        (error "*MAIN-PERFT-TABLE* has no count for ~A at depth ~D" name depth))))

(defparameter *special-perft-table*
  '(("castling-both-sides" "r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"
     (1 2 3 4) ((1 26) (2 568) (3 13744) (4 314346)) ())
    ("illegal-en-passant-horizontal-pin" "3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1"
     (6) ((1 18) (2 92) (3 1670) (4 10138) (5 185429) (6 1134888)) ())
    ("illegal-en-passant-discovered-check" "8/8/4k3/8/2p5/8/B2P2K1/8 w - - 0 1"
     (6) ((1 13) (2 102) (3 1266) (4 10276) (5 135655) (6 1015133)) ())
    ("en-passant-gives-check" "8/8/1k6/2b5/2pP4/8/5K2/8 b - d3 0 1"
     (6) ((1 15) (2 126) (3 1928) (4 13931) (5 206379) (6 1440467)) ())
    ("short-castle-gives-check" "5k2/8/8/8/8/8/8/4K2R w K - 0 1"
     (6) ((1 15) (2 66) (3 1198) (4 6399) (5 120330) (6 661072)) ())
    ("long-castle-gives-check" "3k4/8/8/8/8/8/8/R3K3 w Q - 0 1"
     (6) ((1 16) (2 71) (3 1286) (4 7418) (5 141077) (6 803711)) ())
    ("castling-rights-lost" "r3k2r/1b4bq/8/8/8/8/7B/R3K2R w KQkq - 0 1"
     (4) ((1 26) (2 1141) (3 27826) (4 1274206)) ())
    ("castling-prevented" "r3k2r/8/3Q4/8/8/5q2/8/R3K2R b KQkq - 0 1"
     (4) ((1 44) (2 1494) (3 50509) (4 1720476)) ())
    ("promote-out-of-check" "2K2r2/4P3/8/8/8/8/8/3k4 w - - 0 1"
     (6) ((1 11) (2 133) (3 1442) (4 19174) (5 266199) (6 3821001)) ())
    ("discovered-check" "8/8/1P2K3/8/2n5/1q6/8/5k2 b - - 0 1"
     (5) ((1 29) (2 165) (3 5160) (4 31961) (5 1004658)) ())
    ("promote-to-give-check" "4k3/1P6/8/8/8/8/K7/8 w - - 0 1"
     (6) ((1 9) (2 40) (3 472) (4 2661) (5 38983) (6 217342)) ())
    ("underpromote-to-give-check" "8/P1k5/K7/8/8/8/8/8 w - - 0 1"
     (6) ((1 6) (2 27) (3 273) (4 1329) (5 18135) (6 92683)) ())
    ("self-stalemate" "K1k5/8/P7/8/8/8/8/8 w - - 0 1"
     (6) ((1 2) (2 6) (3 13) (4 63) (5 382) (6 2217)) ())
    ("stalemate-and-checkmate-1" "8/k1P5/8/1K6/8/8/8/8 w - - 0 1"
     (7) ((1 10) (2 25) (3 268) (4 926) (5 10857) (6 43261) (7 567584)) ())
    ("stalemate-and-checkmate-2" "8/8/2k5/5q2/5n2/8/5K2/8 b - - 0 1"
     (4) ((1 37) (2 183) (3 6559) (4 23527)) ())
    ;; Published at depth 1 only; no other depth is recorded.
    ("published-1-castle-pin" "r6r/1b2k1bq/8/8/7B/8/8/R3K2R b KQ - 3 2" (1) ((1 8)) ())
    ("published-1-en-passant-pin" "8/8/8/2k5/2pP4/8/B7/4K3 b - d3 0 3" (1) ((1 8)) ())
    ("published-1-knight-development"
     "r1bqkbnr/pppppppp/n7/8/8/P7/1PPPPPPP/RNBQKBNR w KQkq - 2 2" (1) ((1 19)) ())
    ("published-1-queen-attack"
     "r3k2r/p1pp1pb1/bn2Qnp1/2qPN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQkq - 3 2" (1) ((1 5)) ())
    ("published-1-castle-with-queen"
     "2kr3r/p1ppqpb1/bn2Qnp1/3PN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQ - 3 2" (1) ((1 44)) ())
    ("published-1-promotions-in-check"
     "rnb2k1r/pp1Pbppp/2p5/q7/2B5/8/PPPQNnPP/RNB1K2R w KQ - 3 9" (1) ((1 39)) ())
    ("published-1-pawn-ending" "2r5/3pk3/8/2P5/8/2K5/8/8 w - - 5 4" (1) ((1 9)) ()))
  "(name fen published-depths standard-counts deep-only-counts). See the file header.")

(defun check-perft-count (name fen depth expected)
  "Run perft on FEN to DEPTH, compare with EXPECTED, and report the value reached."
  (let* ((pos (fen-position fen))
         (before (scf-ref:clone-position pos))
         (start (get-internal-real-time))
         (actual (scf-ref:perft pos depth))
         (seconds (/ (- (get-internal-real-time) start) (float internal-time-units-per-second))))
    (note "~A depth ~D: ~D~:[ (expected ~D)~;~*~] ~,2F s" name depth actual
          (eql actual expected) expected seconds)
    (is-eql expected actual "perft of ~A at depth ~D" name depth)
    (is (and (scf-ref:positions-equal-p pos before) (zerop (scf-ref:pos-ply pos)))
        "perft left ~A unchanged" name)))

(defun deep-profile-p ()
  "True when the deep perft profile is selected."
  (eq *perft-profile* :deep))

(deftest :perft main-table
  (loop for (name fen standard deep) in *main-perft-table*
        do (loop for (depth expected) in (append standard (when (deep-profile-p) deep))
                 do (check-perft-count name fen depth expected))))

(deftest :perft special-positions
  (loop for (name fen nil standard deep) in *special-perft-table*
        do (loop for (depth expected) in (append standard (when (deep-profile-p) deep))
                 do (check-perft-count name fen depth expected))))

(deftest :perft every-special-position-names-a-published-depth-it-records
  (loop for (name nil published standard deep) in *special-perft-table*
        do (is (and (consp published)
                    (subsetp published (mapcar #'first (append standard deep))))
               "~A: the published depths ~S are not all recorded" name published)))

(deftest :perft depth-zero-is-one-and-negative-depth-is-refused
  (is-eql 1 (scf-ref:perft (scf-ref:start-position) 0))
  (signals type-error (scf-ref:perft (scf-ref:start-position) -1)))

;;; --- divide ----------------------------------------------------------------------------

(deftest :perft divide-agrees-with-perft-and-the-legal-moves
  (loop for (name fen) in *main-perft-table*
        do (let ((pos (fen-position fen)))
             (loop for depth from 1 to 3
                   do (multiple-value-bind (entries total) (scf-ref:perft-divide pos depth)
                        (is-eql (scf-ref:perft pos depth) total "divide total, ~A d~D" name depth)
                        (is-eql total (reduce #'+ entries :key #'cdr))
                        (is-equal (scf-ref:legal-moves pos) (mapcar #'car entries)
                                  "divide lists the legal moves of ~A" name))))))

(deftest :perft divide-matches-known-startpos-counts
  (multiple-value-bind (entries total) (scf-ref:perft-divide (scf-ref:start-position) 3)
    (is-eql 8902 total)
    (is-eql 20 (length entries))
    (is-eql 600 (cdr (assoc "e2e4" entries :key #'move-to-string :test #'string=))
            "after e2e4 there are 600 continuations of depth 2")
    (is-eql 380 (cdr (assoc "a2a3" entries :key #'move-to-string :test #'string=)))))

(deftest :perft print-divide-prints-every-root-move
  (let ((text (with-output-to-string (out)
                (scf-ref:print-divide (scf-ref:start-position) 2 out))))
    (is (search "e2e4: 20" text))
    (is (search "Nodes searched: 400" text))))

;;; --- colour symmetry ---------------------------------------------------------------------------

(defun swap-case (string)
  "STRING with upper-case letters made lower case and the other way round."
  (map 'string (lambda (char)
                 (cond ((upper-case-p char) (char-downcase char))
                       ((lower-case-p char) (char-upcase char))
                       (t char)))
       string))

(defun mirror-fen (fen)
  "The FEN with colours exchanged: ranks flipped, piece colours swapped, side to move and
castling rights swapped, en-passant rank mirrored. Its perft counts must be equal to FEN's."
  (destructuring-bind (placement side castling en-passant halfmove fullmove)
      (let ((fields (split-on-spaces fen)))
        (if (= (length fields) 4) (append fields (list "0" "1")) fields))
    (let* ((ranks (split-on #\/ placement))
           (flipped (format nil "~{~A~^/~}"
                            (mapcar #'swap-case (reverse ranks))))
           (new-castling (if (string= castling "-")
                             "-"
                             (let ((rights (swap-case castling)))
                               (coerce (loop for char across "KQkq"
                                             when (find char rights) collect char)
                                       'string))))
           (new-en-passant (if (string= en-passant "-")
                               "-"
                               (format nil "~A~D" (char en-passant 0)
                                       (- 9 (digit-char-p (char en-passant 1)))))))
      (format nil "~A ~A ~A ~A ~A ~A" flipped (if (string= side "w") "b" "w") new-castling
              new-en-passant halfmove fullmove))))

(defun split-on (char string)
  "The substrings of STRING separated by CHAR."
  (loop with start = 0
        for end = (position char string :start start)
        collect (subseq string start end)
        while end
        do (setf start (1+ end))))

(defun split-on-spaces (string)
  "The non-empty space-separated words of STRING."
  (remove "" (split-on #\Space string) :test #'string=))

(deftest :perft mirror-helper-is-an-involution
  (loop for (nil fen) in *main-perft-table*
        do (is-equal fen (mirror-fen (mirror-fen fen)))
           (is-false (string= fen (mirror-fen fen)))))

(deftest :perft colour-symmetry
  (flet ((check (name fen)
           (let ((mirror (mirror-fen fen)))
             (loop for depth from 1 to 3
                   do (is-eql (scf-ref:perft (fen-position fen) depth)
                              (scf-ref:perft (fen-position mirror) depth)
                              "~A and its colour mirror differ at depth ~D" name depth)))))
    (loop for (name fen) in *main-perft-table* do (check name fen))
    (loop for (name fen) in *special-perft-table* do (check name fen))))
