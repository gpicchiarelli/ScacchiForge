;;;; test-bitboard.lisp -- the bitboard position and the first differential test.

(in-package #:scacchiforge.test)

(defun external-symbol-names (package)
  "The names of the symbols exported by PACKAGE."
  (let ((names '()))
    (do-external-symbols (symbol package names)
      (push (symbol-name symbol) names))))

(deftest :bitboard start-position-layout
  (let ((bb (scf-opt:bitboard-from-reference (scf-ref:start-position))))
    (is-eql #x000000000000FF00 (aref (scf-opt:bbp-pieces bb) 0) "white pawns")
    (is-eql #x00FF000000000000 (aref (scf-opt:bbp-pieces bb) 6) "black pawns")
    (is-eql (ash 1 +e1+) (aref (scf-opt:bbp-pieces bb) 5) "white king")
    (is-eql (ash 1 +e8+) (aref (scf-opt:bbp-pieces bb) 11) "black king")
    (is-eql #x000000000000FFFF (aref (scf-opt:bbp-colour-occupancy bb) +white+))
    (is-eql #xFFFF000000000000 (aref (scf-opt:bbp-colour-occupancy bb) +black+))
    (is-eql #xFFFF00000000FFFF (scf-opt:bbp-occupancy bb))
    (is-eql 32 (scf-opt:popcount64 (scf-opt:bbp-occupancy bb)))
    (is-eql +castle-all+ (scf-opt:bbp-castling bb))
    (multiple-value-bind (ok problems) (scf-opt:bitboard-consistent-p bb)
      (is-true ok "the start position is consistent: ~S" problems))))

(deftest :bitboard round-trips-the-named-positions
  (dolist (fen (append *round-trip-fens* *fuzz-fens*))
    (let* ((pos (fen-position fen))
           (bb (scf-opt:bitboard-from-reference pos))
           (back (scf-opt:bitboard-to-reference bb)))
      (is (scf-ref:positions-equal-p pos back) "reference -> bitboard -> reference of ~A" fen)
      (is (scf-opt:bitboard-equal-p bb (scf-opt:bitboard-from-reference back))
          "bitboard -> reference -> bitboard of ~A" fen)
      (multiple-value-bind (ok problems) (scf-opt:bitboard-consistent-p bb)
        (is-true ok "~A: ~S" fen problems)))))

(deftest :bitboard keys-agree-between-the-two-representations
  (dolist (fen (append *round-trip-fens* *fuzz-fens*))
    (let* ((pos (fen-position fen))
           (bb (scf-opt:bitboard-from-reference pos)))
      (is-eql (scf-ref:compute-key pos) (scf-opt:bitboard-compute-key bb) "~A" fen)
      ;; The converted position's key is the optimized layer's own computation, not a copy.
      (is-eql (scf-ref:pos-key pos) (scf-opt:bbp-key bb) "stored key of ~A" fen))))

(deftest :bitboard differential-fuzz-reference-to-bitboard-and-back
  ;; The first differential test: convert seeded random legal positions to bitboards and
  ;; back and require equality, and the two independently computed keys to agree.
  (let ((rng (make-rng 20241004))
        (with-en-passant 0)
        (with-usable-en-passant 0)
        (checks 0))
    (dotimes (i 5000)
      (let* ((pos (scf-ref:random-legal-position *fuzz-fens* rng 120))
             (bb (scf-opt:bitboard-from-reference pos))
             (back (scf-opt:bitboard-to-reference bb)))
        (incf checks)
        (when (/= (scf-ref:pos-en-passant pos) +no-square+) (incf with-en-passant))
        (when (scf-ref:en-passant-capture-available-p pos) (incf with-usable-en-passant))
        (unless (and (scf-ref:positions-equal-p pos back)
                     (scf-opt:bitboard-consistent-p bb)
                     (= (scf-opt:bitboard-compute-key bb) (scf-ref:compute-key pos)))
          (record-failure "mismatch on ~A" (scf-ref:position-to-fen pos)))))
    (note "~D positions; ~D with an en-passant square, ~D with a usable one"
          checks with-en-passant with-usable-en-passant)
    (incf *assertions*)
    (is (plusp with-usable-en-passant) "the sample must exercise the en-passant key policy")))

(deftest :bitboard consistency-check-catches-corruption
  (flet ((fresh () (scf-opt:bitboard-from-reference (scf-ref:start-position)))
         (problems-of (bb) (nth-value 1 (scf-opt:bitboard-consistent-p bb))))
    (is-false (problems-of (fresh)))
    (let ((bb (fresh)))
      (setf (aref (scf-opt:bbp-pieces bb) 1) (logior (aref (scf-opt:bbp-pieces bb) 1) #x100))
      (is (problems-of bb) "a knight on a pawn's square"))
    (let ((bb (fresh)))
      (setf (aref (scf-opt:bbp-colour-occupancy bb) +white+) 0)
      (is (problems-of bb) "wrong colour occupancy"))
    (let ((bb (fresh)))
      (setf (scf-opt:bbp-occupancy bb) 0)
      (is (problems-of bb) "wrong total occupancy"))
    (let ((bb (fresh)))
      (setf (scf-opt:bbp-key bb) (logxor (scf-opt:bbp-key bb) 4))
      (is (problems-of bb) "wrong key"))
    (let ((bb (fresh)))
      (setf (aref (scf-opt:bbp-pieces bb) 5) 0)
      (is (problems-of bb) "no white king"))
    (let ((bb (fresh)))
      (setf (aref (scf-opt:bbp-pieces bb) 0)
            (logior (aref (scf-opt:bbp-pieces bb) 0) (ash 1 +a8+)))
      (is (problems-of bb) "a pawn on the last rank"))))

(deftest :bitboard the-layers-do-not-export-the-same-names
  (let ((reference (external-symbol-names "SCACCHIFORGE.REFERENCE"))
        (optimized (external-symbol-names "SCACCHIFORGE.OPTIMIZED")))
    (is (plusp (length reference)))
    (is (plusp (length optimized)))
    (is-equal '() (intersection reference optimized :test #'string=)
              "names exported by both layers")))

(deftest :bitboard shared-definitions-live-in-the-core-only
  ;; The core is the only package defining the piece, square and move vocabulary.
  (dolist (name '("+WHITE-PAWN+" "ENCODE-MOVE" "ZOBRIST-PIECE-KEY" "MAKE-RNG" "PARSE-SQUARE"))
    (dolist (package-name '("SCACCHIFORGE.REFERENCE" "SCACCHIFORGE.OPTIMIZED"))
      (multiple-value-bind (symbol status) (find-symbol name package-name)
        (is (and symbol (eq (symbol-package symbol) (find-package "SCACCHIFORGE.CORE")))
            "~A in ~A is not the core's symbol (~A)" name package-name status)))))

;;; --- what the optimized level takes from the reference (ADR-0010, point 4) -------------

(defparameter *reference-interface-for-the-optimized-level*
  '("CHESS-POSITION" "PIECE-AT" "POS-BOARD" "POS-SIDE" "POS-CASTLING" "POS-EN-PASSANT"
    "POS-HALFMOVE" "POS-FULLMOVE" "MAKE-POSITION-FROM-PARTS")
  "The reference symbols the optimized level may name: the position type, the accessors of
its pieces and state fields, and its constructor. Converting a position needs nothing else
(ADR-0010, point 4). The key accessor is not among them: the optimized level
computes its own key (BITBOARD-COMPUTE-KEY), which the tests compare with the reference's.")

(defun source-files-of-module (system module)
  "The Lisp source files of the module named MODULE of the ASDF system SYSTEM."
  (loop for component in (asdf:component-children (asdf:find-component system module))
        when (typep component 'asdf:cl-source-file)
          collect (asdf:component-pathname component)))

(defun symbols-read-from (pathname)
  "Every symbol in the forms of the Lisp source file PATHNAME, read in the package that each
IN-PACKAGE form selects, without duplicates."
  (let ((*package* (find-package '#:cl-user))
        (*read-eval* nil)
        (symbols '()))
    (labels ((walk (object)
               (typecase object
                 (symbol (pushnew object symbols))
                 (cons (walk (car object)) (walk (cdr object)))
                 ((and vector (not string)) (map nil #'walk object)))))
      (with-open-file (in pathname)
        (loop for form = (read in nil in)
              until (eq form in)
              do (when (and (consp form) (eq (first form) 'in-package))
                   (setf *package* (find-package (second form))))
                 (walk form))))
    symbols))

(deftest :bitboard optimized-level-names-only-the-reference-position-interface
  ;; The source of every file of src/optimized/ is read, not run: a call built at run time,
  ;; for example from a name in a string, would not be seen.
  (let ((files (source-files-of-module "scacchiforge" "optimized"))
        (reference (find-package "SCACCHIFORGE.REFERENCE"))
        (seen '()))
    (is (plusp (length files)) "the optimized module has source files")
    (dolist (file files)
      (dolist (symbol (symbols-read-from file))
        (when (eq (symbol-package symbol) reference)
          (pushnew (symbol-name symbol) seen :test #'string=)
          (is (and (eq :external (nth-value 1 (find-symbol (symbol-name symbol) reference)))
                   (member (symbol-name symbol) *reference-interface-for-the-optimized-level*
                           :test #'string=))
              "~A names ~S, which is not the reference position's type, accessor or constructor"
              (file-namestring file) symbol))))
    ;; The conversion does use the interface, so the reading above found the real names.
    (is (member "MAKE-POSITION-FROM-PARTS" seen :test #'string=)
        "the conversion back to the reference was found: ~S" seen)))
