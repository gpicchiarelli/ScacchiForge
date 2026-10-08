;;;; search.lisp -- the search baselines of the optimized layer: negamax, alpha-beta and
;;;; iterative deepening at fixed depth, with a preallocated triangular table of principal
;;;; variations and a node counter.
;;;;
;;;; They follow the conventions of the reference's searches (src/reference/search.lisp;
;;;; docs/valutazione.md, "Convenzioni per la ricerca"), so that at a fixed depth both layers
;;;; return the same value (the gate of Phase 2, docs/roadmap.md):
;;;;  - Scores are centipawns from the point of view of the side to move; negamax negates them
;;;;    at every ply.
;;;;  - Depth counts plies. A node at depth 0 returns the static evaluation (BITBOARD-EVALUATE)
;;;;    without looking for checkmate or stalemate; there is no quiescence search.
;;;;  - A node at depth above 0 without legal moves scores P - 30000 when the side to move is in
;;;;    check, P being its distance in plies from the root, and 0 otherwise. Repetition, the
;;;;    fifty-move rule and insufficient material are not detected.
;;;;  - Node counts include the root and the leaves.
;;;;  - Alpha-beta is fail-soft; the root is searched with the full window, raising alpha after
;;;;    each root move, and never cuts.
;;;;  - The principal variation of a node is its first move, in search order, that reaches the
;;;;    node's best score, followed by that move's own variation. It ends at depth 0 or at a node
;;;;    without legal moves.
;;;;  - No move ordering, no transposition table, no pruning other than alpha-beta, no
;;;;    quiescence (later phases). The moves of a node are searched in the order of this layer's
;;;;    generator (movegen.lisp, legal.lisp), or, for the tests, in an order permuted by a seeded
;;;;    generator (:SHUFFLE-RNG).
;;;; The generator of this layer writes the legal moves in another order than the reference's, so
;;;; the best move (among moves of equal value), the principal variation and the node count of
;;;; alpha-beta may differ between the layers; the value may not. The node count of negamax does
;;;; not depend on the order of the moves and is equal in both.
;;;;
;;;; Everything a search needs per node is preallocated in a BITBOARD-SEARCH-CONTEXT: the move
;;;; buffer, shared by the plies as in perft, the table of principal variations and the node
;;;; counter. A search with a context allocates nothing per node (test
;;;; optimized-search/search-allocates-nothing-after-warm-up). The entry points that return
;;;; the principal variation as a list, or the iterations of iterative deepening, allocate those
;;;; lists once per search.

