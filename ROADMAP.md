# Roadmap

Detailed timeline for ScacchiForge development phases.

## Phase 0: Foundation (REOPENED)

**Status**: Skeleton only. The code does not load and has never been run. The durations in this file are placeholders, not estimates.

- [x] Repository and build system (ASDF)
- [x] Reference implementation skeleton
- [x] Test framework with FiveAM
- [x] Benchmark infrastructure
- [x] Design documentation
- [x] Contribution guidelines
- [x] GitHub Actions CI/CD

**Deliverables**:
- Reference chess model (correctness oracle)
- PERFT test framework
- Move generation tests
- Position make/unmake tests
- 22 files, 1793 LOC

**Code Quality**: Unverified. The system fails to load (a structure named `position` violates the COMMON-LISP package lock).

---

## 🔄 Phase 1: Core Move Generation (NEXT)

**Target**: 2-4 weeks

### Implementation
1. **Complete reference move generation**
   - [ ] All piece types: pawns, knights, bishops, rooks, queens, kings
   - [ ] Special moves: castling, en passant, promotion
   - [ ] Check detection
   - [ ] Legal move filtering (no king in check)
   - [ ] Edge case testing (pins, discovered checks, etc.)

2. **PERFT Verification Suite**
   - [ ] Standard starting position PERFT (depth 1-4)
   - [ ] Kiwipete position (depth 1-3)
   - [ ] Additional FEN test positions
   - [ ] Random position fuzzer

3. **Correctness Testing**
   - [ ] All PERFT tests pass
   - [ ] Castling legality verified
   - [ ] En passant handling correct
   - [ ] Promotion logic sound
   - [ ] Pin and check detection accurate

### Benchmarks
- [ ] Move generation speed (nodes/sec)
- [ ] Pseudo-legal vs. legal move ratio
- [ ] Position evaluation time

### Quality Gate
- All PERFT tests pass
- No correctness bugs
- Code review completed

---

## 🔄 Phase 2: Optimized Representation

**Target**: 2-3 weeks

### Implementation
1. **Bitboard Position**
   - [ ] 12 piece bitboards (6 types × 2 colors)
   - [ ] Occupancy bitboards
   - [ ] Castling rights (4-bit encoding)
   - [ ] En passant (8-bit encoding)
   - [ ] Side to move

2. **Bitboard Utilities**
   - [ ] popcount (hardware-accelerated when available)
   - [ ] Bit scanning (LSB, MSB)
   - [ ] Bit manipulation (set, clear, test)
   - [ ] PEXT/PDEP (fallback implementations)

3. **Differential Testing**
   - [ ] Every position in optimized = reference
   - [ ] Millions of random positions tested
   - [ ] Move lists identical between implementations

### Verification
- [ ] Differential testing clean on entire PERFT tree
- [ ] Random fuzzing passes
- [ ] No memory corruption
- [ ] Zobrist hashes match

### Quality Gate
- Differential testing 100% pass rate
- No correctness issues
- Code review completed

---

## 🔄 Phase 3: Search Baseline

**Target**: 3-4 weeks

### Implementation
1. **Core Search Algorithms**
   - [ ] Negamax with minimax equivalence
   - [ ] Alpha-Beta pruning
   - [ ] Iterative deepening (ID)
   - [ ] Principal Variation (PV) tracking

2. **Search Utilities**
   - [ ] Depth limiting
   - [ ] Node counting
   - [ ] Time management (basic)
   - [ ] Best move extraction

3. **Evaluation**
   - [ ] Material count (pawn=1, N/B=3, R=5, Q=9)
   - [ ] [Phase 4: Classical evaluation deferred]

### Benchmarks
- [ ] NPS at various depths
- [ ] Branch factor measurement
- [ ] Search tree statistics

### Quality Gate
- Alpha-Beta correctness verified
- Search produces legal moves
- Performance baseline established

---

## Phase 4: Transposition & Ordering

**Target**: 3-4 weeks

### Implementation
1. **Zobrist Hashing**
   - [ ] Position hash computation
   - [ ] Incremental updates
   - [ ] Hash collision handling

2. **Transposition Table**
   - [ ] Entry storage and retrieval
   - [ ] Score interpretation (exact/lower/upper)
   - [ ] Depth-based replacement policy
   - [ ] Hit rate tracking

3. **Move Ordering**
   - [ ] TT move priority
   - [ ] PV move from iteration
   - [ ] Killer moves
   - [ ] History heuristic
   - [ ] Remaining quiet moves

### Benchmarks
- [ ] TT hit rate
- [ ] Move ordering quality (cutoff rate)
- [ ] Speed improvement vs. baseline

