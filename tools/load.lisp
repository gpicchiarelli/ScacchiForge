;;;; load.lisp -- shared loader of every tools/ script that loads the system: build,
;;;; perft-deep, differential-deep, bench, hot-path and generate-magics.
;;;;
;;;; Loads a system with every WARNING and STYLE-WARNING turned into an error, and keeps the
;;;; compiled files inside the repository (build/fasl/) so that nothing is written to
;;;; ~/.cache. SBCL is the only requirement.
;;;;
;;;; A load is forced by default, and a forced load recompiles every system of this repository
;;;; that it reaches, not only the one named: :FORCE T of ASDF forces the named system alone,
;;;; and loads the systems it depends on from their compiled files when these are newer than
;;;; the sources. ASDF does not know which SCF_SLIDERS or which policy (make test-checked) a
;;;; file was compiled with, so such a load would reuse files built with another choice, and
;;;; the hot path of the optimized layer would refuse them (CHECK-COMPILED-CHOICE in
;;;; src/optimized/policy.lisp). The systems are those that scacchiforge.asd defines
;;;; (PROJECT-SYSTEMS); ASDF, UIOP and SBCL's contribs are never recompiled.
;;;;
;;;; The one warning let through is a redefinition that SBCL itself calls uninteresting: a
;;;; definition made again from the same file. It happens on every build (COMPILE-FILE defines
;;;; each macro, then loading the fasl defines it again) and when a system is loaded a second
;;;; time in the same image. A redefinition from another file is counted and fails the build.
;;;; SELF-TEST checks both cases on planted files.
;;;;
;;;; Used as:  (load "tools/load.lisp")  then  (scf-tools:load-strict "scacchiforge")

(require :asdf)

