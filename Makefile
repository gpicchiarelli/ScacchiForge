# ScacchiForge -- build, test, lint and benchmark. SBCL is the only Lisp requirement. The
# targets need make (only GNU make has been used; "make help" reads GNU make's MAKEFILE_LIST).
# For parts of its environment record, make bench also runs git, ps, uname, sysctl and nproc,
# and reads /proc/cpuinfo and /proc/loadavg. None of them is required: each entry falls back
# to another source or says unknown (benchmarks/system-info.lisp). Every target runs from the
# repository root. The environment variable SCF_SLIDERS (fixed-magic, magic or ray; unset means
# fixed-magic) chooses the slider attacks the optimized layer is built with, for every target
# that loads the system (src/optimized/policy.lisp, ADR-0016 in docs/adr/); SCF_EVAL_STATE
# (incremental or recompute; unset means incremental) chooses in the same way whether make and
# unmake keep the incremental evaluation state (research/exp-0002-*.md). Each such target
# recompiles every system of scacchiforge.asd that it loads (tools/load.lisp), so no file
# compiled by an earlier target with another SCF_SLIDERS, or by test-checked, is reused. Run
# the targets one at a time: they compile into the same build/ directory.

SBCL ?= sbcl
SBCL_RUN = $(SBCL) --noinform --no-userinit --non-interactive

.PHONY: help build test test-checked lint lint-selftest links check perft-deep \
	differential-deep bench hot-path magics signatures

help: ## list the targets
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## compile every system with warnings and style warnings as errors, then reload once
	$(SBCL_RUN) --load tools/build.lisp --end-toplevel-options --no-test

test: ## build, then run every test suite (perft to the standard depths, fuzzers, differential tests)
	$(SBCL_RUN) --load tools/build.lisp

test-checked: ## the same as test, with the optimized hot path compiled at safety 3
	$(SBCL_RUN) --load tools/build.lisp --end-toplevel-options --checked

lint: ## check src, tests, benchmarks, tools: no tabs, no trailing blanks, 100 columns, no ignore-errors, no eval
	$(SBCL_RUN) --load tools/lint.lisp --end-toplevel-options src tests benchmarks tools

lint-selftest: ## check the lint, link and strict-load tools on samples with planted problems
	$(SBCL_RUN) --load tools/lint.lisp --end-toplevel-options --self-test
	$(SBCL_RUN) --load tools/check-links.lisp --end-toplevel-options --self-test
	$(SBCL_RUN) --load tools/build.lisp --end-toplevel-options --self-test

links: ## check relative links and anchors in every Markdown file
	$(SBCL_RUN) --load tools/check-links.lisp --end-toplevel-options .

check: build test lint lint-selftest links ## everything: build, test, lint, tool self-tests, links

perft-deep: ## perft to the deepest recorded depths (not part of make check)
	$(SBCL_RUN) --load tools/perft-deep.lisp

differential-deep: ## the optimized layer against the reference on millions of positions (not part of make check)
	$(SBCL_RUN) --load tools/differential-deep.lisp

bench: ## print the environment record, then perft, alpha-beta search, evaluation cost, bit-utility and slider timings (measurements, not results)
	$(SBCL_RUN) --load tools/bench.lisp

hot-path: ## efficiency notes, disassembly, allocation and perft time by policy of the optimized hot path
	$(SBCL_RUN) --load tools/hot-path.lisp

magics: ## search the magic numbers from their seed and rewrite src/optimized/magic-numbers.lisp (not part of make check)
	$(SBCL_RUN) --load tools/generate-magics.lisp

signatures: ## recompute the search signature and rewrite tests/search-signature.sexp (not part of make check)
	$(SBCL_RUN) --load tools/signatures.lisp
