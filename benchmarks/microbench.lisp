(in-package :scacchiforge-bench)

(defun run-microbench ()
  "Run microbenchmarks on individual operations.
   [TODO] Implement microbenchmarks for:
   - Bitboard operations (popcount, pext, pdep)
   - Move generation
   - Make/unmake
   - Zobrist
   - TT operations"
  (format t "Microbenchmark suite~%"))

(defun benchmark-operation (name op &optional (iterations 1000000))
  "Benchmark an operation.
   Returns: (name time-ms throughput)"
  (let ((start (get-internal-run-time)))
    (loop repeat iterations do (funcall op))
    (let ((elapsed (/ (- (get-internal-run-time) start)
                      (float internal-time-units-per-second))))
      (list name elapsed (/ iterations elapsed)))))
