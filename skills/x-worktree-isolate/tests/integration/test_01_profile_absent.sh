#!/usr/bin/env bash
# Test 1: profile absent → ISOLATE_APPLIED=skipped, no state.local.json written.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t01
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
WT="$TEST_TMP/wt"
make_repo "$MAIN"
make_worktree "$MAIN" "$WT" "feat-x"

# Profile NOT written. Run sim_step_6_5.
out="$(sim_step_6_5 "$WT" default)"

assert_contains "$out" "ISOLATE_APPLIED=skipped" "envelope must contain ISOLATE_APPLIED=skipped"
assert_contains "$out" "ISOLATE_REASON=no-profile" "reason must be no-profile"
assert_file_absent "$WT/.worktree-isolate/state.local.json" "state.local.json must not be written"

slots="$(registry_slots_count)"
assert_eq "0" "$slots" "registry must have zero slots"

pass "test 01 — profile absent"
