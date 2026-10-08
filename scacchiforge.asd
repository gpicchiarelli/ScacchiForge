;;;; scacchiforge.asd -- ASDF system definitions.
;;;;
;;;; SBCL is the only requirement: no system listed here depends on a library outside
;;;; SBCL and ASDF. Secondary systems use the "scacchiforge/" prefix so ASDF finds them
;;;; inside this file without warnings.

(in-package #:asdf-user)

(defsystem "scacchiforge"
  :description "Chess engine research platform in Common Lisp (SBCL): shared core, reference model, optimized bitboard layer."
  :author "Giacomo Picchiarelli"
  :license "BSD-2-Clause"
  :version "0.0.0"
  :pathname "src/"
  :serial t
  :components ((:module "core"
                :serial t
                :components ((:file "package")
                             (:file "constants")
                             (:file "move")
                             (:file "prng")
                             (:file "zobrist")))
               (:module "reference"
                :serial t
                :components ((:file "package")
                             (:file "tables")
                             (:file "position")
                             (:file "attacks")
                             (:file "key")
                             (:file "fen")
                             (:file "make")
                             (:file "movegen")
                             (:file "legal")
                             (:file "perft")
                             (:file "outcome")
                             (:file "mirror")
                             (:file "eval")
                             (:file "classical")
                             (:file "search")
                             (:file "invariants")
                             (:file "fuzz")))
               (:module "optimized"
                :serial t
                :components ((:file "package")
                             (:file "policy")
                             (:file "bits")
                             (:file "evaluation-tables")
                             (:file "bitboard-position")
                             (:file "tables")
                             (:file "rays")
                             (:file "magic-numbers")
                             (:file "magic")
                             (:file "sliders")
                             (:file "attacks")
                             (:file "make")
                             (:file "movegen")
                             (:file "legal")
                             (:file "perft")
                             (:file "evaluation")
                             (:file "search")
                             (:file "mirror"))))
  :in-order-to ((test-op (test-op "scacchiforge/test"))))

(defsystem "scacchiforge/test"
  :description "Dependency-free test framework and test suites for ScacchiForge."
  :author "Giacomo Picchiarelli"
  :license "BSD-2-Clause"
  :version "0.0.0"
  :depends-on ("scacchiforge")
  :pathname "tests/"
  :serial t
  :components ((:file "package")
               (:file "framework")
               (:file "support")
               (:file "test-core")
               (:file "test-fen")
               (:file "test-movegen")
               (:file "test-perft")
               (:file "test-make-unmake")
               (:file "test-zobrist")
               (:file "test-bits")
               (:file "test-bitboard")
               (:file "test-optimized")
               (:file "test-optimized-perft")
               (:file "test-differential")
               (:file "test-mirror")
               (:file "test-evaluation")
               (:file "test-search")
               (:file "test-optimized-evaluation")
               (:file "test-optimized-search")
               (:file "test-fuzz")
               (:file "runner"))
  :perform (test-op (o c)
             (unless (uiop:symbol-call '#:scacchiforge.test '#:run-all)
               (error "scacchiforge/test: at least one test failed"))))

(defsystem "scacchiforge/bench"
  :description "Benchmark harness for ScacchiForge: measurements of one machine, not results."
  :author "Giacomo Picchiarelli"
  :license "BSD-2-Clause"
  :version "0.0.0"
  ;; scacchiforge/test holds the expected perft counts, with their provenance
  ;; (tests/test-perft.lisp); the benchmarks read them there instead of copying them.
  :depends-on ("scacchiforge" "scacchiforge/test")
  :pathname "benchmarks/"
  :serial t
  :components ((:file "package")
               (:file "harness")
               (:file "micro")
               (:file "perft-bench")
               (:file "search-bench")
               (:file "system-info")
               (:file "report")))
