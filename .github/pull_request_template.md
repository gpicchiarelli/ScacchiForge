## What changes

<!-- One or two sentences. -->

## Type

- [ ] Documentation / ADR
- [ ] Reference engine (the oracle)
- [ ] Optimized engine
- [ ] Research layer
- [ ] Tooling / CI

## Checklist

- [ ] Classification line filled in: a tag for every technique that reduces work, or `none`. When in doubt, the weaker tag
- [ ] `make check` passes
- [ ] Move generation touched: perft unchanged, or the change is justified under Evidence
- [ ] Optimized layer changed: differential test against the reference engine added or run
- [ ] No performance number without a reproducible measurement (a command committed in the repository)
- [ ] Docs updated in the same commit

## Evidence

<!-- The commands you ran and their output: make check, perft, differential test, measurement. For a measurement, name the machine. -->

Closes #

Classification: <!-- One or more of [THEOREM] [EXACT] [BOUNDED] [PROBABILISTIC] [HEURISTIC] [EMPIRICAL] [LEARNED], or none. -->
