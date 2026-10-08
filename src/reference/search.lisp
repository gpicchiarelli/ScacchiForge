;;;; search.lisp -- reference search baselines (oracle): negamax, alpha-beta, iterative
;;;; deepening.
;;;;
;;;; Deliberately small and simple: nothing here is optimized. They exist so that later search
;;;; techniques have a baseline to be compared against, and so that alpha-beta can be checked
;;;; against negamax. They are the reference's oracle for search results ("REFERENCE ENGINE",
;;;; "SEARCH FOUNDATION"). The searches themselves are not Phase 2 work (ADR-0012); the
;;;; classical evaluation they call by default is (docs/valutazione.md, ADR-0018 in state
;;;; Proposta).
;;;;
;;;; Conventions (docs/valutazione.md, "Convenzioni per la ricerca")
;;;;  - Scores are centipawns from the point of view of the side to move.
;;;;  - Depth counts plies. A node at depth 0 returns the static evaluation, without looking
;;;;    for checkmate or stalemate; there is no quiescence search, so a mate is seen only where
;;;;    the mated side's moves are generated (mate in one needs depth 2).
;;;;  - The static evaluation is EVALUATE-CLASSICAL (classical.lisp) unless the caller passes
;;;;    another one, for example EVALUATE-MATERIAL, with :EVALUATOR.
;;;;  - Mate scores are relative to the ply: the side to move at ply P that is checkmated
;;;;    scores P - +MATE-SCORE+, so the root sees +MATE-SCORE+ - N for "mate in N plies".
;;;;    Stalemate scores 0. Repetition, the fifty-move rule and insufficient material are not
;;;;    detected.
;;;;  - Node counts include the root and the leaves.
;;;;  - The principal variation is a fresh list of moves from the root: at each node, the first
;;;;    move in search order that reaches the node's best score, then that move's own line. It
;;;;    ends at depth 0 or at a node without legal moves.
;;;;  - No move ordering, no transposition table, no pruning other than alpha-beta. The moves of
;;;;    a node are searched in generation order, or, for the tests, in an order permuted by a
;;;;    seeded generator passed with :SHUFFLE-RNG.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defconstant +mate-score+ 30000 "Score of a checkmate delivered at the root's ply 0.")
(defconstant +infinity+ 32000 "Larger than any score; the initial alpha-beta bound.")
(defconstant +mate-bound+ 29000 "Scores with at least this magnitude are mate scores.")

