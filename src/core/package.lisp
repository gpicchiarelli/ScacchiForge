;;;; package.lisp -- the shared core: definitions used by BOTH the reference and the
;;;; optimized layer, kept in one place so they are never duplicated.

(defpackage #:scacchiforge.core
  (:nicknames #:scf-core)
  (:use #:common-lisp)
  (:export
   ;; types
   #:square #:colour #:piece #:move #:u64
   ;; colours and pieces
   #:+white+ #:+black+ #:opposite-colour
   #:+empty+ #:+pawn+ #:+knight+ #:+bishop+ #:+rook+ #:+queen+ #:+king+
   #:+white-pawn+ #:+white-knight+ #:+white-bishop+ #:+white-rook+ #:+white-queen+
   #:+white-king+ #:+black-pawn+ #:+black-knight+ #:+black-bishop+ #:+black-rook+
   #:+black-queen+ #:+black-king+
   #:make-piece #:piece-colour #:piece-type #:piece-index #:piece-char #:char-piece
   ;; castling rights
   #:+castle-white-king+ #:+castle-white-queen+ #:+castle-black-king+
   #:+castle-black-queen+ #:+castle-all+
   ;; squares
   #:+no-square+ #:make-square #:square-file #:square-rank #:square-name #:parse-square
   #:+a1+ #:+b1+ #:+c1+ #:+d1+ #:+e1+ #:+f1+ #:+g1+ #:+h1+
   #:+a2+ #:+b2+ #:+c2+ #:+d2+ #:+e2+ #:+f2+ #:+g2+ #:+h2+
   #:+a3+ #:+b3+ #:+c3+ #:+d3+ #:+e3+ #:+f3+ #:+g3+ #:+h3+
   #:+a4+ #:+b4+ #:+c4+ #:+d4+ #:+e4+ #:+f4+ #:+g4+ #:+h4+
   #:+a5+ #:+b5+ #:+c5+ #:+d5+ #:+e5+ #:+f5+ #:+g5+ #:+h5+
   #:+a6+ #:+b6+ #:+c6+ #:+d6+ #:+e6+ #:+f6+ #:+g6+ #:+h6+
   #:+a7+ #:+b7+ #:+c7+ #:+d7+ #:+e7+ #:+f7+ #:+g7+ #:+h7+
   #:+a8+ #:+b8+ #:+c8+ #:+d8+ #:+e8+ #:+f8+ #:+g8+ #:+h8+
   ;; packed moves
   #:+no-move+ #:+flag-capture+ #:+flag-en-passant+ #:+flag-double-push+
   #:+flag-castle-king+ #:+flag-castle-queen+
   #:encode-move #:move-from #:move-to #:move-promotion #:move-flags
   #:move-capture-p #:move-en-passant-p #:move-double-push-p #:move-castle-p
   #:move-promotion-p #:move-to-string
   ;; deterministic PRNG
   #:rng #:make-rng #:copy-rng #:rng-state #:rng-next-u64 #:rng-below #:rng-pick
   ;; Zobrist
   #:zobrist-piece-key #:zobrist-side-key #:zobrist-castling-key #:zobrist-en-passant-key
   #:+zobrist-seed+ #:zobrist-key-table-snapshot #:regenerate-zobrist-keys))
