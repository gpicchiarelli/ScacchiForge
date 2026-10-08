;;;; bitboard-position.lisp -- the bitboard position, its undo stack, and its conversion to
;;;; and from the reference position.
;;;;
;;;; The position keeps twelve piece bitboards, the occupancy of each colour, the total
;;;; occupancy, a 64-byte board of piece codes (so make/unmake find the piece on a square
;;;; without scanning the bitboards), the state fields of the reference position, the
;;;; incremental state of the classical evaluation (PSQ-MG, PSQ-EG and PHASE-RAW,
;;;; evaluation-tables.lisp) and an undo stack of preallocated typed vectors. Make and unmake
;;;; (make.lisp) change it in place.
;;;;
;;;; This file is not on the hot path: conversion, the from-scratch key and the consistency
;;;; check are written plainly and compiled with safety 2.

(in-package #:scacchiforge.optimized)

(declaim (optimize (speed 1) (safety 2)))

(defconstant +initial-undo-capacity+ 256
  "Plies the undo stack holds before it first grows. A search or a perft never gets near it;
only a long game played on one position does, and then the stack doubles.")

(defconstant +clock-limit+ 9999999
  "The largest halfmove clock and fullmove number: make stops counting there. It is the value
the reference model uses, so a position reached by play has a FEN the reference reads back;
the test clock-limit-equals-the-reference-limit (tests/test-optimized.lisp) compares them.")

(defstruct (bitboard-position (:conc-name bbp-) (:constructor %make-bitboard-position)
                              (:copier nil))
  "Piece bitboards indexed by PIECE-INDEX (white P N B R Q K, then black), occupancy per
colour, total occupancy, a board of piece codes, the same state fields as the reference
position, the incremental state of the classical evaluation, and the undo stack: slot PLY is
the number of moves made and not yet unmade. PSQ-MG and PSQ-EG are White's material and
piece-square values minus Black's, in the middlegame and in the endgame, and PHASE-RAW is the
phase before the cap of 62 (docs/valutazione.md, \"Stato incrementale\").

Classification: [EXACT] (stored occupancies, board, key and evaluation state)
Basis: the occupancy fields are unions of piece bitboards and the board lists the same pieces
square by square; MAKE and UNMAKE keep them in step instead of recomputing them, and update
the key and the evaluation state incrementally. Each must equal what the piece bitboards give.
BITBOARD-CONSISTENT-P recomputes all of them and reports any difference.
Evidence: tests keys-agree-between-the-two-representations and
differential-fuzz-reference-to-bitboard-and-back (tests/test-bitboard.lisp), and every
make/unmake of the differential tests (tests/test-differential.lisp), which call
BITBOARD-CONSISTENT-P after each make and compare the state after each unmake with the state
before (INV-C8)."
  (pieces (make-array 12 :element-type '(unsigned-byte 64) :initial-element 0)
   :type (simple-array (unsigned-byte 64) (12)))
  (colour-occupancy (make-array 2 :element-type '(unsigned-byte 64) :initial-element 0)
   :type (simple-array (unsigned-byte 64) (2)))
  (occupancy 0 :type (unsigned-byte 64))
  (board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)
   :type (simple-array (unsigned-byte 8) (64)))
  (side +white+ :type colour)
  (castling 0 :type (integer 0 15))
  (en-passant +no-square+ :type (integer 0 64))
  (halfmove 0 :type fixnum)
  (fullmove 1 :type fixnum)
  (key 0 :type (unsigned-byte 64))
  ;; Incremental state of the classical evaluation (evaluation-tables.lisp).
  (psq-mg 0 :type (signed-byte 32))
  (psq-eg 0 :type (signed-byte 32))
  (phase-raw 0 :type (unsigned-byte 16))
  ;; Undo stack: one entry per move made, in parallel typed vectors.
  (ply 0 :type fixnum)
  (undo-moves (make-array +initial-undo-capacity+ :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-captured (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                     :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-castling (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                     :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-en-passant (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 8)
                                                       :initial-element 0)
   :type (simple-array (unsigned-byte 8) (*)))
  (undo-halfmove (make-array +initial-undo-capacity+ :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-fullmove (make-array +initial-undo-capacity+ :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (undo-keys (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 64)
                                                 :initial-element 0)
   :type (simple-array (unsigned-byte 64) (*)))
  (undo-psq-mg (make-array +initial-undo-capacity+ :element-type '(signed-byte 32)
                                                   :initial-element 0)
   :type (simple-array (signed-byte 32) (*)))
  (undo-psq-eg (make-array +initial-undo-capacity+ :element-type '(signed-byte 32)
                                                   :initial-element 0)
   :type (simple-array (signed-byte 32) (*)))
  (undo-phase-raw (make-array +initial-undo-capacity+ :element-type '(unsigned-byte 16)
                                                      :initial-element 0)
   :type (simple-array (unsigned-byte 16) (*))))

(defun grow-undo-stack (bbp)
  "Double the capacity of the undo stack of BBP, keeping its contents. Called by make only when
the stack is full, which a search or a perft never reaches."
  (declare (type bitboard-position bbp))
  (flet ((grown (old)
           (let ((new (make-array (* 2 (length old)) :element-type (array-element-type old)
                                                      :initial-element 0)))
             (replace new old)
             new)))
    (setf (bbp-undo-moves bbp) (grown (bbp-undo-moves bbp))
          (bbp-undo-captured bbp) (grown (bbp-undo-captured bbp))
          (bbp-undo-castling bbp) (grown (bbp-undo-castling bbp))
          (bbp-undo-en-passant bbp) (grown (bbp-undo-en-passant bbp))
          (bbp-undo-halfmove bbp) (grown (bbp-undo-halfmove bbp))
          (bbp-undo-fullmove bbp) (grown (bbp-undo-fullmove bbp))
          (bbp-undo-keys bbp) (grown (bbp-undo-keys bbp))
          (bbp-undo-psq-mg bbp) (grown (bbp-undo-psq-mg bbp))
          (bbp-undo-psq-eg bbp) (grown (bbp-undo-psq-eg bbp))
          (bbp-undo-phase-raw bbp) (grown (bbp-undo-phase-raw bbp))))
  bbp)

(defconstant +end-ranks-mask+ #xFF000000000000FF
  "Bits of the first and the last rank.")

(defun bitboard-from-reference (pos)
  "A bitboard position holding the same state as the reference position POS, with an empty
undo stack. Only the pieces and the state fields are read from POS; the key and the evaluation
state are computed by this layer from the bitboards (BITBOARD-COMPUTE-KEY,
BITBOARD-COMPUTE-EVALUATION-STATE), not copied from the reference, so that every comparison of
keys or evaluations between the layers compares two independent computations (ADR-0010,
point 4)."
  (let ((bbp (%make-bitboard-position)))
    (dotimes (square 64)
      (let ((piece (scf-ref:piece-at pos square)))
        (unless (= piece +empty+)
          (let ((bit (ash 1 square)))
            (setf (aref (bbp-pieces bbp) (piece-index piece))
                  (logior (aref (bbp-pieces bbp) (piece-index piece)) bit))
            (setf (aref (bbp-colour-occupancy bbp) (piece-colour piece))
                  (logior (aref (bbp-colour-occupancy bbp) (piece-colour piece)) bit))
            (setf (bbp-occupancy bbp) (logior (bbp-occupancy bbp) bit))
            (setf (aref (bbp-board bbp) square) piece)))))
    (setf (bbp-side bbp) (scf-ref:pos-side pos)
          (bbp-castling bbp) (scf-ref:pos-castling pos)
          (bbp-en-passant bbp) (scf-ref:pos-en-passant pos)
          (bbp-halfmove bbp) (scf-ref:pos-halfmove pos)
          (bbp-fullmove bbp) (scf-ref:pos-fullmove pos))
    (setf (bbp-key bbp) (bitboard-compute-key bbp))
    (set-evaluation-state-from-scratch bbp)
    bbp))

(defun bitboard-compute-evaluation-state (bbp)
  "PSQ-MG, PSQ-EG and PHASE-RAW of BBP computed from scratch from its piece bitboards, as three
values: what make and unmake keep incrementally (docs/valutazione.md, \"Stato incrementale\")."
  (declare (type bitboard-position bbp))
  (evaluation-state-from-scratch (bbp-pieces bbp)))

(defun set-evaluation-state-from-scratch (bbp)
  "Store in BBP the evaluation state computed from scratch from its piece bitboards. Returns
BBP."
  (declare (type bitboard-position bbp))
  (multiple-value-bind (mg eg phase) (bitboard-compute-evaluation-state bbp)
    (setf (bbp-psq-mg bbp) mg
          (bbp-psq-eg bbp) eg
          (bbp-phase-raw bbp) phase))
  bbp)

(defun bitboard-clone (bbp)
  "A copy of the state of BBP with an EMPTY undo stack (it cannot unmake earlier moves)."
  (declare (type bitboard-position bbp))
  (let ((copy (%make-bitboard-position)))
    (replace (bbp-pieces copy) (bbp-pieces bbp))
    (replace (bbp-colour-occupancy copy) (bbp-colour-occupancy bbp))
    (replace (bbp-board copy) (bbp-board bbp))
    (setf (bbp-occupancy copy) (bbp-occupancy bbp)
          (bbp-side copy) (bbp-side bbp)
          (bbp-castling copy) (bbp-castling bbp)
          (bbp-en-passant copy) (bbp-en-passant bbp)
          (bbp-halfmove copy) (bbp-halfmove bbp)
          (bbp-fullmove copy) (bbp-fullmove bbp)
          (bbp-key copy) (bbp-key bbp)
          (bbp-psq-mg copy) (bbp-psq-mg bbp)
          (bbp-psq-eg copy) (bbp-psq-eg bbp)
          (bbp-phase-raw copy) (bbp-phase-raw bbp))
    copy))

(defun bitboard-to-reference (bbp)
  "A new reference position holding the same state as the bitboard position BBP. Its key
is recomputed by the reference code, not copied from BBP."
  (let ((board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)))
    (dotimes (index 12)
      (let ((piece (make-piece (floor index 6) (1+ (mod index 6)))))
        (do-set-bits (square (aref (bbp-pieces bbp) index))
          (setf (aref board square) piece))))
    (scf-ref:make-position-from-parts board (bbp-side bbp) (bbp-castling bbp)
                                      (bbp-en-passant bbp) (bbp-halfmove bbp)
                                      (bbp-fullmove bbp))))

(defun bitboard-en-passant-available-p (bbp)
  "True when BBP has an en-passant square and a pawn of the side to move attacks it. Computed
on the bitboards with explicit file arithmetic, independently of the reference implementation
and of the table lookup that make uses (EN-PASSANT-KEY-PART in make.lisp)."
  (let ((target (bbp-en-passant bbp)))
    (and (/= target +no-square+)
         (let* ((white (= (bbp-side bbp) +white+))
                (pawns (aref (bbp-pieces bbp) (piece-index (make-piece (bbp-side bbp) +pawn+))))
                (file (square-file target))
                ;; Squares from which a pawn of the side to move captures onto TARGET.
                (left (and (> file 0) (if white (- target 9) (+ target 7))))
                (right (and (< file 7) (if white (- target 7) (+ target 9)))))
           (or (and left (logbitp left pawns))
               (and right (logbitp right pawns)))))))

(defun bitboard-compute-key (bbp)
  "The Zobrist key of BBP computed from the bitboards, with the shared key tables."
  (let ((key 0))
    (declare (type u64 key))
    (dotimes (index 12)
      (let ((piece (make-piece (floor index 6) (1+ (mod index 6)))))
        (do-set-bits (square (aref (bbp-pieces bbp) index))
          (setf key (logxor key (zobrist-piece-key piece square))))))
    (when (= (bbp-side bbp) +black+)
      (setf key (logxor key (zobrist-side-key))))
    (setf key (logxor key (zobrist-castling-key (bbp-castling bbp))))
    (when (bitboard-en-passant-available-p bbp)
      (setf key (logxor key (zobrist-en-passant-key (square-file (bbp-en-passant bbp))))))
    key))

(defun bitboard-consistent-p (bbp)
  "Check the internal consistency of BBP. Returns two values: true when no check failed,
and the list of failed checks as strings."
  (let ((problems '())
        (union 0)
        (total 0))
    (declare (type u64 union) (type fixnum total))
    (dotimes (index 12)
      (let ((bits (aref (bbp-pieces bbp) index)))
        (setf union (logior union bits))
        (incf total (popcount64 bits))))
    (unless (= total (popcount64 union))
      (push "two piece bitboards overlap" problems))
    (dotimes (colour 2)
      (let ((expected 0))
        (dotimes (type 6)
          (setf expected (logior expected (aref (bbp-pieces bbp) (+ (* colour 6) type)))))
        (unless (= expected (aref (bbp-colour-occupancy bbp) colour))
          (push (format nil "colour occupancy ~D differs from its piece bitboards" colour)
                problems))))
    (unless (= (bbp-occupancy bbp) (logior (aref (bbp-colour-occupancy bbp) 0)
                                           (aref (bbp-colour-occupancy bbp) 1)))
      (push "total occupancy differs from the colour occupancies" problems))
    (unless (= (bbp-occupancy bbp) union)
      (push "total occupancy differs from the union of the piece bitboards" problems))
    (dotimes (square 64)
      (let ((piece (aref (bbp-board bbp) square)))
        (cond ((= piece +empty+)
               (when (logbitp square union)
                 (push (format nil "the board is empty on ~A, a bitboard is not"
                               (square-name square))
                       problems)))
              ((not (and (typep piece 'piece) (<= 1 (piece-type piece) 6)))
               (push (format nil "invalid piece code ~D on ~A" piece (square-name square))
                     problems))
              ((not (logbitp square (aref (bbp-pieces bbp) (piece-index piece))))
               (push (format nil "the board and the bitboards disagree on ~A"
                             (square-name square))
                     problems)))))
    (dolist (king-index '(5 11))
      (unless (= (popcount64 (aref (bbp-pieces bbp) king-index)) 1)
        (push (format nil "king bitboard ~D does not hold exactly one bit" king-index)
              problems)))
    (unless (zerop (logand +end-ranks-mask+ (logior (aref (bbp-pieces bbp) 0)
                                                    (aref (bbp-pieces bbp) 6))))
      (push "a pawn stands on the first or last rank" problems))
    (unless (= (bbp-key bbp) (bitboard-compute-key bbp))
      (push "stored key differs from the key computed from the bitboards" problems))
    (when-incremental-evaluation
      (multiple-value-bind (mg eg phase) (bitboard-compute-evaluation-state bbp)
        (unless (and (= mg (bbp-psq-mg bbp)) (= eg (bbp-psq-eg bbp))
                     (= phase (bbp-phase-raw bbp)))
          (push (format nil "stored evaluation state (~D ~D ~D) differs from the one computed ~
                             from the bitboards (~D ~D ~D)"
                        (bbp-psq-mg bbp) (bbp-psq-eg bbp) (bbp-phase-raw bbp) mg eg phase)
                problems))))
    (values (null problems) (nreverse problems))))

(defun bitboard-equal-p (a b)
  "True when A and B hold the same bitboards, board, state fields and evaluation state (in the
build with SCF_EVAL_STATE=recompute, where make and unmake do not keep the evaluation state,
everything but it). The undo stacks are not compared."
  (and (equalp (bbp-pieces a) (bbp-pieces b))
       (equalp (bbp-colour-occupancy a) (bbp-colour-occupancy b))
       (= (bbp-occupancy a) (bbp-occupancy b))
       (equalp (bbp-board a) (bbp-board b))
       (= (bbp-side a) (bbp-side b))
       (= (bbp-castling a) (bbp-castling b))
       (= (bbp-en-passant a) (bbp-en-passant b))
       (= (bbp-halfmove a) (bbp-halfmove b))
       (= (bbp-fullmove a) (bbp-fullmove b))
       (= (bbp-key a) (bbp-key b))
       (if-incremental-evaluation
        (and (= (bbp-psq-mg a) (bbp-psq-mg b))
             (= (bbp-psq-eg a) (bbp-psq-eg b))
             (= (bbp-phase-raw a) (bbp-phase-raw b)))
        t)))

;;; The two functions above depend on the evaluation state the layer is compiled with
;;; (SCF_EVAL_STATE): this file must not be loaded with another one.
(check-compiled-choice "evaluation state" (compiled-evaluation-state) *evaluation-state*)
