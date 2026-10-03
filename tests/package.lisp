(defpackage :scacchiforge-tests
  (:use :cl :fiveam :scacchiforge.reference)
  (:export #:run-tests))

(in-package :scacchiforge-tests)

(def-suite scacchiforge-tests
  :description "ScacchiForge test suite")

(defun run-tests ()
  "Run all tests."
  (run! 'scacchiforge-tests))
