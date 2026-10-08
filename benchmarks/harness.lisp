;;;; harness.lisp -- repeated measurement and the median.
;;;;
;;;; Each timed call records four counters: CPU time from GET-INTERNAL-RUN-TIME, wall-clock
;;;; time from GET-INTERNAL-REAL-TIME, bytes allocated from SB-EXT:GET-BYTES-CONSED and
;;;; garbage-collector time from SB-EXT:*GC-RUN-TIME*. GET-INTERNAL-RUN-TIME counts the CPU
;;;; time of the whole process, all threads included, on the one platform where this was
;;;; checked (docs/limiti-e-rischi.md, QA-09). The benchmarks themselves run on one thread.

(in-package #:scacchiforge.bench)

(defun median (numbers)
  "The median of the non-empty list NUMBERS (the mean of the two middle ones when even)."
  (let* ((sorted (sort (copy-list numbers) #'<))
         (count (length sorted))
         (middle (floor count 2)))
    (if (oddp count)
        (nth middle sorted)
        (/ (+ (nth (1- middle) sorted) (nth middle sorted)) 2))))

(defun internal-seconds (units)
  "UNITS of internal time, as seconds."
  (/ units (float internal-time-units-per-second 1d0)))

(defun seconds-since (start)
  "Seconds of wall-clock time elapsed since the internal real time START."
  (internal-seconds (- (get-internal-real-time) start)))

(defun counters ()
  "The current CPU time, wall-clock time, bytes consed and GC time, as a list."
  (list (get-internal-run-time) (get-internal-real-time) (sb-ext:get-bytes-consed)
        sb-ext:*gc-run-time*))

(defun counters-since (start)
  "A sample plist of what the counters gained since START, a list made by COUNTERS: :CPU and
:WALL seconds, :CONSED bytes and :GC seconds."
  (destructuring-bind (cpu wall consed gc) (counters)
    (destructuring-bind (cpu0 wall0 consed0 gc0) start
      (list :cpu (internal-seconds (- cpu cpu0))
            :wall (internal-seconds (- wall wall0))
            :consed (- consed consed0)
            :gc (internal-seconds (- gc gc0))))))

(defun measure (thunk repetitions)
  "Call THUNK REPETITIONS times and return the list of samples, one per call in call order
(see COUNTERS-SINCE). The first value THUNK returns on the last call is the second value."
  (let ((samples '()) (value nil))
    (dotimes (i repetitions)
      (let ((start (counters)))
        (setf value (funcall thunk))
        (push (counters-since start) samples)))
    (values (nreverse samples) value)))

(defun sample-values (samples key)
  "The value of KEY in each of SAMPLES."
  (mapcar (lambda (sample) (getf sample key)) samples))

(defun spread (samples key)
  "The median, minimum and maximum of KEY over SAMPLES, as three values."
  (let ((values (sample-values samples key)))
    (values (median values) (reduce #'min values) (reduce #'max values))))

(defun total (samples key)
  "The sum of KEY over SAMPLES."
  (reduce #'+ (sample-values samples key)))

(defun repetitions-variable ()
  "The text of the environment variable SCF_BENCH_REPETITIONS, or NIL when it is not set."
  (sb-ext:posix-getenv "SCF_BENCH_REPETITIONS"))

(defun repetitions-setting ()
  "How many repetitions to run: SCF_BENCH_REPETITIONS if it is a positive integer, else 5."
  (let* ((text (repetitions-variable))
         (value (and text (every #'digit-char-p text) (plusp (length text))
                     (parse-integer text))))
    (if (and value (plusp value)) value 5)))