(in-package #:scacchiforge.optimized)

;;; The context and the constants are not on the hot path: they are compiled with the policy of
;;; the layer's files outside it. The hot path starts at (DECLAIM-OPTIMIZED-POLICY) below.

(declaim (optimize (speed 1) (safety 2)))

(defconstant +bitboard-mate-score+ 30000
  "Score of a checkmate at the root's ply 0: the side to move mated at ply P scores P - 30000.
The value of the reference's +MATE-SCORE+ (docs/valutazione.md).")

(defconstant +bitboard-mate-bound+ 29000
  "Scores with at least this magnitude are mate scores.")

(defconstant +search-infinity+ 32000 "Larger than any score; the bound of the full window.")

(defconstant +bitboard-max-search-depth+ 62
  "The deepest search a context holds; the reference's searches accept the same depths.")

(deftype search-depth () `(integer 0 ,+bitboard-max-search-depth+))

(defstruct (bitboard-search-context (:conc-name search-context-)
                                    (:constructor %make-bitboard-search-context))
  "What a search of the optimized layer carries through its nodes, preallocated: the move
buffer, shared by the plies; the triangular table of principal variations, in which the row of
ply P (PV-STRIDE slots from P * PV-STRIDE) holds the variation found at that ply and
PV-LENGTHS its length; the node counter; and the optional generator that permutes the moves of
every node (a test hook). MAX-DEPTH is the deepest search it holds."
  (max-depth 0 :type search-depth)
  (buffer (make-bitboard-move-buffer 1) :type bitboard-move-buffer)
  (pv (make-array 1 :element-type 'fixnum :initial-element 0) :type (simple-array fixnum (*)))
  (pv-stride 1 :type fixnum)
  (pv-lengths (make-array 1 :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (nodes 0 :type fixnum)
  (shuffle-rng nil :type (or null rng)))

(defun make-bitboard-search-context (&optional (max-depth +bitboard-max-search-depth+))
  "A search context for searches of at most MAX-DEPTH plies: a move buffer of MAX-DEPTH plies
(MAKE-BITBOARD-MOVE-BUFFER) and a table of (MAX-DEPTH + 1) rows of principal variations."
  (check-type max-depth (and search-depth (integer 1)))
  (let ((stride (1+ max-depth)))
    (%make-bitboard-search-context
     :max-depth max-depth
     :buffer (make-bitboard-move-buffer max-depth)
     :pv (make-array (* stride stride) :element-type 'fixnum :initial-element 0)
     :pv-stride stride
     :pv-lengths (make-array stride :element-type 'fixnum :initial-element 0))))

;;; --- the hot path ---------------------------------------------------------------------------

(declaim-optimized-policy)

(declaim (inline record-variation node-moves terminal-score))

(defun record-variation (context ply move)
  "Make the variation of PLY in CONTEXT be MOVE followed by the variation of PLY + 1."
  (declare (type bitboard-search-context context) (type fixnum ply) (type move move))
  (let* ((pv (search-context-pv context))
         (lengths (search-context-pv-lengths context))
         (stride (search-context-pv-stride context))
         (row (* ply stride))
         (child-row (+ row stride))
         (child-length (aref lengths (1+ ply))))
    (declare (type fixnum row child-row child-length))
    (setf (aref pv row) move)
    (dotimes (index child-length)
      (setf (aref pv (+ row 1 index)) (aref pv (+ child-row index))))
    (setf (aref lengths ply) (1+ child-length))
    nil))

(defun shuffle-node-moves (buffer start end rng)
  "Permute the moves of BUFFER from START below END in place, uniformly, with the Fisher-Yates
shuffle drawing from RNG. A test hook: it calls the core generator, which may allocate."
  (declare (type bitboard-move-buffer buffer) (type fixnum start end) (type rng rng))
  (loop for last of-type fixnum from (1- end) above start
        do (let ((other (+ start (the fixnum (rng-below rng (1+ (- last start)))))))
             (rotatef (aref buffer last) (aref buffer other)))))

(defun node-moves (bbp buffer base context)
  "Store the legal moves of BBP in BUFFER from BASE, permuted when CONTEXT has a shuffle
generator; return the end index."
  (declare (type bitboard-position bbp) (type bitboard-move-buffer buffer) (type fixnum base)
           (type bitboard-search-context context))
  (let ((end (bitboard-generate-legal bbp buffer base))
        (rng (search-context-shuffle-rng context)))
    (declare (type fixnum end))
    (when rng
      (shuffle-node-moves buffer base end rng))
    end))

(defun terminal-score (bbp ply)
  "The score of BBP, which has no legal move, at PLY plies from the root: PLY - 30000 when the
side to move is in check, else 0."
  (declare (type bitboard-position bbp) (type fixnum ply))
  (if (bitboard-in-check-p bbp)
      (- ply +bitboard-mate-score+)
      0))

(declaim (ftype (function (bitboard-position search-depth fixnum fixnum bitboard-search-context)
                          (values fixnum &optional))
                negamax-node)
         (ftype (function (bitboard-position search-depth fixnum fixnum fixnum fixnum
                                             bitboard-search-context)
                          (values fixnum &optional))
                alpha-beta-node))

(defun negamax-node (bbp depth ply base context)
  "Plain negamax value of BBP to DEPTH plies at PLY plies from the root, with the moves of the
node written in the move buffer of CONTEXT from BASE; its principal variation is left in the
row PLY of the table of CONTEXT. It removes no work, so it carries no classification: it is the
baseline the other searches are compared with."
  (declare (type bitboard-position bbp) (type search-depth depth) (type fixnum ply base)
           (type bitboard-search-context context))
  (incf (search-context-nodes context))
  (let ((lengths (search-context-pv-lengths context)))
    (if (zerop depth)
        (progn (setf (aref lengths ply) 0)
               (bitboard-evaluate bbp))
        (let* ((buffer (search-context-buffer context))
               (end (node-moves bbp buffer base context)))
          (declare (type fixnum end))
          (if (= end base)
              (progn (setf (aref lengths ply) 0)
                     (terminal-score bbp ply))
              (let ((best (- +search-infinity+)))
                (declare (type fixnum best))
                (loop for index of-type fixnum from base below end
                      do (let ((move (aref buffer index)))
                           (bitboard-make-move bbp move)
                           (let ((score (- (negamax-node bbp (1- depth) (1+ ply) end context))))
                             (declare (type fixnum score))
                             (bitboard-unmake-move bbp)
                             (when (> score best)
                               (setf best score)
                               (record-variation context ply move)))))
                best))))))

(defun alpha-beta-node (bbp depth ply alpha beta base context)
  "Fail-soft alpha-beta value of BBP to DEPTH plies at PLY plies from the root with the window
(ALPHA, BETA), the moves of the node written in the move buffer of CONTEXT from BASE; the line
of the best move found is left in the row PLY of the table of CONTEXT.

Classification: [BOUNDED]
Basis: a result strictly inside (ALPHA, BETA) is the negamax value; a result at or below ALPHA
is an upper bound on it, and one at or above BETA a lower bound (Knuth and Moore, 1975). With
the full window the result is the negamax value: the root is searched with the window (-32000,
32000), and alpha rises with each root move. The line is exact where the result is: at a node
whose value lies strictly inside its window, the first move reaching that value was searched
with a window that holds it, and a later move of equal value fails low and does not replace
it, so the line is the one negamax returns for the same move order. At a node that fails low
or high the line is not meaningful, and no exact line passes through such a node.
Evidence: tests optimized-search/alpha-beta-equals-negamax-up-to-depth-three and
optimized-search/alpha-beta-value-does-not-depend-on-the-move-order
(tests/test-optimized-search.lisp), and differential/search-values-equal-the-reference."
  (declare (type bitboard-position bbp) (type search-depth depth)
           (type fixnum ply alpha beta base) (type bitboard-search-context context))
  (incf (search-context-nodes context))
  (let ((lengths (search-context-pv-lengths context)))
    (if (zerop depth)
        (progn (setf (aref lengths ply) 0)
               (bitboard-evaluate bbp))
        (let* ((buffer (search-context-buffer context))
               (end (node-moves bbp buffer base context)))
          (declare (type fixnum end))
          (if (= end base)
              (progn (setf (aref lengths ply) 0)
                     (terminal-score bbp ply))
              (let ((best (- +search-infinity+)))
                (declare (type fixnum best))
                (loop for index of-type fixnum from base below end
                      do (let ((move (aref buffer index)))
                           (bitboard-make-move bbp move)
                           (let ((score (- (alpha-beta-node bbp (1- depth) (1+ ply)
                                                            (- beta) (- alpha) end context))))
                             (declare (type fixnum score))
                             (bitboard-unmake-move bbp)
                             (when (> score best)
                               (setf best score)
                               (record-variation context ply move))
                             (when (> score alpha)
                               (setf alpha score))))
                      until (>= alpha beta))
                best))))))

(defun bitboard-search-with-context (context bbp depth algorithm)
  "Search BBP to DEPTH plies with ALGORITHM (:ALPHA-BETA or :NEGAMAX), using the preallocated
CONTEXT, and return three values: the score, the best move (+NO-MOVE+ when the root has no
legal move or DEPTH is 0) and the node count. The principal variation stays in CONTEXT
(BITBOARD-SEARCH-CONTEXT-PV). BBP is left as it was. Allocates nothing, unless CONTEXT has a
shuffle generator."
  (declare (type bitboard-search-context context) (type bitboard-position bbp))
  (unless (typep depth 'search-depth)
    (error 'type-error :datum depth :expected-type 'search-depth))
  (unless (<= depth (search-context-max-depth context))
    (error "a search of depth ~D does not fit a context of depth ~D"
           depth (search-context-max-depth context)))
  (setf (search-context-nodes context) 0)
  (let ((score (ecase algorithm
                 (:alpha-beta (alpha-beta-node bbp depth 0 (- +search-infinity+)
                                               +search-infinity+ 0 context))
                 (:negamax (negamax-node bbp depth 0 0 context)))))
    (declare (type fixnum score))
    (values score
            (if (plusp (aref (search-context-pv-lengths context) 0))
                (aref (search-context-pv context) 0)
                +no-move+)
            (search-context-nodes context))))

;;; The hot path of this file ends here. What follows allocates lists for its callers (the
;;; variation, the iterations) once per search, or a context; it is compiled with the policy of
;;; the layer's files outside the hot path.

(declaim (optimize (speed 1) (safety 2)))

(defun bitboard-mate-score-p (score)
  "True when SCORE says that one side is being checkmated."
  (>= (abs score) +bitboard-mate-bound+))

(defun bitboard-search-context-pv (context)
  "The principal variation of the last search made with CONTEXT, as a fresh list of moves from
the root."
  (declare (type bitboard-search-context context))
  (loop for index from 0 below (aref (search-context-pv-lengths context) 0)
        collect (aref (search-context-pv context) index)))

(defun bitboard-search (bbp depth &key (algorithm :alpha-beta) shuffle-rng context)
  "Search BBP to DEPTH plies with ALGORITHM (:ALPHA-BETA or :NEGAMAX): values score, best move
(+NO-MOVE+ when none), node count and principal variation (a list of moves). SHUFFLE-RNG, a core
RNG, permutes the moves of every node before they are searched: the value must not change (a
test hook). CONTEXT is a search context to use; without one a context for DEPTH is made."
  (declare (type bitboard-position bbp))
  (check-type depth search-depth)
  (let ((context (or context (make-bitboard-search-context (max 1 depth)))))
    (setf (search-context-shuffle-rng context) shuffle-rng)
    (unwind-protect
         (multiple-value-bind (score move nodes)
             (bitboard-search-with-context context bbp depth algorithm)
           (values score move nodes (bitboard-search-context-pv context)))
      (setf (search-context-shuffle-rng context) nil))))

(defun bitboard-negamax-search (bbp depth &key shuffle-rng context)
  "Negamax from BBP to DEPTH plies: values score, best move, node count and principal variation,
as BITBOARD-SEARCH returns them."
  (bitboard-search bbp depth :algorithm :negamax :shuffle-rng shuffle-rng :context context))

(defun bitboard-alpha-beta-search (bbp depth &key shuffle-rng context)
  "Alpha-beta from BBP to DEPTH plies: values score, best move, node count and principal
variation, as BITBOARD-SEARCH returns them."
  (bitboard-search bbp depth :algorithm :alpha-beta :shuffle-rng shuffle-rng :context context))

(defun bitboard-iterative-deepening (bbp max-depth &key (algorithm :alpha-beta) shuffle-rng
                                                        on-iteration context)
  "Search BBP at depth 1, 2, ... MAX-DEPTH with ALGORITHM (:ALPHA-BETA or :NEGAMAX), each
iteration a complete search from scratch, with SHUFFLE-RNG as in BITBOARD-SEARCH. Stops early
once the score is a mate score. Calls ON-ITERATION, if given, with each iteration, a property
list (:DEPTH :SCORE :BEST-MOVE :NODES :PV). Returns the last score, best move, the total node
count, the list of iterations and the last principal variation.

Classification: [EXACT] (the early stop on a mate score)
Basis: the search is full width, with no transposition table, no pruning other than alpha-beta
and a leaf evaluation that does not depend on the depth. A mate score at depth D gives the
length of the fastest mate one side can force against any defence, and that mate lies within D
plies. A deeper search sees the same forced mate; a faster one would also lie within D plies
and would have been found at depth D. So every deeper search returns the same score and, trying
the moves in the same order, the same first best move. Stopping skips the deeper iterations
without changing the result.
Evidence: tests optimized-search/iterative-deepening-equals-the-direct-search-at-every-depth
and optimized-search/iterative-deepening-mate-stop-equals-the-full-depth-search
(tests/test-optimized-search.lisp)."
  (declare (type bitboard-position bbp))
  (check-type max-depth (and search-depth (integer 1)))
  (let ((context (or context (make-bitboard-search-context max-depth)))
        (iterations '())
        (total-nodes 0)
        (score 0)
        (best-move +no-move+)
        (line '()))
    (loop for depth from 1 to max-depth
          do (multiple-value-bind (iteration-score move nodes iteration-line)
                 (bitboard-search bbp depth :algorithm algorithm :shuffle-rng shuffle-rng
                                            :context context)
               (let ((iteration (list :depth depth :score iteration-score :best-move move
                                      :nodes nodes :pv iteration-line)))
                 (push iteration iterations)
                 (when on-iteration
                   (funcall on-iteration iteration)))
               (setf score iteration-score
                     best-move move
                     line iteration-line)
               (incf total-nodes nodes))
          until (bitboard-mate-score-p score))
    (values score best-move total-nodes (nreverse iterations) line)))