(defpackage #:scf-tools
  (:use #:common-lisp)
  (:export #:*repository-root* #:load-strict #:project-systems #:report-build-choices
           #:call-with-strict-warnings #:warning-counts #:self-test))

(in-package #:scf-tools)

(defvar *repository-root*
  (let ((here (or *load-truename* *default-pathname-defaults*)))
    ;; tools/load.lisp -> the repository root is one directory up.
    (make-pathname :name nil :type nil :version nil
                   :directory (butlast (pathname-directory here))
                   :defaults here))
  "The repository root as a directory pathname.")

(defvar *warnings* 0 "WARNINGs (other than style warnings) seen while loading.")
(defvar *style-warnings* 0 "STYLE-WARNINGs seen while loading.")

(defun warning-counts ()
  "The number of warnings and the number of style warnings seen by LOAD-STRICT, as two
values. Each one is an error, so a successful build reports zero for both."
  (values *warnings* *style-warnings*))

(defun configure-asdf ()
  "Point ASDF at this repository and send compiled files to build/fasl/."
  (let ((root (namestring *repository-root*)))
    (asdf:initialize-output-translations
     `(:output-translations
       (,root ,(concatenate 'string root "build/fasl/"))
       :ignore-inherited-configuration))
    (pushnew *repository-root* asdf:*central-registry* :test #'equal)))

(defun treat-as-error (condition)
  "Count the warning CONDITION and turn it into an error. The one exception is a
redefinition of type SB-KERNEL:UNINTERESTING-REDEFINITION, which SBCL muffles by default: a
function, macro, generic function or method defined again from the same file. Every other
redefinition, such as the same function defined in two files, is counted and is an error."
  (unless (typep condition 'sb-kernel:uninteresting-redefinition)
    (if (typep condition 'style-warning)
        (incf *style-warnings*)
        (incf *warnings*))
    (error "Compilation ~A not allowed: ~A" (type-of condition) condition)))

(defun call-with-strict-warnings (thunk)
  "Call THUNK with every warning passed to TREAT-AS-ERROR."
  (handler-bind ((warning #'treat-as-error))
    (funcall thunk)))

(defun project-systems ()
  "The names of the ASDF systems that scacchiforge.asd defines, in the order of the file:
\"scacchiforge\", \"scacchiforge/test\" and \"scacchiforge/bench\" today. The file is read,
not evaluated, so that the list follows it when a system is added."
  (let ((*package* (find-package '#:asdf-user))
        (*read-eval* nil)
        (names '()))
    (with-open-file (in (merge-pathnames "scacchiforge.asd" *repository-root*))
      (loop for form = (read in nil in)
            until (eq form in)
            do (when (and (consp form) (symbolp (first form))
                          (string= (symbol-name (first form)) "DEFSYSTEM"))
                 (push (asdf:coerce-name (second form)) names))))
    (or (nreverse names)
        (error "No DEFSYSTEM form found in scacchiforge.asd"))))

(defun load-strict (system &key (force t))
  "Load SYSTEM with warnings as errors, its compiled files in build/fasl/. FORCE is T by
default: every system of PROJECT-SYSTEMS that the load reaches is compiled again, SYSTEM and
the systems of this repository it depends on, so that no compiled file built with another
SCF_SLIDERS or another policy of the optimized hot path is reused. ASDF, UIOP and SBCL's
contribs are not recompiled. FORCE NIL lets ASDF reuse every compiled file it finds up to
date by its timestamps; a list is passed to ASDF as it is."
  (configure-asdf)
  (setf asdf:*compile-file-failure-behaviour* :error
        asdf:*compile-file-warnings-behaviour* :error)
  (let ((*compile-verbose* nil)
        (*compile-print* nil)
        (*load-verbose* nil)
        (forced (if (eq force t) (project-systems) force)))
    (call-with-strict-warnings (lambda () (asdf:load-system system :force forced))))
  system)

(defun report-build-choices (prefix)
  "Print, after PREFIX, the policy and the slider implementation that the hot path of the
optimized layer was compiled with, as the loaded system reports them, and the value of
SCF_SLIDERS. Call it after LOAD-STRICT: the hot-path files refuse to load unless they were
compiled with the choices of the image, so these are also the choices of the code that runs."
  (let ((*print-pretty* nil)
        (package "SCACCHIFORGE.OPTIMIZED"))
    (format t "~A: optimized hot path compiled with ~(~S~)~%" prefix
            (cons 'optimize (symbol-value (find-symbol "*OPTIMIZED-POLICY*" package))))
    (format t "~A: slider attacks by the ~(~A~) implementation (SCF_SLIDERS ~
               ~:[not set~;~:*~S~])~%"
            prefix (uiop:symbol-call package '#:slider-interface-implementation)
            (sb-ext:posix-getenv "SCF_SLIDERS"))))

;;; --- self-test ------------------------------------------------------------------------

(defparameter *self-test-cases*
  ;; (name expected (file source ...)): the files are compiled and loaded in order, under
  ;; CALL-WITH-STRICT-WARNINGS. EXPECTED is :PASS or :FAIL.
  '(("a macro and a function loaded twice from one file" :pass
     ("same.lisp" "(defmacro planted-macro () 1)
(defun planted-same () (planted-macro))"
      "same.lisp" "(defmacro planted-macro () 1)
(defun planted-same () (planted-macro))"))
    ("one function defined in two files" :fail
     ("first.lisp" "(defun planted-twice () 1)"
      "second.lisp" "(defun planted-twice () 2)"))
    ("one macro defined in two files" :fail
     ("macro-first.lisp" "(defmacro planted-macro-twice () 1)"
      "macro-second.lisp" "(defmacro planted-macro-twice () 2)"))
    ("an unused variable (a style warning)" :fail
     ("style.lisp" "(defun planted-style (x) 1)"))
    ("a constant of the wrong type (a full warning)" :fail
     ("full.lisp" "(defun planted-full () (let ((x 1)) (declare (type string x)) x))")))
  "Planted cases for SELF-TEST.")

(defun self-test-directory ()
  "build/self-test/ below the repository root, where the planted files are written."
  (merge-pathnames "build/self-test/" *repository-root*))

(defun compile-and-load-planted (directory name source)
  "Write SOURCE, in the package SCF-TOOLS-SELF-TEST, to the file NAME in DIRECTORY; compile it
and load the result."
  (let ((path (merge-pathnames name directory)))
    (with-open-file (out path :direction :output :if-exists :supersede)
      (format out "(in-package #:scf-tools-self-test)~%~A~%" source))
    (load (compile-file path :verbose nil :print nil))))

(defun run-self-test-case (directory files)
  "Compile and load FILES, a list (name source ...), under CALL-WITH-STRICT-WARNINGS.
Return :PASS, or :FAIL when an error stopped it, and the number of warnings counted."
  (let ((before (multiple-value-call #'+ (warning-counts))))
    (values (handler-case
                (let ((*compile-verbose* nil) (*compile-print* nil) (*load-verbose* nil))
                  (call-with-strict-warnings
                   (lambda ()
                     (loop for (name source) on files by #'cddr
                           do (compile-and-load-planted directory name source))))
                  :pass)
              (error () :fail))
            (- (multiple-value-call #'+ (warning-counts)) before))))

(defun self-test ()
  "Check the warning gate on the planted cases: each must pass or fail as expected, and a
failure must be counted as a warning. Return true when every case behaves as expected."
  (let ((directory (self-test-directory))
        (failures 0))
    (ensure-directories-exist directory)
    (unless (find-package '#:scf-tools-self-test)
      (make-package '#:scf-tools-self-test :use '(#:common-lisp)))
    (let ((*error-output* (make-broadcast-stream)))
      (loop for (name expected files) in *self-test-cases*
            do (multiple-value-bind (outcome counted) (run-self-test-case directory files)
                 (unless (and (eq outcome expected)
                              (if (eq expected :fail) (plusp counted) (zerop counted)))
                   (incf failures)
                   (format t "FAIL  ~A: expected ~A, found ~A with ~D warning~:P counted~%"
                           name expected outcome counted)))))
    (format t "strict-load self-test: ~D case~:P, ~D failure~:P~%"
            (length *self-test-cases*) failures)
    (zerop failures)))
