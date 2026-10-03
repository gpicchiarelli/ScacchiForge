(defpackage :scacchiforge.reference
  (:use :cl)
  (:nicknames :scf-ref)
  (:export
   ;; Types
   #:piece #:color #:square #:direction
   #:position #:move #:move-flags

   ;; Constants
   #:+white+ #:+black+ #:+empty+
   #:+pawn+ #:+knight+ #:+bishop+ #:+rook+ #:+queen+ #:+king+
   #:+all-pieces+

   ;; Board operations
   #:make-position #:copy-position
   #:position-piece #:position-occupied-p
   #:position-color #:position-bitboard
   #:position-side-to-move #:position-castling-rights
   #:position-en-passant #:position-halfmove-clock #:position-zobrist

   ;; Move operations
   #:make-move #:move-from #:move-to #:move-piece #:move-flags
   #:move-is-capture #:move-is-promotion #:move-is-castling

   ;; Move generation
   #:generate-pseudo-legal-moves #:filter-legal-moves
   #:position-in-check-p

   ;; Board manipulation
   #:make-move-on-position #:unmake-move-on-position

   ;; Evaluation
   #:evaluate

   ;; Utilities
   #:square->notation #:notation->square
   #:piece->char #:color->char))