### Quality Gate
- TT correctness verified (no value corruption)
- Alpha-Beta still produces minimax value
- Performance gain measurable

---

## Phase 5: Classical Evaluation

**Target**: 2-3 weeks

### Implementation
1. **Piece-Square Tables**
   - [ ] Value for each piece on each square
   - [ ] Opening vs. endgame weights

2. **Positional Features**
   - [ ] Piece mobility
   - [ ] Pawn structure (passed, doubled, isolated)
   - [ ] King safety
   - [ ] Center control

3. **Incremental Computation**
   - [ ] Update evaluation on move (not full recompute)
   - [ ] Material count caching
   - [ ] Pawn structure caching

### Benchmarks
- [ ] Evaluation accuracy on test positions
- [ ] Strength improvement vs. material-only
- [ ] Evaluation speed

### Quality Gate
- Evaluation deterministic
- Incremental updates verified vs. full computation
- Strength improvement measurable (Elo)

---

## Phase 6: Quiescence Search

**Target**: 2 weeks

### Implementation
1. **Quiescence Search**
   - [ ] Capture generation and search
   - [ ] Promotion handling
   - [ ] Delta pruning (optional checks)

2. **Static Exchange Evaluation**
   - [ ] Capture value estimation
   - [ ] Move filtering (SEE-based)

### Quality Gate
- Quiescence prevents horizon effect
- Search produces reasonable positions at leaf
- Performance acceptable

---

## Phase 7: Aggressive Pruning

**Target**: 4-6 weeks

### Implementation
1. **Null Move Pruning**
   - [ ] Basic null move
   - [ ] Verification search
   - [ ] Zugzwang detection
   - [ ] Adaptive reduction

2. **Futility Pruning**
   - [ ] Leaf-level futility
   - [ ] Extended futility
   - [ ] Razoring

3. **Late Move Reductions**
   - [ ] Depth reduction based on move index
   - [ ] Adaptive reduction function
   - [ ] Re-search if needed

4. **Singular Extensions**
   - [ ] TT-based singular move detection
   - [ ] Depth extension for clear best move

### Benchmarks
- [ ] Depth improvement per unit time
- [ ] Cutoff rate
- [ ] Strength improvement

### Quality Gate
- No correctness regression
- Measurable strength improvement
- Stability verified (no horizon effect)

---

## Phase 8: Alternative Searches (Research)

**Target**: 4-8 weeks

### Experimental Implementation
1. **Principal Variation Search (PVS/NegaScout)**
2. **MTD(f) - Memory-enhanced Test Driver**
3. **SSS* and DUAL***
4. **Transposition-Driven Search**

### Comparative Study
- [ ] Nodes count for same position
- [ ] Time performance
- [ ] Strength (fixed depth)
- [ ] Practical trade-offs

### Outcome
- Decide which search strategy to advance
- Document findings
- Implement best-performing variant in main engine

---

## Phase 9: Profiling & Cache Optimization

**Target**: 3-4 weeks

### Analysis
1. **CPU Profiling**
   - [ ] Hotspot identification
   - [ ] Instruction cache efficiency
   - [ ] Branch prediction analysis

2. **Memory Profiling**
   - [ ] Cache miss rate
   - [ ] Memory bandwidth usage
   - [ ] False sharing in parallel (future)

3. **Optimization**
   - [ ] Data structure layout
   - [ ] Loop unrolling
   - [ ] SIMD candidates identification

### Benchmarks
- [ ] Cache hit rates
- [ ] Cycles per instruction (CPI)
- [ ] Memory throughput

### Quality Gate
- Measurable performance improvement
- No correctness regression
- Profile baseline established for future work

---

## Phase 10: NNUE Evaluation

**Target**: 4-6 weeks

### Implementation
1. **Neural Network Training**
   - [ ] Feature extraction (piece-on-square)
   - [ ] Network architecture (sparse input → small hidden → output)
   - [ ] Training on self-play or labeled positions

2. **NNUE Integration**
   - [ ] Feature representation
   - [ ] Sparse feature update
   - [ ] Accumulator for incremental computation
   - [ ] Inference path

3. **Optimization**
   - [ ] Fast accumulator update
   - [ ] Inference pipeline

### Benchmarks
- [ ] Evaluation speed vs. classical
- [ ] Strength improvement
- [ ] Memory usage

### Quality Gate
- NNUE output matches classical in test positions
- Incremental updates verified
- Strength improvement demonstrated

---

## Phase 11: SIMD Acceleration

**Target**: 4-6 weeks

### Implementation
1. **Bitboard Operations**
   - [ ] POPCNT instruction dispatch
   - [ ] PEXT/PDEP via BMI2
   - [ ] AVX2 move generation (optional)

