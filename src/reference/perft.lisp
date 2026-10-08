;;;; perft.lisp -- perft, divide, and the named positions the tools share.
;;;;
;;;; PERFT counts the leaf nodes of the legal-move tree to a fixed depth. It is the gate for
;;;; the move generator: its results are compared with published counts (see tests/). At
;;;; the last ply it counts the legal moves instead of making them (bulk counting), which
;;;; does not change the number.

(in-package #:scacchiforge.reference)

(declaim (optimize (safety 3)))

(defparameter *standard-positions*
  '(("startpos" . "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    ("kiwipete" . "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
    ("pos3" . "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
    ("pos4" . "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1")
    ("pos5" . "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8")
    ("pos6" . "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10")
    ("promo" . "n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1"))
  "Well-known positions as (name . FEN). The expected perft counts live in tests/.")

(defun standard-position-fen (name)
  "The FEN of the standard position called NAME, or an error if there is none."
  (or (cdr (assoc name *standard-positions* :test #'string=))
      (error 'position-error :reason (format nil "no standard position named ~S" name))))

(defun perft-node (pos depth buffer base)
  "Leaf count below POS at DEPTH plies, using BUFFER from index BASE.

Classification: [EXACT] (bulk counting)
Basis: at depth 1 every legal move leads to exactly one leaf, so the number of legal moves is
the leaf count; the moves are counted instead of made and unmade.
Evidence: perft against published counts (tests/test-perft.lisp)."
  (declare (type chess-position pos) (type (integer 0 64) depth) (type move-buffer buffer)
           (type fixnum base))
  (cond ((zerop depth) 1)
        (t (let ((end (generate-legal pos buffer base)))
             (declare (type fixnum end))
             (if (= depth 1)
                 (- end base)
                 (let ((total 0))
                   (declare (type fixnum total))
                   (loop for index from base below end
                         do (make-move pos (aref buffer index))
                            (incf total (perft-node pos (1- depth) buffer
                                                    (+ base +move-stride+)))
                            (unmake-move pos))
                   total))))))

(defun perft (pos depth)
  "The number of leaf nodes of the legal-move tree of POS to DEPTH plies. POS is left
exactly as it was."
  (declare (type chess-position pos))
  (check-type depth (integer 0 63))
  (perft-node pos depth (make-move-buffer (max 1 depth)) 0))

(defun perft-divide (pos depth)
  "Perft split by root move: two values, a list of (MOVE . COUNT) in generation order and
the total. DEPTH must be at least 1."
  (declare (type chess-position pos))
  (check-type depth (integer 1 63))
  (let* ((buffer (make-move-buffer depth))
         (end (generate-legal pos buffer 0))
         (entries '())
         (total 0))
    (loop for index from 0 below end
          do (let ((move (aref buffer index)))
               (make-move pos move)
               (let ((count (perft-node pos (1- depth) buffer +move-stride+)))
                 (push (cons move count) entries)
                 (incf total count))
               (unmake-move pos)))
    (values (nreverse entries) total)))

(defun print-divide (pos depth &optional (stream *standard-output*))
  "Print the divide of POS, one \"move: count\" line per root move, then the total."
  (multiple-value-bind (entries total) (perft-divide pos depth)
    (loop for (move . count) in entries
          do (format stream "~A: ~D~%" (move-to-string move) count))
    (format stream "~%Nodes searched: ~D~%" total)
    total))
