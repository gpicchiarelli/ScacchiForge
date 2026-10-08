;;;; package.lisp -- the benchmark harness.
;;;;
;;;; Every number it prints is a measurement of the machine that ran it at that moment. It
;;;; is neither a target nor a result of the project.

(defpackage #:scacchiforge.bench
  (:nicknames #:scf-bench)
  (:use #:common-lisp #:scacchiforge.core)
  (:export #:run-benchmarks #:measure #:median #:environment-record))