(defstruct (search-state (:conc-name state-))
  "What one search carries through its nodes: the node counter, the static evaluation called
at depth 0, and an optional generator that permutes the moves of every node."
  (nodes 0 :type fixnum)
  (evaluator #'evaluate-classical :type function)
  (shuffle-rng nil :type (or null rng)))

(defstruct (search-iteration (:conc-name iteration-))
  "The outcome of one depth of ITERATIVE-DEEPENING."
  (depth 0 :type fixnum)
  (score 0 :type fixnum)
  (best-move +no-move+ :type fixnum)
  (nodes 0 :type fixnum)
  (pv '() :type list))

(defun mate-score-p (score)
  "True when SCORE says that one side is being checkmated."
  (>= (abs score) +mate-bound+))

(defun terminal-score (pos ply)
  "Score of POS, which has no legal move, at distance PLY from the root."
  (if (in-check-p pos)
      (- ply +mate-score+)
      0))

(defun static-score (pos state)
  "The static evaluation of POS that STATE asks for, from the side to move."
  (funcall (state-evaluator state) pos))

(defun shuffle-moves (buffer start end rng)
  "Permute the moves of BUFFER from START below END in place, uniformly, with the
Fisher-Yates shuffle drawing from RNG."
  (declare (type move-buffer buffer) (type fixnum start end) (type rng rng))
  (loop for last from (1- end) above start
        do (let ((other (+ start (rng-below rng (1+ (- last start))))))
             (rotatef (aref buffer last) (aref buffer other)))))

(defun node-moves (pos buffer base state)
  "Store the legal moves of POS in BUFFER from BASE, permuted when STATE has a shuffle
generator; return the end index."
  (declare (type chess-position pos) (type move-buffer buffer) (type fixnum base)
           (type search-state state))
  (let ((end (generate-legal pos buffer base))
        (rng (state-shuffle-rng state)))
    (when rng
      (shuffle-moves buffer base end rng))
    end))

(defun negamax-node (pos depth ply alpha beta buffer state)
  "Plain negamax value of POS to DEPTH plies, and its principal variation, as two values.
ALPHA and BETA are ignored. It removes no work, so it carries no classification: it is the
baseline the other searches are compared with."
  (declare (type chess-position pos) (type fixnum depth ply alpha beta)
           (type move-buffer buffer) (type search-state state) (ignore alpha beta))
  (incf (state-nodes state))
  (if (zerop depth)
      (values (static-score pos state) '())
      (let* ((base (* ply +move-stride+))
             (end (node-moves pos buffer base state))
             (best (- +infinity+))
             (best-line '()))
        (declare (type fixnum base end best))
        (if (= end base)
            (values (terminal-score pos ply) '())
            (progn
              (loop for index from base below end
                    do (let ((move (aref buffer index)))
                         (make-move pos move)
                         (multiple-value-bind (child-score child-line)
                             (negamax-node pos (1- depth) (1+ ply) 0 0 buffer state)
                           (let ((score (- child-score)))
                             (when (> score best)
                               (setf best score
                                     best-line (cons move child-line)))))
                         (unmake-move pos)))
              (values best best-line))))))

(defun alpha-beta-node (pos depth ply alpha beta buffer state)
  "Fail-soft alpha-beta value of POS to DEPTH plies with the window (ALPHA, BETA), and the
line of the best move found, as two values.

Classification: [BOUNDED]
Basis: a result strictly inside (ALPHA, BETA) is the negamax value; a result at or below
ALPHA is an upper bound on it, and one at or above BETA a lower bound (Knuth and Moore,
1975). With the full window the result is the negamax value. SEARCH-ROOT searches every root
move with the window (best so far, +infinity), so the root score and best move it returns
are those of negamax. The line is exact where the result is: at a node whose value lies
strictly inside its window, the first move reaching that value was searched with a window that
holds it, and a later move of equal value fails low and does not replace it, so the line is
the one negamax returns for the same move order. At a node that fails low or high the line is
not meaningful, and no exact line passes through such a node.
Evidence: tests alpha-beta-equals-negamax-up-to-depth-three,
alpha-beta-value-does-not-depend-on-the-move-order and alpha-beta-prunes
(tests/test-search.lisp)."
  (declare (type chess-position pos) (type fixnum depth ply alpha beta)
           (type move-buffer buffer) (type search-state state))
  (incf (state-nodes state))
  (if (zerop depth)
      (values (static-score pos state) '())
      (let* ((base (* ply +move-stride+))
             (end (node-moves pos buffer base state))
             (best (- +infinity+))
             (best-line '()))
        (declare (type fixnum base end best))
        (if (= end base)
            (values (terminal-score pos ply) '())
            (progn
              (loop for index from base below end
                    do (let ((move (aref buffer index)))
                         (make-move pos move)
                         (multiple-value-bind (child-score child-line)
                             (alpha-beta-node pos (1- depth) (1+ ply) (- beta) (- alpha)
                                              buffer state)
                           (let ((score (- child-score)))
                             (when (> score best)
                               (setf best score
                                     best-line (cons move child-line)))
                             (when (> score alpha)
                               (setf alpha score))))
                         (unmake-move pos))
                    until (>= alpha beta))
              (values best best-line))))))

(defun search-root (pos depth node-function evaluator shuffle-rng)
  "Search the root moves of POS with NODE-FUNCTION, evaluating the leaves with EVALUATOR (a
function designator); return score, best move, node count and principal variation. The best
move is the first root move, in search order, that reaches the best score."
  (declare (type chess-position pos) (type function node-function))
  (check-type depth (integer 0 62))
  (let* ((state (make-search-state :evaluator (coerce evaluator 'function)
                                   :shuffle-rng shuffle-rng))
         (buffer (make-move-buffer (1+ depth)))
         (end (node-moves pos buffer 0 state))
         (best (- +infinity+))
         (best-move +no-move+)
         (best-line '())
         (alpha (- +infinity+)))
    (declare (type fixnum end best best-move alpha))
    (incf (state-nodes state))
    (cond ((zerop depth)
           (setf best (static-score pos state)))
          ((zerop end)
           (setf best (terminal-score pos 0)))
          (t (loop for index from 0 below end
                   do (let ((move (aref buffer index)))
                        (make-move pos move)
                        (multiple-value-bind (child-score child-line)
                            (funcall node-function pos (1- depth) 1
                                     (- +infinity+) (- alpha) buffer state)
                          (let ((score (- child-score)))
                            (when (> score best)
                              (setf best score
                                    best-move move
                                    best-line (cons move child-line)))
                            (when (> score alpha)
                              (setf alpha score))))
                        (unmake-move pos)))))
    (values best best-move (state-nodes state) best-line)))

(defun negamax-search (pos depth &key (evaluator #'evaluate-classical) shuffle-rng)
  "Negamax from POS to DEPTH plies: values score, best move (0 when none), node count and
principal variation (a list of moves). EVALUATOR is the static evaluation of the leaves.
SHUFFLE-RNG, a core RNG, permutes the moves of every node before they are searched: the value
must not change (a test hook)."
  (search-root pos depth #'negamax-node evaluator shuffle-rng))

(defun alpha-beta-search (pos depth &key (evaluator #'evaluate-classical) shuffle-rng)
  "Alpha-beta from POS to DEPTH plies: values score, best move (0 when none), node count and
principal variation (a list of moves). EVALUATOR and SHUFFLE-RNG are as in NEGAMAX-SEARCH."
  (search-root pos depth #'alpha-beta-node evaluator shuffle-rng))

(defun iterative-deepening (pos max-depth &key (algorithm :alpha-beta) on-iteration
                                               (evaluator #'evaluate-classical) shuffle-rng)
  "Search POS at depth 1, 2, ... MAX-DEPTH with ALGORITHM (:ALPHA-BETA or :NEGAMAX), each
iteration a complete search from scratch with EVALUATOR and SHUFFLE-RNG as in NEGAMAX-SEARCH.
Stops early once the score is a mate score. Calls ON-ITERATION, if given, with each
SEARCH-ITERATION. Returns the last score, best move, the total node count, the list of
iterations and the last principal variation.

Classification: [EXACT] (the early stop on a mate score)
Basis: this search is full width, with no transposition table, no pruning other than
alpha-beta and a leaf evaluation that does not depend on the depth. A mate score at depth D
gives the length of the fastest mate one side can force against any defence, and that mate
lies within D plies. A deeper search sees the same forced mate; a faster one would also lie
within D plies and would have been found at depth D. So every deeper search returns the same
score and, trying the moves in the same order, the same first best move. Stopping skips the
deeper iterations without changing the result.
Evidence: tests iterative-deepening-stops-once-a-mate-is-found and
iterative-deepening-mate-stop-equals-the-full-depth-search (tests/test-search.lisp)."
  (check-type max-depth (integer 1 62))
  (let ((search (ecase algorithm
                  (:alpha-beta #'alpha-beta-search)
                  (:negamax #'negamax-search)))
        (iterations '())
        (total-nodes 0)
        (score 0)
        (best-move +no-move+)
        (line '()))
    (loop for depth from 1 to max-depth
          do (multiple-value-bind (iteration-score move nodes iteration-line)
                 (funcall search pos depth :evaluator evaluator :shuffle-rng shuffle-rng)
               (let ((iteration (make-search-iteration :depth depth :score iteration-score
                                                       :best-move move :nodes nodes
                                                       :pv iteration-line)))
                 (push iteration iterations)
                 (when on-iteration
                   (funcall on-iteration iteration)))
               (setf score iteration-score
                     best-move move
                     line iteration-line)
               (incf total-nodes nodes))
          until (mate-score-p score))
    (values score best-move total-nodes (nreverse iterations) line)))
