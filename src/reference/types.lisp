(in-package :scacchiforge.reference)

(deftype piece () '(member :pawn :knight :bishop :rook :queen :king))
(deftype color () '(member :white :black))
(deftype square () '(integer 0 63))
(deftype direction () '(integer -9 9))

(defconstant +empty+ nil)
(defconstant +pawn+ :pawn)
(defconstant +knight+ :knight)
(defconstant +bishop+ :bishop)
(defconstant +rook+ :rook)
(defconstant +queen+ :queen)
(defconstant +king+ :king)

(defconstant +white+ :white)
(defconstant +black+ :black)

(defconstant +all-pieces+ '(:pawn :knight :bishop :rook :queen :king))

(defstruct (position (:constructor %make-position))
  "Represent a chess position with full state.
   CORRECTNESS: This structure is the oracle for position state.
   Each field must be kept consistent through make/unmake."
  (board (make-array 64 :initial-element nil :element-type t) :type (array t (64)))
  (side-to-move +white+ :type color)
  (castling-rights #(t t t t) :type (simple-array boolean (4)))
  (en-passant nil :type (or null square))
  (halfmove-clock 0 :type (integer 0 100))
  (fullmove 1 :type (integer 1 1000))
  (zobrist 0 :type (unsigned-byte 64)))

(defstruct (move (:constructor %make-move
                   (from to &key piece promoted flags)))
  "Represent a move as a simple structure.
   Packed representation not needed at reference level.
   [EXACT] All moves generated are legal. [THEOREM] Legality verified by filter."
  (from 0 :type square)
  (to 0 :type square)
  (piece nil :type piece)
  (promoted nil :type (or null piece))
  (flags 0 :type (unsigned-byte 8)))

(defconstant +move-flag-capture+ 1)
(defconstant +move-flag-castling+ 2)
(defconstant +move-flag-en-passant+ 4)
(defconstant +move-flag-double-push+ 8)

(defun make-position ()
  "Create a position representing the standard chess starting position."
  (let ((pos (%make-position)))
    (init-standard-position pos)
    pos))

(defun copy-position (pos)
  "Create a deep copy of a position."
  (let ((new-pos (%make-position
                  :board (copy-seq (position-board pos))
                  :side-to-move (position-side-to-move pos)
                  :castling-rights (copy-seq (position-castling-rights pos))
                  :en-passant (position-en-passant pos)
                  :halfmove-clock (position-halfmove-clock pos)
                  :fullmove (position-fullmove pos)
                  :zobrist (position-zobrist pos))))
    new-pos))

(defun init-standard-position (pos)
  "Initialize position to standard chess starting position."
  (let ((board (position-board pos)))
    (setf (aref board 0) (cons +white+ +rook+))
    (setf (aref board 1) (cons +white+ +knight+))
    (setf (aref board 2) (cons +white+ +bishop+))
    (setf (aref board 3) (cons +white+ +queen+))
    (setf (aref board 4) (cons +white+ +king+))
    (setf (aref board 5) (cons +white+ +bishop+))
    (setf (aref board 6) (cons +white+ +knight+))
    (setf (aref board 7) (cons +white+ +rook+))
    (loop for i from 8 to 15
          do (setf (aref board i) (cons +white+ +pawn+)))
    (loop for i from 48 to 55
          do (setf (aref board i) (cons +black+ +pawn+)))
    (setf (aref board 56) (cons +black+ +rook+))
    (setf (aref board 57) (cons +black+ +knight+))
    (setf (aref board 58) (cons +black+ +bishop+))
    (setf (aref board 59) (cons +black+ +queen+))
    (setf (aref board 60) (cons +black+ +king+))
    (setf (aref board 61) (cons +black+ +bishop+))
    (setf (aref board 62) (cons +black+ +knight+))
    (setf (aref board 63) (cons +black+ +rook+)))
  (setf (aref (position-castling-rights pos) 0) t)
  (setf (aref (position-castling-rights pos) 1) t)
  (setf (aref (position-castling-rights pos) 2) t)
  (setf (aref (position-castling-rights pos) 3) t)
  (setf (position-en-passant pos) nil)
  (setf (position-halfmove-clock pos) 0)
  (setf (position-fullmove pos) 1)
  (setf (position-side-to-move pos) +white+)
  pos)

(defun position-piece (pos sq)
  "Get the piece at square sq in position pos.
   Returns (color . piece) or nil if empty."
  (aref (position-board pos) sq))

(defun position-occupied-p (pos sq)
  "Check if square sq is occupied in position pos."
  (not (null (position-piece pos sq))))

(defun (setf position-piece) (piece pos sq)
  "Set the piece at square sq in position pos."
  (setf (aref (position-board pos) sq) piece))

(defun position-color (pos sq)
  "Get the color of the piece at square sq, or nil if empty."
  (car (position-piece pos sq)))

(defun opposite-color (c)
  "Return the opposite color."
  (if (eq c +white+) +black+ +white+))

(defun square->notation (sq)
  "Convert square index (0-63) to algebraic notation (a1-h8)."
  (let ((file (mod sq 8))
        (rank (floor sq 8)))
    (format nil "~a~d" (code-char (+ (char-code #\a) file)) (+ rank 1))))

(defun notation->square (notation)
  "Convert algebraic notation (e.g. 'e4') to square index (0-63)."
  (let* ((file (- (char-code (char notation 0)) (char-code #\a)))
         (rank (- (parse-integer (subseq notation 1)) 1)))
    (+ (* rank 8) file)))

(defun piece->char (p)
  "Convert piece type to character."
  (case p
    (:pawn #\P)
    (:knight #\N)
    (:bishop #\B)
    (:rook #\R)
    (:queen #\Q)
    (:king #\K)
    (t #\?)))

(defun color->char (c)
  "Convert color to character."
  (case c
    (:white #\W)
    (:black #\B)
    (t #\?)))
