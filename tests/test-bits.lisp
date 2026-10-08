;;;; test-bits.lisp -- the optimized bit utilities against deliberately naive versions.

(in-package #:scacchiforge.test)

(defun naive-popcount (x)
  "Count the set bits of X one by one."
  (loop for index below 64 count (logbitp index x)))

(defun naive-lsb (x)
  "Index of the lowest set bit of X by scanning up, or -1."
  (loop for index below 64 when (logbitp index x) return index finally (return -1)))

(defun naive-msb (x)
  "Index of the highest set bit of X by scanning down, or -1."
  (loop for index from 63 downto 0 when (logbitp index x) return index finally (return -1)))

(defun naive-pext (x mask)
  "Parallel bit extract by scanning every position."
  (let ((result 0) (out 0))
    (dotimes (index 64 result)
      (when (logbitp index mask)
        (when (logbitp index x)
          (setf result (logior result (ash 1 out))))
        (incf out)))))

(defun naive-pdep (x mask)
  "Parallel bit deposit by scanning every position."
  (let ((result 0) (in 0))
    (dotimes (index 64 result)
      (when (logbitp index mask)
        (when (logbitp in x)
          (setf result (logior result (ash 1 index))))
        (incf in)))))

(defun random-u64-sample (rng count)
  "COUNT 64-bit values of mixed density: random, sparse, dense, single-bit, plus edge cases."
  (let ((values (list 0 1 2 (ash 1 63) (1- (ash 1 64)) (1- (ash 1 63)) #xAAAAAAAAAAAAAAAA
                      #x5555555555555555 #xFF #xFF00000000000000 #x8000000000000001)))
    (dotimes (i count)
      (push (case (mod i 5)
              (0 (rng-next-u64 rng))
              (1 (logand (rng-next-u64 rng) (rng-next-u64 rng) (rng-next-u64 rng)))
              (2 (logior (rng-next-u64 rng) (rng-next-u64 rng) (rng-next-u64 rng)))
              (3 (ash 1 (rng-below rng 64)))
              (t (ldb (byte (rng-below rng 65) 0) (rng-next-u64 rng))))
            values))
    values))

(deftest :bits popcount-matches-the-naive-count
  (dolist (x (random-u64-sample (make-rng 1) 20000))
    (let ((expected (naive-popcount x)))
      (is-eql expected (scf-opt:popcount64 x) "popcount64 of ~X" x)
      (is-eql expected (scf-opt:popcount64-swar x) "popcount64-swar of ~X" x))))

(deftest :bits lsb-and-msb-match-the-naive-scan
  (dolist (x (random-u64-sample (make-rng 2) 20000))
    (is-eql (naive-lsb x) (scf-opt:lsb64 x) "lsb64 of ~X" x)
    (is-eql (naive-lsb x) (scf-opt:lsb64-debruijn x) "lsb64-debruijn of ~X" x)
    (is-eql (naive-msb x) (scf-opt:msb64 x) "msb64 of ~X" x))
  (is-eql -1 (scf-opt:lsb64 0))
  (is-eql -1 (scf-opt:msb64 0))
  (is-eql -1 (scf-opt:lsb64-debruijn 0)))

(deftest :bits single-bit-edge-cases
  (dotimes (index 64)
    (let ((x (ash 1 index)))
      (is-eql index (scf-opt:lsb64 x))
      (is-eql index (scf-opt:msb64 x))
      (is-eql index (scf-opt:lsb64-debruijn x))
      (is-eql 1 (scf-opt:popcount64 x))
      (is-eql 0 (scf-opt:clear-lowest-bit x)))))

(deftest :bits de-bruijn-constant-gives-a-perfect-index
  (is-eql 64 (length (remove-duplicates
                      (loop for index below 64
                            collect (ash (ldb (byte 64 0) (* (ash 1 index) scf-opt:+debruijn64+))
                                         -58))))
          "the 64 isolated bits map to 64 different table slots"))

(deftest :bits pext-matches-the-naive-version
  (let ((rng (make-rng 3)))
    (dolist (mask (random-u64-sample (make-rng 4) 4000))
      (let ((x (rng-next-u64 rng)))
        (is-eql (naive-pext x mask) (scf-opt:pext64 x mask) "pext64 ~X ~X" x mask)))
    (is-eql 0 (scf-opt:pext64 #xFFFFFFFFFFFFFFFF 0))
    (is-eql #xFFFFFFFFFFFFFFFF (scf-opt:pext64 #xFFFFFFFFFFFFFFFF #xFFFFFFFFFFFFFFFF))
    (is-eql #b1011 (scf-opt:pext64 #b1010100 #b1110100) "a small worked example")))

(deftest :bits pdep-matches-the-naive-version
  (let ((rng (make-rng 5)))
    (dolist (mask (random-u64-sample (make-rng 6) 4000))
      (let ((x (rng-next-u64 rng)))
        (is-eql (naive-pdep x mask) (scf-opt:pdep64 x mask) "pdep64 ~X ~X" x mask)))
    (is-eql 0 (scf-opt:pdep64 #xFFFFFFFFFFFFFFFF 0))
    (is-eql #b100100 (scf-opt:pdep64 #b101 #b1110100) "a small worked example")))

(deftest :bits pext-and-pdep-are-inverse-on-the-mask
  (let ((rng (make-rng 7)))
    (dolist (mask (random-u64-sample (make-rng 8) 2000))
      (let* ((x (rng-next-u64 rng))
             (width (scf-opt:popcount64 mask))
             (low (ldb (byte width 0) x)))
        (is-eql (logand x mask) (scf-opt:pdep64 (scf-opt:pext64 x mask) mask))
        (is-eql low (scf-opt:pext64 (scf-opt:pdep64 x mask) mask))))))

(deftest :bits set-bit-iteration
  (dolist (x (random-u64-sample (make-rng 9) 2000))
    (let ((visited '()))
      (scf-opt:do-set-bits (index x)
        (push index visited))
      (is-equal (loop for index below 64 when (logbitp index x) collect index)
                (nreverse visited) "do-set-bits of ~X" x)
      (is-equal (loop for index below 64 when (logbitp index x) collect index)
                (scf-opt:bit-indices x)))))

(deftest :bits do-set-bits-returns-its-result-form-and-handles-zero
  (let ((count 0)
        (empty (parse-integer "0")))
    (is-eql :done (scf-opt:do-set-bits (index empty :done) (incf count index)))
    (is-eql 0 count)))
