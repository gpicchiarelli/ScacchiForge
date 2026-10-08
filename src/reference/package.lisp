;;;; package.lisp -- the reference model: deliberately simple and readable. It is the oracle
;;;; the optimized layer is compared with.

(defpackage #:scacchiforge.reference
  (:nicknames #:scf-ref)
  (:use #:common-lisp #:scacchiforge.core)
  (:export
   ;; position
   #:chess-position #:chess-position-p #:clone-position #:positions-equal-p
   #:pos-board #:pos-side #:pos-castling #:pos-en-passant #:pos-halfmove #:pos-fullmove
   #:pos-key #:pos-ply #:piece-at #:king-square #:board-vector
   #:make-position-from-parts #:position-error #:position-error-reason #:+max-clock+
   ;; FEN
   #:*start-fen* #:*max-fen-length* #:parse-fen #:position-to-fen #:start-position
   #:fen-error #:fen-error-fen
   ;; attacks and check
   #:square-attacked-p #:king-attacked-p #:in-check-p #:en-passant-capture-available-p
   ;; Zobrist
   #:compute-key
   ;; make and unmake
   #:make-move #:unmake-move
   ;; move generation
   #:move-buffer #:make-move-buffer #:+move-stride+ #:generate-pseudo-legal
   #:generate-legal #:pseudo-legal-moves #:legal-moves #:legal-move-count
   #:parse-move #:move-legal-p
   ;; perft
   #:perft #:perft-divide #:print-divide #:*standard-positions* #:standard-position-fen
   ;; terminal detection
   #:game-outcome #:checkmate-p #:stalemate-p
   ;; colour swap
   #:mirror-position #:mirror-move
   ;; evaluation: the material baseline and the classical evaluation (docs/valutazione.md)
   #:evaluate-material #:material-value
   #:evaluate-classical #:classical-breakdown
   ;; search baselines
   #:+mate-score+ #:+infinity+ #:+mate-bound+ #:mate-score-p
   #:negamax-search #:alpha-beta-search #:iterative-deepening
   #:search-iteration #:iteration-depth #:iteration-score #:iteration-best-move
   #:iteration-nodes #:iteration-pv
   ;; invariants and fuzzing
   #:invariant-violation #:invariant-violation-fen #:invariant-violation-problems
   #:position-invariant-violations #:check-position-invariants
   #:king-attacked-by-generation-p
   #:random-playout #:random-legal-position #:fuzz-playouts))
