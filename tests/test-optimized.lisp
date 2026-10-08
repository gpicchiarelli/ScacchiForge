;;;; test-optimized.lisp -- the parts of the optimized layer below the move generator: attack
;;;; tables against the board geometry, the slider interface and each slider implementation
;;;; (rays and the two magic-bitboard layouts) against a naive walk, the magic numbers against
;;;; the seeded search, make and unmake at their edges, and allocation in the hot path.

(in-package #:scacchiforge.test)

;;; --- tables -----------------------------------------------------------------------------

(defun naive-steps (square deltas)
  "The bitboard of the squares reached from SQUARE by the (file . rank) DELTAS that stay on the
board, worked out with file and rank arithmetic."
  (let ((bits 0))
    (loop for (df . dr) in deltas
          for file = (+ (square-file square) df)
          for rank = (+ (square-rank square) dr)
          do (when (and (<= 0 file 7) (<= 0 rank 7))
               (setf bits (logior bits (ash 1 (make-square file rank))))))
    bits))

(defparameter *knight-steps*
  '((1 . 2) (2 . 1) (2 . -1) (1 . -2) (-1 . -2) (-2 . -1) (-2 . 1) (-1 . 2))
  "The (file . rank) steps of a knight.")

(defparameter *king-steps*
  '((-1 . -1) (-1 . 0) (-1 . 1) (0 . -1) (0 . 1) (1 . -1) (1 . 0) (1 . 1))
  "The (file . rank) steps of a king.")

(defun pawn-capture-steps (colour)
  "The (file . rank) steps of a capture by a pawn of COLOUR."
  (if (= colour +white+) '((-1 . 1) (1 . 1)) '((-1 . -1) (1 . -1))))

(deftest :optimized leaper-tables-match-the-board-geometry
  (dotimes (square 64)
    (is-eql (naive-steps square *knight-steps*)
            (scf-opt:knight-attacks square) "knight on ~A" (square-name square))
    (is-eql (naive-steps square *king-steps*)
            (scf-opt:king-attacks square) "king on ~A" (square-name square))
    (is-eql (naive-steps square (pawn-capture-steps +white+))
            (scf-opt:pawn-attacks +white+ square)
            "white pawn on ~A" (square-name square))
    (is-eql (naive-steps square (pawn-capture-steps +black+))
            (scf-opt:pawn-attacks +black+ square)
            "black pawn on ~A" (square-name square))))

(defparameter *rook-steps* '((0 . 1) (1 . 0) (0 . -1) (-1 . 0)))
(defparameter *bishop-steps* '((1 . 1) (-1 . 1) (1 . -1) (-1 . -1)))

(defun naive-slide (square occupancy steps)
  "The squares a slider on SQUARE attacks along the (file . rank) STEPS when OCCUPANCY is the
set of occupied squares: walk each direction one square at a time, stopping after the first
occupied square."
  (let ((bits 0))
    (loop for (df . dr) in steps
          do (loop for file = (+ (square-file square) df) then (+ file df)
                   for rank = (+ (square-rank square) dr) then (+ rank dr)
                   while (and (<= 0 file 7) (<= 0 rank 7))
                   do (let ((target (make-square file rank)))
                        (setf bits (logior bits (ash 1 target)))
                        (when (logbitp target occupancy)
                          (return)))))
    bits))

(defun inner-ray-mask (square steps)
  "The squares of the rays of SQUARE along STEPS without the last square of each ray: the only
squares whose occupancy can change what a slider on SQUARE attacks."
  (let ((bits 0))
    (loop for (df . dr) in steps
          do (loop for file = (+ (square-file square) df) then (+ file df)
                   for rank = (+ (square-rank square) dr) then (+ rank dr)
                   while (and (<= 0 (+ file df) 7) (<= 0 (+ rank dr) 7))
                   do (setf bits (logior bits (ash 1 (make-square file rank))))))
    bits))

(deftest :optimized slider-attacks-match-a-naive-walk
  ;; Exhaustive: for every square, every subset of the squares that can block its rays (at most
  ;; 2^12 for a rook, 2^9 for a bishop), with seeded random bits added off those squares, which
  ;; must change nothing. It checks the interface, whichever implementation the build chose;
  ;; every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy checks each
  ;; implementation on its own.
  (let ((rng (make-rng 64))
        (checked 0)
        (failures 0))
    (dotimes (square 64)
      (loop for (steps attacks) in (list (list *rook-steps* #'scf-opt:rook-attacks)
                                         (list *bishop-steps* #'scf-opt:bishop-attacks))
            do (let* ((mask (inner-ray-mask square steps))
                      (bits (scf-opt:bit-indices mask)))
                 (dotimes (subset (ash 1 (length bits)))
                   (let* ((blockers (loop for bit in bits
                                          for index from 0
                                          when (logbitp index subset)
                                            sum (ash 1 bit)))
                          (occupancy (logior blockers
                                             (logandc2 (rng-next-u64 rng) mask))))
                     (incf checked)
                     (unless (= (funcall attacks square occupancy)
                                (naive-slide square occupancy steps))
                       (when (< (incf failures) 10)
                         (record-failure "~A on ~A with occupancy ~16,'0X"
                                         (if (eq steps *rook-steps*) "rook" "bishop")
                                         (square-name square) occupancy))))))))
    (incf *assertions*)
    (note "~D square/occupancy pairs" checked)
    (is-eql 0 failures)
    (is (= (scf-opt:queen-attacks +d4+ #x0000001008000000)
           (logior (scf-opt:rook-attacks +d4+ #x0000001008000000)
                   (scf-opt:bishop-attacks +d4+ #x0000001008000000))))))

;;; --- the slider implementations: rays and the two magic layouts -------------------------

(defparameter *slider-implementations-under-test*
  (list (list :ray #'scf-opt:ray-rook-attacks #'scf-opt:ray-bishop-attacks)
        (list :magic #'scf-opt:magic-rook-attacks #'scf-opt:magic-bishop-attacks)
        (list :fixed-magic #'scf-opt:fixed-magic-rook-attacks
              #'scf-opt:fixed-magic-bishop-attacks))
  "(implementation rook-attacks bishop-attacks) of each slider implementation of the optimized
layer, the classical rays first.")

(defun slider-subsets (mask)
  "Every subset of the squares of MASK, as a list of bitboards."
  (let ((bits (scf-opt:bit-indices mask)))
    (loop for subset below (ash 1 (length bits))
          collect (loop for bit in bits
                        for index from 0
                        when (logbitp index subset)
                          sum (ash 1 bit)))))

(deftest :optimized every-slider-implementation-is-under-test
  (is-equal (sort (copy-list scf-opt:*slider-implementations*) #'string<)
            (sort (mapcar #'first *slider-implementations-under-test*) #'string<)))

(deftest :optimized relevant-occupancy-masks-and-magic-table-sizes
  ;; The layer's masks are the test's own inner rays; the table sizes follow from them.
  (let ((magic-size 0))
    (dotimes (square 64)
      (loop for (steps slot low high) in `((,*rook-steps* ,square 10 12)
                                           (,*bishop-steps* ,(+ 64 square) 5 9))
            do (let ((mask (inner-ray-mask square steps)))
                 (is-eql mask (scf-opt:relevant-occupancy-mask slot) "mask of slot ~D" slot)
                 (is (<= low (scf-opt:popcount64 mask) high) "relevant squares of slot ~D" slot)
                 (incf magic-size (ash 1 (scf-opt:popcount64 mask))))))
    (is-eql magic-size scf-opt:+magic-table-size+)
    (is-eql (+ (* 64 4096) (* 64 512)) scf-opt:+fixed-magic-table-size+)))

(defun slider-results (piece square occupancy)
  "The attacks of a PIECE (:ROOK or :BISHOP) on SQUARE with OCCUPANCY by each implementation
of *SLIDER-IMPLEMENTATIONS-UNDER-TEST*, in its order: the ray attacks first."
  (loop for (nil rook bishop) in *slider-implementations-under-test*
        collect (funcall (if (eq piece :rook) rook bishop) square occupancy)))

(deftest :optimized every-slider-implementation-matches-a-naive-walk-on-every-relevant-occupancy
  ;; Exhaustive: for every square and every subset of its relevant squares (up to 2^12 for a
  ;; rook, 2^9 for a bishop), each implementation must give both the naive walk's set and the
  ;; ray attacks' set, on the subset alone and with seeded random bits added off the relevant
  ;; squares: the magic lookups equal the ray attacks on every relevant occupancy of every
  ;; square.
  (let ((rng (make-rng 2026100501))
        (checked 0)
        (failures 0))
    (dotimes (square 64)
      (loop for (steps piece) in (list (list *rook-steps* :rook) (list *bishop-steps* :bishop))
            do (let ((mask (inner-ray-mask square steps)))
                 (dolist (subset (slider-subsets mask))
                   (dolist (occupancy (list subset
                                            (logior subset
                                                    (logandc2 (rng-next-u64 rng) mask))))
                     (let* ((expected (naive-slide square occupancy steps))
                            (results (slider-results piece square occupancy))
                            (ray (first results)))
                       (loop for (name) in *slider-implementations-under-test*
                             for result in results
                             do (incf checked)
                                (unless (= expected ray result)
                                  (when (< (incf failures) 10)
                                    (record-failure "~(~A~) ~(~A~) on ~A with occupancy ~
                                                     ~16,'0X"
                                                    name piece (square-name square)
                                                    occupancy))))))))))
    (incf *assertions*)
    (note "~D implementation/square/occupancy triples" checked)
    (is-eql (* 2 (length *slider-implementations-under-test*) scf-opt:+magic-table-size+)
            checked)
    (is-eql 0 failures)))

(deftest :optimized slider-implementations-agree-on-random-occupancies
  ;; Seeded random full-board occupancies of four densities (about 8, 16, 32 and 48 occupied
  ;; squares), the slider's own square occupied or not: every implementation must give the
  ;; naive walk's set.
  (let ((rng (make-rng 2026100502))
        (checked 0)
        (failures 0))
    (flet ((draw () (rng-next-u64 rng)))
      (dotimes (square 64)
        (dotimes (i 50)
          (dolist (occupancy (list (logand (draw) (draw) (draw)) (logand (draw) (draw))
                                   (draw) (logior (draw) (draw))))
            (loop for (steps piece) in (list (list *rook-steps* :rook)
                                             (list *bishop-steps* :bishop))
                  do (let ((expected (naive-slide square occupancy steps)))
                       (loop for (name) in *slider-implementations-under-test*
                             for result in (slider-results piece square occupancy)
                             do (incf checked)
                                (unless (= expected result)
                                  (when (< (incf failures) 10)
                                    (record-failure "~(~A~) ~(~A~) on ~A with occupancy ~
                                                     ~16,'0X"
                                                    name piece (square-name square)
                                                    occupancy))))))))))
    (incf *assertions*)
    (note "~D implementation/square/occupancy triples" checked)
    (is-eql 0 failures)))

(deftest :optimized committed-magic-numbers-are-the-output-of-the-seeded-search
  ;; The numbers in src/optimized/magic-numbers.lisp must be what the search finds from the
  ;; seed (tools/generate-magics.lisp writes them): they come from this layer, not from another
  ;; engine, and the search gives the same numbers on every platform that runs this test.
  (let ((search (scf-opt:search-magic-numbers scf-opt:+magic-seed+))
        (committed scf-opt:*committed-magic-numbers*))
    (note "seed ~16,'0X: ~{~D~^ and ~} candidates drawn for the two layouts"
          scf-opt:+magic-seed+ (getf search :candidates))
    (is-eql scf-opt:+magic-seed+ (getf committed :seed) "the seed recorded in the file")
    (is-equal (getf search :magic) (getf committed :magic) "the :magic numbers")
    (is-equal (getf search :fixed-magic) (getf committed :fixed-magic)
              "the :fixed-magic numbers")))

(deftest :optimized a-number-that-is-not-magic-is-refused
  ;; Building the tables checks every relevant occupancy: a number under which two blocker
  ;; sets with different attacks share an index must stop the build. Multiplying by 1 sends
  ;; every blocker set of the rook on a1 to index 0.
  (let ((broken (copy-list scf-opt:*committed-magic-numbers*)))
    (setf (getf broken :magic) (cons 1 (rest (getf broken :magic))))
    (unwind-protect (signals error (scf-opt:initialise-magic-tables broken))
      (scf-opt:initialise-magic-tables)))
  (is (and (= (scf-opt:magic-rook-attacks +a1+ 0) (scf-opt:ray-rook-attacks +a1+ 0))
           (= (scf-opt:fixed-magic-rook-attacks +a1+ 0) (scf-opt:ray-rook-attacks +a1+ 0)))
      "the tables are rebuilt from the committed numbers"))

(deftest :optimized the-slider-implementation-is-chosen-by-name
  (is-eql (first scf-opt:*slider-implementations*) (scf-opt:parse-slider-implementation nil))
  (is-eql (first scf-opt:*slider-implementations*) (scf-opt:parse-slider-implementation ""))
  (is-eql :ray (scf-opt:parse-slider-implementation "ray"))
  (is-eql :fixed-magic (scf-opt:parse-slider-implementation "Fixed-Magic"))
  (is-eql :magic (scf-opt:parse-slider-implementation "magic"))
  (signals error (scf-opt:parse-slider-implementation "rays"))
  (is-eql scf-opt:*slider-implementation* (scf-opt:slider-interface-implementation)
          "the interface was compiled with the implementation the build chose"))

(defun hot-path-fasl (name)
  "The compiled file of the hot-path file NAME of src/optimized/ that ASDF loaded."
  (asdf:output-file 'asdf:compile-op (asdf:find-component "scacchiforge" (list "optimized" name))))

(deftest :optimized a-compiled-choice-that-differs-refuses-to-load
  ;; ASDF does not track SCF_SLIDERS or the checked policy, so each compiled hot-path file
  ;; compares, when it is loaded, the choices it was compiled with and those of the image.
  (is-false (scf-opt:check-compiled-choice "slider implementation" :ray :ray))
  (signals error (scf-opt:check-compiled-choice "slider implementation" :fixed-magic :ray))
  (signals error (scf-opt:check-compiled-choice "compilation policy" '((speed 3)) '((speed 1))))
  ;; The wiring: the files this build loaded, loaded again while the image asks for another
  ;; choice, must stop. Loading one of them again with the image's own choice is harmless: it
  ;; defines the same functions, and SBCL's LOAD keeps the file's OPTIMIZE proclamation local.
  (let* ((current (scf-opt:slider-interface-implementation))
         (other (find current scf-opt:*slider-implementations* :test-not #'eq)))
    (signals error (let ((scf-opt:*slider-implementation* other))
                     (load (hot-path-fasl "sliders"))))
    (is-eql current (scf-opt:slider-interface-implementation) "the interface is unchanged"))
  (signals error (let ((scf-opt:*optimized-policy* '((speed 0) (safety 3) (debug 3))))
                   (load (hot-path-fasl "perft"))))
  (is (load (hot-path-fasl "perft")) "the same file loads with the image's own choices"))

;;; --- the macros that write the generator ------------------------------------------------
;;;
;;; DO-SQUARES (tables.lisp) and the pawn and target macros of movegen.lisp are internal: the
;;; test below names them with SCF-OPT:: on purpose. Each form is compiled when the test runs,
;;; so that a macro that captures a caller's variable or rejects a declaration fails this test
;;; instead of the build.

(defun compile-quietly (form)
  "The function FORM (a lambda expression) compiles to, or NIL when the compiler reports a
warning or a failure."
  (multiple-value-bind (function warnings-p failure-p)
      (let ((*error-output* (make-broadcast-stream)))
        (compile nil form))
    (and (not warnings-p) (not failure-p) function)))

(deftest :optimized bit-loops-accept-declarations-like-dolist
  (let ((bits (logior 1 (ash 1 5) (ash 1 63))))
    (loop for form in '((lambda (bits)
                          (let ((seen '()))
                            (scf-opt:do-set-bits (index bits (nreverse seen))
                              (declare (type (integer 0 63) index))
                              (push index seen))))
                        (lambda (bits)
                          (let ((seen '()))
                            (scf-opt::do-squares (square bits)
                              (declare (ignorable square))
                              (push square seen))
                            (nreverse seen))))
          do (let ((function (compile-quietly form)))
               (is function "~S compiles" form)
               (when function
                 (is-equal '(0 5 63) (funcall function bits)))))))

(deftest :optimized move-writing-macros-do-not-capture-the-callers-variables
  ;; The caller's variables are the optimized package's own symbols named like the ones the
  ;; macros bind or used to bind (TO, FROM, SINGLE, DOUBLE, WEST-CAPTURES), as a caller inside
  ;; the layer would name them: only such a caller can collide with a name a macro binds. The
  ;; moves written must be those of the generator.
  (let ((targets (compile-quietly
                  '(lambda (scf-opt::to)
                    (let ((buffer (make-array 8 :element-type 'fixnum :initial-element 0))
                          (index 0))
                      (scf-opt::push-targets buffer index scf-opt::to (ash 1 20) (ash 1 20))
                      (list index (aref buffer 0)))))))
    (is targets "PUSH-TARGETS compiles")
    (when targets
      (is-equal (list 1 (encode-move +e1+ 20 0 +flag-capture+)) (funcall targets +e1+)
                "the origin square is the caller's TO")))
  (let* ((fen "4k3/8/8/3pP3/8/8/PPP5/4K3 w - d6 0 1")
         (bbp (scf-opt:bitboard-from-reference (fen-position fen)))
         (expected (remove-if-not (lambda (move)
                                    (= (aref (scf-opt:bbp-board bbp) (move-from move))
                                       +white-pawn+))
                                  (scf-opt:bitboard-pseudo-legal-moves bbp)))
         ;; SINGLE holds the pawns, DOUBLE the empty squares, WEST-CAPTURES the enemy pieces,
         ;; TO the en-passant square and FROM the side to move.
         (function (compile-quietly
                    '(lambda (buffer scf-opt::single scf-opt::double scf-opt::west-captures
                              scf-opt::to scf-opt::from)
                      (let ((index 0))
                        (scf-opt::push-pawn-moves buffer index scf-opt::single scf-opt::double
                                                  scf-opt::west-captures scf-opt::to
                                                  scf-opt::from
                                                  :up 8 :double-rank scf-opt::+rank-3+
                                                  :promotion-rank scf-opt::+rank-8+
                                                  :west 7 :east 9)
                        index)))))
    (is function "PUSH-PAWN-MOVES compiles")
    (when function
      (let* ((buffer (scf-opt:make-bitboard-move-buffer))
             (end (funcall function buffer
                           (aref (scf-opt:bbp-pieces bbp) 0)
                           (ldb (byte 64 0) (lognot (scf-opt:bbp-occupancy bbp)))
                           (aref (scf-opt:bbp-colour-occupancy bbp) +black+)
                           (scf-opt:bbp-en-passant bbp)
                           +white+)))
        (is (> (length expected) 5) "the position has pawn pushes, captures and en passant")
        (is-equal (sort (copy-list expected) #'<)
                  (sort (loop for index below end collect (aref buffer index)) #'<)
                  "the pawn moves of ~A" fen)))))

(deftest :optimized between-and-line-match-a-naive-walk
  (dotimes (a 64)
    (dotimes (b 64)
      (let ((between 0)
            (line 0))
        ;; Walk from A in each of the eight directions; if B is met, the squares before it are
        ;; between, and the line is both rays through A plus A.
        (loop for (df . dr) in (append *rook-steps* *bishop-steps*)
              do (let ((walked 0))
                   (loop for file = (+ (square-file a) df) then (+ file df)
                         for rank = (+ (square-rank a) dr) then (+ rank dr)
                         while (and (<= 0 file 7) (<= 0 rank 7))
                         do (let ((target (make-square file rank)))
                              (when (= target b)
                                (setf between walked
                                      line (logior (ash 1 a)
                                                   (naive-slide a 0 (list (cons df dr)))
                                                   (naive-slide a 0
                                                                (list (cons (- df) (- dr))))))
                                (return))
                              (setf walked (logior walked (ash 1 target)))))))
        (is-eql between (scf-opt:between-squares a b) "between ~A and ~A"
                (square-name a) (square-name b))
        (is-eql line (scf-opt:line-through a b) "line through ~A and ~A"
                (square-name a) (square-name b))))))

;;; --- make and unmake at their edges -----------------------------------------------------

(deftest :optimized clock-limit-equals-the-reference-limit
  (is-eql scf-ref:+max-clock+ scf-opt:+clock-limit+))

(deftest :optimized the-undo-stack-grows-past-its-initial-capacity
  ;; 600 plies of two kings and a rook shuffling: beyond the 256 entries the stack starts with.
  (let* ((bbp (scf-opt:bitboard-from-reference (fen-position "4k3/8/8/8/8/8/8/R3K3 w - - 0 1")))
         (before (scf-opt:bitboard-clone bbp)))
    (dotimes (i 150)
      (play bbp "a1a2" "e8e7" "a2a1" "e7e8"))
    (is-eql 600 (scf-opt:bbp-ply bbp))
    (is-eql (scf-opt:bitboard-compute-key bbp) (scf-opt:bbp-key bbp))
    (dotimes (i 600)
      (scf-opt:bitboard-unmake-move bbp))
    (is (and (scf-opt:bitboard-equal-p bbp before) (zerop (scf-opt:bbp-ply bbp)))
        "600 plies unmade")))

(deftest :optimized misuse-is-refused-with-a-clean-error
  (let* ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position)))
         (before (scf-opt:bitboard-clone bbp)))
    (signals error (scf-opt:bitboard-unmake-move bbp))
    (signals error (scf-opt:bitboard-make-move bbp (encode-move +e4+ +e5+ 0 0)))
    (is (and (scf-opt:bitboard-equal-p bbp before) (zerop (scf-opt:bbp-ply bbp)))
        "the failed calls changed nothing")))

(deftest :optimized clone-is-independent
  (let* ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position)))
         (copy (scf-opt:bitboard-clone bbp)))
    (is (scf-opt:bitboard-equal-p bbp copy))
    (play copy "e2e4")
    (is (scf-opt:bitboard-equal-p bbp (scf-opt:bitboard-from-reference (scf-ref:start-position)))
        "the original is untouched")
    (is-false (scf-opt:bitboard-equal-p bbp copy))))

(deftest :optimized consistency-check-catches-a-board-out-of-step
  (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position))))
    (setf (aref (scf-opt:bbp-board bbp) +e4+) +white-queen+)
    (is (nth-value 1 (scf-opt:bitboard-consistent-p bbp)) "a piece on the board only"))
  (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position))))
    (setf (aref (scf-opt:bbp-board bbp) +e2+) +empty+)
    (is (nth-value 1 (scf-opt:bitboard-consistent-p bbp)) "a piece in the bitboards only"))
  (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position))))
    (setf (aref (scf-opt:bbp-board bbp) +e2+) +white-knight+)
    (is (nth-value 1 (scf-opt:bitboard-consistent-p bbp)) "a different piece")))

;;; --- move buffers -----------------------------------------------------------------------

(deftest :optimized a-buffer-too-small-signals-an-error-not-a-wrong-count
  ;; A buffer with room for one ply's worth of moves cannot hold a three-ply tree of
  ;; kiwipete. The bounds check on the store must stop it.
  (let ((bbp (scf-opt:bitboard-from-reference
              (fen-position (scf-ref:standard-position-fen "kiwipete"))))
        (tiny (make-array 64 :element-type 'fixnum :initial-element 0)))
    (signals error (scf-opt:bitboard-perft-with-buffer bbp 3 tiny))))

(deftest :optimized a-position-with-nine-queens-fits-and-agrees-with-the-reference
  ;; White has nine queens, two rooks, two bishops and two knights, all of them mobile: about as
  ;; many moves as a position can have. The counts are compared with the reference, not with a
  ;; recorded value.
  (let* ((fen "R6R/3Q4/1Q4Q1/4Q3/2Q4Q/Q4Q2/pp1Q4/kBNN1KB1 w - - 0 1")
         (pos (fen-position fen))
         (bbp (scf-opt:bitboard-from-reference pos))
         (pseudo (length (scf-opt:bitboard-pseudo-legal-moves bbp))))
    (note "~D pseudo-legal moves, ~D legal" pseudo (length (scf-opt:bitboard-legal-moves bbp)))
    (is (<= pseudo scf-opt:+bitboard-ply-moves+))
    (loop for depth from 1 to 2
          do (is-eql (scf-ref:perft pos depth) (scf-opt:bitboard-perft bbp depth)
                     "perft ~D" depth))))

(deftest :optimized buffer-size-follows-the-documented-formula
  (is-eql (* 2 scf-opt:+bitboard-ply-moves+) (length (scf-opt:make-bitboard-move-buffer)))
  (is-eql (* 7 scf-opt:+bitboard-ply-moves+) (length (scf-opt:make-bitboard-move-buffer 6)))
  (is (>= scf-opt:+bitboard-ply-moves+ (+ (* 9 27) (* 2 14) (* 2 13) (* 2 8) 8 2))
      "room for the most pseudo-legal moves of a position whose material could arise in a game"))

;;; --- allocation in the hot path ---------------------------------------------------------

(defparameter *allocation-perfts*
  '(("startpos" 5) ("kiwipete" 4) ("pos3" 6) ("pos4" 5) ("pos5" 4) ("pos6" 4) ("promo" 5))
  "Perft runs (standard position, depth) whose allocation is measured. Together they make more
than a million moves, with castling, en passant and promotions among them. tools/hot-path.lisp
measures the same runs.")

(defun moves-made-by-perft (bbp depth)
  "How many moves a bulk-counting perft of BBP to DEPTH makes: the leaves of every depth below
DEPTH, since the last ply is counted without making its moves."
  (loop for d from 1 below depth sum (scf-opt:bitboard-perft bbp d)))

(deftest :optimized perft-allocates-nothing-after-warm-up
  ;; SB-EXT:GET-BYTES-CONSED moves one allocation region at a time, not one object at a time
  ;; ("make hot-path" prints its steps on the machine that runs it), so a short run proves
  ;; nothing. These runs make over a million moves, with one generation each: one 16-byte
  ;; object per move would show as at least 16 MB. The bound of 1 MiB therefore means less
  ;; than one byte per move made.
  (let ((runs (loop for (name depth) in *allocation-perfts*
                    collect (list name depth
                                  (scf-opt:bitboard-from-reference
                                   (fen-position (scf-ref:standard-position-fen name)))
                                  (scf-opt:make-bitboard-move-buffer depth))))
        (moves 0))
    ;; Warm-up: every run once, outside the measurement.
    (loop for (nil depth bbp buffer) in runs
          do (scf-opt:bitboard-perft-with-buffer bbp depth buffer)
             (incf moves (moves-made-by-perft bbp depth)))
    (let ((before (sb-ext:get-bytes-consed)))
      (loop for (nil depth bbp buffer) in runs
            do (scf-opt:bitboard-perft-with-buffer bbp depth buffer))
      (let ((consed (- (sb-ext:get-bytes-consed) before)))
        (note "~D moves made and unmade, ~D bytes consed" moves consed)
        (is (> moves 1000000) "enough moves for the bound to mean something: ~D" moves)
        (is (<= consed (* 1024 1024)) "~D bytes consed over ~D moves" consed moves)))))
