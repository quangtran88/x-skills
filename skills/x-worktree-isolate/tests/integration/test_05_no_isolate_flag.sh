#!/usr/bin/env bash
# Test 5: --no-isolate → envelope omits ISOLATE_APPLIED line entirely.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t05
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out="$(sim_step_6_5 "$WT" no-isolate)"

# Output must be empty (no ISOLATE_APPLIED line emitted).
assert_eq "" "$out" "envelope must omit ISOLATE_APPLIED entirely on --no-isolate"

# No state.local.json written.
assert_file_absent "$WT/.worktree-isolate/state.local.json" "state.local.json must not be written"

# No slot claimed.
slots="$(registry_slots_count)"
assert_eq "0" "$slots" "registry must have zero slots"

pass "test 05 — --no-isolate"
