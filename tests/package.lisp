;;;; package.lisp -- the dependency-free test framework and the suites.

(defpackage #:scacchiforge.test
  (:nicknames #:scf-test)
  (:use #:common-lisp #:scacchiforge.core)
  (:export
   ;; framework
   #:deftest #:is #:is-true #:is-false #:is-eql #:is-equal #:is-equalp #:is-set-equal
   #:signals #:note #:run-tests #:run-all #:run-perft-deep #:run-differential-deep
   #:list-suites
   ;; configuration
   #:*perft-profile* #:*differential-profile* #:*layer*
   ;; expected values that the benchmarks and the tools read
   #:main-perft-count #:*allocation-perfts*
   ;; the search signature (tests/search-signature.sexp): read by the benchmarks, written by
   ;; tools/signatures.lisp
   #:read-search-signature #:write-search-signature-file #:search-signature-pathname
   #:*search-signature-positions*))
