;;;; package.lisp -- the optimized layer: bit utilities, a bitboard position that converts to
;;;; and from the reference position, precomputed attack tables, slider attacks behind one
;;;; small interface (classical rays, or magic bitboards whose numbers this layer searches from
;;;; a seed), make/unmake with a preallocated undo stack and an incremental key, pseudo-legal
;;;; generation, a legality filter, perft, the classical evaluation with its incremental state,
;;;; the colour swap of a position, and the search baselines (negamax, alpha-beta, iterative
;;;; deepening). Every result it computes is compared with the reference model by the tests.
;;;; There is no PEXT, no SIMD and no CPU detection yet; they belong to later phases and must be
;;;; checked the same way.
;;;;
;;;; Names that the reference also exports (MAKE-MOVE, PERFT, ...) carry a BITBOARD- prefix
;;;; here: the two layers never export the same name (test the-layers-do-not-export-the-same-
;;;; names in tests/test-bitboard.lisp).

(defpackage #:scacchiforge.optimized
  (:nicknames #:scf-opt)
  (:use #:common-lisp #:scacchiforge.core)
  (:export
   ;; build policy and slider implementation
   #:*optimized-policy* #:declaim-optimized-policy #:*hot-path-files* #:check-compiled-choice
   #:*inline-node-functions*
   #:*slider-implementations* #:*slider-implementation* #:parse-slider-implementation
   #:*evaluation-states* #:*evaluation-state* #:parse-evaluation-state
   #:evaluation-state-implementation
   ;; bit utilities
   #:popcount64 #:popcount64-swar #:lsb64 #:lsb64-debruijn #:msb64 #:clear-lowest-bit
   #:pext64 #:pdep64 #:do-set-bits #:bit-indices #:+debruijn64+
   ;; bitboard position
   #:bitboard-position #:bitboard-position-p
   #:bbp-pieces #:bbp-colour-occupancy #:bbp-occupancy #:bbp-side #:bbp-castling
   #:bbp-en-passant #:bbp-halfmove #:bbp-fullmove #:bbp-key #:bbp-board #:bbp-ply
   #:bitboard-from-reference #:bitboard-to-reference #:bitboard-compute-key
   #:bitboard-consistent-p #:bitboard-equal-p #:bitboard-clone #:+clock-limit+
   ;; attack tables and the slider interface
   #:knight-attacks #:king-attacks #:pawn-attacks #:bishop-attacks #:rook-attacks
   #:queen-attacks #:between-squares #:line-through #:slider-interface-implementation
   ;; the slider implementations and the magic numbers
   #:ray-bishop-attacks #:ray-rook-attacks #:magic-bishop-attacks #:magic-rook-attacks
   #:fixed-magic-bishop-attacks #:fixed-magic-rook-attacks #:relevant-occupancy-mask
   #:+magic-seed+ #:+magic-table-size+ #:+fixed-magic-table-size+ #:search-magic-numbers
   #:*committed-magic-numbers* #:initialise-magic-tables
   #:bitboard-square-attacked-p #:bitboard-in-check-p #:bitboard-checkers
   ;; make and unmake
   #:bitboard-make-move #:bitboard-unmake-move
   ;; move generation
   #:bitboard-move-buffer #:make-bitboard-move-buffer #:+bitboard-ply-moves+
   #:bitboard-generate-pseudo-legal #:bitboard-generate-legal
   #:bitboard-pseudo-legal-moves #:bitboard-legal-moves
   ;; perft
   #:bitboard-perft #:bitboard-perft-with-buffer #:bitboard-perft-divide
   ;; classical evaluation (docs/valutazione.md) and its incremental state
   #:bbp-psq-mg #:bbp-psq-eg #:bbp-phase-raw #:bitboard-compute-evaluation-state
   #:bitboard-evaluate #:bitboard-evaluate-from-scratch #:bitboard-classical-breakdown
   ;; colour swap
   #:bitboard-mirror
   ;; search baselines
   #:bitboard-search-context #:make-bitboard-search-context #:bitboard-search-with-context
   #:bitboard-search-context-pv #:bitboard-search #:bitboard-negamax-search
   #:bitboard-alpha-beta-search #:bitboard-iterative-deepening #:bitboard-mate-score-p
   #:+bitboard-mate-score+ #:+bitboard-mate-bound+ #:+bitboard-max-search-depth+))
