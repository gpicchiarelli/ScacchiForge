;;;; fen.lisp -- FEN parsing and serialisation.
;;;;
;;;; PARSE-FEN builds a fresh position and returns it only when every check passed, so a
;;;; malformed FEN signals FEN-ERROR and leaves no state behind. Parsing is one pass over a
;;;; bounded string and cannot loop.
;;;;
;;;; Accepted: 6 fields, or 4 fields (the halfmove clock and fullmove number then default
;;;; to 0 and 1). Rejected, with FEN-ERROR: a wrong number of ranks or files, an unknown
;;;; letter, a side other than w or b, bad castling or en-passant fields, a king count other
;;;; than one per side, pawns on the first or last rank, castling rights without the king and
;;;; rook on their home squares, an en-passant square that no double push could have
;;;; produced, and a position where the side NOT to move is in check.
;;;; Piece counts per side are NOT limited. Digits are the ASCII digits 0 to 9 only: other
;;;; Unicode decimal digits, which DIGIT-CHAR-P accepts, are rejected. A clock field has at
;;;; most seven digits, so its value is at most +MAX-CLOCK+, where MAKE-MOVE stops counting.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defparameter *start-fen* "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
  "FEN of the initial position.")

(defparameter *max-fen-length* 256
  "Longer inputs are rejected before parsing; a real FEN is under 100 characters.")

(define-condition fen-error (position-error)
  ((fen :initarg :fen :reader fen-error-fen))
  (:report (lambda (condition stream)
             (format stream "Invalid FEN ~S: ~A" (fen-error-fen condition)
                     (position-error-reason condition))))
  (:documentation "Signalled by PARSE-FEN for a malformed or illegal FEN."))

(defun fen-fail (fen control &rest arguments)
  "Signal FEN-ERROR for FEN with a reason built from CONTROL and ARGUMENTS."
  (error 'fen-error :fen fen :reason (apply #'format nil control arguments)))

