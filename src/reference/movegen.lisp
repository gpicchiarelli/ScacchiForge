(in-package :scacchiforge.reference)

(defun generate-pseudo-legal-moves (pos)
  "Generate all pseudo-legal moves in a position.
   [EXACT] All pseudo-legal moves are generated.
   Legality check (not leaving king in check) must be done by caller."
  (let ((moves nil))
    (loop for sq from 0 to 63
          when (and (position-occupied-p pos sq)
                    (eq (position-color pos sq) (position-side-to-move pos)))
          do (dolist (move (piece-pseudo-legal-moves pos sq))
               (push move moves)))
    moves))

(defun piece-pseudo-legal-moves (pos sq)
  "Generate all pseudo-legal moves for piece at square sq."
  (let ((piece-info (position-piece pos sq)))
    (unless piece-info (return-from piece-pseudo-legal-moves nil))
    (let* ((color (car piece-info))
           (piece (cdr piece-info)))
      (case piece
        (:pawn (pawn-pseudo-legal-moves pos color sq))
        (:knight (knight-pseudo-legal-moves pos sq))
        (:bishop (bishop-pseudo-legal-moves pos sq))
        (:rook (rook-pseudo-legal-moves pos sq))
        (:queen (queen-pseudo-legal-moves pos sq))
        (:king (king-pseudo-legal-moves pos sq))))))

