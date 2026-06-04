#!/usr/bin/env bash
# domain-contract.sh — grep-anchored checks that the research-driven generation
# doc contracts contain their load-bearing clauses. Grows across T9/T10/T11/T13;
# each task appends its anchors and keeps this suite green at its own commit.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF -- "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# --- Task 1: scout-prompt.md domain research ---
need references/scout-prompt.md "## Domain Research"
need references/scout-prompt.md "domain_model"
need references/scout-prompt.md "obligations"
need references/scout-prompt.md "code-first"

# --- Task 2: failure-mode-taxonomy.md ---
need references/failure-mode-taxonomy.md "## A. Failure-Probing Modes"
need references/failure-mode-taxonomy.md "## B. Semantic Correctness"
need references/failure-mode-taxonomy.md "false case"
need references/failure-mode-taxonomy.md "fmode:"

echo "domain-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
