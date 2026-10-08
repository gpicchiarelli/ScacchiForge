;;;; framework.lisp -- a small test framework: DEFTEST, assertions with useful failure
;;;; messages, and a runner that prints counts and says whether everything passed.
;;;;
;;;; A test is a named thunk in a suite (a keyword). Assertions record a failure and let the
;;;; test continue, so one run reports every broken assertion. A condition that escapes a test
;;;; body is recorded as a failure of that test.

(in-package #:scacchiforge.test)

(defstruct (test-case (:conc-name test-))
  "A registered test."
  (suite :none :type keyword)
  (name nil :type symbol)
  (function nil :type function))

(defvar *tests* '()
  "Registered tests in definition order. Re-evaluating a DEFTEST replaces it in place.")

(defvar *current-test* nil "The TEST-CASE being run.")
(defvar *assertions* 0 "Assertions made so far in this run.")
(defvar *failures* '() "Failure records, newest first: (test-case . message).")

(defun register-test (suite name function)
  "Add or replace the test SUITE / NAME."
  (let ((existing (find-if (lambda (test) (and (eq (test-suite test) suite)
                                               (eq (test-name test) name)))
                           *tests*))
        (new (make-test-case :suite suite :name name :function function)))
    (if existing
        (setf *tests* (substitute new existing *tests*))
        (setf *tests* (append *tests* (list new))))
    name))

(defmacro deftest (suite name &body body)
  "Define the test NAME in SUITE (a keyword); BODY makes assertions."
  `(register-test ,suite ',name (lambda () ,@body)))

(defun show (object)
  "A short printed form of OBJECT for failure messages."
  (let ((*print-pretty* nil) (*print-length* 24) (*print-level* 4))
    (prin1-to-string object)))

(defun record-failure (control &rest arguments)
  "Record a failure of the current test."
  (push (cons *current-test* (apply #'format nil control arguments)) *failures*)
  nil)

(defun describe-with (message arguments)
  "MESSAGE formatted with ARGUMENTS, followed by a colon, or an empty string."
  (if message
      (format nil "~? -- " message arguments)
      ""))

(defmacro is (form &optional message &rest arguments)
  "Assert that FORM is true. MESSAGE and ARGUMENTS are a FORMAT control string and arguments."
  `(progn
     (incf *assertions*)
     (unless ,form
       (record-failure "~Aassertion failed: ~A" (describe-with ,message (list ,@arguments))
                       ',form))
     nil))

(defmacro is-true (form &optional message &rest arguments)
  "Assert that FORM is true."
  `(is ,form ,message ,@arguments))

(defmacro is-false (form &optional message &rest arguments)
  "Assert that FORM is false."
  `(is (not ,form) ,message ,@arguments))

(defun check-same (test expected actual form message arguments)
  "Apply the predicate TEST to EXPECTED and ACTUAL; record a failure naming FORM if false."
  (incf *assertions*)
  (unless (funcall test expected actual)
    (record-failure "~A~A~%      expected: ~A~%      actual:   ~A"
                    (describe-with message arguments) form (show expected) (show actual)))
  nil)

(defmacro is-eql (expected actual &optional message &rest arguments)
  "Assert (EQL EXPECTED ACTUAL)."
  `(check-same #'eql ,expected ,actual ',actual ,message (list ,@arguments)))

(defmacro is-equal (expected actual &optional message &rest arguments)
  "Assert (EQUAL EXPECTED ACTUAL)."
  `(check-same #'equal ,expected ,actual ',actual ,message (list ,@arguments)))

(defmacro is-equalp (expected actual &optional message &rest arguments)
  "Assert (EQUALP EXPECTED ACTUAL)."
  `(check-same #'equalp ,expected ,actual ',actual ,message (list ,@arguments)))

(defun same-set-p (expected actual)
  "True when the string lists EXPECTED and ACTUAL hold the same strings, ignoring order."
  (and (= (length expected) (length actual))
       (equal (sort (copy-list expected) #'string<)
              (sort (copy-list actual) #'string<))))

(defmacro is-set-equal (expected actual &optional message &rest arguments)
  "Assert that two lists of strings hold the same elements in any order."
  `(check-same #'same-set-p ,expected ,actual ',actual ,message (list ,@arguments)))

(defmacro signals (condition-type &body body)
  "Assert that evaluating BODY signals a condition of CONDITION-TYPE."
  `(progn
     (incf *assertions*)
     (handler-case (progn ,@body
                          (record-failure "expected ~S to be signalled by ~S, nothing was"
                                          ',condition-type ',(cons 'progn body)))
       (,condition-type () nil))
     nil))

(defun note (control &rest arguments)
  "Print an informational line from inside a test."
  (format t "~&      ~?~%" control arguments)
  (finish-output))

(defun selected-tests (suites)
  "The registered tests belonging to SUITES (all of them when SUITES is NIL)."
  (remove-if-not (lambda (test) (or (null suites) (member (test-suite test) suites)))
                 *tests*))

(defun list-suites ()
  "The suites that have at least one test, in definition order."
  (remove-duplicates (mapcar #'test-suite *tests*) :from-end t))

(defun run-one-test (test)
  "Run TEST, recording an error escaping the body as a failure. Return the seconds taken."
  (let ((start (get-internal-real-time))
        (*current-test* test))
    (handler-case (funcall (test-function test))
      (serious-condition (condition)
        (record-failure "error escaped the test: ~A"
                        (remove #\Newline (princ-to-string condition)))))
    (/ (- (get-internal-real-time) start) (float internal-time-units-per-second))))

(defun run-tests (&key suites)
  "Run the tests of SUITES (all when NIL), printing one line per test and a summary.
Returns true when no assertion failed and no test signalled an error."
  (let ((*assertions* 0)
        (*failures* '())
        (tests (selected-tests suites))
        (started (get-internal-real-time)))
    (dolist (test tests)
      (let* ((before (length *failures*))
             (seconds (run-one-test test)))
        (format t "~&~A ~(~A/~A~) (~,2F s)~%"
                (if (= before (length *failures*)) "ok  " "FAIL")
                (test-suite test) (test-name test) seconds)
        (finish-output)))
    (let ((failures (reverse *failures*)))
      (dolist (failure failures)
        (format t "~&FAILURE in ~(~A/~A~): ~A~%" (test-suite (car failure))
                (test-name (car failure)) (cdr failure)))
      (format t "~&~D test~:P, ~D assertion~:P, ~D failure~:P (~,2F s)~%"
              (length tests) *assertions* (length failures)
              (/ (- (get-internal-real-time) started) (float internal-time-units-per-second)))
      (finish-output)
      (null failures))))