(defun ascii-digit-value (char)
  "The value 0 to 9 of CHAR when it is an ASCII digit, else NIL."
  (and (char<= #\0 char #\9)
       (- (char-code char) (char-code #\0))))

(defun split-fields (string)
  "The space-separated fields of STRING (runs of spaces count as one separator)."
  (let ((fields '()) (start nil))
    (dotimes (i (length string))
      (if (char= (char string i) #\Space)
          (when start
            (push (subseq string start i) fields)
            (setf start nil))
          (unless start (setf start i))))
    (when start (push (subseq string start) fields))
    (nreverse fields)))

(defun parse-placement (fen placement board)
  "Fill BOARD from the piece-placement field PLACEMENT of FEN."
  (let ((ranks '()) (start 0))
    (dotimes (i (length placement))
      (when (char= (char placement i) #\/)
        (push (subseq placement start i) ranks)
        (setf start (1+ i))))
    (push (subseq placement start) ranks)
    (unless (= (length ranks) 8)
      (fen-fail fen "expected 8 ranks, found ~D" (length ranks)))
    ;; RANKS is in reverse order: the first element is rank 1.
    (loop for rank-text in ranks
          for rank from 0
          do (let ((file 0) (previous-digit nil))
               (loop for char across rank-text
                     do (let ((digit (ascii-digit-value char))
                              (piece (char-piece char)))
                          (cond ((and digit (<= 1 digit 8))
                                 (when previous-digit
                                   (fen-fail fen "adjacent digits in rank ~D" (1+ rank)))
                                 (incf file digit)
                                 (setf previous-digit t))
                                (piece
                                 (when (> file 7)
                                   (fen-fail fen "rank ~D has more than 8 files" (1+ rank)))
                                 (setf (aref board (make-square file rank)) piece)
                                 (incf file)
                                 (setf previous-digit nil))
                                (t (fen-fail fen "unexpected character ~S in rank ~D"
                                             char (1+ rank))))))
               (unless (= file 8)
                 (fen-fail fen "rank ~D does not have exactly 8 files" (1+ rank)))))))

(defun parse-castling-field (fen field)
  "The castling-rights set written in FIELD."
  (if (string= field "-")
      0
      (let ((rights 0))
        (loop for char across field
              do (let ((right (case char
                                (#\K +castle-white-king+)
                                (#\Q +castle-white-queen+)
                                (#\k +castle-black-king+)
                                (#\q +castle-black-queen+)
                                (t (fen-fail fen "bad castling character ~S" char)))))
                   (when (logtest rights right)
                     (fen-fail fen "repeated castling character ~S" char))
                   (setf rights (logior rights right))))
        rights)))

(defun parse-clock (fen field name minimum)
  "The decimal integer in FIELD: ASCII digits only, at most seven of them, a value from
MINIMUM to +MAX-CLOCK+."
  (unless (and (<= 1 (length field) 7) (every #'ascii-digit-value field))
    (fen-fail fen "~A must be a decimal number of at most 7 digits, found ~S" name field))
  (let ((value (parse-integer field)))
    (unless (<= minimum value +max-clock+)
      (fen-fail fen "~A must be from ~D to ~D" name minimum +max-clock+))
    value))

(defun check-board-rules (fen board)
  "Signal FEN-ERROR unless BOARD satisfies the structural rules for pawns and kings."
  (dotimes (square 64)
    (when (and (member (aref board square) (list +white-pawn+ +black-pawn+))
               (member (square-rank square) '(0 7)))
      (fen-fail fen "pawn on the first or last rank (~A)" (square-name square))))
  (handler-case (find-kings board)
    (position-error ()
      (fen-fail fen "each side needs exactly one king"))))

(defun check-castling-rules (fen board castling)
  "Signal FEN-ERROR unless every castling right has its king and rook at home."
  (flet ((require-home (right king-square king rook-square rook name)
           (when (and (logtest castling right)
                      (not (and (= (aref board king-square) king)
                                (= (aref board rook-square) rook))))
             (fen-fail fen "castling right ~A needs the king and rook on their home squares"
                       name))))
    (require-home +castle-white-king+ +e1+ +white-king+ +h1+ +white-rook+ "K")
    (require-home +castle-white-queen+ +e1+ +white-king+ +a1+ +white-rook+ "Q")
    (require-home +castle-black-king+ +e8+ +black-king+ +h8+ +black-rook+ "k")
    (require-home +castle-black-queen+ +e8+ +black-king+ +a8+ +black-rook+ "q")))

(defun check-en-passant-rules (fen board side target)
  "Signal FEN-ERROR unless TARGET is a square a double push by the side NOT to move could
have just crossed."
  (unless (= target +no-square+)
    (let* ((white-to-move (= side +white+))
           (expected-rank (if white-to-move 5 2))
           (pawn-square (if white-to-move (- target 8) (+ target 8)))
           (origin-square (if white-to-move (+ target 8) (- target 8)))
           (pawn (if white-to-move +black-pawn+ +white-pawn+)))
      (unless (= (square-rank target) expected-rank)
        (fen-fail fen "en-passant square ~A is on the wrong rank for the side to move"
                  (square-name target)))
      (unless (and (= (aref board pawn-square) pawn)
                   (= (aref board target) +empty+)
                   (= (aref board origin-square) +empty+))
        (fen-fail fen "en-passant square ~A does not follow a double pawn push"
                  (square-name target))))))

(defun parse-fen (fen)
  "A new position for the FEN string FEN, or a FEN-ERROR. See the file header for the
rules. The halfmove clock and fullmove number are stored but no rule uses them."
  (unless (stringp fen)
    (error 'fen-error :fen fen :reason "not a string"))
  (when (> (length fen) *max-fen-length*)
    (fen-fail (subseq fen 0 40) "longer than ~D characters" *max-fen-length*))
  (let ((fields (split-fields fen))
        (board (make-array 64 :element-type '(unsigned-byte 8) :initial-element 0)))
    (unless (member (length fields) '(4 6))
      (fen-fail fen "expected 4 or 6 fields, found ~D" (length fields)))
    (destructuring-bind (placement side-field castling-field en-passant-field
                         &optional (halfmove-field "0") (fullmove-field "1"))
        fields
      (parse-placement fen placement board)
      (let* ((side (cond ((string= side-field "w") +white+)
                         ((string= side-field "b") +black+)
                         (t (fen-fail fen "side to move must be w or b, found ~S" side-field))))
             (castling (parse-castling-field fen castling-field))
             (en-passant (cond ((string= en-passant-field "-") +no-square+)
                               ((parse-square en-passant-field))
                               (t (fen-fail fen "bad en-passant field ~S" en-passant-field))))
             (halfmove (parse-clock fen halfmove-field "halfmove clock" 0))
             (fullmove (parse-clock fen fullmove-field "fullmove number" 1)))
        (check-board-rules fen board)
        (check-castling-rules fen board castling)
        (check-en-passant-rules fen board side en-passant)
        (let ((pos (make-position-from-parts board side castling en-passant halfmove fullmove)))
          (when (king-attacked-p pos (opposite-colour side))
            (fen-fail fen "the side not to move is in check"))
          pos)))))

(defun position-to-fen (pos)
  "The FEN string of POS (6 fields, castling letters in the order KQkq)."
  (declare (type chess-position pos))
  (with-output-to-string (out)
    (loop for rank from 7 downto 0
          do (let ((empty 0))
               (dotimes (file 8)
                 (let ((piece (piece-at pos (make-square file rank))))
                   (cond ((= piece +empty+) (incf empty))
                         (t (when (plusp empty)
                              (write-char (digit-char empty) out)
                              (setf empty 0))
                            (write-char (piece-char piece) out)))))
               (when (plusp empty)
                 (write-char (digit-char empty) out))
               (when (plusp rank)
                 (write-char #\/ out))))
    (write-string (if (= (pos-side pos) +white+) " w " " b ") out)
    (let ((castling (pos-castling pos)))
      (if (zerop castling)
          (write-char #\- out)
          (loop for (right . letter) in `((,+castle-white-king+ . #\K)
                                          (,+castle-white-queen+ . #\Q)
                                          (,+castle-black-king+ . #\k)
                                          (,+castle-black-queen+ . #\q))
                when (logtest castling right)
                  do (write-char letter out))))
    (format out " ~A ~D ~D"
            (if (= (pos-en-passant pos) +no-square+) "-" (square-name (pos-en-passant pos)))
            (pos-halfmove pos)
            (pos-fullmove pos))))

(defun start-position ()
  "A new position set up for the start of a game."
  (parse-fen *start-fen*))
