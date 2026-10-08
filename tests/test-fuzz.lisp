;;;; test-fuzz.lisp -- the legal-position fuzzer itself.

(in-package #:scacchiforge.test)

(deftest :fuzz a-playout-can-be-replayed-from-its-moves
  (let ((rng (make-rng 1001)))
    (dolist (fen *fuzz-fens*)
      (let ((start (fen-position fen)))
        (multiple-value-bind (final plies outcome moves)
            (scf-ref:random-playout start rng 90)
          (declare (ignore outcome))
          (is-eql plies (length moves))
          (let ((replay (scf-ref:clone-position start)))
            (dolist (move moves)
              (is (scf-ref:move-legal-p replay move) "a recorded move is legal when replayed")
              (scf-ref:make-move replay move))
            (is (scf-ref:positions-equal-p replay final) "replay of ~A" fen)))))))

(deftest :fuzz a-playout-does-not-touch-its-start-position
  (let* ((start (scf-ref:start-position))
         (before (snapshot start)))
    (scf-ref:random-playout start (make-rng 5) 60)
    (is (same-state-p start before 0))))

(deftest :fuzz random-legal-positions-are-legal-and-varied
  (let ((rng (make-rng 77))
        (fens (make-hash-table :test 'equal)))
    (dotimes (i 400)
      (let ((pos (scf-ref:random-legal-position *fuzz-fens* rng 100)))
        (is-eql nil (scf-ref:position-invariant-violations pos :moves nil))
        (setf (gethash (scf-ref:position-to-fen pos) fens) t)))
    (is (> (hash-table-count fens) 300) "the sample is varied: ~D distinct positions"
        (hash-table-count fens))))

(deftest :fuzz large-playout-sample-keeps-every-invariant
  (let ((result (scf-ref:fuzz-playouts *fuzz-fens* 987654321 :games 60 :max-plies 150)))
    (note "~D playouts, ~D positions, ~D checkmates, ~D stalemates"
          (getf result :games) (getf result :positions)
          (getf result :checkmates) (getf result :stalemates))
    (is (> (getf result :positions) 30000))))
