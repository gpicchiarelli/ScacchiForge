# Contributing to ScacchiForge

This is a research platform for chess engine development. Contributions should uphold high standards for correctness, clarity, and measurable impact.

## Philosophy

1. **Correctness is non-negotiable** - Every claim must be verifiable
2. **Measure everything** - Optimization without data is speculation
3. **Design matters** - Code should be clear about intent and tradeoffs
4. **Respect the oracle** - Reference implementation is the ground truth

## Before You Contribute

- Read [DESIGN.md](DESIGN.md) for architecture and principles
- Understand which phase the project is in
- Familiarize yourself with classification system: [THEOREM], [EXACT], [BOUNDED], [PROBABILISTIC], [HEURISTIC], [EMPIRICAL], [LEARNED]

## Reporting Issues

### Correctness Bugs
- Include minimal reproducible example
- Run through reference implementation
- Verify PERFT test
- Include differential testing results

### Research Ideas
- State hypothesis clearly
- Provide theoretical or empirical justification
- Classify the technique (see DESIGN.md)
- Link to related work

## Making Changes

### Code Style

**Naming**: Clear, descriptive names. Longer is better than cryptic.

```lisp
;; Good
(defun bishop-can-attack-p (pos from-square to-square)
  ...)

;; Bad
(defun bca (p f t) ...)
```

**Comments**: Only for non-obvious logic.

```lisp
;; Why, not what
(when (zerop depth)  ;; At leaf, no more pruning needed
  (return-from alpha-beta (evaluate pos)))

;; Not this
(if (zerop depth)
  (return-from alpha-beta (evaluate pos)))  ;; If depth is zero, return evaluation
```

**Structure**: Keep hot paths clean. Move support code to helper functions.

### Correctness Verification

1. **Code review** - Read for logical errors
2. **Unit tests** - Test individual functions
3. **Differential testing** - Compare with reference implementation
4. **PERFT** - If move generation changes, PERFT must pass
5. **Regression tests** - Ensure no existing functionality breaks

### Performance Measurement

1. **Establish baseline** - Measure before change
2. **Microbenchmark** - If optimizing a kernel
3. **Engine benchmark** - Impact on overall performance
4. **Self-play** - Verify strength change (if applicable)

**Rule**: No optimization without before/after measurements.

### Commit Messages

Format:
```
[TYPE] Brief description

Longer explanation if needed. Reference issue numbers.
Classify changes: [THEOREM], [EXACT], [HEURISTIC], etc.
Include benchmark impact.
```

Examples:

```
[OPTIMIZATION] Inline pawn attack square lookup

Replace function call with precomputed table lookup.
Classification: [EXACT] - identical behavior, faster execution.
Microbench: +15% for pawn move generation.
Engine bench: +2% NPS on middlegame positions.
```

```
[FEATURE] Implement Late Move Reductions

LMR reduces search depth for moves near end of move list.
Classification: [HEURISTIC] - effective but may miss best move in rare cases.

Implementation:
- Adaptive reduction based on depth and move index
- Experimental tuning parameters
- Research frame for alternatives

PERFT: Pass (no move generation change)
Engine bench: +8% NPS, +0.3 Elo (50 games, 95% confidence)
```

## Testing Requirements

### Minimum Requirements
- [ ] Code compiles without warnings (SBCL)
- [ ] All existing tests pass
- [ ] No new test failures
- [ ] Commit message documents changes

### For Optimizations
- [ ] Differential testing against reference (if applicable)
- [ ] Microbenchmark results
- [ ] Engine benchmark results
- [ ] No regression in strength

### For New Features
- [ ] Unit tests for new code
- [ ] Integration with existing tests
- [ ] PERFT verification (if move generation related)
- [ ] Documentation updated

### For Research Changes
- [ ] Correctness classification clear
- [ ] Measurable hypothesis
- [ ] Self-play validation (if strength claim)
- [ ] Rollback mechanism working

## Benchmark Standards

### Microbenchmarks
- Run 3+ iterations
- Report mean and stddev
- Specify CPU model and OS
- Note: Compiler optimizations, GC state, etc.

### Engine Benchmarks
- Position set: diverse (opening, middlegame, endgame, tactical, quiet)
- Fixed time: 1s minimum per position
- Fixed nodes: 100k minimum
- Report: NPS, depth, TT hit rate, evaluation time

### Self-Play
- Minimum: 30 games
- Randomized openings
- Same hardware for both engines
- Report: Elo difference, 95% confidence interval

## Review Process

1. **Automatic checks** - Code compiles, tests pass
2. **Differential testing** - Reference implementation comparison
3. **Benchmark review** - Data quality and significance
4. **Design review** - Correctness claims verified
5. **Merge** - Only after all checks pass

## When in Doubt

- Ask. File an issue with [QUESTION] tag
- Reference existing code and design
- Link to related chess engine papers or discussions
- Propose measurement plan

## Experimental Branch

For early-stage research:

```bash
git checkout -b research/hypothesis-name
```

Work in `src/research/` or create isolated modules. When ready for integration:
1. Finalize measurements
2. Write up results
3. Create PR with full documentation
4. Request review

## Recognition

Contributors are recognized in:
- `CREDITS.md` (for significant contributions)
- Commit history
- Research papers (if applicable)

## License

By contributing, you agree that your contributions are licensed under the BSD-2-Clause license, same as the project.
