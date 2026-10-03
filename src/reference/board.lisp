(in-package :scacchiforge.reference)

(defun rank (sq)
  "Get rank (0-7) from square index (0-63)."
  (floor sq 8))

(defun file (sq)
  "Get file (0-7) from square index (0-63)."
  (mod sq 8))

(defun make-square (f r)
  "Create square index from file (0-7) and rank (0-7)."
  (+ (* r 8) f))

(defun square-valid-p (sq)
  "Check if square is valid (0-63)."
  (and (>= sq 0) (<= sq 63)))

(defun same-rank-p (sq1 sq2)
  "Check if two squares are on the same rank."
  (= (rank sq1) (rank sq2)))

(defun same-file-p (sq1 sq2)
  "Check if two squares are on the same file."
  (= (file sq1) (file sq2)))

(defun same-diagonal-p (sq1 sq2)
  "Check if two squares are on the same diagonal."
  (= (abs (- (file sq1) (file sq2)))
     (abs (- (rank sq1) (rank sq2)))))

(defun orthogonal-p (sq1 sq2)
  "Check if two squares are orthogonally aligned."
  (or (same-rank-p sq1 sq2) (same-file-p sq1 sq2)))

(defun horizontal-distance (sq1 sq2)
  "Get horizontal distance between squares."
  (abs (- (file sq1) (file sq2))))

(defun vertical-distance (sq1 sq2)
  "Get vertical distance between squares."
  (abs (- (rank sq1) (rank sq2))))

(defun chebyshev-distance (sq1 sq2)
  "Get king-move distance (Chebyshev distance) between squares."
  (max (horizontal-distance sq1 sq2)
       (vertical-distance sq1 sq2)))

(defun pieces-attacking-square (pos sq)
  "Return list of pieces (as (color . piece)) that attack square sq."
  (loop for src from 0 to 63
        when (and (position-occupied-p pos src)
                  (not (eq (position-color pos src) (position-color pos sq)))
                  (piece-attacks-p pos src sq))
        collect (position-piece pos src)))

(defun piece-attacks-p (pos from to)
  "Check if piece at 'from' attacks 'to'.
   [THEOREM] Correct if move-generation is correct."
  (let ((piece (position-piece from)))
    (when piece
      (member to (piece-attack-squares pos from)))))

(defun piece-attack-squares (pos from)
  "Get list of squares attacked by piece at 'from'.
   [EXACT] All squares attacked by the piece."
  (let ((piece-info (position-piece pos from))
        (sq from))
    (unless piece-info (return-from piece-attack-squares nil))
    (let* ((color (car piece-info))
           (piece (cdr piece-info)))
      (case piece
        (:pawn (pawn-attack-squares color sq))
        (:knight (knight-attack-squares sq))
        (:bishop (bishop-attack-squares pos color sq))
        (:rook (rook-attack-squares pos color sq))
        (:queen (append (rook-attack-squares pos color sq)
                        (bishop-attack-squares pos color sq)))
        (:king (king-attack-squares sq))))))

(defun pawn-attack-squares (color sq)
  "Get squares attacked by pawn."
  (let ((direction (if (eq color +white+) 1 -1))
        (result nil))
    (dolist (df '(-1 1))
      (let ((target (+ sq (* direction 8) df)))
        (when (and (square-valid-p target)
                   (not (eq (mod target 8) (mod sq 8))))
          (push target result))))
    result))

(defun knight-attack-squares (sq)
  "Get squares attacked by knight."
  (let ((offsets '((-2 -1) (-2 1) (-1 -2) (-1 2) (1 -2) (1 2) (2 -1) (2 1)))
        (result nil)
        (f (file sq))
        (r (rank sq)))
    (dolist (offset offsets)
      (let ((nf (+ f (first offset)))
            (nr (+ r (second offset))))
        (when (and (>= nf 0) (<= nf 7) (>= nr 0) (<= nr 7))
          (push (make-square nf nr) result))))
    result))

(defun king-attack-squares (sq)
  "Get squares attacked by king."
  (let ((result nil)
        (f (file sq))
        (r (rank sq)))
    (loop for df from -1 to 1
          do (loop for dr from -1 to 1
                   when (not (and (= df 0) (= dr 0)))
                   do (let ((nf (+ f df))
                            (nr (+ r dr)))
                        (when (and (>= nf 0) (<= nf 7) (>= nr 0) (<= nr 7))
                          (push (make-square nf nr) result)))))
    result))

(defun bishop-attack-squares (pos color sq)
  "Get squares attacked by bishop (considering board)."
  (sliding-attack-squares pos sq '((-1 -1) (-1 1) (1 -1) (1 1))))

(defun rook-attack-squares (pos color sq)
  "Get squares attacked by rook (considering board)."
  (sliding-attack-squares pos sq '((-1 0) (1 0) (0 -1) (0 1))))

(defun sliding-attack-squares (pos sq directions)
  "Get squares attacked by sliding piece in given directions."
  (let ((result nil)
        (f (file sq))
        (r (rank sq)))
    (dolist (dir directions)
      (let ((df (first dir))
            (dr (second dir)))
        (loop for i from 1 to 8
              do (let ((nf (+ f (* i df)))
                       (nr (+ r (* i dr))))
                  (cond
                    ((not (and (>= nf 0) (<= nf 7) (>= nr 0) (<= nr 7)))
                     (return))
                    (t
                     (let ((target (make-square nf nr)))
                       (push target result)
                       (when (position-occupied-p pos target)
                         (return)))))))))
    result))
