;;;; movegen.lisp -- preallocated move buffers and pseudo-legal move generation on bitboards.
;;;;
;;;; A pseudo-legal move obeys the movement rules of the piece but may leave the mover's own
;;;; king attacked. Legality is a separate step (legal.lisp). Castling is the one exception,
;;;; with the same rule as the reference model: it is generated only when the right is held,
;;;; the king and rook stand on their home squares, the squares between them are empty and
;;;; none of the three squares the king uses (start, crossed, landing) is attacked. The two
;;;; layers therefore define the same pseudo-legal set, and the tests compare it too.
;;;;
;;;; Moves are the packed fixnums of src/core/move.lisp, written into a preallocated buffer:
;;;; nothing is allocated per move.

(in-package #:scacchiforge.optimized)

;;; Everything up to (DECLAIM-OPTIMIZED-POLICY) below is outside the hot path: the macros that
;;; write the generator's code (their expanders run at compile time), the constants they use
;;; and the function that allocates a move buffer. They are compiled with the policy of the
;;; layer's files outside the hot path, so that the efficiency notes of "make hot-path" are
;;; about the generated code only. The macros take variables for BUFFER and INDEX, evaluate
;;; every other argument once and bind only uninterned names around the caller's forms.

(declaim (optimize (speed 1) (safety 2)))

(deftype bitboard-move-buffer () '(simple-array fixnum (*)))

(defconstant +bitboard-ply-moves+ 512
  "Slots a move buffer reserves per ply: more than the 323 pseudo-legal moves a position can
have when its material could arise in a game (see MAKE-BITBOARD-MOVE-BUFFER).")

(defun make-bitboard-move-buffer (&optional (plies 1))
  "A move buffer for a tree of PLIES plies: (PLIES + 1) * +BITBOARD-PLY-MOVES+ fixnums.

The plies share the buffer as a stack: the moves of a node start where the legal moves of its
parent end, so no ply ever writes over a list still in use. The generator first writes the
pseudo-legal moves of a node and then keeps the legal ones in place.

When the material of each side could arise in a game (a king, at most 15 other pieces, and no
more queens, rooks, bishops or knights than the original ones plus the promoted pawns), a node
has at most 323 pseudo-legal moves: the sum of the most moves each piece can have, nine queens
of 27, two rooks of 14, two bishops of 13, two knights of 8 and a king of 8 plus 2 castlings (a
pawn has at most 12, fewer than the queen it can become). A tree of PLIES plies then needs at
most 323 * PLIES slots, fewer than this buffer has. A position outside that bound whose moves
do not fit makes the bounds check of the store signal an error, which SBCL keeps at every safety
above 0 (src/optimized/policy.lisp, ADR-0014): it cannot give a wrong count. Test
a-buffer-too-small-signals-an-error-not-a-wrong-count (tests/test-optimized.lisp)."
  (check-type plies (integer 1 1024))
  (make-array (* (1+ plies) +bitboard-ply-moves+) :element-type 'fixnum :initial-element 0))

(defconstant +file-a+ #x0101010101010101 "The squares of the a-file.")
(defconstant +file-h+ #x8080808080808080 "The squares of the h-file.")
(defconstant +rank-1+ #x00000000000000FF "The squares of the first rank.")
(defconstant +rank-3+ #x0000000000FF0000 "The squares of the third rank.")
(defconstant +rank-6+ #x0000FF0000000000 "The squares of the sixth rank.")
(defconstant +rank-8+ #xFF00000000000000 "The squares of the eighth rank.")

(defmacro push-move (buffer index move)
  "Store MOVE at INDEX of BUFFER and advance INDEX. BUFFER and INDEX must be variables: INDEX
is read twice and written once. MOVE is evaluated once."
  (check-type buffer symbol)
  (check-type index symbol)
  `(progn (setf (aref ,buffer ,index) ,move)
          (incf ,index)))

(defmacro shift-bits (bits amount)
  "BITS shifted by the constant AMOUNT squares: towards higher indices when AMOUNT is positive,
keeping 64 bits."
  (check-type amount integer)
  (if (plusp amount)
      `(ldb (byte 64 0) (ash ,bits ,amount))
      `(ash ,bits ,amount)))

(defmacro push-promotions (buffer index from to flags)
  "Store the four promotions of the pawn move FROM -> TO: queen, rook, bishop, knight. FROM, TO
and FLAGS are evaluated once."
  (let ((origin (gensym "FROM"))
        (target (gensym "TO"))
        (move-flags (gensym "FLAGS")))
    `(let ((,origin ,from)
           (,target ,to)
           (,move-flags ,flags))
       (push-move ,buffer ,index (encode-move ,origin ,target +queen+ ,move-flags))
       (push-move ,buffer ,index (encode-move ,origin ,target +rook+ ,move-flags))
       (push-move ,buffer ,index (encode-move ,origin ,target +bishop+ ,move-flags))
       (push-move ,buffer ,index (encode-move ,origin ,target +knight+ ,move-flags)))))

(defmacro push-pawn-moves (buffer index pawns empty enemy en-passant side
                           &key up double-rank promotion-rank west east)
  "Store the pseudo-legal pawn moves of SIDE. UP is the constant step of a push (8 or -8),
WEST and EAST the constant steps of a capture towards the a-file and the h-file, DOUBLE-RANK
the rank a single push reaches when a double push is possible and PROMOTION-RANK the last
rank. The moves are generated a set at a time: the destination squares of all the pawns at
once, by shifting the pawn bitboard. PAWNS, EMPTY, ENEMY, EN-PASSANT, SIDE, DOUBLE-RANK and
PROMOTION-RANK are evaluated once, in this order."
  (check-type up integer)
  (check-type west integer)
  (check-type east integer)
  (let ((own-pawns (gensym "PAWNS"))
        (empty-squares (gensym "EMPTY"))
        (enemy-pieces (gensym "ENEMY"))
        (target (gensym "EN-PASSANT"))
        (colour (gensym "SIDE"))
        (double-push-rank (gensym "DOUBLE-RANK"))
        (last-rank (gensym "PROMOTION-RANK"))
        (single (gensym "SINGLE"))
        (double (gensym "DOUBLE"))
        (west-captures (gensym "WEST-CAPTURES"))
        (east-captures (gensym "EAST-CAPTURES"))
        (to (gensym "TO"))
        (from (gensym "FROM")))
    `(let* ((,own-pawns ,pawns)
            (,empty-squares ,empty)
            (,enemy-pieces ,enemy)
            (,target ,en-passant)
            (,colour ,side)
            (,double-push-rank ,double-rank)
            (,last-rank ,promotion-rank)
            (,single (logand (shift-bits ,own-pawns ,up) ,empty-squares))
            (,double (logand (shift-bits (logand ,single ,double-push-rank) ,up) ,empty-squares))
            (,west-captures (logand (shift-bits (logandc2 ,own-pawns +file-a+) ,west)
                                    ,enemy-pieces))
            (,east-captures (logand (shift-bits (logandc2 ,own-pawns +file-h+) ,east)
                                    ,enemy-pieces)))
       (declare (type bitboard ,own-pawns ,empty-squares ,enemy-pieces ,double-push-rank
                      ,last-rank ,single ,double ,west-captures ,east-captures))
       (do-squares (,to (logandc2 ,single ,last-rank))
         (push-move ,buffer ,index (encode-move (- ,to ,up) ,to 0 0)))
       (do-squares (,to (logand ,single ,last-rank))
         (push-promotions ,buffer ,index (- ,to ,up) ,to 0))
       (do-squares (,to ,double)
         (push-move ,buffer ,index (encode-move (- ,to ,(* 2 up)) ,to 0 +flag-double-push+)))
       (do-squares (,to (logandc2 ,west-captures ,last-rank))
         (push-move ,buffer ,index (encode-move (- ,to ,west) ,to 0 +flag-capture+)))
       (do-squares (,to (logand ,west-captures ,last-rank))
         (push-promotions ,buffer ,index (- ,to ,west) ,to +flag-capture+))
       (do-squares (,to (logandc2 ,east-captures ,last-rank))
         (push-move ,buffer ,index (encode-move (- ,to ,east) ,to 0 +flag-capture+)))
       (do-squares (,to (logand ,east-captures ,last-rank))
         (push-promotions ,buffer ,index (- ,to ,east) ,to +flag-capture+))
       ;; En passant: the pawns of SIDE that attack the target stand where a pawn of the other
       ;; colour on the target would attack.
       (unless (= ,target +no-square+)
         (do-squares (,from (logand (pawn-attacks (opposite-colour ,colour) ,target)
                                    ,own-pawns))
           (push-move ,buffer ,index
                      (encode-move ,from ,target 0
                                   (logior +flag-capture+ +flag-en-passant+))))))))

(defmacro push-targets (buffer index from targets enemy)
  "Store a move from FROM to each square of TARGETS, flagged as a capture where ENEMY has a
piece. FROM, TARGETS and ENEMY are evaluated once."
  (let ((origin (gensym "FROM"))
        (bits (gensym "TARGETS"))
        (enemy-pieces (gensym "ENEMY"))
        (to (gensym "TO")))
    `(let ((,origin ,from)
           (,bits ,targets)
           (,enemy-pieces ,enemy))
       (declare (type square ,origin) (type bitboard ,bits ,enemy-pieces))
       (do-squares (,to (logand ,bits ,enemy-pieces))
         (push-move ,buffer ,index (encode-move ,origin ,to 0 +flag-capture+)))
       (do-squares (,to (logandc2 ,bits ,enemy-pieces))
         (push-move ,buffer ,index (encode-move ,origin ,to 0 0))))))

;;; The hot path starts here.

(declaim-optimized-policy)

(declaim (inline generate-castling))

(defun generate-castling (bbp buffer index side occupancy)
  "Store the castling moves of SIDE that satisfy the rule in the file header; return the new
index."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer) (type fixnum index)
           (type colour side) (type bitboard occupancy))
  (let* ((rights (bbp-castling bbp))
         (white (= side +white+))
         (king-right (if white +castle-white-king+ +castle-black-king+))
         (queen-right (if white +castle-white-queen+ +castle-black-queen+)))
    (when (logtest rights (logior king-right queen-right))
      (let ((board (bbp-board bbp))
            (home (if white +e1+ +e8+))
            (other (opposite-colour side))
            (rook (make-piece side +rook+)))
        (declare (type square home))
        (when (and (= (aref board home) (make-piece side +king+))
                   (not (attacked-by-p bbp home other occupancy)))
          (when (and (logtest rights king-right)
                     (= (aref board (+ home 3)) rook)
                     (zerop (logand occupancy (logior (ash 1 (+ home 1)) (ash 1 (+ home 2)))))
                     (not (attacked-by-p bbp (+ home 1) other occupancy))
                     (not (attacked-by-p bbp (+ home 2) other occupancy)))
            (push-move buffer index (encode-move home (+ home 2) 0 +flag-castle-king+)))
          (when (and (logtest rights queen-right)
                     (= (aref board (- home 4)) rook)
                     (zerop (logand occupancy (logior (ash 1 (- home 1)) (ash 1 (- home 2))
                                                      (ash 1 (- home 3)))))
                     (not (attacked-by-p bbp (- home 1) other occupancy))
                     (not (attacked-by-p bbp (- home 2) other occupancy)))
            (push-move buffer index (encode-move home (- home 2) 0 +flag-castle-queen+))))))
    index))

(declaim (inline bitboard-generate-pseudo-legal))

(defun bitboard-generate-pseudo-legal (bbp buffer start)
  "Store the pseudo-legal moves of the side to move of BBP in BUFFER from index START; return
the index after the last move. Pawns are generated a set at a time, the other pieces one at a
time from their attack sets, sliders through the interface of sliders.lisp."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer) (type fixnum start))
  (let* ((index start)
         (side (bbp-side bbp))
         (pieces (bbp-pieces bbp))
         (base (* side 6))
         (own (aref (bbp-colour-occupancy bbp) side))
         (enemy (aref (bbp-colour-occupancy bbp) (opposite-colour side)))
         (occupancy (bbp-occupancy bbp))
         (empty (ldb (byte 64 0) (lognot occupancy)))
         (en-passant (bbp-en-passant bbp))
         (queens (aref pieces (+ base 4))))
    (declare (type fixnum index) (type bitboard own enemy occupancy empty queens))
    (let ((pawns (aref pieces base)))
      (declare (type bitboard pawns))
      (if (= side +white+)
          (push-pawn-moves buffer index pawns empty enemy en-passant side
                           :up 8 :double-rank +rank-3+ :promotion-rank +rank-8+
                           :west 7 :east 9)
          (push-pawn-moves buffer index pawns empty enemy en-passant side
                           :up -8 :double-rank +rank-6+ :promotion-rank +rank-1+
                           :west -9 :east -7)))
    (do-squares (from (aref pieces (+ base 1)))
      (push-targets buffer index from (logandc2 (knight-attacks from) own) enemy))
    (do-squares (from (logior (aref pieces (+ base 2)) queens))
      (push-targets buffer index from (logandc2 (bishop-attacks from occupancy) own) enemy))
    (do-squares (from (logior (aref pieces (+ base 3)) queens))
      (push-targets buffer index from (logandc2 (rook-attacks from occupancy) own) enemy))
    (do-squares (from (aref pieces (+ base 5)))
      (push-targets buffer index from (logandc2 (king-attacks from) own) enemy))
    (generate-castling bbp buffer index side occupancy)))

;;; Proclaimed inline only while it is defined, as BITBOARD-MAKE-MOVE is (make.lisp): every
;;; caller calls it, except PERFT-NODE, which asks for its inline expansion.
(declaim (notinline bitboard-generate-pseudo-legal))
