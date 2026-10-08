;;;; test-optimized-perft.lisp -- perft of the optimized layer.
;;;;
;;;; The expected counts are read from the tables of tests/test-perft.lisp, *MAIN-PERFT-TABLE*
;;;; and *SPECIAL-PERFT-TABLE*, the same ones the reference is judged by; where each count
;;;; comes from is written in that file's header. Nothing is copied here. MAKE TEST runs the
;;;; standard depths, MAKE PERFT-DEEP adds the deep ones.

(in-package #:scacchiforge.test)

(defun check-optimized-perft-count (name fen depth expected)
  "Run the optimized perft on FEN to DEPTH, compare with EXPECTED, and report the value."
  (let* ((bbp (scf-opt:bitboard-from-reference (fen-position fen)))
         (before (scf-opt:bitboard-clone bbp))
         (start (get-internal-real-time))
         (actual (scf-opt:bitboard-perft bbp depth))
         (seconds (/ (- (get-internal-real-time) start) (float internal-time-units-per-second))))
    (note "~A depth ~D: ~D~:[ (expected ~D)~;~*~] ~,2F s" name depth actual
          (eql actual expected) expected seconds)
    (is-eql expected actual "optimized perft of ~A at depth ~D" name depth)
    (is (and (scf-opt:bitboard-equal-p bbp before) (zerop (scf-opt:bbp-ply bbp)))
        "optimized perft left ~A unchanged" name)))

(deftest :optimized-perft main-table
  (loop for (name fen standard deep) in *main-perft-table*
        do (loop for (depth expected) in (append standard (when (deep-profile-p) deep))
                 do (check-optimized-perft-count name fen depth expected))))

(deftest :optimized-perft special-positions
  (loop for (name fen nil standard deep) in *special-perft-table*
        do (loop for (depth expected) in (append standard (when (deep-profile-p) deep))
                 do (check-optimized-perft-count name fen depth expected))))

(deftest :optimized-perft depth-zero-is-one-and-negative-depth-is-refused
  (let ((bbp (scf-opt:bitboard-from-reference (scf-ref:start-position))))
    (is-eql 1 (scf-opt:bitboard-perft bbp 0))
    (signals type-error (scf-opt:bitboard-perft bbp -1))
    (signals type-error (scf-opt:bitboard-perft-divide bbp 0))))

(deftest :optimized-perft divide-agrees-with-the-reference-divide
  ;; Divide is how a perft difference is located; here the two layers must give the same
  ;; count for every root move, not only the same total.
  (loop for (name fen) in (append *main-perft-table* *special-perft-table*)
        do (let ((pos (fen-position fen))
                 (bbp (scf-opt:bitboard-from-reference (fen-position fen))))
             (loop for depth from 1 to 2
                   do (multiple-value-bind (reference reference-total)
                          (scf-ref:perft-divide pos depth)
                        (multiple-value-bind (optimized optimized-total)
                            (scf-opt:bitboard-perft-divide bbp depth)
                          (is-eql reference-total optimized-total "divide total, ~A d~D"
                                  name depth)
                          (is-equal (sort (copy-list reference) #'< :key #'car)
                                    (sort (copy-list optimized) #'< :key #'car)
                                    "divide of ~A at depth ~D" name depth)))))))
