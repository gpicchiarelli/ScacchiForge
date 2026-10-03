# ScacchiForge

A high-performance chess engine research platform in Common Lisp / SBCL.

## Philosophy

**Optimize the work required to make a strong decision.** Not operations per second. Not depth. Not memory consumption.

Every reduction in computational work must be classified and measured:

- **[THEOREM]** Provably correct
- **[EXACT]** Algorithmically exact without loss of correctness  
- **[BOUNDED]** Mathematically interpretable bounds
- **[PROBABILISTIC]** Correct with explicit probabilistic guarantees
- **[HEURISTIC]** Effective without general guarantees
- **[EMPIRICAL]** Validated experimentally
- **[LEARNED]** Parameters or functions obtained through training

The ultimate goal: **max Strength / CPU-time** with verifiable correctness and reproducible benchmarks.

## Architecture

```
scacchiforge/
├── src/
│   ├── reference/          # Oracle: simple, correct, readable
│   │   ├── types.lisp
│   │   ├── board.lisp
│   │   ├── movegen.lisp
│   │   ├── position.lisp
│   │   ├── eval.lisp
│   │   └── search.lisp
│   └── optimized/          # Optimized: must match reference
│       ├── bitboards.lisp
│       └── board-opt.lisp
├── tests/                  # Verification
├── benchmarks/             # Measurement infrastructure
├── research/               # Experimental layer
└── doc/                    # Design documentation
```

## Phases

### Phase 0: Foundation ✓
- Repository, build system, structure, tests, benchmarks
- Reference implementation model

### Phase 1: Core (In Progress)
- Bitboards, Position, Move, legal move generation
- PERFT verification
- Make/unmake correctness

### Phase 2: Search Baseline
- Negamax, Alpha-Beta, Iterative Deepening
- Classical evaluation (material + position)

### Phase 3: Transposition & Ordering
- Zobrist hashing
- Transposition Table
- Move ordering (TT, PV, killer, history)

### Phase 4: Quiescence & Tactics
- Quiescence search with SEE
- Aspiration windows

### Phase 5: Aggressive Pruning
- Null Move Pruning, Futility, Razoring
- Late Move Reductions (adaptive)
- Singular Extensions

### Phase 6: Alternative Searches
- PVS/NegaScout, MTD(f), SSS*, DUAL*
- Comparative benchmark

### Phase 7: Profiling & Cache Optimization
- CPU cache locality analysis
- Memory traffic reduction

### Phase 8: NNUE Evaluation
- Incremental feature extraction
- Fast inference

### Phase 9: SIMD Acceleration
- AVX2, AVX-512, VNNI
- NEON, SVE/SVE2 for ARM
- CPU feature detection

### Phase 10: Automated Tuning
- SPSA, Bayesian optimization
- Self-play optimization

### Phase 11: Parallel Search
- Lazy SMP, parallel move generation
- NUMA-aware architecture

### Phase 12: Learned Search
- Learned move ordering
- Learned reductions and extensions
- Adaptive pruning policies

## Building

```bash
# Load system in SBCL
(asdf:load-system :scacchiforge)

# Run tests
(asdf:test-system :scacchiforge)

# Run microbenchmarks
(asdf:load-system :scacchiforge-bench)
(scacchiforge-bench:run-microbench)

# Run engine benchmarks
(scacchiforge-bench:run-engine-bench)
```

## Reference Implementation

The `scacchiforge.reference` package is the oracle:
- Simple, readable, obviously correct
- Exhaustive correctness checks (PERFT, fuzzing, differential testing)
- All optimizations must be verified against reference

## Testing Strategy

1. **PERFT** - Leaf node count verification (gate: must pass)
2. **Legal move generation** - Fuzzing with random positions
3. **Differential testing** - Reference vs optimized
4. **Search regression** - Consistency across commits
5. **Strength measurement** - Elo, fixed-time matches

## Performance Infrastructure

### Microbenchmarks
- Individual operations: popcount, PEXT, move generation, make/unmake
- Measured in isolation with CPU affinity

### Engine Benchmarks
- Nodes per second (not primary metric)
- Depth per second
- Strength at fixed time
- TT hit rate, cutoff rate, branching factor
- CPU utilization, memory, allocation, GC pauses

## Key Design Decisions

1. **Reference first** - Correctness is not negotiable. Optimize only against verified oracle.
2. **Deduplication as architecture** - Transposition tables, Zobrist hashing, incremental computation, caching are first-class design concerns.
3. **Measurement-driven** - No optimization without benchmarks. No benchmarks without understanding what we're measuring.
4. **CPU-aware but portable** - Feature detection for modern x86 and ARM. Always maintain portable fallback.
5. **Trade-off clarity** - Understand memory/speed tradeoffs. Measure cache effects. Don't blindly allocate more.

## License

BSD-2-Clause

## Contributing

This is a research platform. Design decisions are documented and justified. Experimental changes must:
1. Not break existing tests
2. Include differential testing against reference
3. Be benchmarked with clear metrics
4. Include reproducible test cases
