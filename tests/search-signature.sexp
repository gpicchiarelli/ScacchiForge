;;;; search-signature.sexp -- the first search signature of the optimized engine (Phase 2).
;;;;
;;;; Written by tools/signatures.lisp ("make signatures"); do not edit by hand. The test
;;;; optimized-search/search-signature-is-reproduced recomputes every entry and compares
;;;; it. When to regenerate it: docs/verifica.md, "Regressione di ricerca".
;;;;
;;;; Each entry: the name and FEN of a position (tests/test-optimized-search.lisp, where
;;;; each position's origin is written), then the value from the side to move, the best
;;;; move, the node count (root and leaves included) and the principal variation of the
;;;; optimized layer's alpha-beta at the depth below, one thread, no transposition table,
;;;; no move ordering (the generator's order), the classical evaluation of
;;;; docs/valutazione.md. The moves are in long algebraic form.
;;;;
;;;; Provenance of this file:
;;;;   revision base: 024bdb9, working tree not clean (uncommitted changes on top of it)
;;;;   policy of the hot path: (optimize (speed 3) (safety 1) (debug 0))
;;;;   slider implementation: fixed-magic (SCF_SLIDERS not set)
;;;;   Lisp: SBCL 2.6.9
;;;;   system: Darwin 27.0.0, ARM64
;;;;   date: 2026-10-07T20:02:47Z

(:format 1
 :algorithm :alpha-beta
 :depth 4
 :entries
 (("startpos"
   "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
   :score 10 :best-move "b1c3" :nodes 61888
   :pv ("b1c3" "b8c6" "g1f3" "g8f6"))
  ("kiwipete"
   "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
   :score -80 :best-move "d5e6" :nodes 100829
   :pv ("d5e6" "a6e2" "c3e2" "h3g2"))
  ("pos3"
   "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
   :score 25 :best-move "b4c4" :nodes 2713
   :pv ("b4c4" "h4g4" "c4c7" "h5b5"))
  ("pos4"
   "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
   :score -456 :best-move "g1h1" :nodes 55375
   :pv ("g1h1" "b2a1q" "d1a1" "a3b4"))
  ("pos5"
   "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"
   :score 192 :best-move "d7c8q" :nodes 82178
   :pv ("d7c8q" "f2d1" "c8d8" "e7d8"))
  ("pos6"
   "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"
   :score -64 :best-move "c3d5" :nodes 132867
   :pv ("c3d5" "c5f2" "e2f2" "f6d5"))
  ("promo"
   "n1n5/PPPk4/8/8/8/8/4Kppp/5N1N b - - 0 1"
   :score 74 :best-move "g2h1q" :nodes 2126
   :pv ("g2h1q" "b7b8q" "h1e4" "e2f2"))
  ("quiet-queens-gambit"
   "r1bq1rk1/pppnbppp/4pn2/3p2B1/2PP4/2N1PN2/PP3PPP/R2QKB1R w KQ - 3 7"
   :score 3 :best-move "g5f6" :nodes 56393
   :pv ("g5f6" "d7f6" "c4d5" "e6d5"))
  ("quiet-italian"
   "r1bq1rk1/ppp2ppp/2np1n2/2b1p3/2B1P3/2PP1N2/PP3PPP/RNBQ1RK1 w - - 2 7"
   :score -21 :best-move "c1g5" :nodes 69633
   :pv ("c1g5" "c8g4" "g5f6" "d8f6"))
  ("tactical-knight-takes-f7"
   "r1bqkb1r/ppp2ppp/2n5/3np1N1/2B5/8/PPPP1PPP/RNBQK2R w KQkq - 0 6"
   :score -79 :best-move "h2h4" :nodes 275975
   :pv ("h2h4" "f8c5" "c4d5" "d8d5"))
  ("tactical-knight-takes-e5"
   "rn1qkbnr/ppp2p1p/3p2p1/4p3/2B1P1b1/2N2N2/PPPP1PPP/R1BQK2R w KQkq - 0 5"
   :score 14 :best-move "h2h3" :nodes 76559
   :pv ("h2h3" "g4d7" "c3d5" "d7h3"))
  ("tactical-mate-in-one"
   "r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4"
   :score 29999 :best-move "h5f7" :nodes 123660
   :pv ("h5f7"))))
