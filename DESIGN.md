# ScacchiForge Design Document

## Objective

Build an original chess engine in Common Lisp/SBCL as a research platform for minimax search, evaluation, and computational optimization. The goal is not to maximize arbitrary metrics (NPS, depth, memory) but to **maximize playing strength per unit of CPU time**.

## Core Principles

### 1. Correctness First
Every claim about correctness must be verifiable:
- **[THEOREM]** claims require mathematical proof
- **[EXACT]** algorithms must produce identical results to reference
- **[HEURISTIC]** techniques must be explicitly marked as approximations
- Reference implementation is the oracle for all optimizations

### 2. Deduplication as Architecture
Computation is expensive. Reuse systematically:
- **Memoization**: Transposition Tables, move ordering caches
- **Incremental computation**: Zobrist, material counts, NNUE accumulators
- **Precomputation**: Attack tables, evaluation LUTs
- **Cache locality**: Contiguous arrays, compact structures, predictable access patterns

### 3. Measurement-Driven
No optimization without data:
- Microbenchmarks for kernels (popcount, PEXT, move generation)
- Engine benchmarks for system-level impact
- Differential testing between reference and optimized
- Search regression detection across commits
- Strength measurement via self-play

### 4. Trade-Off Clarity
Every design choice has costs:
- Memory vs. speed (TT size, data layout)
- Cache coherence vs. parallelism
- Code complexity vs. performance gain
- Generality vs. specialization (x86 vs ARM, AVX vs generic)

Understand and measure each trade-off.

## Board Representation

### Reference Implementation
- Array of 64 cells
- Each cell: `(color . piece)` or `nil`
- Simple but correct, allows exhaustive verification

### Optimized Implementation (Bitboards)
- 12 bitboards: 6 pieces × 2 colors
- 3 occupancy boards: white, black, total
- Side to move, castling rights (packed)
- En passant square, halfmove clock, zobrist

**Invariant**: Bitboards must exactly match reference board state.
**Verification**: Differential testing at each position.

## Move Generation

### Pseudo-Legal Generation
[EXACT] All legal moves according to rules, *without* check verification.

Pieces generate:
- **Pawns**: Forward moves, captures, promotions, en passant, double-push from start
- **Knights**: 8 squares (with bounds checking)
- **Bishops/Rooks/Queens**: Sliding moves in 4/4/8 directions, stopped by pieces
- **Kings**: 8 adjacent squares + castling (if rights + path clear)

### Legal Filtering
[EXACT] Remove moves that leave king in check.

1. Generate pseudo-legal moves
2. For each move: simulate with make/unmake
3. Check if king is under attack
4. Keep only safe moves

**Critical**: Make/unmake must be perfectly symmetric.

### Castling Legality
- King and rook haven't moved (castling rights)
- Path between king and rook is empty
- King not in check
- King doesn't pass through check
- King doesn't land in check

### En Passant Legality
- Pawn must be on 4th rank (white) or 5th rank (black)
- Opponent must have just double-pushed
- En passant capture doesn't expose own king to check (rare but real)

## Position State

### Make/Unmake Pattern
**Reference**: Copy entire position before move, restore on unmake. Correct but slow.
**Optimized**: Incremental updates with careful undo.

**Invariant**: `unmake(make(pos, move), move) == pos` always.

### State Components
1. **Board**: Piece placement
2. **Side to move**: White or Black (toggle each move)
3. **Castling rights**: 4 bits (KQkq)
4. **En passant**: Square (0-63) or none
5. **Halfmove clock**: 50-move draw counter
6. **Fullmove**: Starting at 1, increments after black moves
7. **Zobrist key**: Incremental hash (if optimizing)

### Update Rules
- **Piece moves**: Remove from source, add to destination
- **Captures**: Remove opponent piece
- **Promotion**: Change piece type
- **Castling**: Move king and rook
- **Castling rights**: Lost if king/rook moves, or if rook captured
- **En passant**: Set if pawn double-push, else none
- **Halfmove clock**: Reset on pawn move or capture, else increment
- **Fullmove**: Increment after black moves

## Zobrist Hashing

**[EXACT]** Deterministic position hash for transposition table lookups.

Components:
- 64 squares × 12 pieces (white/black × 6 types) = 768 random 64-bit numbers
- 16 castling states (2^4) = 16 numbers
- 8 en passant files = 8 numbers (if en passant on any square)
- 1 number for "black to move"

**Update rule**: When position component changes, XOR out old, XOR in new.

**Collision handling**: Zobrist is not a checksum. Collisions may occur; handled by TT entry validation.

## Search Architecture

### Baseline: Negamax + Alpha-Beta
[THEOREM] Alpha-Beta produces minimax value with proven cutoff bounds.

```
value = -alphabeta(position, depth-1, -beta, -alpha)
if value >= beta: return beta  (fail-high: opponent won't allow this)
if value > alpha: alpha = value (better move found)
```

### Iterative Deepening
[EXACT] Search depths 1, 2, ..., max-depth sequentially.

**Benefit**: 
- Anytime algorithm (can interrupt after any depth)
- Move ordering improves as depth increases
- Asymptotically optimal with good move ordering (overhead negligible)

### Move Ordering Priority
1. TT move (if this position was analyzed before)
2. PV move (from previous iteration)
3. Winning captures (SEE > 0)
4. Promotions (especially to queen)
5. Killer moves (quiet moves that caused cutoffs at same depth)
6. History heuristic (moves that worked well before)
7. SEE-ordered (by material gain)
8. Remaining moves

**[HEURISTIC]** Killer and history are effective but not proven to be optimal.

## Quiescence Search

**Problem**: Horizon effect. Evaluation at search depth may miss upcoming tactics.

**Solution**: Continue searching forcing moves (captures, checks) at shallow depth.