(defun pawn-pseudo-legal-moves (pos color sq)
  "Generate pawn moves."
  (let ((moves nil)
        (direction (if (eq color +white+) 1 -1))
        (start-rank (if (eq color +white+) 1 6))
        (promo-rank (if (eq color +white+) 7 0)))
    ;; Single push
    (let ((target (+ sq (* direction 8))))
      (when (and (square-valid-p target)
                 (not (position-occupied-p pos target)))
        (if (= (rank target) promo-rank)
            ;; Promotions
            (dolist (promo '(:knight :bishop :rook :queen))
              (push (%make-move sq target :piece +pawn+ :promoted promo) moves))
            ;; Regular push
            (push (%make-move sq target :piece +pawn+) moves))))
    ;; Double push from starting position
    (when (= (rank sq) start-rank)
      (let ((target (+ sq (* direction 16)))
            (intermediate (+ sq (* direction 8))))
        (when (and (not (position-occupied-p pos intermediate))
                   (not (position-occupied-p pos target)))
          (push (%make-move sq target :piece +pawn+
                           :flags +move-flag-double-push+) moves))))
    ;; Captures
    (dolist (df '(-1 1))
      (let ((target (+ sq (* direction 8) df)))
        (when (and (square-valid-p target)
                   (not (eq (mod target 8) (mod sq 8)))
                   (position-occupied-p pos target)
                   (not (eq (position-color pos target) color)))
          (if (= (rank target) promo-rank)
              ;; Capture promotion
              (dolist (promo '(:knight :bishop :rook :queen))
                (push (%make-move sq target :piece +pawn+ :promoted promo
                                 :flags +move-flag-capture+) moves))
              ;; Regular capture
              (push (%make-move sq target :piece +pawn+
                               :flags +move-flag-capture+) moves)))))
    ;; En passant
    (when (and (position-en-passant pos)
               (= target (position-en-passant pos)))
      (let ((target (position-en-passant pos))
            (captured (- target (* direction 8))))
        (when (and (square-valid-p target)
                   (not (eq (mod target 8) (mod sq 8))))
          (push (%make-move sq target :piece +pawn+
                           :flags +move-flag-en-passant+) moves))))
    moves))

(defun knight-pseudo-legal-moves (pos sq)
  "Generate knight moves."
  (let ((moves nil))
    (dolist (target (knight-attack-squares sq))
      (cond
        ((not (position-occupied-p pos target))
         (push (%make-move sq target :piece +knight+) moves))
        ((not (eq (position-color pos target) (position-color pos sq)))
         (push (%make-move sq target :piece +knight+
                          :flags +move-flag-capture+) moves))))
    moves))

(defun bishop-pseudo-legal-moves (pos sq)
  "Generate bishop moves."
  (sliding-pseudo-legal-moves pos sq +bishop+
                              '((-1 -1) (-1 1) (1 -1) (1 1))))

(defun rook-pseudo-legal-moves (pos sq)
  "Generate rook moves."
  (sliding-pseudo-legal-moves pos sq +rook+
                              '((-1 0) (1 0) (0 -1) (0 1))))

(defun queen-pseudo-legal-moves (pos sq)
  "Generate queen moves."
  (append (sliding-pseudo-legal-moves pos sq +queen+
                                      '((-1 -1) (-1 1) (1 -1) (1 1)))
          (sliding-pseudo-legal-moves pos sq +queen+
                                      '((-1 0) (1 0) (0 -1) (0 1)))))

(defun sliding-pseudo-legal-moves (pos from piece directions)
  "Generate moves for sliding piece."
  (let ((moves nil)
        (f (file from))
        (r (rank from))
        (color (position-color pos from)))
    (dolist (dir directions)
      (let ((df (first dir))
            (dr (second dir)))
        (loop for i from 1 to 8
              do (let ((nf (+ f (* i df)))
                       (nr (+ r (* i dr))))
                  (cond
                    ((not (and (>= nf 0) (<= nf 7) (>= nr 0) (<= nr 7)))
                     (return))
                    ((position-occupied-p pos (make-square nf nr))
                     (let ((target (make-square nf nr)))
                       (if (not (eq (position-color pos target) color))
                           (push (%make-move from target :piece piece
                                            :flags +move-flag-capture+) moves))
                       (return)))
                    (t
                     (let ((target (make-square nf nr)))
                       (push (%make-move from target :piece piece) moves))))))))
    moves))

(defun king-pseudo-legal-moves (pos sq)
  "Generate king moves including castling."
  (let ((moves nil)
        (color (position-color pos sq)))
    ;; Regular king moves
    (dolist (target (king-attack-squares sq))
      (cond
        ((not (position-occupied-p pos target))
         (push (%make-move sq target :piece +king+) moves))
        ((not (eq (position-color pos target) color))
         (push (%make-move sq target :piece +king+
                          :flags +move-flag-capture+) moves))))
    ;; Castling
    (dolist (castling-move (castling-moves pos color sq))
      (push castling-move moves))
    moves))

(defun castling-moves (pos color king-sq)
  "Generate castling moves if legal."
  (let ((moves nil)
        (rank (rank king-sq))
        (castling-rights (position-castling-rights pos)))
    ;; Kingside castling
    (when (aref castling-rights (if (eq color +white+) 0 2))
      (let ((rook-sq (if (eq color +white+) 7 63))
            (f-sq (if (eq color +white+) 5 61))
            (g-sq (if (eq color +white+) 6 62)))
        (when (and (position-occupied-p pos rook-sq)
                   (eq (position-piece pos rook-sq) (cons color +rook+))
                   (not (position-occupied-p pos f-sq))
                   (not (position-occupied-p pos g-sq)))
          (push (%make-move king-sq g-sq :piece +king+
                           :flags +move-flag-castling+) moves))))
    ;; Queenside castling
    (when (aref castling-rights (if (eq color +white+) 1 3))
      (let ((rook-sq (if (eq color +white+) 0 56))
            (d-sq (if (eq color +white+) 3 59))
            (c-sq (if (eq color +white+) 2 58))
            (b-sq (if (eq color +white+) 1 57)))
        (when (and (position-occupied-p pos rook-sq)
                   (eq (position-piece pos rook-sq) (cons color +rook+))
                   (not (position-occupied-p pos d-sq))
                   (not (position-occupied-p pos c-sq))
                   (not (position-occupied-p pos b-sq)))
          (push (%make-move king-sq c-sq :piece +king+
                           :flags +move-flag-castling+) moves))))
    moves))

(defun filter-legal-moves (pos moves)
  "Filter pseudo-legal moves to only legal moves.
   [EXACT] Removes moves that leave king in check."
  (loop for move in moves
        when (legal-move-p pos move)
        collect move))

(defun legal-move-p (pos move)
  "Check if move is legal (doesn't leave king in check)."
  (let ((test-pos (copy-position pos)))
    (make-move-on-position test-pos move)
    (not (king-in-check-p test-pos))))

(defun position-in-check-p (pos)
  "Check if current side to move is in check."
  (king-in-check-p pos))

(defun king-in-check-p (pos)
  "Check if the side to move's king is in check."
  (let ((king-sq (find-king pos (position-side-to-move pos))))
    (when king-sq
      (opponent-attacks-square-p pos king-sq))))

(defun find-king (pos color)
  "Find the square of the king of given color."
  (loop for sq from 0 to 63
        when (and (position-occupied-p pos sq)
                  (eq (position-piece pos sq) (cons color +king+)))
        return sq))

(defun opponent-attacks-square-p (pos sq)
  "Check if opponent's pieces attack the given square."
  (let ((opponent (opposite-color (position-side-to-move pos))))
    (loop for attacker-sq from 0 to 63
          when (and (position-occupied-p pos attacker-sq)
                    (eq (position-color pos attacker-sq) opponent)
                    (piece-attacks-p pos attacker-sq sq))
          return t
          finally (return nil))))
