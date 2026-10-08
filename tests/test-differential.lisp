;;;; test-differential.lisp -- the optimized layer judged by the reference model.
;;;;
;;;; On every position visited the two layers must agree on (INV-C1, INV-C2, INV-C3):
;;;;  - the set of legal moves, compared as sorted lists of packed moves (the flags included),
;;;;    and the set of pseudo-legal moves, which the two layers define the same way;
;;;;  - whether the side to move is in check;
;;;;  - for every square and both colours, whether a piece of that colour attacks the square
;;;;    (BITBOARD-SQUARE-ATTACKED-P against the reference's SQUARE-ATTACKED-P);
;;;;  - the set of pieces giving check (BITBOARD-CHECKERS) against a set found by walking the
;;;;    board from every enemy piece with the test's own geometry (NAIVE-CHECKERS);
;;;;  - after each legal move, made on both: the whole state (board, side, castling rights,
;;;;    en-passant square, clocks), the incremental key of the optimized layer against its own
;;;;    from-scratch key (BITBOARD-COMPUTE-KEY) and against the reference key, and the internal
;;;;    consistency of the bitboards (BITBOARD-CONSISTENT-P);
;;;;  - after the move is unmade on both: the exact bitboard state before it, and the ply.
;;;; The positions come from the perft tables, from the special-case suites (their FENs are
;;;; read from the test sources) and from seeded random playouts in which both layers play the
;;;; same moves in lockstep. Random legal positions are also compared by perft count.
;;;;
;;;; MAKE TEST runs the :STANDARD profile; MAKE DIFFERENTIAL-DEEP runs :DEEP, which visits
;;;; millions of positions. The seeds are declared here.

(in-package #:scacchiforge.test)

(defvar *differential-profile* :standard
  "Either :STANDARD (what MAKE TEST runs) or :DEEP (what MAKE DIFFERENTIAL-DEEP runs).")

(defun differential-scale (standard deep)
  "STANDARD under the :STANDARD profile, DEEP under the :DEEP one."
  (if (eq *differential-profile* :deep) deep standard))

(defparameter *differential-failure-limit* 25
  "After this many differences a differential test stops: the first ones locate the error.")

(defvar *differential-failures* 0 "Differences recorded by the current differential test.")

(defun differential-failure (control &rest arguments)
  "Record a difference between the layers; stop the test after *DIFFERENTIAL-FAILURE-LIMIT*."
  (apply #'record-failure control arguments)
  (when (>= (incf *differential-failures*) *differential-failure-limit*)
    (error "~D differences between the layers; stopping here" *differential-failures*)))

(defmacro with-differential-test (() &body body)
  "Run BODY with a fresh count of differences."
  `(let ((*differential-failures* 0))
     ,@body))

(defun sorted-moves (moves)
  "MOVES sorted as integers, in a fresh list."
  (sort (copy-list moves) #'<))

(defun state-differences (bbp pos)
  "The fields on which the bitboard position BBP and the reference position POS differ, as a
list of strings (empty when they hold the same state). The key is compared separately."
  (let ((differences '()))
    (dotimes (square 64)
      (unless (= (aref (scf-opt:bbp-board bbp) square) (scf-ref:piece-at pos square))
        (push (format nil "piece on ~A" (square-name square)) differences)))
    (unless (= (scf-opt:bbp-side bbp) (scf-ref:pos-side pos))
      (push "side to move" differences))
    (unless (= (scf-opt:bbp-castling bbp) (scf-ref:pos-castling pos))
      (push "castling rights" differences))
    (unless (= (scf-opt:bbp-en-passant bbp) (scf-ref:pos-en-passant pos))
      (push "en-passant square" differences))
    (unless (= (scf-opt:bbp-halfmove bbp) (scf-ref:pos-halfmove pos))
      (push "halfmove clock" differences))
    (unless (= (scf-opt:bbp-fullmove bbp) (scf-ref:pos-fullmove pos))
      (push "fullmove number" differences))
    differences))

(defun move-list-text (moves)
  "MOVES as one string of long algebraic moves."
  (format nil "~{~A~^ ~}" (move-strings moves)))

(defun naive-piece-attacks (piece square occupancy)
  "The squares PIECE on SQUARE attacks when OCCUPANCY is the set of occupied squares, by
walking the board with the test's own steps (NAIVE-STEPS and NAIVE-SLIDE,
tests/test-optimized.lisp), independently of both layers."
  (let ((type (piece-type piece)))
    (cond ((= type +pawn+) (naive-steps square (pawn-capture-steps (piece-colour piece))))
          ((= type +knight+) (naive-steps square *knight-steps*))
          ((= type +king+) (naive-steps square *king-steps*))
          ((= type +bishop+) (naive-slide square occupancy *bishop-steps*))
          ((= type +rook+) (naive-slide square occupancy *rook-steps*))
          (t (naive-slide square occupancy (append *rook-steps* *bishop-steps*))))))

(defun naive-checkers (pos)
  "The squares of the pieces giving check to the king of the side to move of the reference
position POS: every piece of the other colour whose NAIVE-PIECE-ATTACKS reach that king."
  (let* ((side (scf-ref:pos-side pos))
         (king-piece (make-piece side +king+))
         (occupancy 0)
         (king nil)
         (checkers 0))
    (dotimes (square 64)
      (let ((piece (scf-ref:piece-at pos square)))
        (unless (= piece +empty+)
          (setf occupancy (logior occupancy (ash 1 square))))
        (when (= piece king-piece)
          (setf king square))))
    (dotimes (square 64 checkers)
      (let ((piece (scf-ref:piece-at pos square)))
        (when (and (/= piece +empty+)
                   (/= (piece-colour piece) side)
                   (logbitp king (naive-piece-attacks piece square occupancy)))
          (setf checkers (logior checkers (ash 1 square))))))))

(defun attack-differences (pos bbp)
  "The (square . colour) pairs on which the reference's SQUARE-ATTACKED-P and the optimized
layer's BITBOARD-SQUARE-ATTACKED-P disagree, over every square and both colours."
  (let ((differences '()))
    (dotimes (square 64)
      (dolist (by (list +white+ +black+))
        (unless (eq (and (scf-ref:square-attacked-p pos square by) t)
                    (and (scf-opt:bitboard-square-attacked-p bbp square by) t))
          (push (cons square by) differences))))
    (nreverse differences)))

(defun check-layers-agree (pos bbp)
  "Compare the reference position POS and the bitboard position BBP, which must hold the same
state, as described in the file header. Both are left as they were. Returns the legal moves of
the reference and the number of moves made and unmade on both."
  (let ((before (state-differences bbp pos))
        (legal (scf-ref:legal-moves pos))
        (checked 0))
    (incf *assertions*)
    (when before
      (differential-failure "~A: the layers hold different states: ~{~A~^, ~}"
                            (scf-ref:position-to-fen pos) before)
      (return-from check-layers-agree (values legal 0)))
    (let ((optimized (scf-opt:bitboard-legal-moves bbp))
          (reference-pseudo (scf-ref:pseudo-legal-moves pos))
          (optimized-pseudo (scf-opt:bitboard-pseudo-legal-moves bbp)))
      (incf *assertions* 4)
      (unless (equal (sorted-moves legal) (sorted-moves optimized))
        (differential-failure "~A: legal moves differ; reference only: ~A; optimized only: ~A"
                              (scf-ref:position-to-fen pos)
                              (move-list-text (set-difference legal optimized))
                              (move-list-text (set-difference optimized legal))))
      (unless (equal (sorted-moves reference-pseudo) (sorted-moves optimized-pseudo))
        (differential-failure
         "~A: pseudo-legal moves differ; reference only: ~A; optimized only: ~A"
         (scf-ref:position-to-fen pos)
         (move-list-text (set-difference reference-pseudo optimized-pseudo))
         (move-list-text (set-difference optimized-pseudo reference-pseudo))))
      (unless (eq (and (scf-ref:in-check-p pos) t) (and (scf-opt:bitboard-in-check-p bbp) t))
        (differential-failure "~A: the layers disagree on check" (scf-ref:position-to-fen pos)))
      (incf *assertions* 2)
      (let ((differences (attack-differences pos bbp)))
        (when differences
          (differential-failure "~A: the layers disagree on ~D attacked square~:P, first~{ ~A~}"
                                (scf-ref:position-to-fen pos) (length differences)
                                (loop for (square . by) in differences
                                      repeat 8
                                      collect (format nil "~A-by-~:[black~;white~]"
                                                      (square-name square) (= by +white+))))))
      (let ((naive-checkers (naive-checkers pos))
            (optimized-checkers (scf-opt:bitboard-checkers bbp)))
        (unless (= naive-checkers optimized-checkers)
          (differential-failure "~A: the checkers differ: ~:[none~;~:*~{~A~^ ~}~] by walking ~
                                 the board, ~:[none~;~:*~{~A~^ ~}~] by the optimized layer"
                                (scf-ref:position-to-fen pos)
                                (mapcar #'square-name (scf-opt:bit-indices naive-checkers))
                                (mapcar #'square-name
                                        (scf-opt:bit-indices optimized-checkers)))))
      (unless (= (scf-opt:bbp-key bbp) (scf-opt:bitboard-compute-key bbp) (scf-ref:pos-key pos))
        (differential-failure "~A: the keys differ" (scf-ref:position-to-fen pos))))
    (let ((snapshot (scf-opt:bitboard-clone bbp))
          (ply (scf-opt:bbp-ply bbp)))
      (dolist (move legal)
        (let ((problems '()))
          (scf-ref:make-move pos move)
          (scf-opt:bitboard-make-move bbp move)
          (incf *assertions* 4)
          (let ((differences (state-differences bbp pos)))
            (when differences
              (push (format nil "states differ: ~{~A~^, ~}" differences) problems)))
          (unless (= (scf-opt:bbp-key bbp) (scf-opt:bitboard-compute-key bbp))
            (push "incremental key differs from the from-scratch key" problems))
          (unless (= (scf-opt:bbp-key bbp) (scf-ref:pos-key pos))
            (push "key differs from the reference key" problems))
          (multiple-value-bind (consistent inconsistencies) (scf-opt:bitboard-consistent-p bbp)
            (unless consistent
              (push (format nil "~{~A~^, ~}" inconsistencies) problems)))
          (scf-ref:unmake-move pos)
          (scf-opt:bitboard-unmake-move bbp)
          (unless (and (scf-opt:bitboard-equal-p bbp snapshot) (= (scf-opt:bbp-ply bbp) ply))
            (push "unmake did not restore the exact state" problems))
          (when problems
            (differential-failure "~A, move ~A: ~{~A~^; ~}" (scf-ref:position-to-fen pos)
                                  (move-to-string move) (reverse problems)))
          (incf checked))))
    (values legal checked)))

(defun check-tree-agrees (pos bbp depth)
  "CHECK-LAYERS-AGREE on POS / BBP and on every position reachable from it in fewer than DEPTH
plies. Returns the number of positions and the number of moves checked."
  (let ((positions 1))
    (multiple-value-bind (legal checked) (check-layers-agree pos bbp)
      (when (> depth 1)
        (dolist (move legal)
          (scf-ref:make-move pos move)
          (scf-opt:bitboard-make-move bbp move)
          (multiple-value-bind (child-positions child-checked)
              (check-tree-agrees pos bbp (1- depth))
            (incf positions child-positions)
            (incf checked child-checked))
          (scf-ref:unmake-move pos)
          (scf-opt:bitboard-unmake-move bbp)))
      (values positions checked))))

(defun check-trees-from (fens depth)
  "CHECK-TREE-AGREES from each of FENS to DEPTH. Returns the positions and the moves checked."
  (let ((positions 0) (checked 0))
    (dolist (fen fens)
      (let ((pos (fen-position fen)))
        (multiple-value-bind (p c) (check-tree-agrees pos (scf-opt:bitboard-from-reference pos)
                                                      depth)
          (incf positions p)
          (incf checked c))))
    (values positions checked)))

;;; --- the positions of the special-case suites -------------------------------------------

(defun strings-read-from (pathname)
  "Every string literal in the forms of the Lisp source file PATHNAME, read in the package
that each IN-PACKAGE form selects, in order, without duplicates."
  (let ((*package* (find-package '#:cl-user))
        (*read-eval* nil)
        (strings '()))
    (labels ((walk (object)
               (typecase object
                 (string (pushnew object strings :test #'string=))
                 (cons (walk (car object)) (walk (cdr object))))))
      (with-open-file (in pathname)
        (loop for form = (read in nil in)
              until (eq form in)
              do (when (and (consp form) (eq (first form) 'in-package))
                   (setf *package* (find-package (second form))))
                 (walk form))))
    (nreverse strings)))

(defun fen-string-p (string)
  "True when the reference reads STRING as a legal FEN."
  (handler-case (and (scf-ref:parse-fen string) t)
    (scf-ref:position-error () nil)))

(defparameter *special-case-test-files* '("test-movegen" "test-make-unmake" "test-zobrist")
  "The test files whose FEN literals are the positions of the special-case suites.")

(defun special-case-fens ()
  "The FENs written in the special-case test files, read from their source: every string
literal there that the reference reads as a legal FEN."
  (remove-duplicates
   (loop for name in *special-case-test-files*
         append (remove-if-not #'fen-string-p
                               (strings-read-from
                                (asdf:component-pathname
                                 (asdf:find-component "scacchiforge/test" name)))))
   :test #'string= :from-end t))

;;; --- the tests ----------------------------------------------------------------------------

(deftest :differential the-special-case-positions-are-found-in-the-sources
  (let ((fens (special-case-fens)))
    (note "~D special-case positions" (length fens))
    (is (> (length fens) 40) "the FENs of the special-case suites were found: ~D" (length fens))
    (is (member "8/8/8/K2pP2r/8/8/8/7k w - d6 0 1" fens :test #'string=)
        "the horizontal en-passant pin is among them")))

(deftest :differential perft-table-positions
  (with-differential-test ()
    (let ((depth (differential-scale 2 3)))
      (multiple-value-bind (positions moves)
          (check-trees-from (mapcar #'second (append *main-perft-table* *special-perft-table*))
                            depth)
        (note "~D positions within ~D plies of the perft positions, ~D moves made on both"
              positions (1- depth) moves)
        (is (plusp positions))))))

(deftest :differential special-case-positions
  (with-differential-test ()
    (let ((depth (differential-scale 2 3)))
      (multiple-value-bind (positions moves)
          (check-trees-from (append (special-case-fens) *round-trip-fens* *fuzz-fens*) depth)
        (note "~D positions within ~D plies of the special-case positions, ~D moves made on both"
              positions (1- depth) moves)
        (is (plusp positions))))))

(defun lockstep-playouts (fens seed games max-plies)
  "Play GAMES random games of up to MAX-PLIES plies from each of FENS, drawing from a generator
seeded with SEED, with every move made on both layers; check the layers on every position;
at the end of a game take every move back on the optimized layer and require its start state.
Returns the games, the positions and the moves checked, and a property list counting the
positions in check and those with an en-passant capture, a castling move or a promotion among
their legal moves."
  (let ((rng (make-rng seed))
        (games-played 0) (positions 0) (checked 0)
        (in-check 0) (en-passant 0) (castling 0) (promotion 0))
    (dolist (fen fens)
      (let ((start (fen-position fen)))
        (dotimes (game games)
          (let* ((pos (scf-ref:clone-position start))
                 (bbp (scf-opt:bitboard-from-reference pos))
                 (initial (scf-opt:bitboard-clone bbp))
                 (plies 0))
            (loop
              (multiple-value-bind (legal moves) (check-layers-agree pos bbp)
                (incf positions)
                (incf checked moves)
                (when (scf-ref:in-check-p pos) (incf in-check))
                (when (some #'move-en-passant-p legal) (incf en-passant))
                (when (some #'move-castle-p legal) (incf castling))
                (when (some #'move-promotion-p legal) (incf promotion))
                (when (or (null legal) (>= plies max-plies))
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
                                    fen plies))
            (incf games-played)))))
    (values games-played positions checked
            (list :in-check in-check :en-passant en-passant :castling castling
                  :promotion promotion))))

(deftest :differential lockstep-random-playouts
  (with-differential-test ()
    (let ((seed 20261004))
      (multiple-value-bind (games positions moves kinds)
          (lockstep-playouts *fuzz-fens* seed (differential-scale 30 2000) 120)
        (note "seed ~D: ~D games, ~D positions, ~D moves made on both" seed games positions moves)
        (note "positions in check ~D, with en passant ~D, castling ~D, promotion ~D"
              (getf kinds :in-check) (getf kinds :en-passant) (getf kinds :castling)
              (getf kinds :promotion))
        (is (> positions (differential-scale 30000 2000000)) "~D positions" positions)
        (loop for (kind count) on kinds by #'cddr
              do (is (plusp count) "the playouts reach positions with ~(~A~)" kind))))))

(deftest :differential perft-of-random-positions
  ;; Counts deeper than one move from positions that no table lists.
  (with-differential-test ()
    (let ((rng (make-rng 41))
          (count (differential-scale 300 2000))
          (depth (differential-scale 2 3))
          (leaves 0))
      (dotimes (i count)
        (let* ((pos (scf-ref:random-legal-position *fuzz-fens* rng 120))
               (reference (scf-ref:perft pos depth))
               (optimized (scf-opt:bitboard-perft (scf-opt:bitboard-from-reference pos) depth)))
          (incf leaves reference)
          (incf *assertions*)
          (unless (= reference optimized)
            (differential-failure "~A: perft ~D is ~D for the reference, ~D optimized"
                                  (scf-ref:position-to-fen pos) depth reference optimized))))
      (note "seed 41: ~D random positions, perft ~D, ~D leaves" count depth leaves))))
