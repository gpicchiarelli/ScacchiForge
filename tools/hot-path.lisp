;;;; hot-path.lisp -- what SBCL makes of the hot path of the optimized layer.
;;;;
;;;; Usage: sbcl --noinform --no-userinit --non-interactive --load tools/hot-path.lisp
;;;; ("make hot-path"). It prints, in this order:
;;;;   1. SBCL's efficiency notes for each hot-path file, recompiled with the notes shown (the
;;;;      build muffles them: src/optimized/policy.lisp);
;;;;   2. for each hot function (perft's and the search's), the length of its disassembly and
;;;;      every full call, call of a static or assembly routine (generic arithmetic among them)
;;;;      and allocation sequence the disassembly names; before that, the same scan on planted
;;;;      functions with a generic +, a cons, a full call, a boxed 64-bit result and a call of
;;;;      ERROR, each of which it must report, and on a planted function with none, for which it
;;;;      must report nothing (the tool fails otherwise), so that the scan is shown to work on
;;;;      the machine that runs it;
;;;;   3. the bytes consed by perft runs that make over a million moves, after a warm-up;
;;;;   4. the CPU time of perft with the hot path compiled under the default policy, under
;;;;      the default policy with PERFT-NODE calling the generator, make and unmake instead of
;;;;      expanding them inline (*INLINE-NODE-FUNCTIONS*), under safety 0 and under the
;;;;      checked policy of "make test-checked". Each variant is compiled once; the variants
;;;;      then run in two passes, in order and in reverse, so that a drift of the machine
;;;;      reaches each the same way; a timed sample repeats the perft call until it lasts about
;;;;      half a second of CPU, and the time per call is printed with the median of each pass.
;;;; The hot-path files are those that src/optimized/policy.lisp lists in *HOT-PATH-FILES*, and
;;;; the slider implementation is the build's (SCF_SLIDERS, ADR-0016); "make bench" times the
;;;; other implementations. The recompiled files go to build/hot-path/, never to build/fasl/.
;;;; Parts 3 and 4 are measurements of the machine and the SBCL that ran them, not results; the
;;;; policy decision that reads them is ADR-0014 (docs/adr/). The perft runs and their expected
;;;; counts are read from the test system: *MAIN-PERFT-TABLE* (tests/test-perft.lisp, whose
;;;; header says where each count comes from) and *ALLOCATION-PERFTS*
;;;; (tests/test-optimized.lisp); nothing is copied here. Exit code 0 when everything ran, the
;;;; scan passed its self-check and each perft gave its expected count, 1 otherwise. It is not
;;;; part of "make check".

(load (merge-pathnames "load.lisp" (or *load-truename* *default-pathname-defaults*)))

