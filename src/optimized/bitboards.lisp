(in-package :scacchiforge.optimized)

(deftype bitboard () '(unsigned-byte 64))

(defun popcount (bb)
  "Count set bits in bitboard.
   [EXACT] Correct bit count.
   Dispatch to CPU instruction when available.
   [TODO] POPCNT instruction dispatch."
  (let ((count 0))
    (loop while (> bb 0)
          do (incf count (logand bb 1))
             (setf bb (ash bb -1)))
    count))

(defun lsb (bb)
  "Find position of least significant bit.
   [EXACT] Returns position of LSB (0-63).
   Returns -1 if bb is 0."
  (if (zerop bb)
      -1
      (logcount (logand bb (- bb 1)))))

(defun msb (bb)
  "Find position of most significant bit.
   [EXACT] Returns position of MSB (0-63).
   Returns -1 if bb is 0."
  (if (zerop bb)
      -1
      (- 63 (logcount (lognot bb)))))

(defun bit-scan-forward (bb)
  "Scan from LSB to find first set bit."
  (lsb bb))

(defun bit-scan-backward (bb)
  "Scan from MSB to find first set bit."
  (msb bb))

(defun popcount-intel (bb)
  "POPCNT instruction on Intel x86.
   [EXACT] CPU-native instruction.
   [TODO] FFI to native code."
  (popcount bb))

(defun pext (bb mask)
  "Parallel Bit Extract (BMI2).
   [EXACT] Extract bits according to mask.
   [TODO] FFI to PEXT instruction."
  ;; Fallback: naive implementation
  (let ((result 0)
        (result-bit 0))
    (loop for source-bit from 0 to 63
          when (logtest mask (ash 1 source-bit))
          do (when (logtest bb (ash 1 source-bit))
               (setf result (logior result (ash 1 result-bit))))
             (incf result-bit))
    result))

(defun pdep (bb mask)
  "Parallel Bit Deposit (BMI2).
   [EXACT] Deposit bits according to mask.
   [TODO] FFI to PDEP instruction."
  ;; Fallback: naive implementation
  (let ((result 0)
        (source-bit 0))
    (loop for dest-bit from 0 to 63
          when (logtest mask (ash 1 dest-bit))
          do (when (logtest bb (ash 1 source-bit))
               (setf result (logior result (ash 1 dest-bit))))
             (incf source-bit))
    result))