**[BOUNDED]** Quiescence ensures no major tactics are hidden beyond search horizon.

**[HEURISTIC]** Decision to include checks varies; usually depth-dependent.

### Quiescence Moves
1. Captures (ordered by SEE)
2. Promotions (especially queens)
3. Checks (optional, depth-dependent)

### Pruning in Quiescence
- **Delta pruning**: `eval + material_margin < alpha` → prune (position is too bad)
- **SEE pruning**: Don't search losing captures

## Transposition Table

**[EXACT]** Memoization: Store evaluated positions to avoid re-searching.

### Entry Components
- **Hash key**: Zobrist hash (may collide; use full-key checking)
- **Value**: Evaluation or move
- **Type**: Exact, Lower bound, Upper bound
- **Depth**: Depth at which value was computed
- **Move**: Best move (if known)
- **Generation**: For aging entries

### Score Interpretation
- **Exact (PVNODE)**: Score is precise
- **Lower bound (CUTNODE)**: Score ≥ value (fail-high)
- **Upper bound (ALLNODE)**: Score ≤ value (fail-low)

### Replacement Policy
Options:
1. **Replace always**: Newest always overwrites
2. **Depth preference**: Keep entry if new depth ≤ old depth
3. **Hybrid**: Prefer deeper entries but replace old entries

**[EMPIRICAL]** Depth preference is usually better than replace-always.

## Evaluation

### Reference: Material Only
Simplest evaluation: Count material (1P=1, N=3, B=3, R=5, Q=9, K=0).

**[EXACT]** Deterministic but ignores position.

### Classical Evaluation (Phase 2)
- Material (as above)
- Piece-square tables (piece placement bonus)
- Mobility (safe squares for piece)
- King safety (attack distance to enemy)
- Pawn structure (passed, doubled, isolated)
- Threats and attacks

**[HEURISTIC]** Weights are hand-tuned.

### NNUE Evaluation (Phase 8)
Neural Network (with updated efficiently):
- Sparse input features (piece-on-square)
- Small HxHxn hidden layer
- Fast inference (few operations)
- Incremental update on move

**[LEARNED]** Weights trained on self-play or labeled positions.

## Pruning Techniques

### Null Move Pruning
[HEURISTIC] If `eval - margin >= beta`, opponent's best move in position without one move:
1. Make null move (pass)
2. Search reduced depth
3. If still fails high, null move may have been hiding a threat (zugzwang)

**[EMPIRICAL]** Fails on zugzwang positions; detect and avoid.

### Futility Pruning
[HEURISTIC] If `eval + margin < alpha` at leaf, prune.
**Idea**: Even best move won't improve alpha enough to matter.

### Razoring
[HEURISTIC] Similar to futility but at higher depths.

### Late Move Reductions
[HEURISTIC] Later-searched moves are less likely to be best; reduce depth for them.

**[EMPIRICAL]** Reduction depends on:
- Depth (deeper → more reduction)
- Move index (later → more reduction)
- Node type (All/Cut/PV)
- Move quality (captures less reduction)

### Singular Extensions
[HEURISTIC] If TT shows one move is much better, search it deeper.

## Performance Optimization

### CPU-Level
1. **Algorithm choice**: Reduce work, not improve throughput
2. **Data layout**: Cache-friendly structures, contiguous arrays
3. **Memory traffic**: Minimize bandwidth use
4. **Branch behavior**: Reduce mispredicts
5. **SIMD**: Only after algorithm/layout optimization

### x86 Features
- **POPCNT**: Bit counting (hardware)
- **BMI2**: PEXT/PDEP for bitboard extraction
- **AVX2**: 256-bit SIMD (usually stable)
- **AVX-512**: 512-bit (fast on some CPUs, slow on others; benchmark)
- **VNNI**: Vector neural network extensions (for NNUE)

### ARM Features
- **NEON**: 128-bit SIMD
- **SVE**: Scalable vectors
- **SVE2**: Extended scalable vectors

**[EXACT]** Feature detection at runtime; always maintain portable fallback.

## Research Layer

Separate from core engine for experimental techniques:
- Alternative pruning strategies
- Learned move ordering
- Learned reductions
- Adaptive aspiration windows
- Alternative search algorithms

Each experiment:
- Is reproducible and configurable
- Can be disabled without affecting base engine
- Has benchmark comparisons with baseline
- Includes rollback mechanism

## Self-Play

Strength evaluation via self-play:
- Fixed-time matches
- Fixed-node matches
- Randomized openings
- Reproducible seeds (same opening sequence)

**[EMPIRICAL]** Elo difference requires statistical significance (typically 30+ games).

## Phases Summary

| Phase | Goal | Critical Path |
|-------|------|----------------|
| 0 | Foundation | Build system, tests, benchmarks |
| 1 | Move generation | PERFT, differential testing |
| 2 | Search baseline | Negamax, Alpha-Beta, ID |
| 3 | Transposition | Zobrist, TT, move ordering |
| 4 | Tactics | Quiescence, SEE |
| 5 | Pruning | Null move, LMR, Futility |
| 6 | Alternatives | PVS, MTD(f), SSS* comparison |
| 7 | Profiling | Cache optimization, CPU dispatch |
| 8 | NNUE | Neural evaluation, incremental update |
| 9 | SIMD | AVX2, VNNI, ARM support |
| 10 | Tuning | Automated parameter optimization |
| 11 | Parallel | Lazy SMP, NUMA |
| 12 | Learned | Adaptive pruning, learned search |

## Quality Gates

Before advancing to next phase:
- ✓ All tests pass
- ✓ PERFT verified (if applicable)
- ✓ Differential testing clean
- ✓ No regressions in benchmark suite
- ✓ Commit message documents changes
