(in-package :scacchiforge.optimized)

(defstruct (position-optimized
            (:constructor %make-position-optimized))
  "Optimized position representation using bitboards.
   [EXACT] Equivalent to reference implementation.
   Must pass differential testing against reference."
  (white-pawns 0 :type bitboard)
  (white-knights 0 :type bitboard)
  (white-bishops 0 :type bitboard)
  (white-rooks 0 :type bitboard)
  (white-queens 0 :type bitboard)
  (white-king 0 :type bitboard)
  (black-pawns 0 :type bitboard)
  (black-knights 0 :type bitboard)
  (black-bishops 0 :type bitboard)
  (black-rooks 0 :type bitboard)
  (black-queens 0 :type bitboard)
  (black-king 0 :type bitboard)
  (white-occupancy 0 :type bitboard)
  (black-occupancy 0 :type bitboard)
  (occupancy 0 :type bitboard)
  (side-to-move :white :type (member :white :black))
  (castling-rights 0 :type (unsigned-byte 4))
  (en-passant 0 :type (unsigned-byte 8))
  (halfmove-clock 0 :type (unsigned-byte 8))
  (fullmove 1 :type (unsigned-byte 16))
  (zobrist 0 :type (unsigned-byte 64)))

(defun make-position-optimized ()
  "Create optimized position at standard starting position."
  (let ((pos (%make-position-optimized)))
    (init-standard-position-optimized pos)
    pos))

(defun init-standard-position-optimized (pos)
  "Initialize optimized position to standard chess starting position."
  ;; White pieces
  (setf (position-optimized-white-pawns pos) #xFF00)
  (setf (position-optimized-white-knights pos) #x42)
  (setf (position-optimized-white-bishops pos) #x24)
  (setf (position-optimized-white-rooks pos) #x81)
  (setf (position-optimized-white-queens pos) #x8)
  (setf (position-optimized-white-king pos) #x10)
  ;; Black pieces
  (setf (position-optimized-black-pawns pos) #xFF000000000000)
  (setf (position-optimized-black-knights pos) #x4200000000000000)
  (setf (position-optimized-black-bishops pos) #x2400000000000000)
  (setf (position-optimized-black-rooks pos) #x8100000000000000)
  (setf (position-optimized-black-queens pos) #x800000000000000)
  (setf (position-optimized-black-king pos) #x1000000000000000)
  ;; Occupancy
  (update-occupancy pos)
  ;; State
  (setf (position-optimized-side-to-move pos) :white)
  (setf (position-optimized-castling-rights pos) #xF)
  (setf (position-optimized-en-passant pos) 0)
  (setf (position-optimized-halfmove-clock pos) 0)
  (setf (position-optimized-fullmove pos) 1)
  pos)

(defun update-occupancy (pos)
  "Update occupancy bitboards."
  (setf (position-optimized-white-occupancy pos)
        (logior (position-optimized-white-pawns pos)
                (position-optimized-white-knights pos)
                (position-optimized-white-bishops pos)
                (position-optimized-white-rooks pos)
                (position-optimized-white-queens pos)
                (position-optimized-white-king pos)))
  (setf (position-optimized-black-occupancy pos)
        (logior (position-optimized-black-pawns pos)
                (position-optimized-black-knights pos)
                (position-optimized-black-bishops pos)
                (position-optimized-black-rooks pos)
                (position-optimized-black-queens pos)
                (position-optimized-black-king pos)))
  (setf (position-optimized-occupancy pos)
        (logior (position-optimized-white-occupancy pos)
                (position-optimized-black-occupancy pos)))
  pos)

(defun position-occupied-p (pos sq)
  "Check if square sq is occupied."
  (logtest (position-optimized-occupancy pos) (ash 1 sq)))

(defun generate-moves-fast (pos)
  "Generate moves using optimized bitboard representation.
   [TODO] Implement efficient move generation."
  nil)
