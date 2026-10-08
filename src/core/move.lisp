;;;; move.lisp -- packed move encoding.
;;;;
;;;; A move is a non-negative fixnum, so no Lisp object is allocated per move:
;;;;   bits  0..5   from square
;;;;   bits  6..11  to square
;;;;   bits 12..14  promotion piece type (0 = none, 2..5 = N B R Q)
;;;;   bits 15..19  flags (see the +FLAG-...+ constants)
;;;; The value 0 (a1 to a1) is never a legal move and is used as "no move".

(in-package #:scacchiforge.core)

(deftype move () '(unsigned-byte 20))

(defconstant +no-move+ 0)

(defconstant +flag-capture+ 1)
(defconstant +flag-en-passant+ 2)
(defconstant +flag-double-push+ 4)
(defconstant +flag-castle-king+ 8)
(defconstant +flag-castle-queen+ 16)

(declaim (inline encode-move move-from move-to move-promotion move-flags
                 move-capture-p move-en-passant-p move-double-push-p move-castle-p
                 move-promotion-p))

(defun encode-move (from to promotion flags)
  "Pack FROM, TO, PROMOTION (0 or a piece type 2..5) and FLAGS into a move."
  (declare (type square from to) (type (integer 0 7) promotion) (type (integer 0 31) flags))
  (logior from (ash to 6) (ash promotion 12) (ash flags 15)))

(defun move-from (move)
  "From square of MOVE."
  (declare (type move move))
  (logand move 63))

(defun move-to (move)
  "To square of MOVE."
  (declare (type move move))
  (logand (ash move -6) 63))

(defun move-promotion (move)
  "Promotion piece type of MOVE, or 0 when it is not a promotion."
  (declare (type move move))
  (logand (ash move -12) 7))

(defun move-flags (move)
  "Flag bits of MOVE."
  (declare (type move move))
  (ash move -15))

(defun move-capture-p (move)
  "True when MOVE captures (including en passant)."
  (declare (type move move))
  (logtest (move-flags move) +flag-capture+))

(defun move-en-passant-p (move)
  "True when MOVE is an en-passant capture."
  (declare (type move move))
  (logtest (move-flags move) +flag-en-passant+))

(defun move-double-push-p (move)
  "True when MOVE is a two-square pawn push."
  (declare (type move move))
  (logtest (move-flags move) +flag-double-push+))

(defun move-castle-p (move)
  "True when MOVE is a castling move."
  (declare (type move move))
  (logtest (move-flags move) (logior +flag-castle-king+ +flag-castle-queen+)))

(defun move-promotion-p (move)
  "True when MOVE promotes a pawn."
  (declare (type move move))
  (/= 0 (move-promotion move)))

(defun move-to-string (move)
  "Long algebraic text of MOVE as used by UCI, for example \"e2e4\" or \"e7e8q\"."
  (declare (type move move))
  (let ((promotion (move-promotion move)))
    (format nil "~A~A~A"
            (square-name (move-from move))
            (square-name (move-to move))
            (if (zerop promotion) "" (char "pnbrqk" (1- promotion))))))