(defpackage #:scf-hot-path
  (:use #:common-lisp))

(in-package #:scf-hot-path)

(defparameter *hot-functions*
  '("BITBOARD-GENERATE-PSEUDO-LEGAL" "BITBOARD-GENERATE-LEGAL" "BITBOARD-MAKE-MOVE"
    "BITBOARD-UNMAKE-MOVE" "PERFT-NODE" "BITBOARD-EVALUATE" "NEGAMAX-NODE" "ALPHA-BETA-NODE")
  "The functions of SCACCHIFORGE.OPTIMIZED whose code a perft or a search runs for every node.
The build expands the first four inline into PERFT-NODE (*INLINE-NODE-FUNCTIONS*,
policy.lisp); their own compiled versions are those that every other caller runs, the search
nodes NEGAMAX-NODE and ALPHA-BETA-NODE among them, which call BITBOARD-EVALUATE at depth 0.")

(defparameter *timed-perfts*
  '(("startpos" 5) ("kiwipete" 4) ("pos3" 6))
  "(position depth) of the perft runs timed under each policy. The expected count of each is
read from *MAIN-PERFT-TABLE* of the test system (EXPECTED-COUNT).")

(defun opt (name)
  "The symbol NAME of the optimized layer."
  (or (find-symbol name "SCACCHIFORGE.OPTIMIZED")
      (error "No symbol ~A in the optimized layer" name)))

(defun test-value (name)
  "The value of the global variable NAME of the test system."
  (symbol-value (or (find-symbol name "SCACCHIFORGE.TEST")
                    (error "No symbol ~A in the test system" name))))

(defun expected-count (name depth)
  "The perft count of the standard position NAME at DEPTH, from *MAIN-PERFT-TABLE* of the test
system (MAIN-PERFT-COUNT, tests/test-perft.lisp)."
  (uiop:symbol-call "SCACCHIFORGE.TEST" "MAIN-PERFT-COUNT" name depth))

(defun call (name &rest arguments)
  "Call the function NAME of the optimized layer."
  (apply (symbol-function (opt name)) arguments))

(defun position-of (name)
  "A fresh bitboard position for the standard position NAME."
  (call "BITBOARD-FROM-REFERENCE"
        (uiop:symbol-call "SCACCHIFORGE.REFERENCE" "PARSE-FEN"
                          (uiop:symbol-call "SCACCHIFORGE.REFERENCE" "STANDARD-POSITION-FEN"
                                            name))))

(defun rule (title)
  "Print a section title."
  (format t "~%~A~%~A~%" title (make-string (length title) :initial-element #\-)))

(defun recompile-hot-path (directory policy &key notes (inline-node-functions t))
  "Compile and load the hot-path files into DIRECTORY (below build/hot-path/) with POLICY as
the layer's policy; with NOTES, keep SBCL's efficiency notes; with INLINE-NODE-FUNCTIONS false,
let PERFT-NODE call the generator, make and unmake instead of expanding them inline (the
build expands them). Return the compiler's output."
  (let ((root scf-tools:*repository-root*)
        (policy-variable (opt "*OPTIMIZED-POLICY*"))
        (notes-variable (opt "*SHOW-EFFICIENCY-NOTES*"))
        (inline-variable (opt "*INLINE-NODE-FUNCTIONS*")))
    (progv (list policy-variable notes-variable inline-variable)
        (list policy notes inline-node-functions)
      (with-output-to-string (*error-output*)
        (let ((*standard-output* *error-output*))
          (scf-tools:call-with-strict-warnings
           (lambda ()
             (dolist (name (symbol-value (opt "*HOT-PATH-FILES*")))
               (let ((output (merge-pathnames (format nil "build/hot-path/~A/~A.fasl"
                                                      directory name)
                                              root)))
                 (ensure-directories-exist output)
                 (load (compile-file (merge-pathnames (format nil "src/optimized/~A.lisp" name)
                                                      root)
                                     :output-file output :verbose nil :print nil)))))))))))

(defun print-notes (compiler-output)
  "Print the file and function lines of COMPILER-OUTPUT and each note with its continuation
lines, then how many notes there are."
  (let ((notes 0)
        (in-note nil))
    (with-input-from-string (in compiler-output)
      (loop for line = (read-line in nil)
            while line
            do (cond ((search "; note:" line)
                      (incf notes)
                      (setf in-note t)
                      (format t "    ~A~%" (string-trim " ;" line)))
                     ((and in-note (> (length line) 3) (string= ";   " line :end2 4))
                      (format t "      ~A~%" (string-trim " ;" line)))
                     (t
                      (setf in-note nil)
                      (when (or (search "; in: " line) (search "; file: " line))
                        (format t "  ~A~%" (string-trim " ;" line)))))))
    (format t "  ~D efficiency note~:P~%" notes)))

(defparameter *remark-markers*
  '(("FDEFN" . "full call")
    ("GENERIC" . "generic arithmetic")
    ("TWO-ARG-" . "generic arithmetic")
    ("SB-BIGNUM" . "bignum arithmetic")
    ("TRAMP" . "allocation")
    ("ALLOC" . "allocation"))
  "(text . kind): a disassembly remark containing TEXT is reported as KIND. SBCL names a full
call by its FDEFN, generic arithmetic by an assembly routine (GENERIC-+ on x86-64) or a static
function (SB-KERNEL:TWO-ARG-+ on arm64), and an allocation by its trampoline
(SB-VM::ALLOC-TRAMP, SB-VM::LIST-ALLOC-TRAMP).")

(defun remark-kind (instruction remark)
  "Why a disassembly line with INSTRUCTION and REMARK is reported, as a string, or NIL when it is
not: a remark that *REMARK-MARKERS* matches, or any remark on an instruction that calls a routine
or loads the address of one from the static-function table (LDR LR, [NULL, ...] on arm64,
whose remark names the function, ERROR among them)."
  (or (loop for (text . kind) in *remark-markers*
            when (search text remark)
              return kind)
      (and (or (search "LDR LR, [NULL" instruction) (search "CALL" instruction))
           "call of a static or assembly routine")))

(defun disassembly-findings (function)
  "The disassembly of FUNCTION (a function or a function name) scanned line by line: the number
of instructions, and the list of (remark . kind) that REMARK-KIND reports, without repetitions,
in order."
  (let ((text (with-output-to-string (*standard-output*)
                (disassemble function)))
        (instructions 0)
        (findings '()))
    (with-input-from-string (in text)
      (loop for line = (read-line in nil)
            while line
            do (when (and (> (length line) 2) (char= (char line 0) #\;)
                          (digit-char-p (char line 2) 16))
                 (incf instructions))
               (let ((comment (position #\; line :start 1)))
                 (when comment
                   (let* ((remark (string-trim " " (subseq line (1+ comment))))
                          (kind (remark-kind (subseq line 0 comment) remark)))
                     (when kind
                       (pushnew (cons remark kind) findings :test #'equal)))))))
    (values instructions (reverse findings))))

(defun disassembly-summary (name)
  "Print the size of the disassembly of the hot function NAME and the lines that REMARK-KIND
reports, with their kind."
  (multiple-value-bind (instructions findings) (disassembly-findings (opt name))
    (format t "  ~A: ~D instruction~:P; ~:[no full call, routine call or allocation~;it names:~]~%"
            name instructions findings)
    (loop for (remark . kind) in findings
          do (format t "      ~A  (~A)~%" remark kind))))

(defun planted-callee (x)
  "A function the planted full call calls."
  (list x))

(defparameter *planted-functions*
  '(("a generic +" :report (lambda (a b) (+ a b)))
    ("a cons" :report (lambda (a b) (cons a b)))
    ("a full call" :report (lambda (a) (planted-callee a)))
    ("a boxed 64-bit result" :report
     (lambda (a) (declare (type (unsigned-byte 64) a)) (logxor a (ash a -3))))
    ("a call of ERROR" :report (lambda (a) (if (> a 0) (error "planted ~A" a) a)))
    ("fixnum arithmetic only" :nothing
     (lambda (a b)
       (declare (type (signed-byte 32) a b) (optimize (speed 3) (safety 0) (debug 0)))
       (logand (+ a b) #xFFFF))))
  "(label expectation lambda-form): each form is compiled and its disassembly scanned. A
:REPORT form must give at least one finding, a :NOTHING form none.")

(defun scan-self-check ()
  "Scan the disassembly of each of *PLANTED-FUNCTIONS* and print what the scan reports. Signal
an error unless each one meets its expectation."
  (let ((failures '()))
    (loop for (label expectation form) in *planted-functions*
          do (let ((findings (nth-value 1 (disassembly-findings (compile nil form)))))
               (format t "  planted ~A: ~:[nothing reported~;~:*~{~A~^, ~}~]~%" label
                       (mapcar (lambda (finding) (format nil "~A (~A)" (car finding)
                                                         (cdr finding)))
                               findings))
               (unless (eq (and findings t) (eq expectation :report))
                 (push label failures))))
    (when failures
      (error "the disassembly scan missed or invented findings for: ~{~A~^; ~}"
             (reverse failures)))
    (format t "  the scan reported every planted case and nothing on the clean one~%~%")))

(defun moves-made (bbp depth)
  "Moves a bulk-counting perft of BBP to DEPTH makes: the leaves of every depth below DEPTH."
  (loop for d from 1 below depth sum (call "BITBOARD-PERFT" bbp d)))

(defvar *sink* nil "Where ALLOCATION-STEPS stores each cell, so that the consing is kept.")

(defun allocation-steps (count)
  "COUNT successive changes of SB-EXT:GET-BYTES-CONSED while one cell is consed at a time,
each as (bytes-the-counter-moved . cells-consed-since-the-last-change)."
  (let ((steps '())
        (last (sb-ext:get-bytes-consed))
        (cells 0))
    (loop while (< (length steps) count)
          do (setf *sink* (cons cells nil))
             (incf cells)
             (let ((now (sb-ext:get-bytes-consed)))
               (when (/= now last)
                 (push (cons (- now last) cells) steps)
                 (setf last now
                       cells 0))))
    (rest (reverse steps))))

(defun measure-allocation ()
  "Print how coarsely SB-EXT:GET-BYTES-CONSED counts, then the bytes consed by the allocation
perft runs after a warm-up."
  (format t "  SB-EXT:GET-BYTES-CONSED while consing one cell at a time moved by~%")
  (loop for (bytes . cells) in (allocation-steps 6)
        do (format t "    ~D bytes after ~D cells~%" bytes cells))
  (let ((runs (loop for (name depth) in (test-value "*ALLOCATION-PERFTS*")
                    collect (list depth (position-of name)
                                  (call "MAKE-BITBOARD-MOVE-BUFFER" depth))))
        (moves 0))
    (loop for (depth bbp buffer) in runs
          do (call "BITBOARD-PERFT-WITH-BUFFER" bbp depth buffer)
             (incf moves (moves-made bbp depth)))
    (let ((before (sb-ext:get-bytes-consed)))
      (loop for (depth bbp buffer) in runs
            do (call "BITBOARD-PERFT-WITH-BUFFER" bbp depth buffer))
      (format t "  perft runs after a warm-up: ~D moves made and unmade, ~D bytes consed~%"
              moves (- (sb-ext:get-bytes-consed) before)))))

(defun median (numbers)
  "The median of the non-empty list NUMBERS."
  (let ((sorted (sort (copy-list numbers) #'<)))
    (nth (floor (length sorted) 2) sorted)))

(defparameter *sample-seconds* 0.5d0
  "The CPU time a timed sample of part 4 lasts at least: a sample repeats the perft call as many
times as a calibration call says it takes.")

(defparameter *samples-per-pass* 5 "Timed samples per perft run in each pass of part 4.")

(defun cpu-seconds-since (start)
  "CPU seconds since the internal run time START."
  (/ (- (get-internal-run-time) start) (float internal-time-units-per-second 1d0)))

(defun variant-directory (label)
  "The directory below build/hot-path/ of the variant LABEL."
  (substitute #\- #\Space (remove #\, label)))

(defun load-variant (label policy)
  "Load the hot-path files that RECOMPILE-HOT-PATH compiled for the variant LABEL with POLICY.
Each checks, as it loads, that it was compiled with the policy the image asks for, which is
POLICY while they load."
  (progv (list (opt "*OPTIMIZED-POLICY*")) (list policy)
    (dolist (name (symbol-value (opt "*HOT-PATH-FILES*")))
      (load (merge-pathnames (format nil "build/hot-path/~A/~A.fasl" (variant-directory label)
                                     name)
                             scf-tools:*repository-root*)))))

(defun time-variants (variants)
  "Compile the hot path once for each of VARIANTS, a list of (label policy inline), then time
each perft run of *TIMED-PERFTS* in passes: the variants in order, then in reverse, loading the
files of a variant before its pass. Each pass of a run makes an untimed warm-up call and
*SAMPLES-PER-PASS* samples, each of as many calls as a calibration call (in the first pass)
says reach *SAMPLE-SECONDS* of CPU. Print, for each variant and run, the median CPU time per
call over both passes with its minimum and maximum, and the median of each pass. Signal an
error if a count is wrong."
  (loop for (label policy inline) in variants
        do (recompile-hot-path (variant-directory label) policy :inline-node-functions inline))
  (let ((calls (make-hash-table :test #'equal))
        (passes (make-hash-table :test #'equal)))
    (loop for (label policy) in (append variants (reverse variants))
          do (load-variant label policy)
             (loop for (name depth) in *timed-perfts*
                   do (let* ((bbp (position-of name))
                             (buffer (call "MAKE-BITBOARD-MOVE-BUFFER" depth))
                             (expected (expected-count name depth))
                             (key (list label name)))
                        (flet ((perft ()
                                 (let ((count (call "BITBOARD-PERFT-WITH-BUFFER" bbp depth
                                                    buffer)))
                                   (unless (= count expected)
                                     (error "perft ~A depth ~D gave ~D, expected ~D" name depth
                                            count expected)))))
                          (perft)
                          (unless (gethash key calls)
                            (let ((start (get-internal-run-time)))
                              (perft)
                              (setf (gethash key calls)
                                    (max 1 (ceiling *sample-seconds*
                                                    (max 1d-4 (cpu-seconds-since start)))))))
                          (let ((k (gethash key calls)))
                            (push (loop repeat *samples-per-pass*
                                        collect (let ((start (get-internal-run-time)))
                                                  (dotimes (i k) (perft))
                                                  (/ (cpu-seconds-since start) k)))
                                  (gethash key passes)))))))
    (format t "  CPU seconds per perft call. Passes in the order:~%~{    ~A~%~}"
            (mapcar #'first (append variants (reverse variants))))
    (loop for (label policy inline) in variants
          do (format t "  ~A: ~(~S~)~:[; PERFT-NODE calls the generator, make and unmake~;~]~%"
                     label (cons 'optimize policy) inline)
             (loop for (name depth) in *timed-perfts*
                   do (let* ((key (list label name))
                             (runs (reverse (gethash key passes)))
                             (all (reduce #'append runs)))
                        (format t "    perft ~A ~D, ~D call~:P/sample: median ~,5F (min ~,5F, ~
                                   max ~,5F), passes~{ ~,5F~}~%"
                                name depth (gethash key calls) (median all)
                                (reduce #'min all) (reduce #'max all)
                                (mapcar #'median runs)))))))

(defun run ()
  "Print the four parts described in the file header."
  ;; A forced load: scacchiforge and scacchiforge/test are compiled again (tools/load.lisp).
  (scf-tools:load-strict "scacchiforge/test")
  (format t "Hot path of the optimized layer: ~A ~A, ~A ~A~%" (lisp-implementation-type)
          (lisp-implementation-version) (software-type) (machine-type))
  (format t "Measurements of this machine at this moment, not results.~%")
  (format t "Slider attacks by the ~(~A~) implementation.~%"
          (call "SLIDER-INTERFACE-IMPLEMENTATION"))
  (let ((default (symbol-value (opt "*OPTIMIZED-POLICY*"))))
    (rule (format nil "1. Efficiency notes, policy ~(~S~)" (cons 'optimize default)))
    (print-notes (recompile-hot-path "notes" default :notes t))
    (rule "2. Disassembly of the functions run at every node")
    (scan-self-check)
    (dolist (name *hot-functions*)
      (disassembly-summary name))
    (rule "3. Allocation")
    (measure-allocation)
    (rule "4. Perft CPU time by policy of the hot path")
    (time-variants
     `(("default" ,(symbol-value (opt "*DEFAULT-POLICY*")) t)
       ("default, node functions called" ,(symbol-value (opt "*DEFAULT-POLICY*")) nil)
       ("safety 0" ((speed 3) (safety 0) (debug 0)) t)
       ("checked" ,(symbol-value (opt "*CHECKED-POLICY*")) t)))))

(let ((ok nil))
  (handler-case (progn (run) (setf ok t))
    (error (condition)
      (format t "~&hot-path: ~A~%" condition)))
  (format t "~&hot-path: ~:[FAILED~;done~]~%" ok)
  (sb-ext:exit :code (if ok 0 1)))
