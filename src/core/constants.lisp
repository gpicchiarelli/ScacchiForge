;;;; constants.lisp -- squares, colours, pieces, castling rights.
;;;;
;;;; Only integers are defined with DEFCONSTANT, so loading the system twice in one image
;;;; never redefines a constant with a value that is not EQL.

(in-package #:scacchiforge.core)

(deftype square () '(integer 0 63))
(deftype colour () '(integer 0 1))
(deftype piece () '(integer 0 14))
(deftype u64 () '(unsigned-byte 64))

;;; Colours.
(defconstant +white+ 0)
(defconstant +black+ 1)

;;; Piece types 1..6; 0 means "no piece".
(defconstant +empty+ 0)
(defconstant +pawn+ 1)
(defconstant +knight+ 2)
(defconstant +bishop+ 3)
(defconstant +rook+ 4)
(defconstant +queen+ 5)
(defconstant +king+ 6)

;;; A piece code is (colour * 8) + type: white 1..6, black 9..14.
(defconstant +white-pawn+ 1)
(defconstant +white-knight+ 2)
(defconstant +white-bishop+ 3)
(defconstant +white-rook+ 4)
(defconstant +white-queen+ 5)
(defconstant +white-king+ 6)
(defconstant +black-pawn+ 9)
(defconstant +black-knight+ 10)
(defconstant +black-bishop+ 11)
(defconstant +black-rook+ 12)
(defconstant +black-queen+ 13)
(defconstant +black-king+ 14)

(declaim (inline opposite-colour make-piece piece-colour piece-type piece-index))

(defun opposite-colour (colour)
  "The other colour."
  (declare (type colour colour))
  (logxor colour 1))

(defun make-piece (colour type)
  "Piece code for COLOUR and TYPE (1..6)."
  (declare (type colour colour) (type (integer 1 6) type))
  (logior (ash colour 3) type))

(defun piece-colour (piece)
  "Colour of a non-empty PIECE code."
  (declare (type piece piece))
  (ash piece -3))

(defun piece-type (piece)
  "Type (1..6) of a non-empty PIECE code."
  (declare (type piece piece))
  (logand piece 7))

(defun piece-index (piece)
  "Dense index 0..11 of a non-empty PIECE code: white P..K then black p..k."
  (declare (type piece piece))
  (+ (1- (logand piece 7)) (* 6 (ash piece -3))))

(defun piece-char (piece)
  "FEN letter of PIECE: upper case for white, lower case for black."
  (declare (type piece piece))
  (char (if (= (piece-colour piece) +white+) "PNBRQK" "pnbrqk") (1- (piece-type piece))))

(defun char-piece (char)
  "Piece code of the FEN letter CHAR, or NIL when CHAR is not a piece letter."
  (let ((white (position char "PNBRQK"))
        (black (position char "pnbrqk")))
    (cond (white (make-piece +white+ (1+ white)))
          (black (make-piece +black+ (1+ black)))
          (t nil))))

;;; Castling rights are a 4-bit set.
(defconstant +castle-white-king+ 1)
(defconstant +castle-white-queen+ 2)
(defconstant +castle-black-king+ 4)
(defconstant +castle-black-queen+ 8)
(defconstant +castle-all+ 15)

;;; Squares: a1 = 0, b1 = 1, ..., h1 = 7, a2 = 8, ..., h8 = 63.
;;; +NO-SQUARE+ stands for "no square" (for example no en-passant target).
(defconstant +no-square+ 64)

(declaim (inline make-square square-file square-rank))

(defun make-square (file rank)
  "Square index of FILE (0 = a) and RANK (0 = first rank)."
  (declare (type (integer 0 7) file rank))
  (+ (* rank 8) file))

(defun square-file (square)
  "File 0..7 of SQUARE."
  (declare (type square square))
  (logand square 7))

(defun square-rank (square)
  "Rank 0..7 of SQUARE."
  (declare (type square square))
  (ash square -3))

(defun square-name (square)
  "Algebraic name of SQUARE, for example \"e4\"."
  (declare (type square square))
  (coerce (list (char "abcdefgh" (square-file square))
                (char "12345678" (square-rank square)))
          'string))

(defun parse-square (string)
  "Square index of an algebraic name such as \"e4\", or NIL if STRING is not one."
  (when (and (stringp string) (= (length string) 2))
    (let ((file (position (char string 0) "abcdefgh"))
          (rank (position (char string 1) "12345678")))
      (and file rank (make-square file rank)))))

(macrolet ((define-square-constants ()
             `(progn
                ,@(loop for rank from 0 below 8
                        append (loop for file from 0 below 8
                                     collect `(defconstant
                                                  ,(intern (format nil "+~A~D+"
                                                                   (char "ABCDEFGH" file)
                                                                   (1+ rank)))
                                                ,(+ (* rank 8) file)))))))
  (define-square-constants))
