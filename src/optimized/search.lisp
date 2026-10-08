;;;; search.lisp -- the searches of the optimized layer at fixed depth: the baselines of Phase 2
;;;; (negamax and alpha-beta), the searches of Phase 3 (alpha-beta, PVS and NegaScout with the
;;;; move ordering of ordering.lisp and the transposition table of transposition.lisp, with
;;;; explicit node types), and iterative deepening over any of them; a preallocated triangular
;;;; table of principal variations, a node counter and the statistics of a search.
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
;;;;  - Node counts include the root and the leaves; a node searched again (the re-search of PVS
;;;;    and NegaScout) counts again, and so does a node cut by the transposition table.
;;;;  - Alpha-beta is fail-soft; the root is searched with the full window, raising alpha after
;;;;    each root move, and never cuts.
;;;;  - The principal variation of a node is its first move, in search order, that reaches the
;;;;    node's best score, followed by that move's own variation. It ends at depth 0 or at a node
;;;;    without legal moves.
;;;;  - No pruning other than alpha-beta and the cutoffs of the transposition table, no
;;;;    quiescence, no killer or history (later phases).
;;;;
;;;; The baselines, NEGAMAX-NODE and ALPHA-BETA-NODE, are the searches of Phase 2, unchanged: the
;;;; moves of a node are searched in the order of this layer's generator (movegen.lisp,
;;;; legal.lisp), or, for the tests, in an order permuted by a seeded generator (:SHUFFLE-RNG).
;;;; The generator of this layer writes the legal moves in another order than the reference's, so
;;;; the best move (among moves of equal value), the principal variation and the node count of
;;;; alpha-beta may differ between the layers; the value may not. The node count of negamax does
;;;; not depend on the order of the moves and is equal in both.
;;;;
;;;; SEARCH-NODE is the node of Phase 3 (ADR-0021, ADR-0022 and ADR-0023 in docs/adr/). The
;;;; context says which window scheme it runs: alpha-beta (every move with the node's window),
;;;; PVS (the first move with the node's window, every other with a null window and, when the
;;;; result falls strictly inside the node's window, again with the node's window) or NegaScout
;;;; (as PVS, but the re-search window starts one below the null-window result, and a move whose
;;;; result is already exact is not searched again). It may order the moves (ordering.lisp),
;;;; probe and store the transposition table (transposition.lisp), and it records for every node
;;;; the type it was expected to have before the search (PV, Cut or All, after Knuth and Moore)
;;;; and the type it had after (from its result and its window).
;;;;
;;;; Everything a search needs per node is preallocated in a BITBOARD-SEARCH-CONTEXT: the move
;;;; buffer, shared by the plies as in perft, the keys of the ordering, the table of principal
;;;; variations, the previous iteration's variation, the node counter and the other counters. A
;;;; search with a context allocates nothing per node (tests
;;;; optimized-search/search-allocates-nothing-after-warm-up and
;;;; optimized-pvs/phase-3-search-allocates-nothing-after-warm-up). The entry points that return
;;;; the principal variation as a list, the statistics or the iterations of iterative deepening
;;;; allocate those lists once per search.

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

(defconstant +pv-node+ 0 "Node type PV: its value is expected inside its window.")
(defconstant +cut-node+ 1 "Node type Cut: expected to fail high, at or above beta.")
(defconstant +all-node+ 2 "Node type All: expected to fail low, at or below alpha.")

(defconstant +algorithm-alpha-beta+ 0 "Window scheme of SEARCH-NODE: alpha-beta.")
(defconstant +algorithm-pvs+ 1 "Window scheme of SEARCH-NODE: principal variation search.")
(defconstant +algorithm-negascout+ 2 "Window scheme of SEARCH-NODE: NegaScout.")

(defparameter *bitboard-search-algorithms* '(:negamax :alpha-beta :pvs :negascout)
  "The searches of the optimized layer: the baselines :NEGAMAX and :ALPHA-BETA, and :PVS and
:NEGASCOUT of Phase 3.")

(defstruct (bitboard-search-context (:conc-name search-context-)
                                    (:constructor %make-bitboard-search-context))
  "What a search of the optimized layer carries through its nodes, preallocated: the move
buffer, shared by the plies, and ORDER-KEYS, parallel to it, for the ordering; the triangular
table of principal variations, in which the row of ply P (PV-STRIDE slots from P * PV-STRIDE)
holds the variation found at that ply and PV-LENGTHS its length; PREVIOUS-PV and its length, the
variation of the previous iteration of iterative deepening, and PV-FOLLOW, the number of leading
plies of the current path that follow it; the node counter and the other counters of a search
(NODE-TYPE-COUNTS holds, at 3 x expected + observed, the nodes of each pair of types); the
configuration of SEARCH-NODE (window scheme, ordering, transposition table); and the optional
test hooks, a generator that permutes the moves of every node and a function that reorders
them. MAX-DEPTH is the deepest search it holds."
  (max-depth 0 :type search-depth)
  (buffer (make-bitboard-move-buffer 1) :type bitboard-move-buffer)
  (order-keys (make-bitboard-move-buffer 1) :type bitboard-move-buffer)
  (pv (make-array 1 :element-type 'fixnum :initial-element 0) :type (simple-array fixnum (*)))
  (pv-stride 1 :type fixnum)
  (pv-lengths (make-array 1 :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (previous-pv (make-array 1 :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (*)))
  (previous-pv-length 0 :type fixnum)
  (pv-follow 0 :type fixnum)
  (nodes 0 :type fixnum)
  (node-type-counts (make-array 9 :element-type 'fixnum :initial-element 0)
   :type (simple-array fixnum (9)))
  (beta-cutoffs 0 :type fixnum)
  (first-move-cutoffs 0 :type fixnum)
  (cutoff-nodes 0 :type fixnum)
  (re-searches 0 :type fixnum)
  (pv-move-first 0 :type fixnum)
  (algorithm-code 0 :type (integer 0 2))
  (ordering nil :type boolean)
  (tt nil :type (or null bitboard-transposition-table))
  (shuffle-rng nil :type (or null rng))
  (order-hook nil :type (or null function)))

(defun make-bitboard-search-context (&optional (max-depth +bitboard-max-search-depth+))
  "A search context for searches of at most MAX-DEPTH plies: a move buffer of MAX-DEPTH plies
(MAKE-BITBOARD-MOVE-BUFFER) with its array of order keys, and tables of (MAX-DEPTH + 1) rows
of principal variations."
  (check-type max-depth (and search-depth (integer 1)))
  (let ((stride (1+ max-depth)))
    (%make-bitboard-search-context
     :max-depth max-depth
     :buffer (make-bitboard-move-buffer max-depth)
     :order-keys (make-bitboard-move-buffer max-depth)
     :pv (make-array (* stride stride) :element-type 'fixnum :initial-element 0)
     :pv-stride stride
     :pv-lengths (make-array stride :element-type 'fixnum :initial-element 0)
     :previous-pv (make-array stride :element-type 'fixnum :initial-element 0))))

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

;;; --- the node of Phase 3 --------------------------------------------------------------------

(declaim (inline record-node-type child-node-type score-to-tt score-from-tt))

(defun record-node-type (context expected score alpha beta)
  "Count, in CONTEXT, a node of EXPECTED type whose result SCORE, against its window (ALPHA,
BETA), shows the observed type: Cut at or above BETA, All at or below ALPHA, PV strictly
inside."
  (declare (type bitboard-search-context context) (type (integer 0 2) expected)
           (type fixnum score alpha beta))
  (let ((observed (cond ((>= score beta) +cut-node+)
                        ((<= score alpha) +all-node+)
                        (t +pv-node+)))
        (counts (search-context-node-type-counts context)))
    (incf (aref counts (+ (* 3 expected) observed)))
    nil))

(defun child-node-type (expected first-move-p)
  "The type a child is expected to have, from the type EXPECTED of its parent and whether it is
the parent's first move (Knuth and Moore, 1975): the first child of a PV node is PV and the
others Cut; every child of a Cut node is All; every child of an All node is Cut."
  (declare (type (integer 0 2) expected))
  (cond ((= expected +pv-node+) (if first-move-p +pv-node+ +cut-node+))
        ((= expected +cut-node+) +all-node+)
        (t +cut-node+)))

(defun score-to-tt (score ply)
  "SCORE, found at PLY plies from the root, made relative to its node for the transposition
table: a mate score counts its plies from the node instead of from the root. The declared
ranges hold every score a node returns and every ply of a search; they also keep the result a
fixnum, so that nothing is boxed."
  (declare (type (integer -32000 32000) score) (type (integer 0 63) ply))
  (cond ((>= score +bitboard-mate-bound+) (+ score ply))
        ((<= score (- +bitboard-mate-bound+)) (- score ply))
        (t score)))

(defun score-from-tt (stored ply)
  "The score relative to the root, at PLY plies from it, of STORED, a score of the
transposition table relative to its node (the inverse of SCORE-TO-TT)."
  (declare (type (integer -32768 32767) stored) (type (integer 0 63) ply))
  (cond ((>= stored +bitboard-mate-bound+) (- stored ply))
        ((<= stored (- +bitboard-mate-bound+)) (+ stored ply))
        (t stored)))

(declaim (ftype (function (bitboard-position search-depth fixnum fixnum fixnum fixnum
                                             (integer 0 2) bitboard-search-context)
                          (values fixnum &optional))
                search-node))

(defun search-node (bbp depth ply alpha beta base expected context)
  "Fail-soft value of BBP to DEPTH plies at PLY plies from the root with the window (ALPHA,
BETA), the moves of the node written in the move buffer of CONTEXT from BASE, by the window
scheme of CONTEXT (alpha-beta, PVS or NegaScout), with the ordering and the transposition table
of CONTEXT when it has them; EXPECTED is the type (PV, Cut or All) the node is expected to have.
The line of the best move found is left in the row PLY of the table of CONTEXT, and the node is
counted by its expected and observed type.

Classification: [EXACT] on the value at full window without the table or with the table in
verification mode; [HEURISTIC] on the value at fixed depth with the table in normal mode
Basis: every scheme returns a fail-soft bound with the meaning of ALPHA-BETA-NODE: strictly
inside (ALPHA, BETA) the negamax value, at or below ALPHA an upper bound, at or above BETA a
lower bound; at the root, whose window is full, the negamax value.
 - Alpha-beta: ALPHA-BETA-NODE with the moves in another order, which changes the nodes and
   not the value (Knuth and Moore, 1975).
 - PVS: a move after the first is searched with the null window (a, a + 1), a being the node's
   alpha so far. Scores are integers, so the result s is a bound: s <= a says the move's value
   is at most s, and it raises nothing, as in alpha-beta; s >= a + 1 says its value is at least
   s, which at s >= BETA is the cutoff alpha-beta would make. When a < s < BETA (possible only
   at a node whose window is wider than one), the move is searched again with (a, BETA), whose
   result is the one alpha-beta gets.
 - NegaScout: as PVS, with two differences (Reinefeld, 1983). The re-search window is
   (s - 1, BETA): the value is at least s, so it lies strictly inside unless it is at least
   BETA, and the line found is exact; Reinefeld's window (s, BETA) would leave a value equal to
   s on its edge. A move is not searched again when its result is already exact: when the child
   is a leaf (depth 0), or a child at depth 1 that searched its moves (a non-empty line) and
   failed low, so that its result is the maximum of exact leaf values.
 - Transposition table: an entry is used for a cutoff only at a node below the root, only
   when its depth may be used (equal to DEPTH in verification mode, TT-1; at least DEPTH in
   normal mode), and only as the bound it is: an exact score at or outside the window, a lower
   bound at or above BETA, an upper bound at or below ALPHA. An exact score strictly inside an
   open window is not used for a cutoff, so every node of an exact line is searched and the
   line stays whole. Scores are stored relative to the node and converted on reading. In
   verification mode, with TT-2 (no repetition or fifty-move rule in any score) and TT-4 (no
   pruning that depends on the state of the search), an entry states a true bound on the value
   of (position, depth), and a cutoff on it returns what the search without the table could
   return; a slot whose key matches another position is discarded (TT-3). In normal mode a
   deeper entry gives the value of a deeper search, and a false hit of the key is possible.
 - The TT move and the PV move change only the order (ORDER-NODE-MOVES); a move is played only
   if the generator wrote it among the legal moves of the node (INV-C6).
The node types are recorded, not used: no window, ordering or cutoff depends on them.
Evidence: tests optimized-pvs/pvs-and-negascout-return-the-alpha-beta-value,
optimized-pvs/ordering-does-not-change-the-value,
optimized-pvs/perfect-ordering-searches-the-minimal-tree,
optimized-tt/verification-mode-equals-the-search-without-table and
optimized-tt/forced-false-hits-are-discarded-and-counted (tests/test-optimized-pvs.lisp,
tests/test-optimized-tt.lisp); differential/search-values-equal-the-reference."
  (declare (type bitboard-position bbp) (type search-depth depth)
           (type fixnum ply alpha beta base) (type (integer 0 2) expected)
           (type bitboard-search-context context))
  (incf (search-context-nodes context))
  (let ((lengths (search-context-pv-lengths context)))
    (when (zerop depth)
      (setf (aref lengths ply) 0)
      (let ((score (bitboard-evaluate bbp)))
        (declare (type fixnum score))
        (record-node-type context expected score alpha beta)
        (return-from search-node score)))
    (let ((table (search-context-tt context))
          (tt-move +no-move+))
      (declare (type move tt-move))
      ;; The transposition table: the TT move, and a cutoff where the entry allows one.
      (when table
        (let ((slot (bitboard-tt-probe table bbp)))
          (when (>= slot 0)
            (let ((word (aref (tt-data table) slot)))
              (setf tt-move (tt-word-move word))
              (when (and (plusp ply)
                         (if (tt-verification table)
                             (= (tt-word-depth word) depth)
                             (>= (tt-word-depth word) depth)))
                (incf (tt-usable-hits table))
                (let ((value (score-from-tt (tt-word-score word) ply))
                      (bound (tt-word-bound word)))
                  (declare (type fixnum value))
                  (when (cond ((= bound +bitboard-tt-exact+) (or (<= value alpha) (>= value beta)))
                              ((= bound +bitboard-tt-lower+) (>= value beta))
                              (t (<= value alpha)))
                    (incf (tt-cutoffs table))
                    (setf (aref lengths ply) 0)
                    (record-node-type context expected value alpha beta)
                    (return-from search-node value))))))))
      (let* ((buffer (search-context-buffer context))
             (end (node-moves bbp buffer base context)))
        (declare (type fixnum end))
        (when (= end base)
          (setf (aref lengths ply) 0)
          (let ((score (terminal-score bbp ply)))
            (declare (type fixnum score))
            (when table
              (bitboard-tt-store table bbp depth (score-to-tt score ply) +bitboard-tt-exact+
                                 +no-move+))
            (record-node-type context expected score alpha beta)
            (return-from search-node score)))
        (let* ((on-pv (and (= (search-context-pv-follow context) ply)
                           (< ply (search-context-previous-pv-length context))))
               (pv-move (if on-pv (aref (search-context-previous-pv context) ply) +no-move+)))
          (declare (type move pv-move))
          ;; The order of Phase 3, then the test hook that may reorder.
          (when (search-context-ordering context)
            (order-node-moves bbp buffer (search-context-order-keys context) base end tt-move
                              pv-move)
            (let ((first-move (aref buffer base)))
              (when (and table (/= tt-move +no-move+))
                (if (= first-move tt-move)
                    (incf (tt-move-first table))
                    (incf (tt-rejected-moves table))))
              (when (and on-pv (= first-move pv-move))
                (incf (search-context-pv-move-first context)))))
          (let ((hook (search-context-order-hook context)))
            (when hook
              (funcall hook bbp buffer base end depth)))
          ;; The moves.
          (let ((best (- +search-infinity+))
                (best-move +no-move+)
                (original-alpha alpha)
                (algorithm (search-context-algorithm-code context))
                (child-depth (1- depth))
                (child-ply (1+ ply))
                (searched 0))
            (declare (type fixnum best original-alpha searched child-ply)
                     (type move best-move) (type search-depth child-depth))
            (flet ((follow (move)
                     ;; Whether the child of MOVE lies on the previous principal variation.
                     (when on-pv
                       (setf (search-context-pv-follow context)
                             (if (= move pv-move) child-ply ply)))))
              (declare (inline follow))
              (loop for index of-type fixnum from base below end
                    do (let ((move (aref buffer index))
                             (first-move-p (= index base)))
                         (incf searched)
                         (bitboard-make-move bbp move)
                         (follow move)
                         (let ((score
                                 (if (or first-move-p (= algorithm +algorithm-alpha-beta+))
                                     (- (search-node bbp child-depth child-ply (- beta) (- alpha)
                                                     end (child-node-type expected first-move-p)
                                                     context))
                                     (let ((scout (- (search-node bbp child-depth child-ply
                                                                  (- -1 alpha) (- alpha) end
                                                                  (child-node-type expected nil)
                                                                  context))))
                                       (declare (type fixnum scout))
                                       (if (and (> scout alpha) (< scout beta)
                                                (or (= algorithm +algorithm-pvs+)
                                                    (not (or (= child-depth 0)
                                                             (and (= child-depth 1)
                                                                  (plusp (aref lengths
                                                                               child-ply)))))))
                                           (progn
                                             (incf (search-context-re-searches context))
                                             (follow move)
                                             (- (search-node bbp child-depth child-ply (- beta)
                                                             (if (= algorithm +algorithm-pvs+)
                                                                 (- alpha)
                                                                 (- 1 scout))
                                                             end +pv-node+ context)))
                                           scout)))))
                           (declare (type fixnum score))
                           (bitboard-unmake-move bbp)
                           (when (> score best)
                             (setf best score
                                   best-move move)
                             (record-variation context ply move))
                           (when (> score alpha)
                             (setf alpha score))))
                    until (>= alpha beta)))
            ;; Counters of the ordering's efficiency (docs/misure.md).
            (when (plusp ply)
              (incf (search-context-cutoff-nodes context)))
            (when (>= alpha beta)
              (incf (search-context-beta-cutoffs context))
              (when (= searched 1)
                (incf (search-context-first-move-cutoffs context))))
            (when table
              (let ((bound (cond ((<= best original-alpha) +bitboard-tt-upper+)
                                 ((>= best beta) +bitboard-tt-lower+)
                                 (t +bitboard-tt-exact+))))
                (bitboard-tt-store table bbp depth (score-to-tt best ply) bound
                                   (if (= bound +bitboard-tt-upper+) +no-move+ best-move))))
            (record-node-type context expected best original-alpha beta)
            best))))))

(defun run-search (context bbp depth algorithm ordering tt node-types keep-previous-pv
                   new-generation)
  "Search BBP to DEPTH plies with ALGORITHM (one of *BITBOARD-SEARCH-ALGORITHMS*) using CONTEXT,
with the move ordering of Phase 3 when ORDERING is true and the transposition table TT when it
is not NIL; with NODE-TYPES, an :ALPHA-BETA search runs SEARCH-NODE, which records the node
types, instead of the baseline ALPHA-BETA-NODE (so does any :ALPHA-BETA search with ordering, a
table or an order hook). KEEP-PREVIOUS-PV keeps the previous principal variation of CONTEXT
for the ordering (iterative deepening); NEW-GENERATION starts a new generation in TT. Resets
the counters of CONTEXT. Returns the score, the best move (+NO-MOVE+ when the root has no legal
move or DEPTH is 0) and the node count."
  (declare (type bitboard-search-context context) (type bitboard-position bbp))
  (unless (typep depth 'search-depth)
    (error 'type-error :datum depth :expected-type 'search-depth))
  (unless (<= depth (search-context-max-depth context))
    (error "a search of depth ~D does not fit a context of depth ~D"
           depth (search-context-max-depth context)))
  (unless (typep tt '(or null bitboard-transposition-table))
    (error 'type-error :datum tt :expected-type '(or null bitboard-transposition-table)))
  (let ((phase-3 (case algorithm
                   (:negamax
                    (when (or ordering tt node-types (search-context-order-hook context))
                      (error "negamax takes no ordering, transposition table, node types or ~
                              order hook"))
                    nil)
                   (:alpha-beta
                    (and (or ordering tt node-types (search-context-order-hook context)) t))
                   ((:pvs :negascout) t)
                   (t (error "~S is not one of the searches~{ ~S~}" algorithm
                             *bitboard-search-algorithms*)))))
    (setf (search-context-nodes context) 0
          (search-context-beta-cutoffs context) 0
          (search-context-first-move-cutoffs context) 0
          (search-context-cutoff-nodes context) 0
          (search-context-re-searches context) 0
          (search-context-pv-move-first context) 0
          (search-context-pv-follow context) 0
          (search-context-ordering context) (and ordering t)
          (search-context-tt context) tt
          (search-context-algorithm-code context) (case algorithm
                                                    (:pvs +algorithm-pvs+)
                                                    (:negascout +algorithm-negascout+)
                                                    (t +algorithm-alpha-beta+)))
    (fill (search-context-node-type-counts context) 0)
    (unless keep-previous-pv
      (setf (search-context-previous-pv-length context) 0))
    (when (and tt new-generation)
      (bitboard-tt-new-search tt))
    (let ((score (cond ((eq algorithm :negamax)
                        (negamax-node bbp depth 0 0 context))
                       ((not phase-3)
                        (alpha-beta-node bbp depth 0 (- +search-infinity+) +search-infinity+ 0
                                         context))
                       (t
                        (search-node bbp depth 0 (- +search-infinity+) +search-infinity+ 0
                                     +pv-node+ context)))))
      (declare (type fixnum score))
      (values score
              (if (plusp (aref (search-context-pv-lengths context) 0))
                  (aref (search-context-pv context) 0)
                  +no-move+)
              (search-context-nodes context)))))

(defun bitboard-search-with-context (context bbp depth algorithm &key ordering tt node-types)
  "Search BBP to DEPTH plies with ALGORITHM (:NEGAMAX, :ALPHA-BETA, :PVS or :NEGASCOUT), using
the preallocated CONTEXT, and return three values: the score, the best move (+NO-MOVE+ when the
root has no legal move or DEPTH is 0) and the node count. ORDERING true orders the moves as in
Phase 3 (ordering.lisp); TT, a BITBOARD-TRANSPOSITION-TABLE, is probed and stored, and starts a
new generation; NODE-TYPES true makes an :ALPHA-BETA search record the node types (the
baseline does not). Negamax takes none of the three. The principal variation stays in CONTEXT
(BITBOARD-SEARCH-CONTEXT-PV) and so do the counters (BITBOARD-SEARCH-STATISTICS). BBP is left as
it was. Allocates nothing, unless CONTEXT has a shuffle generator or an order hook."
  (run-search context bbp depth algorithm ordering tt node-types nil t))

;;; The hot path of this file ends here. What follows allocates lists for its callers (the
;;; variation, the statistics, the iterations) once per search, or a context; it is compiled
;;; with the policy of the layer's files outside the hot path.

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

(defparameter *node-type-names* '(:pv :cut :all)
  "The node types by code: +PV-NODE+, +CUT-NODE+, +ALL-NODE+.")

(defun node-statistics (context)
  "The counters of the last search made with CONTEXT, as a property list: :NODES; :BETA-CUTOFFS,
the nodes where a move reached beta; :FIRST-MOVE-CUTOFFS, those where it was the first move;
:CUTOFF-NODES, the nodes below the root that searched at least one move (where a cutoff could
happen); :RE-SEARCHES of PVS and NegaScout; :PV-MOVE-FIRST, the nodes on the previous principal
variation where its move was searched first; :NODE-TYPES, a list of (expected observed count)
for the nine pairs of types. The node types and the cutoffs are counted by the searches of
Phase 3 (SEARCH-NODE), not by the baselines, for which they are zero."
  (declare (type bitboard-search-context context))
  (let ((counts (search-context-node-type-counts context)))
    (list :nodes (search-context-nodes context)
          :beta-cutoffs (search-context-beta-cutoffs context)
          :first-move-cutoffs (search-context-first-move-cutoffs context)
          :cutoff-nodes (search-context-cutoff-nodes context)
          :re-searches (search-context-re-searches context)
          :pv-move-first (search-context-pv-move-first context)
          :node-types (loop for expected from 0 below 3
                            append (loop for observed from 0 below 3
                                         collect (list (nth expected *node-type-names*)
                                                       (nth observed *node-type-names*)
                                                       (aref counts (+ (* 3 expected)
                                                                       observed))))))))

(defun add-node-statistics (a b)
  "The sum of two property lists made by NODE-STATISTICS (NIL counts as zero)."
  (if (null a)
      b
      (list :nodes (+ (getf a :nodes) (getf b :nodes))
            :beta-cutoffs (+ (getf a :beta-cutoffs) (getf b :beta-cutoffs))
            :first-move-cutoffs (+ (getf a :first-move-cutoffs) (getf b :first-move-cutoffs))
            :cutoff-nodes (+ (getf a :cutoff-nodes) (getf b :cutoff-nodes))
            :re-searches (+ (getf a :re-searches) (getf b :re-searches))
            :pv-move-first (+ (getf a :pv-move-first) (getf b :pv-move-first))
            :node-types (mapcar (lambda (x y) (list (first x) (second x) (+ (third x) (third y))))
                                (getf a :node-types) (getf b :node-types)))))

(defun bitboard-search-statistics (context)
  "The statistics of the last search made with CONTEXT: the counters of NODE-STATISTICS and, when
the search used a transposition table, :TT with the table's statistics
(BITBOARD-TT-STATISTICS), which count since the table was made, cleared or reset."
  (declare (type bitboard-search-context context))
  (let ((table (search-context-tt context)))
    (append (node-statistics context)
            (list :tt (and table (bitboard-tt-statistics table))))))

(defun bitboard-search (bbp depth &key (algorithm :alpha-beta) ordering tt node-types
                                    shuffle-rng order-hook context)
  "Search BBP to DEPTH plies with ALGORITHM (:NEGAMAX, :ALPHA-BETA, :PVS or :NEGASCOUT), with
ORDERING, TT and NODE-TYPES as BITBOARD-SEARCH-WITH-CONTEXT takes them: values score, best move
(+NO-MOVE+ when none), node count, principal variation (a list of moves) and the statistics of
the search (BITBOARD-SEARCH-STATISTICS). SHUFFLE-RNG, a core RNG, permutes the moves of every
node before they are ordered and searched: the value must not change (a test hook). ORDER-HOOK,
a function of (bbp buffer start end depth), may reorder the legal moves of every node of a
search of Phase 3 in BUFFER from START below END after the ordering, leaving BBP as it found it
(a test hook). CONTEXT is a search context to use; without one a context for DEPTH is made."
  (declare (type bitboard-position bbp))
  (check-type depth search-depth)
  (check-type order-hook (or null function))
  (let ((context (or context (make-bitboard-search-context (max 1 depth)))))
    (setf (search-context-shuffle-rng context) shuffle-rng
          (search-context-order-hook context) order-hook)
    (unwind-protect
         (multiple-value-bind (score move nodes)
             (bitboard-search-with-context context bbp depth algorithm :ordering ordering :tt tt
                                                                       :node-types node-types)
           (values score move nodes (bitboard-search-context-pv context)
                   (bitboard-search-statistics context)))
      (setf (search-context-shuffle-rng context) nil
            (search-context-order-hook context) nil))))

(defun bitboard-negamax-search (bbp depth &key shuffle-rng context)
  "Negamax from BBP to DEPTH plies: values score, best move, node count and principal variation,
as BITBOARD-SEARCH returns them."
  (bitboard-search bbp depth :algorithm :negamax :shuffle-rng shuffle-rng :context context))

(defun bitboard-alpha-beta-search (bbp depth &key shuffle-rng context)
  "Alpha-beta from BBP to DEPTH plies: values score, best move, node count and principal
variation, as BITBOARD-SEARCH returns them."
  (bitboard-search bbp depth :algorithm :alpha-beta :shuffle-rng shuffle-rng :context context))

(defun bitboard-iterative-deepening (bbp max-depth &key (algorithm :alpha-beta) ordering tt
                                                        node-types shuffle-rng order-hook
                                                        on-iteration context)
  "Search BBP at depth 1, 2, ... MAX-DEPTH with ALGORITHM (:NEGAMAX, :ALPHA-BETA, :PVS or
:NEGASCOUT), with ORDERING, TT, NODE-TYPES, SHUFFLE-RNG and ORDER-HOOK as in BITBOARD-SEARCH.
Each iteration is a complete search of its depth. It hands to the next, with ORDERING, its
principal variation, whose move is searched first at every node of that line (the PV move), and
with TT the entries it stored, which give TT moves and the cutoffs the table's mode allows; TT
keeps one generation for the whole run. Stops early once the score is a mate score. Calls
ON-ITERATION, if given, with each iteration, a property list (:DEPTH :SCORE :BEST-MOVE :NODES
:PV). Returns the last score, best move, the total node count, the list of iterations, the last
principal variation and the statistics of the run (the counters of BITBOARD-SEARCH-STATISTICS
summed over the iterations, and :TT as the table has them at the end).

Classification: [EXACT] (the early stop on a mate score)
Basis: the search is full width, with no pruning other than alpha-beta and, with a table in
verification mode, cutoffs that keep the value (TT-1...TT-4), and a leaf evaluation that does
not depend on the depth. A mate score at depth D gives the length of the fastest mate one side
can force against any defence, and that mate lies within D plies. A deeper search sees the same
forced mate; a faster one would also lie within D plies and would have been found at depth D. So
every deeper search returns the same score, and stopping skips the deeper iterations without
changing it. Without ordering or a table each iteration tries the moves in the same order as a
deeper one, and the best move is the same too; with them the order changes from one iteration
to the next, and the best move is a move of the same forced mate. With a table in normal mode
the value is not the value of a fixed-depth search ([HEURISTIC]), and neither is the stop.
Evidence: tests optimized-search/iterative-deepening-equals-the-direct-search-at-every-depth,
optimized-search/iterative-deepening-mate-stop-equals-the-full-depth-search
(tests/test-optimized-search.lisp) and
optimized-pvs/phase-3-iterative-deepening-returns-the-alpha-beta-value-at-every-depth
(tests/test-optimized-pvs.lisp)."
  (declare (type bitboard-position bbp))
  (check-type max-depth (and search-depth (integer 1)))
  (check-type order-hook (or null function))
  (let ((context (or context (make-bitboard-search-context max-depth)))
        (iterations '())
        (total-nodes 0)
        (score 0)
        (best-move +no-move+)
        (line '())
        (statistics nil))
    (setf (search-context-shuffle-rng context) shuffle-rng
          (search-context-order-hook context) order-hook)
    (unwind-protect
         (loop for depth from 1 to max-depth
               for first-iteration = t then nil
               do (multiple-value-bind (iteration-score move nodes)
                      (run-search context bbp depth algorithm ordering tt node-types
                                  (not first-iteration) first-iteration)
                    (let* ((iteration-line (bitboard-search-context-pv context))
                           (iteration (list :depth depth :score iteration-score :best-move move
                                            :nodes nodes :pv iteration-line))
                           (length (aref (search-context-pv-lengths context) 0)))
                      ;; The variation of this iteration orders the next one.
                      (replace (search-context-previous-pv context) (search-context-pv context)
                               :end2 length)
                      (setf (search-context-previous-pv-length context) length
                            statistics (add-node-statistics statistics
                                                            (node-statistics context)))
                      (push iteration iterations)
                      (when on-iteration
                        (funcall on-iteration iteration))
                      (setf score iteration-score
                            best-move move
                            line iteration-line)
                      (incf total-nodes nodes)))
               until (bitboard-mate-score-p score))
      (setf (search-context-shuffle-rng context) nil
            (search-context-order-hook context) nil
            (search-context-previous-pv-length context) 0))
    (values score best-move total-nodes (nreverse iterations) line
            (append statistics (list :tt (and tt (bitboard-tt-statistics tt)))))))

(defparameter *bitboard-default-search*
  (list :driver :iterative-deepening :algorithm :pvs :ordering t
        :tt-entries +bitboard-tt-default-entries+ :tt-policy (first *bitboard-tt-policies*))
  "The default search of Phase 3 (docs/adr/0022-pvs-negascout-e-tipi-di-nodo.md): iterative
deepening of PVS with the move ordering of Phase 3 and a fresh transposition table of
+BITBOARD-TT-DEFAULT-ENTRIES+ slots with the default replacement policy. Which mode the table
has is the caller's choice: :NORMAL for play, :VERIFICATION for the tests and for the search
signature, which records this search (tests/search-signature.sexp).")

(defun bitboard-default-search (bbp depth &key (mode :normal) table context)
  "The default search of Phase 3 (*BITBOARD-DEFAULT-SEARCH*) of BBP to DEPTH: iterative
deepening to DEPTH with PVS, the ordering of Phase 3 and TABLE, or, without TABLE, a fresh
table of the default size and policy in MODE (:NORMAL or :VERIFICATION). CONTEXT as in
BITBOARD-ITERATIVE-DEEPENING. Returns the score, the best move, the node count of every
iteration together, the principal variation and the statistics of the run."
  (declare (type bitboard-position bbp))
  (destructuring-bind (&key driver algorithm ordering tt-entries tt-policy)
      *bitboard-default-search*
    (assert (eq driver :iterative-deepening))
    (let ((table (or table (make-bitboard-transposition-table :entries tt-entries
                                                              :policy tt-policy :mode mode))))
      (multiple-value-bind (score move nodes iterations line statistics)
          (bitboard-iterative-deepening bbp depth :algorithm algorithm :ordering ordering
                                                  :tt table :context context)
        (declare (ignore iterations))
        (values score move nodes line statistics)))))
