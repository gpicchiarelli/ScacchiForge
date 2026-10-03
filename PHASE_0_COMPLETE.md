# Phase 0: Foundation - Complete

## Status
✅ **COMPLETE** — Foundation established and committed to private GitHub repository.

## Deliverables

### Core Implementation (22 files)
- **Reference implementation**: Correct, readable oracle for all optimizations
  - Types and constants (piece, color, square, move)
  - Board utilities and square indexing
  - Complete pseudo-legal move generation
  - Legal move filtering (check detection)
  - Position state management (make/unmake)
  - Basic evaluation (material count)
  - Search baseline (Negamax, Alpha-Beta, Iterative Deepening)
  - Zobrist hashing (simplified reference)

- **Optimized skeleton**: Bitboard representation (to be implemented)
  - Bitboard utilities (popcount, LSB, MSB, PEXT, PDEP)
  - Position structure using bitboards
  - Must be verified against reference via differential testing

### Build System
- ASDF system definition with 3 subsystems:
  - `scacchiforge`: Main engine
  - `scacchiforge-test`: Test suite
  - `scacchiforge-bench`: Benchmark infrastructure

### Testing
- PERFT framework (leaf node counting verification)
- Move generation tests
- Position make/unmake symmetry tests
- Test suite using FiveAM

### Benchmarking
- Microbenchmark framework
- Engine benchmark framework
- Performance measurement structure

### Documentation (4 main documents + GitHub templates)
- **README.md**: Philosophy, principles, architecture overview
- **DESIGN.md**: Detailed algorithms, design decisions, chess domain knowledge
- **CONTRIBUTING.md**: Code style, testing standards, measurement practices
- **ROADMAP.md**: 14-phase development timeline with detailed deliverables
- **GitHub issue templates**: Correctness bugs, research proposals
- **GitHub PR template**: Quality checklist, benchmark results
- **GitHub Actions CI/CD**: Automated testing on Ubuntu + macOS

### Repository
- Private repository at `https://github.com/gpicchiarelli/ScacchiForge`
- Fully committed with 2 commits
- Branch protection-ready
- Quality gates established

## Key Design Decisions

### 1. Correctness First
Every optimization must be classified:
- **[THEOREM]** - Mathematically proven
- **[EXACT]** - Algorithmically exact, identical results to reference
- **[BOUNDED]** - Provable mathematical bounds
- **[PROBABILISTIC]** - Explicit probabilistic guarantees
- **[HEURISTIC]** - Effective without general guarantees
- **[EMPIRICAL]** - Validated experimentally
- **[LEARNED]** - Obtained through training

### 2. Reference as Oracle
- Reference implementation is the ground truth
- Simple, obviously correct code
- Exhaustive verification before optimization
- Differential testing mandatory

### 3. Deduplication as Architecture
Every optimization must reduce work through:
- Memoization (transposition tables)
- Incremental computation (Zobrist, material, NNUE accumulators)
- Precomputation (attack tables, evaluation LUTs)
- Cache locality (contiguous arrays, compact structures)

### 4. Measurement-Driven
- No optimization without benchmarks
- Before/after comparisons required
- Statistical significance required for claims
- Regression detection automatic

## Code Statistics
- **Total lines**: 1,793 (including comments and blank lines)
- **Core logic**: ~800 LOC (reference implementation)
- **Tests**: ~100 LOC
- **Build system**: 80 LOC
- **Benchmarks**: 40 LOC

## Quality Checklist
✅ All code compiles without warnings
✅ Code is simple and correct
✅ Comments document non-obvious logic
✅ Test framework in place
✅ Benchmark framework in place
✅ Design documented
✅ Contribution guidelines clear
✅ GitHub repository configured
✅ CI/CD pipeline ready
✅ 14-phase roadmap documented

## Next Phase: Phase 1 (Core Move Generation)

### Goals
1. Complete reference move generation for all pieces
2. Implement PERFT verification suite
3. Verify all edge cases (castling, en passant, promotion, pins, checks)

### Estimated Duration
2-4 weeks

### Quality Gates
- All PERFT tests pass
- No correctness issues
- Code reviewed
- Differential testing framework ready

## How to Use

### Load the System
```lisp
(asdf:load-system :scacchiforge)
```

### Run Tests
```lisp
(asdf:test-system :scacchiforge)
```

### Load Benchmarks
```lisp
(asdf:load-system :scacchiforge-bench)
(scacchiforge-bench:run-microbench)
(scacchiforge-bench:run-engine-bench)
```

## Repository Structure
```
ScacchiForge/
├── src/
│   ├── reference/         # Oracle implementation
│   │   ├── types.lisp     # Core data types
│   │   ├── board.lisp     # Board utilities
│   │   ├── movegen.lisp   # Move generation
│   │   ├── position.lisp  # State management
│   │   ├── eval.lisp      # Evaluation
│   │   └── search.lisp    # Search algorithms
│   └── optimized/         # Bitboard variant (to implement)
│       ├── bitboards.lisp # Bit utilities
│       └── board-opt.lisp # Bitboard position
├── tests/                 # Test suite
│   ├── test-perft.lisp
│   ├── test-movegen.lisp
│   └── test-position.lisp
├── benchmarks/            # Performance measurement
│   ├── microbench.lisp
│   └── engine-bench.lisp
├── .github/
│   ├── ISSUE_TEMPLATE/    # GitHub issue templates
│   └── workflows/         # CI/CD pipeline
├── scacchiforge.asd       # ASDF system definition
├── README.md              # Quick start
├── DESIGN.md              # Architecture
├── CONTRIBUTING.md        # Contribution guidelines
├── ROADMAP.md             # 14-phase timeline
└── LICENSE                # BSD-2-Clause
```

## Philosophical Foundation

### Core Principle
**"Optimize the work required to make a strong decision."**

Not:
- Operations per second (NPS)
- Maximum search depth
- Memory consumption

But:
- Strength per unit CPU time
- Verifiable correctness
- Measurable improvement
- Architectural clarity

### Development Methodology
1. **Design first** - Understand the problem
2. **Measure baseline** - Before any optimization
3. **Implement carefully** - With verification in place
4. **Measure impact** - After/before comparison
5. **Document tradeoffs** - Why this choice?
6. **Commit to history** - Full audit trail

## Support

### Documentation
- See [README.md](README.md) for philosophy and quick start
- See [DESIGN.md](DESIGN.md) for detailed algorithms
- See [CONTRIBUTING.md](CONTRIBUTING.md) for code standards
- See [ROADMAP.md](ROADMAP.md) for timeline

### Issues and Questions
- Use GitHub issue templates
- Tag with [BUG], [RESEARCH], or [QUESTION]
- Include reproducible example for bugs
- Include hypothesis and rationale for research

### Contributing
- Follow CONTRIBUTING.md guidelines
- Ensure all tests pass
- Include benchmark data
- Document correctness classification

## Next Action Items

1. ✅ Repository created (private GitHub)
2. ✅ Foundation code committed
3. ✅ Documentation complete
4. ✅ CI/CD pipeline ready
5. 📅 Phase 1: Complete move generation
6. 📅 Phase 2: Implement bitboard variant
7. 📅 Phase 3: Baseline search
8. ... (through Phase 14)

---

**Created**: October 3, 2026
**Status**: Foundation solid, ready for Phase 1
**Repository**: https://github.com/gpicchiarelli/ScacchiForge (Private)
**License**: BSD-2-Clause
