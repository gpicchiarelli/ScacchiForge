;;;; system-info.lisp -- the environment record: when and how the numbers were produced, and
;;;; on what machine, software, build and inputs (docs/misure.md, "Registro dell'ambiente").

(in-package #:scacchiforge.bench)

;;; --- running commands -----------------------------------------------------------------

(defun command-output (program &rest arguments)
  "Everything the command PROGRAM prints on standard output, or NIL if it cannot be run or
exits with a code other than 0."
  (handler-case
      (with-output-to-string (out)
        (let ((process (sb-ext:run-program program arguments :search t :output out
                                                              :error nil :input nil)))
          (unless (eql 0 (sb-ext:process-exit-code process))
            (return-from command-output nil))))
    (error () nil)))

(defun first-line (string)
  "STRING up to its first newline, trimmed; NIL for NIL or an empty result."
  (when string
    (let ((line (string-trim '(#\Space #\Tab #\Newline #\Return)
                             (subseq string 0 (position #\Newline string)))))
      (and (plusp (length line)) line))))

(defun line-count (string)
  "The number of non-blank lines of STRING."
  (with-input-from-string (in string)
    (loop for line = (read-line in nil)
          while line
          count (plusp (length (string-trim '(#\Space #\Tab #\Return) line))))))

;;; --- machine ----------------------------------------------------------------------------

(defun cpuinfo-field (name)
  "The value of the first line \"NAME : value\" of /proc/cpuinfo, or NIL."
  (handler-case
      (with-open-file (in "/proc/cpuinfo" :if-does-not-exist nil)
        (when in
          (loop for line = (read-line in nil)
                while line
                do (when (and (> (length line) (length name))
                              (string-equal name line :end2 (length name))
                              (position #\: line))
                     (return (string-trim " " (subseq line (1+ (position #\: line)))))))))
    (error () nil)))

(defun cpu-model ()
  "The CPU model name as the operating system reports it."
  (or (first-line (command-output "sysctl" "-n" "machdep.cpu.brand_string"))
      (cpuinfo-field "model name")
      (cpuinfo-field "Model")
      (cpuinfo-field "Hardware")
      (first-line (command-output "sysctl" "-n" "hw.model"))
      "unknown"))

(defun cpu-count ()
  "The number of logical CPUs the operating system reports."
  (or (first-line (command-output "sysctl" "-n" "hw.ncpu"))
      (first-line (command-output "nproc"))
      "unknown"))

(defun load-average ()
  "The 1, 5 and 15 minute load averages as the operating system reports them, as a string."
  (let ((text (or (first-line (command-output "sysctl" "-n" "vm.loadavg"))
                  (handler-case
                      (with-open-file (in "/proc/loadavg" :if-does-not-exist nil)
                        (and in (read-line in nil)))
                    (error () nil)))))
    (if text
        (string-trim " {}" (subseq text 0 (min (length text) 40)))
        "unknown")))

(defun operating-system ()
  "The operating system name, release and machine, from uname."
  (or (first-line (command-output "uname" "-srm"))
      (format nil "~A ~A" (software-type) (software-version))))

;;; --- run and code -----------------------------------------------------------------------

(defun utc-timestamp (&optional (time (get-universal-time)))
  "TIME, a universal time, as an ISO 8601 date and time in UTC."
  (multiple-value-bind (second minute hour day month year) (decode-universal-time time 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ" year month day hour minute second)))

(defun process-command-line ()
  "The command line of this process as the operating system reports it. The shell started
here asks ps for the arguments of its parent, which is this process."
  (or (first-line (command-output "/bin/sh" "-c" "ps -o args= -p $PPID"))
      "unknown (ps did not answer)"))

(defun repository-root ()
  "The directory that holds scacchiforge.asd."
  (asdf:system-source-directory "scacchiforge"))

(defun source-revision ()
  "The short git revision of the repository, and whether its working tree is clean."
  (let* ((root (namestring (repository-root)))
         (revision (first-line (command-output "git" "-C" root "rev-parse" "--short" "HEAD")))
         (status (command-output "git" "-C" root "--no-optional-locks" "status" "--porcelain"
                                 "--untracked-files=normal")))
    (cond ((null revision) "unknown (git did not answer)")
          ((null status) (format nil "~A, state of the working tree unknown" revision))
          ((zerop (line-count status)) (format nil "~A, working tree clean" revision))
          (t (format nil "~A, working tree not clean (~D path~:P changed or untracked)"
                     revision (line-count status))))))

;;; --- build policy -----------------------------------------------------------------------

(defmacro optimization-settings-at-compile-time ()
  "The optimization settings in effect while this form is compiled, as a quoted list."
  `',(uiop:get-optimization-settings))

(defparameter *global-policy* (optimization-settings-at-compile-time)
  "The optimization settings in effect while this file was compiled, after every file of
SCACCHIFORGE had been compiled and loaded in the same process. This file proclaims none of its
own, so a proclamation that outlived the file making it would show here.")

(defun system-source-files (name)
  "The Lisp source files of the ASDF system NAME, in the order of its definition."
  (let ((files '()))
    (labels ((walk (component)
               (typecase component
                 (asdf:cl-source-file (push (asdf:component-pathname component) files))
                 (asdf:parent-component (mapc #'walk (asdf:component-children component))))))
      (walk (asdf:find-system name)))
    (nreverse files)))

(defun optimize-proclamations (pathname)
  "The OPTIMIZE declaration specifiers of the top-level DECLAIM forms of the Lisp source file
PATHNAME, read in the package that each IN-PACKAGE form selects. A top-level
(SCF-OPT:DECLAIM-OPTIMIZED-POLICY) counts as the OPTIMIZE proclamation it expands into, the
policy of the optimized layer's hot path in this build."
  (let ((*package* (find-package '#:cl-user))
        (*read-eval* nil)
        (found '()))
    (with-open-file (in pathname)
      (loop for form = (read in nil in)
            until (eq form in)
            do (when (consp form)
                 (case (first form)
                   (in-package (setf *package* (find-package (second form))))
                   (declaim (dolist (specifier (rest form))
                              (when (and (consp specifier) (eq (first specifier) 'optimize))
                                (push specifier found))))
                   (scf-opt:declaim-optimized-policy
                    (push (cons 'optimize scf-opt:*optimized-policy*) found))))))
    (nreverse found)))

(defun build-policy ()
  "A list of (SPECIFIER-TEXT DIRECTORY FILE-NAMES): each OPTIMIZE proclamation found at the
top level of the measured systems, with the files that make it, grouped by directory. A file
that makes the same proclamation more than once is named once: perft.lisp, for one, returns to
the policy of the layer's other files after its hot part (src/optimized/policy.lisp)."
  (let ((groups '())
        (root (repository-root)))
    (dolist (file (append (system-source-files "scacchiforge")
                          (system-source-files "scacchiforge/bench")))
      (dolist (specifier (optimize-proclamations file))
        (let* ((text (string-downcase (format nil "~S" specifier)))
               (relative (enough-namestring file root))
               (directory (subseq relative 0 (1+ (or (position #\/ relative :from-end t) -1))))
               (group (find-if (lambda (entry) (and (string= (first entry) text)
                                                    (string= (second entry) directory)))
                               groups)))
          (if group
              (pushnew (pathname-name file) (third group) :test #'string=)
              (push (list text directory (list (pathname-name file))) groups)))))
    (mapcar (lambda (group) (list (first group) (second group) (reverse (third group))))
            (reverse groups))))

;;; --- the record -------------------------------------------------------------------------

(defun environment-record (&key (start-time (get-universal-time)) (repetitions 5))
  "The environment record of a run whose measurements start at the universal time START-TIME
with REPETITIONS timed calls per row, as a list of (LABEL . TEXT) and (LABEL . LINES)."
  (let ((*print-pretty* nil))
    (list
     (cons "date" (format nil "~A (UTC, before the measurements)" (utc-timestamp start-time)))
     (cons "command" (process-command-line))
     (cons "directory" (namestring (uiop:getcwd)))
     (cons "SCF_BENCH_REPETITIONS" (let ((text (repetitions-variable)))
                                     (if text (format nil "~S" text) "not set")))
     (cons "source revision" (source-revision))
     (cons "Lisp" (format nil "~A ~A" (lisp-implementation-type) (lisp-implementation-version)))
     (cons "ASDF" (asdf:asdf-version))
     (cons "dynamic space" (format nil "~D MiB" (floor (sb-ext:dynamic-space-size)
                                                      (* 1024 1024))))
     (cons "GC" (format nil "a collection every ~D bytes consed (bytes-consed-between-gcs)"
                        (sb-ext:bytes-consed-between-gcs)))
     (cons "operating system" (operating-system))
     (cons "CPU model" (cpu-model))
     (cons "logical CPUs" (cpu-count))
     (cons "CPU frequency" "not recorded")
     (cons "load average" (format nil "~A (at start; the end of the output gives it at the ~
                                      end; a busy machine makes timings unreliable)"
                                  (load-average)))
     (cons "build"
           (append
            (list (concatenate 'string "scacchiforge, scacchiforge/test (the expected perft "
                               "counts) and scacchiforge/bench recompiled by this run, every "
                               "warning an error (tools/load.lisp)")
                  (format nil "global optimize policy: ~(~{~S~^ ~}~)" *global-policy*))
            (loop for (text directory names) in (build-policy)
                  collect (format nil "~A in ~A~{ ~A~}" text directory names))
            (list (format nil "~(~S~) declared inside each bit-utility kernel"
                          (cons 'optimize *kernel-optimization*))
                  (format nil "~(~S~) declared inside each slider kernel"
                          (cons 'optimize scf-opt:*optimized-policy*))
                  "every other file: no OPTIMIZE proclamation of its own")))
     (cons "slider attacks"
           (list (format nil "~(~A~) in the build (SCF_SLIDERS ~:[not set~;~:*~S~]; the ~
                              implementations are~{ ~(~A~)~^,~})"
                         (scf-opt:slider-interface-implementation)
                         (sb-ext:posix-getenv "SCF_SLIDERS") scf-opt:*slider-implementations*)
                 (format nil "this run compiles the hot path (~{~A~^ ~} in src/optimized/) ~
                              once with each implementation into build/bench/, with the policy ~
                              above, loads the files of an implementation before each of its ~
                              perft passes, and compiles them again with the build's ~
                              implementation at the end"
                         scf-opt:*hot-path-files*)
                 (format nil "magic numbers: seed #x~16,'0X, committed in ~
                              src/optimized/magic-numbers.lisp (make magics); tables of ~D ~
                              (magic) and ~D (fixed-magic) 64-bit entries"
                         scf-opt:+magic-seed+ scf-opt:+magic-table-size+
                         scf-opt:+fixed-magic-table-size+)))
     (cons "engine" (concatenate 'string "perft of the reference engine and of the optimized "
                                 "level with each slider implementation; alpha-beta of the "
                                 "optimized level at fixed depth, in the generator's move order, "
                                 "with the classical evaluation (docs/valutazione.md); the "
                                 "classical evaluation of both levels; bit utilities and slider "
                                 "attacks of the optimized level; one thread; no transposition "
                                 "table; the evaluation's weights are the untuned constants of "
                                 "docs/valutazione.md, no other parameters"))
     (cons "seeds" (format nil "inputs (MAKE-RNG seed):~{ ~(~A~) ~D~^,~} (evaluation: the random ~
                                legal positions of the evaluation rows); perft and search have ~
                                no random input"
                           (loop for (kind . seed) in *input-seeds* append (list kind seed))))
     (cons "positions"
           (list (concatenate 'string "perft: positions by name from STANDARD-POSITION-FEN "
                              "(FENs below the perft table), expected counts from "
                              "*MAIN-PERFT-TABLE* (tests/test-perft.lisp)")
                 (format nil "search: positions of tests/search-signature.sexp by name (FENs ~
                              below the search table), expected value and node count from that ~
                              file, depth ~D"
                         (getf (scf-test:read-search-signature) :depth))
                 (format nil "evaluation: ~D random legal positions reached from the perft ~
                              positions in at most 120 random plies"
                         *evaluation-positions*)
                 "no position or opening file"))
     (cons "repetitions"
           (list (format nil "microbenchmarks: ~D timed call~:P per row, after an untimed ~
                              warm-up call; the median is reported, min and max show the spread"
                         repetitions)
                 (format nil "perft: ~D timed sample~:P per row and pass, each of as many ~
                              calls as reach ~,1F s of CPU by a calibration call, after an ~
                              untimed warm-up call; the reference in one pass, the optimized ~
                              layer in two per slider implementation, in the order~{ ~(~A~)~}; ~
                              the median over the samples is reported with min and max, and ~
                              the median of each pass"
                         repetitions *perft-sample-seconds* (slider-pass-order))
                 (format nil "search: ~D timed sample~:P per row, each of as many searches as ~
                              reach ~,1F s of CPU by a calibration call, after an untimed ~
                              warm-up search, with the build's slider implementation; the ~
                              median is reported with min and max"
                         repetitions *search-sample-seconds*)
                 (format nil "evaluation: ~D timed sample~:P per row and pass, each of as many ~
                              passes over the positions as reach ~,1F s of CPU by a ~
                              calibration pass, after an untimed warm-up pass; the three rows ~
                              in two interleaved passes, A B C C B A; the median over the ~
                              samples is reported with min and max, and the median of each pass"
                         repetitions *evaluation-sample-seconds*)))
     (cons "timers" (concatenate 'string "CPU: GET-INTERNAL-RUN-TIME (CPU time of the "
                                 "process); wall: GET-INTERNAL-REAL-TIME"))
     (cons "GC counters" (concatenate 'string "SB-EXT:GET-BYTES-CONSED and "
                                      "SB-EXT:*GC-RUN-TIME*, summed over the timed calls of "
                                      "each row")))))