2. **NNUE SIMD**
   - [ ] AVX2 accumulator update
   - [ ] AVX2 inference
   - [ ] VNNI support (if available)

3. **CPU Feature Detection**
   - [ ] Runtime detection
   - [ ] Dispatch to appropriate kernel
   - [ ] Graceful fallback

4. **Platform Support**
   - [ ] x86-64 (Intel/AMD)
   - [ ] ARM64 (NEON, SVE)
   - [ ] macOS Apple Silicon

### Benchmarks
- [ ] SIMD vs. generic throughput
- [ ] Latency improvement
- [ ] Scaling across platforms

### Quality Gate
- Correctness verified on all platforms
- Performance improvement measurable
- Fallback path used automatically when needed

---

## Phase 12: Automated Tuning

**Target**: 3-4 weeks

### Implementation
1. **Parameter Optimization**
   - [ ] Grid search
   - [ ] Coordinate descent
   - [ ] SPSA (Simultaneous Perturbation Stochastic Approximation)
   - [ ] Bayesian optimization

2. **Automated Self-Play**
   - [ ] Match scheduler
   - [ ] Opening book
   - [ ] Statistical significance testing
   - [ ] Result tracking

3. **Search Parameter Tuning**
   - [ ] Null move reduction factors
   - [ ] LMR reduction function
   - [ ] Futility margins
   - [ ] Pruning thresholds

### Benchmarks
- [ ] Time to convergence
- [ ] Final tuned strength vs. hand-tuned
- [ ] Sensitivity analysis

### Quality Gate
- Tuned parameters improve strength
- Reproducible
- Documentation complete

---

## Phase 13: Parallel Search

**Target**: 4-6 weeks

### Implementation
1. **Shared Transposition Table**
   - [ ] Thread-safe TT
   - [ ] Lock-free structures (if feasible)
   - [ ] Contention analysis

2. **Lazy SMP**
   - [ ] Parallel iterative deepening
   - [ ] Worker threads with shared TT
   - [ ] Scaling analysis

3. **NUMA Support (Optional)**
   - [ ] NUMA-aware memory allocation
   - [ ] Local vs. shared TT
   - [ ] Scalability on multi-socket systems

### Benchmarks
- [ ] Speedup vs. single-thread
- [ ] Scaling efficiency
- [ ] Strength stability

### Quality Gate
- Parallel search produces same results (same seed)
- Measurable speedup
- Stability verified

---

## Phase 14: Learned Search (Research)

**Target**: Ongoing

### Experimental
1. **Learned Move Ordering**
   - [ ] Train neural network on move quality
   - [ ] Integration with existing ordering

2. **Learned Reductions**
   - [ ] Learn when/how much to reduce
   - [ ] Adaptive reduction policy

3. **Learned Extensions**
   - [ ] Identify when to extend
   - [ ] Position-aware extension decisions

### Outcome
- Document effectiveness
- Compare with hand-tuned heuristics
- Integrate if beneficial

---

## Metrics for Success

### Correctness
- [ ] 100% PERFT pass rate (all tested positions)
- [ ] Differential testing clean
- [ ] No crashes or undefined behavior
- [ ] All edge cases handled

### Performance
- [ ] Elo progression tracked
- [ ] NPS growth with hardware
- [ ] Benchmark reproducibility

### Engineering
- [ ] Code quality high
- [ ] Test coverage > 80%
- [ ] Documentation current
- [ ] Performance profiles analyzed

### Research
- [ ] Techniques classified and justified
- [ ] Experimental results documented
- [ ] Trade-offs understood
- [ ] Reproducible

---

## Timeline Summary

| Phase | Effort | Status |
|-------|--------|--------|
| 0: Foundation | 1 week | ✅ DONE |
| 1: Core | 2-4 weeks | 🔄 NEXT |
| 2: Optimized | 2-3 weeks | 📅 |
| 3: Search | 3-4 weeks | 📅 |
| 4: Transposition | 3-4 weeks | 📅 |
| 5: Classical Eval | 2-3 weeks | 📅 |
| 6: Quiescence | 2 weeks | 📅 |
| 7: Pruning | 4-6 weeks | 📅 |
| 8: Alternatives | 4-8 weeks | 📅 |
| 9: Profiling | 3-4 weeks | 📅 |
| 10: NNUE | 4-6 weeks | 📅 |
| 11: SIMD | 4-6 weeks | 📅 |
| 12: Tuning | 3-4 weeks | 📅 |
| 13: Parallel | 4-6 weeks | 📅 |
| 14: Learned | Ongoing | 📅 |

**Total Estimate**: 6-12 months for full implementation to Phase 13.
