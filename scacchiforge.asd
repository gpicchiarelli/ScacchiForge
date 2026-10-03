(defsystem "scacchiforge"
  :description "High-performance chess engine research platform in Common Lisp"
  :version "0.0.1"
  :author "ScacchiForge Contributors"
  :license "BSD-2-Clause"
  :pathname "src/"
  :depends-on ("alexandria" "trivial-features")
  :components ((:module "reference"
                :pathname "reference/"
                :components ((:file "package")
                             (:file "types" :depends-on ("package"))
                             (:file "board" :depends-on ("types"))
                             (:file "movegen" :depends-on ("board"))
                             (:file "position" :depends-on ("movegen"))
                             (:file "eval" :depends-on ("position"))
                             (:file "search" :depends-on ("eval"))))
               (:module "optimized"
                :pathname "optimized/"
                :components ((:file "package")
                             (:file "bitboards" :depends-on ("package"))
                             (:file "board-opt" :depends-on ("bitboards"))))
               (:module "test-utils"
                :pathname "../tests/"
                :components ((:file "package")
                             (:file "perft" :depends-on ("package"))
                             (:file "fuzzer" :depends-on ("package"))
                             (:file "differential" :depends-on ("package")))))
  :in-order-to ((test-op (load-op "scacchiforge-test"))))

(defsystem "scacchiforge-test"
  :description "Test suite for ScacchiForge"
  :version "0.0.1"
  :depends-on ("scacchiforge" "fiveam")
  :pathname "tests/"
  :components ((:file "package")
               (:file "test-perft" :depends-on ("package"))
               (:file "test-movegen" :depends-on ("package"))
               (:file "test-position" :depends-on ("package")))
  :perform (test-op (op c)
             (uiop:symbol-call :fiveam :run! :scacchiforge-tests)))

(defsystem "scacchiforge-bench"
  :description "Benchmark infrastructure for ScacchiForge"
  :version "0.0.1"
  :depends-on ("scacchiforge")
  :pathname "benchmarks/"
  :components ((:file "package")
               (:file "microbench" :depends-on ("package"))
               (:file "engine-bench" :depends-on ("package"))))
