;;;; outcome.lisp -- terminal detection: checkmate and stalemate.
;;;;
;;;; Only these two are implemented. Draws by repetition, by the fifty-move rule and by
;;;; insufficient material are NOT detected: the halfmove clock is kept but no rule uses it.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defun game-outcome (pos)
  "NIL when the side to move has a legal move, else :CHECKMATE or :STALEMATE."
  (cond ((plusp (legal-move-count pos)) nil)
        ((in-check-p pos) :checkmate)
        (t :stalemate)))

(defun checkmate-p (pos)
  "True when the side to move is checkmated."
  (eq (game-outcome pos) :checkmate))

(defun stalemate-p (pos)
  "True when the side to move is stalemated."
  (eq (game-outcome pos) :stalemate))
