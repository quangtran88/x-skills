#!/usr/bin/env bash
# explore-contract.sh — grep-anchored checks that the exploratory-team contracts
# contain their load-bearing clauses. Cheap guard against silent contract drift.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
pass=0; fail=0
need() { if grep -qF -- "$2" "$SKILL_DIR/$1"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 missing: $2"; fi; }

# --- Task 15: explorer-prompts.md (the curious worker) ---
need references/explorer-prompts.md "false case"
need references/explorer-prompts.md "probe budget"
need references/explorer-prompts.md "MUST NOT run the repository's own test suites"
need references/explorer-prompts.md "bug-board"

# --- Task 15: explore-team.md (coordination + gate) ---
need references/explore-team.md "shared bug-board"
need references/explore-team.md "native Claude team"
need references/explore-team.md "background"
need references/explore-team.md "skipped in CI"
need references/explore-team.md "≤6"

# --- Task 18: SKILL.md wiring (filled by Task 18) ---
need SKILL.md "--no-explore"
need SKILL.md "Exploratory bug-hunt"
need SKILL.md "EXPLORE_CONFIRMED"
need SKILL.md "X_QA_EXPLORE_MODE"

echo "explore-contract: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
