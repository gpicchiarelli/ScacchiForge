;;;; build.lisp -- compile everything with warnings as errors, then run the tests.
;;;;
;;;; Usage:
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/build.lisp
;;;;       compile scacchiforge, scacchiforge/test and scacchiforge/bench; every WARNING and
;;;;       STYLE-WARNING is an error; load the main and test systems a second time in the
;;;;       same image to prove that reloading works; then run every test suite.
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/build.lisp \
;;;;        --end-toplevel-options --no-test
;;;;       the same without running the tests (this is "make build").
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/build.lisp \
;;;;        --end-toplevel-options --checked
;;;;       the same as the first form, with the feature :SCACCHIFORGE-CHECKED: the hot path of
;;;;       the optimized layer is compiled at safety 3 instead of its default policy, so that
;;;;       every type declaration is checked while the tests run (this is "make test-checked";
;;;;       see src/optimized/policy.lisp and ADR-0014 in docs/adr/).
;;;; With the environment variable SCF_SLIDERS set to magic, fixed-magic or ray, every form
;;;; compiles the slider interface of the optimized layer with that implementation instead of
;;;; the default (src/optimized/policy.lisp, ADR-0016 in docs/adr/); the build prints which.
;;;;   sbcl --noinform --no-userinit --non-interactive --load tools/build.lisp \
;;;;        --end-toplevel-options --self-test
;;;;       check the warning gate itself on planted files in build/self-test/: a definition
;;;;       loaded twice from one file must pass; a function or macro defined in two files, a
;;;;       style warning and a full warning must each fail (part of "make lint-selftest").
;;;; Exit code 0 on success, 1 on any warning, error or failed test. Modelled on ArcDocDB's
;;;; tools/build.lisp. Compiled files go to build/fasl/, never to ~/.cache. Every load is
;;;; forced (SCF-TOOLS:LOAD-STRICT, tools/load.lisp): the files compiled by an earlier build
;;;; with another SCF_SLIDERS or another policy are never reused.

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(defun run-build (run-tests)
  "Build everything; with RUN-TESTS also run the tests. Return true on success."
  (handler-case
      (progn
        ;; scacchiforge/bench depends on scacchiforge/test, which depends on scacchiforge: one
        ;; forced load compiles the three (SCF-TOOLS:LOAD-STRICT forces every system of the
        ;; repository that a load reaches).
        (scf-tools:load-strict "scacchiforge/bench")
        (format t "~&build: compiled scacchiforge, scacchiforge/test, scacchiforge/bench~%")
        (scf-tools:report-build-choices "build")
        ;; A second load in the same image must not fail (no constant redefinition, no
        ;; structure redefinition problems). It is forced too: scacchiforge and
        ;; scacchiforge/test are compiled and loaded again.
        (scf-tools:load-strict "scacchiforge/test")
        (format t "build: reloaded scacchiforge and scacchiforge/test in the same image~%")
        (multiple-value-bind (warnings style-warnings) (scf-tools:warning-counts)
          (format t "build: ~D warning~:P, ~D style warning~:P~%" warnings style-warnings))
        (or (not run-tests)
            (uiop:symbol-call '#:scacchiforge.test '#:run-all)))
    (error (condition)
      (format t "~&build: FAILED: ~A~%" condition)
      nil)))

(let ((arguments (rest sb-ext:*posix-argv*)))
  (when (member "--checked" arguments :test #'string=)
    (pushnew :scacchiforge-checked *features*))
  (if (member "--self-test" arguments :test #'string=)
      (sb-ext:exit :code (if (scf-tools:self-test) 0 1))
      (let ((ok (run-build (not (member "--no-test" arguments :test #'string=)))))
        (format t "~&build: ~:[FAILED~;ok~]~%" ok)
        (sb-ext:exit :code (if ok 0 1)))))
