(in-package :scacchiforge-tests)

(def-suite position-suite
  :description "Position and make/unmake tests"
  :in scacchiforge-tests)

(in-suite position-suite)

(test position-creation
  "Test position creation"
  (let ((pos (make-position)))
    (is (not (null pos)))
    (is (eq (position-side-to-move pos) :white))
    (is (= (position-halfmove-clock pos) 0))))

(test position-copy
  "Test position copying"
  (let ((pos1 (make-position))
        (pos2 (copy-position (make-position))))
    (is (not (eq pos1 pos2)))
    ;; Content should be identical
    (is (eq (position-side-to-move pos1) (position-side-to-move pos2)))))

(test piece-placement
  "Test piece placement on board"
  (let ((pos (make-position)))
    ;; Check white pieces
    (is (equal (position-piece pos 0) (cons :white :rook)))
    (is (equal (position-piece pos 1) (cons :white :knight)))
    ;; Check black pieces
    (is (equal (position-piece pos 56) (cons :black :rook)))
    (is (equal (position-piece pos 57) (cons :black :knight)))))

(test make-unmake-symmetry
  "Test that make-unmake is symmetric"
  (let ((pos (make-position)))
    (let ((prior-state (copy-position pos)))
      (let ((move (first (filter-legal-moves pos (generate-pseudo-legal-moves pos)))))
        (make-move-on-position pos move)
        ;; Position should change
        (is (not (eq (position-side-to-move prior-state)
                     (position-side-to-move pos))))
        ;; Unmake
        (unmake-move-on-position pos move prior-state)
        ;; Should be back to original
        (is (eq (position-side-to-move pos) (position-side-to-move prior-state)))))))
