#!/bin/sh
# The labels that the issue forms and dependabot.yml apply.
#
# GitHub does not create them. An issue form or Dependabot skips a label that
# does not exist in the repository, without a warning. The maintainer runs this
# script once with the GitHub CLI, from the repository root, and again after a
# change to this list:
#
#   sh .github/labels.sh
#
# --force updates a label that already exists. Labels not listed here are left
# alone.

set -eu

label() {
  gh label create "$1" --color "$2" --description "$3" --force
}

# Used by the issue forms and by dependabot.yml.
label correctness    3a3a3c "A wrong move, count or result"
label performance    6e6e73 "Speed, memory or a measurement that changed"
label research       c9892f "A technique to be tested, with a hypothesis"
label dependencies   c7c7cc "Dependency updates"
label github-actions d2d2d7 "Workflows and pinned actions"

# For triage by hand.
label documentation  8e8e93 "Documents, ADRs and the glossary"
label tooling        a1a1a6 "Makefile, scripts and local tools"

# The seven classification tags, for triage by hand.
label class:theorem       636366 "[THEOREM] provable correctness"
label class:exact         636366 "[EXACT] exact algorithm, no loss of correctness"
label class:bounded       636366 "[BOUNDED] produces interpretable bounds"
label class:probabilistic 636366 "[PROBABILISTIC] correctness from explicit probabilistic properties"
label class:heuristic     636366 "[HEURISTIC] no general guarantee"
label class:empirical     636366 "[EMPIRICAL] validated experimentally"
label class:learned       636366 "[LEARNED] parameters or functions from training"
