(in-package :scacchiforge-bench)

(defun run-engine-bench ()
  "Run engine benchmarks.
   [TODO] Implement:
   - NPS measurement
   - Depth/time measurement
   - TT hit rate
   - Cutoff rate
   - Strength at fixed time
   - Nodes / solved position"
  (format t "Engine benchmark suite~%"))

(defun measure-nps (pos depth iterations)
  "Measure nodes per second."
  (let ((total-nodes 0)
        (start (get-internal-run-time)))
    (loop repeat iterations
          do (incf total-nodes (perft pos depth)))
    (let ((elapsed (/ (- (get-internal-run-time) start)
                      (float internal-time-units-per-second))))
      (/ total-nodes elapsed))))

(defun benchmark-search (pos depth)
  "Benchmark search at depth.
   Returns: (depth nodes time-ms nps)"
  (let ((start (get-internal-run-time)))
    (let ((result (search-at-depth pos depth)))
      (let ((elapsed (- (get-internal-run-time) start)))
        (list depth 0 elapsed 0)))))
