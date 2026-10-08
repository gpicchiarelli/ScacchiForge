;;;; test-optimized-tt.lisp -- the transposition table of the optimized layer
;;;; (src/optimized/transposition.lisp) and the searches that use it (src/optimized/search.lisp).
;;;;
;;;; Suite optimized-tt. The data word packs and unpacks every field; the constructor refuses a
;;;; size that is not a power of two, an unknown policy and an unknown mode; each replacement
;;;; policy follows its rule. Every entry a search leaves in the table states a true bound on the
;;;; value of its position at its depth, mate scores included, judged by the baseline alpha-beta
;;;; searched from that position. In verification mode (docs/verifica.md, "Modalità di verifica
;;;; della TT") the search with the table returns exactly the value of the search without it, for
;;;; alpha-beta, PVS and NegaScout, with and without the move ordering, on the search positions,
;;;; the positions of the search signature and seeded random positions, with tables from 2 to
;;;; 65536 slots and the three policies; tiny tables force replacement and many positions into
;;;; one bucket; a key mask of a few bits forces false hits, which are discarded and counted. In
;;;; normal mode the same mask makes the search read moves of other positions: they are rejected,
;;;; never played, and the search ends without an error. Positions reached by two paths, with
;;;; different clocks and histories, share one key and one value: the option of QA-02 (no
;;;; repetition and no fifty-move rule in the search).
;;;;
;;;; The value of the search without the table is BASELINE-VALUE: the baseline alpha-beta of the
;;;; optimized layer, whose value the suite differential compares with the reference's. The
;;;; principal variations of the searches with a table in verification mode are replayed by the
;;;; reference (PRINCIPAL-VARIATION-PROBLEMS, tests/test-search.lisp).

(in-package #:scacchiforge.test)

;;; --- helpers shared with tests/test-optimized-pvs.lisp ------------------------------------

(defvar *baseline-values* (make-hash-table :test #'equal)
  "BASELINE-VALUE by (FEN . DEPTH): a cache of a pure function of its arguments.")

(defun baseline-value (fen depth)
  "The value of the baseline alpha-beta of the optimized layer for FEN at DEPTH: the value of
the search without ordering and without transposition table."
  (let ((key (cons fen depth)))
    (or (gethash key *baseline-values*)
        (setf (gethash key *baseline-values*)
              (scf-opt:bitboard-alpha-beta-search (optimized-position fen) depth)))))

(defun random-search-fens (seed count)
  "COUNT FENs of seeded random legal positions (SCF-REF:RANDOM-LEGAL-POSITION from *FUZZ-FENS*,
up to 120 plies), drawn with the generator seeded with SEED."
  (let ((rng (make-rng seed)))
    (loop repeat count
          collect (scf-ref:position-to-fen
                   (scf-ref:random-legal-position *fuzz-fens* rng 120)))))

(defun tt-statistic (statistics key)
  "The value of KEY in the :TT part of the search STATISTICS."
  (getf (getf statistics :tt) key))

(defun phase-3-search (fen depth &rest options)
  "BITBOARD-SEARCH of the optimized layer on a fresh position for FEN at DEPTH with OPTIONS:
score, best move, nodes, principal variation and statistics."
  (apply #'scf-opt:bitboard-search (optimized-position fen) depth options))

(defun search-value-problems (label fen depth score line)
  "The problems of a search of FEN at DEPTH that returned SCORE and LINE: SCORE differs from
BASELINE-VALUE, or the reference does not accept LINE (PRINCIPAL-VARIATION-PROBLEMS). A list
of strings, each starting with LABEL."
  (append (unless (= score (baseline-value fen depth))
            (list (format nil "~A: ~A depth ~D: value ~D, without the table ~D" label fen depth
                          score (baseline-value fen depth))))
          (mapcar (lambda (problem) (format nil "~A: ~A depth ~D: ~A" label fen depth problem))
                  (principal-variation-problems (fen-position fen) depth score line
                                                #'scf-ref:evaluate-classical))))

;;; --- the table itself -------------------------------------------------------------------

(deftest :optimized-tt the-data-word-packs-every-field
  (let ((moves (scf-opt:bitboard-legal-moves
                (optimized-position (scf-ref:standard-position-fen "kiwipete"))))
        (checked 0))
    (dolist (move (list* +no-move+ (encode-move 63 63 5 31) moves))
      (dolist (score '(-32768 -30000 -29001 -1 0 1 29001 30000 32767))
        (dolist (depth '(0 1 62 127))
          (dolist (bound (list scf-opt:+bitboard-tt-exact+ scf-opt:+bitboard-tt-lower+
                               scf-opt:+bitboard-tt-upper+))
            (dolist (generation '(0 1 255))
              (let ((word (scf-opt::pack-tt-word move score depth bound generation)))
                (incf checked)
                (unless (and (= move (scf-opt::tt-word-move word))
                             (= score (scf-opt::tt-word-score word))
                             (= depth (scf-opt::tt-word-depth word))
                             (= bound (scf-opt::tt-word-bound word))
                             (= generation (scf-opt::tt-word-generation word))
                             (< word (expt 2 53)))
                  (record-failure "word ~X does not give back ~S" word
                                  (list move score depth bound generation)))))))))
    (incf *assertions*)
    (note "~D field combinations packed and unpacked" checked)))

(deftest :optimized-tt the-constructor-checks-its-arguments
  (signals error (scf-opt:make-bitboard-transposition-table :entries 1))
  (signals error (scf-opt:make-bitboard-transposition-table :entries 3))
  (signals error (scf-opt:make-bitboard-transposition-table :entries 1000))
  (signals error (scf-opt:make-bitboard-transposition-table :policy :lru))
  (signals error (scf-opt:make-bitboard-transposition-table :mode :fast))
  (dolist (policy scf-opt:*bitboard-tt-policies*)
    (dolist (mode scf-opt:*bitboard-tt-modes*)
      (let ((table (scf-opt:make-bitboard-transposition-table :entries 64 :policy policy
                                                              :mode mode)))
        (is-eql 64 (scf-opt:bitboard-tt-size table))
        (is-eql policy (scf-opt:bitboard-tt-policy table))
        (is-eql mode (scf-opt:bitboard-tt-mode table))
        (is-eql 0 (scf-opt:bitboard-tt-occupancy table)))))
  (let ((table (scf-opt:make-bitboard-transposition-table)))
    (is-eql scf-opt:+bitboard-tt-default-entries+ (scf-opt:bitboard-tt-size table))
    (is-eql :two-slot (scf-opt:bitboard-tt-policy table))
    (is-eql :normal (scf-opt:bitboard-tt-mode table))))

(deftest :optimized-tt store-probe-and-clear
  (dolist (mode scf-opt:*bitboard-tt-modes*)
    (let* ((table (scf-opt:make-bitboard-transposition-table :entries 1024 :mode mode))
           (start (optimized-position scf-ref:*start-fen*))
           (kiwipete (optimized-position (scf-ref:standard-position-fen "kiwipete")))
           (move (first (scf-opt:bitboard-legal-moves start))))
      (is-eql -1 (scf-opt:bitboard-tt-probe table start) "~A: an empty table" mode)
      (scf-opt:bitboard-tt-store table start 3 -29997 scf-opt:+bitboard-tt-lower+ move)
      (is (>= (scf-opt:bitboard-tt-probe table start) 0) "~A: the stored position" mode)
      (is-eql -1 (scf-opt:bitboard-tt-probe table kiwipete) "~A: another position" mode)
      (is-equal (list :move move :score -29997 :depth 3 :bound :lower :generation 0)
                (scf-opt:bitboard-tt-entry table start) "~A" mode)
      (is-equal '(3 1 0) (list (getf (scf-opt:bitboard-tt-statistics table) :probes)
                               (getf (scf-opt:bitboard-tt-statistics table) :hits)
                               (getf (scf-opt:bitboard-tt-statistics table) :false-hits))
                "~A: probes, hits and false hits; BITBOARD-TT-ENTRY counts nothing" mode)
      (is-eql 1 (scf-opt:bitboard-tt-new-search table))
      (scf-opt:bitboard-tt-store table start 2 7 scf-opt:+bitboard-tt-exact+ +no-move+)
      (is-equal (list :move +no-move+ :score 7 :depth 2 :bound :exact :generation 1)
                (scf-opt:bitboard-tt-entry table start)
                "~A: the slot of the same position is written again" mode)
      (is-eql 1 (scf-opt:bitboard-tt-occupancy table))
      (scf-opt:bitboard-tt-clear table)
      (is-eql nil (scf-opt:bitboard-tt-entry table start) "~A: cleared" mode)
      (is-eql 0 (getf (scf-opt:bitboard-tt-statistics table) :stores)))))

(defun distinct-positions (count)
  "COUNT bitboard positions with distinct placements: the start position and its children."
  (let ((start (optimized-position scf-ref:*start-fen*)))
    (cons start
          (loop for move in (scf-opt:bitboard-legal-moves start)
                repeat (1- count)
                collect (let ((child (scf-opt:bitboard-clone start)))
                          (scf-opt:bitboard-make-move child move)
                          (scf-opt:bitboard-clone child))))))

(deftest :optimized-tt each-replacement-policy-follows-its-rule
  ;; The key mask 0 sends every position to bucket 0 with the key 0; in verification mode the
  ;; independent check still tells the positions apart, so that each store meets the policy.
  (destructuring-bind (a b c d) (distinct-positions 4)
    (flet ((table (policy)
             (scf-opt:make-bitboard-transposition-table :entries 2 :policy policy
                                                        :mode :verification :key-mask 0))
           (depth-of (table position)
             (getf (scf-opt:bitboard-tt-entry table position) :depth))
           (store (table position depth)
             (scf-opt:bitboard-tt-store table position depth 0 scf-opt:+bitboard-tt-exact+
                                        +no-move+)))
      ;; Always: one slot per bucket, always replaced.
      (let ((table (table :always)))
        (store table a 3)
        (store table b 1)
        (is-eql nil (depth-of table a) "always: A replaced")
        (is-eql 1 (depth-of table b) "always: B stored")
        (is-eql -1 (scf-opt:bitboard-tt-probe table a) "always: the probe of A")
        (is-eql 1 (getf (scf-opt:bitboard-tt-statistics table) :false-hits)
                "always: the probe of A met B, whose key is equal, and counted a false hit"))
      ;; Depth-preferred: a shallower entry of the same generation is refused.
      (let ((table (table :depth-preferred)))
        (store table a 3)
        (store table b 1)
        (is-eql 3 (depth-of table a) "depth-preferred: A kept")
        (is-eql nil (depth-of table b) "depth-preferred: B refused")
        (is-eql 1 (getf (scf-opt:bitboard-tt-statistics table) :refused-stores))
        (store table a 1)
        (is-eql 1 (depth-of table a) "depth-preferred: the same position is written again")
        (store table b 1)
        (is-eql 1 (depth-of table b) "depth-preferred: as deep, replaces")
        (store table a 2)
        (is-eql 2 (depth-of table a) "depth-preferred: deeper, replaces")
        (store table b 0)
        (is-eql nil (depth-of table b) "depth-preferred: shallower, refused")
        (scf-opt:bitboard-tt-new-search table)
        (store table b 0)
        (is-eql 0 (depth-of table b) "depth-preferred: an older generation gives way"))
      ;; Two slots: the first depth-preferred, the second always replaced.
      (let ((table (table :two-slot)))
        (store table a 3)
        (store table b 1)
        (is-equal '(3 1) (list (depth-of table a) (depth-of table b)) "two-slot: A and B")
        (store table c 2)
        (is-equal '(3 nil 2) (list (depth-of table a) (depth-of table b) (depth-of table c))
                  "two-slot: C takes the second slot")
        (store table d 5)
        (is-equal '(nil nil 2 5) (list (depth-of table a) (depth-of table b) (depth-of table c)
                                       (depth-of table d))
                  "two-slot: D, deeper, takes the first slot")
        (is-eql 2 (getf (scf-opt:bitboard-tt-statistics table) :overwrites)
                "two-slot: C over B, D over A")))))

;;; --- what the searches store ------------------------------------------------------------

(defun reachable-positions (fen plies)
  "Bitboard positions reached from FEN in 0 to PLIES plies, each once, as a list of clones."
  (let ((seen (make-hash-table))
        (positions '()))
    (labels ((walk (bbp remaining)
               (unless (gethash (scf-opt:bbp-key bbp) seen)
                 (setf (gethash (scf-opt:bbp-key bbp) seen) t)
                 (push (scf-opt:bitboard-clone bbp) positions))
               (when (plusp remaining)
                 (dolist (move (scf-opt:bitboard-legal-moves bbp))
                   (scf-opt:bitboard-make-move bbp move)
                   (walk bbp (1- remaining))
                   (scf-opt:bitboard-unmake-move bbp)))))
      (walk (optimized-position fen) plies))
    (nreverse positions)))

(deftest :optimized-tt every-entry-is-a-true-bound
  ;; After an iterative deepening with a table in verification mode, every entry of every
  ;; position within two plies of the root is a true statement about the value of that position
  ;; at the entry's depth, which the baseline alpha-beta searched from the position gives: equal
  ;; for an exact entry, at most the score for an upper bound, at least for a lower bound. The
  ;; score is relative to the position, so a mate score counts its plies from it. (In normal
  ;; mode a cutoff on a deeper entry can put the value of a deeper search in a shallower entry:
  ;; that is why normal mode is [HEURISTIC] on the value at fixed depth.)
  (let ((entries 0)
        (mates 0))
    (dolist (case '(("rook-ladder" 4) ("back-rank" 3) ("scholars-mate" 3) ("pos3" 4)
                    ("promotion" 4) ("startpos" 3)))
      (destructuring-bind (name depth) case
        (let ((fen (or (cdr (assoc name *search-positions* :test #'string=))
                       (scf-ref:standard-position-fen name))))
          (dolist (algorithm '(:alpha-beta :pvs :negascout))
            (let ((mode :verification))
              (let ((table (scf-opt:make-bitboard-transposition-table :entries 65536
                                                                      :mode mode)))
                (scf-opt:bitboard-iterative-deepening (optimized-position fen) depth
                                                      :algorithm algorithm :ordering t
                                                      :tt table)
                (dolist (bbp (reachable-positions fen 2))
                  (let ((entry (scf-opt:bitboard-tt-entry table bbp)))
                    (when entry
                      (destructuring-bind (&key score ((:depth entry-depth)) bound
                                           &allow-other-keys)
                          entry
                        (let ((value (scf-opt:bitboard-alpha-beta-search bbp entry-depth)))
                          (incf entries)
                          (when (scf-opt:bitboard-mate-score-p score)
                            (incf mates))
                          (incf *assertions*)
                          (unless (ecase bound
                                    (:exact (= value score))
                                    (:lower (>= value score))
                                    (:upper (<= value score)))
                            (record-failure "~A ~A ~A: ~A entry ~D at depth ~D, value ~D"
                                            name algorithm mode bound score entry-depth
                                            value)))))))))))))
    (note "~D entries compared with the value of their position, ~D of them mate scores"
          entries mates)))

;;; --- verification mode ------------------------------------------------------------------

(deftest :optimized-tt verification-mode-equals-the-search-without-table
  ;; Docs/verifica.md, "Modalità di verifica della TT": with the table in verification mode the
  ;; value is the value without it, for each search of Phase 3, with and without ordering. The
  ;; principal variation of each search is replayed by the reference. In this mode a hit is the
  ;; same position, so its move is legal: no TT move is rejected.
  (let ((searches 0)
        (hits 0)
        (cutoffs 0)
        (false-hits 0)
        (random-fens (random-search-fens 20261009 30)))
    (flet ((check (label fen depth algorithm ordering)
             (let ((table (scf-opt:make-bitboard-transposition-table :mode :verification)))
               (multiple-value-bind (score move nodes line statistics)
                   (phase-3-search fen depth :algorithm algorithm :ordering ordering :tt table)
                 (declare (ignore move nodes))
                 (incf searches)
                 (incf hits (tt-statistic statistics :hits))
                 (incf cutoffs (tt-statistic statistics :cutoffs))
                 (incf false-hits (tt-statistic statistics :false-hits))
                 (incf *assertions*)
                 (dolist (problem (search-value-problems
                                   (format nil "~A ~(~A~)~:[~; ordered~]" label algorithm
                                           ordering)
                                   fen depth score line))
                   (record-failure "~A" problem))
                 (is-eql 0 (tt-statistic statistics :rejected-moves)
                         "~A ~A depth ~D: a TT move rejected in verification mode"
                         label algorithm depth)))))
      (dolist (algorithm '(:alpha-beta :pvs :negascout))
        (dolist (ordering '(nil t))
          (loop for (name . fen) in *search-positions*
                do (loop for depth from 1 to 4
                         do (check name fen depth algorithm ordering)))
          (dolist (fen random-fens)
            (check "random" fen 3 algorithm ordering))))
      (loop for (name fen) in *search-signature-positions*
            do (check name fen *search-signature-depth* :pvs t)))
    (note "~D searches with a table of ~D slots in verification mode: ~D hits, ~D cutoffs, ~D ~
           false hits; 30 random positions (seed 20261009) at depth 3"
          searches scf-opt:+bitboard-tt-default-entries+ hits cutoffs false-hits)))

(deftest :optimized-tt tiny-tables-force-replacement
  ;; Tables of 2 to 4096 slots, with each policy: most positions share a bucket with others, and
  ;; entries are replaced or refused all the time. The value must not change.
  (let ((searches 0)
        (overwrites 0)
        (refused 0))
    (dolist (entries '(2 16 256 4096))
      (dolist (policy scf-opt:*bitboard-tt-policies*)
        (let ((replaced 0))
          (loop for (name . fen) in *search-positions*
                do (loop for depth from 1 to 4
                         do (let ((table (scf-opt:make-bitboard-transposition-table
                                          :entries entries :policy policy
                                          :mode :verification)))
                              (multiple-value-bind (score move nodes line statistics)
                                  (phase-3-search fen depth :algorithm :pvs :ordering t
                                                            :tt table)
                                (declare (ignore move nodes))
                                (incf searches)
                                (incf replaced (+ (tt-statistic statistics :overwrites)
                                                  (tt-statistic statistics :refused-stores)))
                                (incf overwrites (tt-statistic statistics :overwrites))
                                (incf refused (tt-statistic statistics :refused-stores))
                                (incf *assertions*)
                                (dolist (problem (search-value-problems
                                                  (format nil "~D slots ~(~A~)" entries policy)
                                                  fen depth score line))
                                  (record-failure "~A" problem))))))
          (when (<= entries 16)
            (is (plusp replaced) "~D slots ~A: no entry was replaced or refused"
                entries policy)))))
    (note "~D searches with PVS and ordering: ~D entries replaced by another position, ~D ~
           stores refused" searches overwrites refused)))

(deftest :optimized-tt forced-false-hits-are-discarded-and-counted
  ;; QA-01: a key mask of 8 or 4 bits makes many positions share a key. In verification mode
  ;; each such hit fails the independent check: it is discarded and counted, its move is never
  ;; read, and the value is the value without the table.
  (let ((false-hits 0)
        (searches 0))
    (dolist (mask '(#xFF #xF))
      (dolist (algorithm '(:pvs :negascout))
        (loop for (name . fen) in *search-positions*
              do (loop for depth from 1 to 4
                       do (let ((table (scf-opt:make-bitboard-transposition-table
                                        :entries 4096 :mode :verification :key-mask mask)))
                            (multiple-value-bind (score move nodes line statistics)
                                (phase-3-search fen depth :algorithm algorithm :ordering t
                                                          :tt table)
                              (declare (ignore move nodes))
                              (incf searches)
                              (incf false-hits (tt-statistic statistics :false-hits))
                              (incf *assertions*)
                              (dolist (problem (search-value-problems
                                                (format nil "mask ~X ~(~A~)" mask algorithm)
                                                fen depth score line))
                                (record-failure "~A" problem))
                              (is-eql 0 (tt-statistic statistics :rejected-moves)
                                      "mask ~X ~A ~A depth ~D: a foreign move was read"
                                      mask algorithm name depth)))))))
    (is (plusp false-hits) "no false hit was forced")
    (note "~D searches with a key mask of 8 and 4 bits: ~D false hits discarded and counted"
          searches false-hits)))

(defun line-legality-problems (fen line)
  "The moves of LINE that the reference does not accept as legal where they are played from
FEN, as a list of strings."
  (let ((copy (fen-position fen)))
    (dolist (move line '())
      (unless (scf-ref:move-legal-p copy move)
        (return (list (format nil "~A is not legal in ~A" (move-to-string move)
                              (scf-ref:position-to-fen copy)))))
      (scf-ref:make-move copy move))))

(deftest :optimized-tt false-hits-in-normal-mode-never-play-an-illegal-move
  ;; INV-C6: in normal mode the same key mask makes the search read the entries, and the moves,
  ;; of other positions. A move that is not legal where it is read is rejected and counted;
  ;; the search plays only moves of the generator, ends without an error, leaves the position
  ;; as it was, and its line is legal. Its value may differ from the value without the table:
  ;; the note counts how often.
  (let ((rejected 0)
        (different 0)
        (searches 0))
    (loop for (name . fen) in *search-positions*
          do (loop for depth from 1 to 4
                   do (let* ((table (scf-opt:make-bitboard-transposition-table
                                     :entries 4096 :key-mask #xFF))
                             (bbp (optimized-position fen))
                             (before (scf-opt:bitboard-clone bbp)))
                        (multiple-value-bind (score move nodes line statistics)
                            (scf-opt:bitboard-search bbp depth :algorithm :pvs :ordering t
                                                               :tt table)
                          (declare (ignore move nodes))
                          (incf searches)
                          (incf rejected (tt-statistic statistics :rejected-moves))
                          (unless (= score (baseline-value fen depth))
                            (incf different))
                          (is (and (scf-opt:bitboard-equal-p bbp before)
                                   (zerop (scf-opt:bbp-ply bbp)))
                              "~A depth ~D: the position changed" name depth)
                          (is-equal '() (line-legality-problems fen line)
                                    "~A depth ~D" name depth)))))
    (is (plusp rejected) "no TT move was rejected: the test did not reach INV-C6")
    (note "~D searches in normal mode with a key mask of 8 bits: ~D TT moves rejected as not ~
           legal, ~D values different from the value without the table"
          searches rejected different)))

(deftest :optimized-tt altered-entries-never-play-an-illegal-move
  ;; An entry altered by hand: every position within one ply of the root holds a move that is
  ;; not legal there (a1 to h8), at depth 0, which no search of depth 1 or more may cut on. The
  ;; search rejects each of those moves, plays only legal ones, and returns the value without
  ;; the table.
  (let ((bogus (encode-move 0 63 0 0)))
    (dolist (name '("startpos" "kiwipete" "pos4" "endgame"))
      (let* ((fen (or (cdr (assoc name *search-positions* :test #'string=))
                      (scf-ref:standard-position-fen name)))
             (table (scf-opt:make-bitboard-transposition-table :entries 4096)))
        (dolist (bbp (reachable-positions fen 1))
          (scf-opt:bitboard-tt-store table bbp 0 0 scf-opt:+bitboard-tt-exact+ bogus))
        (multiple-value-bind (score move nodes line statistics)
            (phase-3-search fen 3 :algorithm :pvs :ordering t :tt table)
          (declare (ignore move nodes))
          (is (plusp (tt-statistic statistics :rejected-moves)) "~A: nothing rejected" name)
          (is-eql (baseline-value fen 3) score "~A: value" name)
          (is-equal '() (principal-variation-problems (fen-position fen) 3 score line
                                                      #'scf-ref:evaluate-classical)
                    "~A: variation" name))))))

(deftest :optimized-tt one-position-by-two-paths-has-one-key-and-one-value
  ;; The option of QA-02: the search detects no repetition and no fifty-move rule, so no score
  ;; depends on the path; the clocks are not in the key. The start position reached again after
  ;; Ng1-f3 Ng8-f6 Nf3-g1 Nf6-g8 has other clocks and a history with a repetition, the same key,
  ;; and, searched with the table the first search filled, the same value, found through the
  ;; table. Not the equality of verification mode: what QA-02 chooses (docs/verifica.md).
  (let* ((start (optimized-position scf-ref:*start-fen*))
         (again (optimized-position scf-ref:*start-fen*))
         (table (scf-opt:make-bitboard-transposition-table :mode :verification)))
    (dolist (text '("g1f3" "g8f6" "f3g1" "f6g8"))
      (play again text))
    (is (/= (scf-opt:bbp-halfmove start) (scf-opt:bbp-halfmove again)) "the clocks differ")
    (is-eql (scf-opt:bbp-key start) (scf-opt:bbp-key again) "one key")
    (let ((first-value (scf-opt:bitboard-search start 4 :algorithm :pvs :ordering t :tt table)))
      (scf-opt:bitboard-tt-reset-statistics table)
      (multiple-value-bind (score move nodes line statistics)
          (scf-opt:bitboard-search again 4 :algorithm :pvs :ordering t :tt table)
        (declare (ignore move nodes line))
        (is-eql first-value score "the value after the repetition")
        (is-eql (baseline-value scf-ref:*start-fen* 4) score "the value without the table")
        (is (plusp (tt-statistic statistics :cutoffs)) "the second search used the table")))))
