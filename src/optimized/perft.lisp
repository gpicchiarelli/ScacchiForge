;;;; perft.lisp -- perft and divide of the optimized layer.
;;;;
;;;; The same definition as the reference perft (src/reference/perft.lisp): the number of
;;;; leaves of the legal-move tree to a fixed depth, counting the legal moves at the last ply
;;;; instead of making them. Its counts are compared with the published ones and with the
;;;; reference (tests/test-optimized-perft.lisp).

(in-package #:scacchiforge.optimized)

;;; The two macros below run at compile time and are not on the hot path: they are compiled
;;; with the policy of the layer's files outside the hot path. The hot path starts after them.

(declaim (optimize (speed 1) (safety 2)))

(defmacro with-node-functions (&body body)
  "BODY, in which BITBOARD-GENERATE-PSEUDO-LEGAL, BITBOARD-MAKE-MOVE and BITBOARD-UNMAKE-MOVE
are expanded inline when *INLINE-NODE-FUNCTIONS* (policy.lisp) is true while this file is
compiled, and called otherwise. Their files keep the inline expansions without making them the
default (make.lisp, movegen.lisp)."
  `(locally (declare (,(if *inline-node-functions* 'inline 'notinline)
                      bitboard-generate-pseudo-legal bitboard-make-move bitboard-unmake-move))
     ,@body))

(defmacro node-legal-moves (bbp buffer start)
  "Store the legal moves of BBP in BUFFER from START and return the index after the last one,
as BITBOARD-GENERATE-LEGAL does: when *INLINE-NODE-FUNCTIONS* is true while this file is
compiled, by its two steps written out (pseudo-legal generation, then the inline legality
filter), so that WITH-NODE-FUNCTIONS can expand the generator; otherwise by calling it. BBP,
BUFFER and START must be variables."
  (check-type bbp symbol)
  (check-type buffer symbol)
  (check-type start symbol)
  (if *inline-node-functions*
      `(filter-legal ,bbp ,buffer ,start (bitboard-generate-pseudo-legal ,bbp ,buffer ,start))
      `(bitboard-generate-legal ,bbp ,buffer ,start)))

(declaim-optimized-policy)

(declaim (ftype (function (bitboard-position (integer 1 63) bitboard-move-buffer fixnum)
                          (values fixnum &optional))
                perft-node))

(defun perft-node (bbp depth buffer base)
  "Leaf count below BBP at DEPTH (at least 1) plies, writing moves into BUFFER from BASE.

The legal moves are generated as BITBOARD-GENERATE-LEGAL generates them, pseudo-legal
generation and then the legality filter. The generator, the filter, make and unmake are
expanded inline here, not called (NODE-LEGAL-MOVES, WITH-NODE-FUNCTIONS): the same code runs
without the calls of every node. \"make hot-path\" times perft with and without them
(*INLINE-NODE-FUNCTIONS*, policy.lisp).

Classification: [EXACT] (bulk counting)
Basis: at depth 1 every legal move leads to exactly one leaf, so the number of legal moves is
the leaf count; the moves are counted instead of made and unmade.
Evidence: perft against published counts (tests/test-optimized-perft.lisp)."
  (declare (type bitboard-position bbp) (type (integer 1 63) depth)
           (type bitboard-move-buffer buffer) (type fixnum base))
  (with-node-functions
    (let ((end (node-legal-moves bbp buffer base)))
      (declare (type fixnum end))
      (if (= depth 1)
          (- end base)
          (let ((total 0))
            (declare (type fixnum total))
            (loop for index of-type fixnum from base below end
                  do (bitboard-make-move bbp (aref buffer index))
                     (incf total (perft-node bbp (1- depth) buffer end))
                     (bitboard-unmake-move bbp))
            total)))))

(defun bitboard-perft-with-buffer (bbp depth buffer)
  "Perft of BBP to DEPTH using the preallocated BUFFER (from MAKE-BITBOARD-MOVE-BUFFER with at
least DEPTH plies). Allocates nothing. BBP is left exactly as it was."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer))
  (check-type depth (integer 0 63))
  (if (zerop depth)
      1
      (perft-node bbp depth buffer 0)))

;;; The hot path of this file ends here. BITBOARD-PERFT allocates its move buffer and
;;; BITBOARD-PERFT-DIVIDE a list; they are compiled with the policy of the layer's files outside
;;; the hot path. Both call PERFT-NODE, whose code is the hot path's.

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-perft (bbp depth)
  "The number of leaf nodes of the legal-move tree of BBP to DEPTH plies. BBP is left exactly
as it was."
  (declare (type bitboard-position bbp))
  (check-type depth (integer 0 63))
  (bitboard-perft-with-buffer bbp depth (make-bitboard-move-buffer (max 1 depth))))

(defun bitboard-perft-divide (bbp depth)
  "Perft split by root move: two values, a list of (MOVE . COUNT) in generation order and the
total. DEPTH must be at least 1."
  (declare (type bitboard-position bbp))
  (check-type depth (integer 1 63))
  (let* ((buffer (make-bitboard-move-buffer depth))
         (end (bitboard-generate-legal bbp buffer 0))
         (entries '())
         (total 0))
    (declare (type bitboard-move-buffer buffer) (type fixnum end total))
    (loop for index of-type fixnum from 0 below end
          do (let ((move (aref buffer index)))
               (bitboard-make-move bbp move)
               (let ((count (if (= depth 1) 1 (perft-node bbp (1- depth) buffer end))))
                 (push (cons move count) entries)
                 (incf total count))
               (bitboard-unmake-move bbp)))
    (values (nreverse entries) total)))
