(defpackage :scacchiforge.optimized
  (:use :cl)
  (:nicknames :scf-opt)
  (:export
   ;; Bitboard types
   #:bitboard

   ;; Board representation
   #:make-position-optimized
   #:position-occupied-p

   ;; Move generation (optimized)
   #:generate-moves-fast

   ;; Utilities
   #:popcount #:lsb #:msb
   #:pext #:pdep))
