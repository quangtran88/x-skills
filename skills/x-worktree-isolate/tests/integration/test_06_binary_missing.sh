#!/usr/bin/env bash
# Test 6: simulating binary-missing path → ISOLATE_APPLIED=skipped, ISOLATE_REASON=binary-missing.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t06
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
WT="$TEST_TMP/wt"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"
make_worktree "$MAIN" "$WT" "feat-x"

# Simulate binary-missing branch (sim_step_6_5 short-circuits).
out="$(sim_step_6_5 "$WT" binary-missing)"

assert_contains "$out" "ISOLATE_APPLIED=skipped" "envelope must contain ISOLATE_APPLIED=skipped"
assert_contains "$out" "ISOLATE_REASON=binary-missing" "reason must be binary-missing"
assert_file_absent "$WT/.worktree-isolate/state.local.json" "state.local.json must not be written"

slots="$(registry_slots_count)"
assert_eq "0" "$slots" "registry must have zero slots"

pass "test 06 — binary missing"
