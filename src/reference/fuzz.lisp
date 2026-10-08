;;;; fuzz.lisp -- a legal-position fuzzer: seeded random playouts with invariants.
;;;;
;;;; Every random choice comes from the generator the caller passes in, so a seed fully
;;;; determines a run. A playout starts from a position, plays random legal moves, checks
;;;; the invariants after each one, then takes every move back and requires the starting
;;;; position to be restored exactly.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun random-playout (start rng max-plies &key (check t) (deep nil))
  "Play up to MAX-PLIES random legal moves from a copy of START, drawing from RNG.
With CHECK, verify the invariants of every position reached (also the move-level ones
with DEEP) and verify that unmaking all the moves restores START. START is not changed.
Returns four values: the final position (a copy), the plies played, the outcome (NIL,
:CHECKMATE or :STALEMATE) and the list of moves played."
  (declare (type chess-position start))
  (let ((pos (clone-position start))
        (played '()))
    (when check
      (check-position-invariants pos :moves deep))
    (loop repeat max-plies
          do (let ((legal (legal-moves pos)))
               (when (null legal)
                 (return))
               (let ((move (rng-pick rng legal)))
                 (make-move pos move)
                 (push move played)
                 (when check
                   (check-position-invariants pos :moves deep)))))
    (let ((final (clone-position pos))
          (outcome (game-outcome pos)))
      (when check
        (loop repeat (length played)
              do (unmake-move pos))
        (unless (and (positions-equal-p pos start) (zerop (pos-ply pos)))
          (error 'invariant-violation
                 :fen (position-to-fen start)
                 :problems (list "unmaking a whole playout did not restore the start"))))
      (values final (length played) outcome (nreverse played)))))

(defun random-legal-position (fens rng max-plies)
  "A new position reached from a randomly chosen FEN of FENS by a random number (0 to
MAX-PLIES) of random legal moves."
  (let ((start (parse-fen (rng-pick rng fens)))
        (plies (rng-below rng (1+ max-plies))))
    (values (random-playout start rng plies :check nil))))

(defun fuzz-playouts (fens seed &key (games 10) (max-plies 100) (deep nil))
  "Run GAMES random playouts per FEN in FENS with generator seed SEED, checking invariants.
Returns a property list with :GAMES, :POSITIONS, :CHECKMATES and :STALEMATES. Signals
INVARIANT-VIOLATION on the first problem."
  (let ((rng (make-rng seed))
        (games-played 0) (positions 0) (checkmates 0) (stalemates 0))
    (dolist (fen fens)
      (let ((start (parse-fen fen)))
        (dotimes (game games)
          (multiple-value-bind (final plies outcome)
              (random-playout start rng max-plies :deep deep)
            (declare (ignore final))
            (incf games-played)
            (incf positions (1+ plies))
            (case outcome
              (:checkmate (incf checkmates))
              (:stalemate (incf stalemates)))))))
    (list :games games-played :positions positions
          :checkmates checkmates :stalemates stalemates)))
