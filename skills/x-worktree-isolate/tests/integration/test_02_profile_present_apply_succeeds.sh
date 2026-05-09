#!/usr/bin/env bash
# Test 2: profile present → ISOLATE_APPLIED=true, state.local.json + override + env written.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t02
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out="$(sim_step_6_5 "$WT" default)"

assert_contains "$out" "ISOLATE_APPLIED=true" "envelope must contain ISOLATE_APPLIED=true"
assert_file_exists "$WT/.worktree-isolate/state.local.json" "state.local.json must exist"
assert_file_exists "$WT/compose.override.yml" "compose.override.yml must exist"
assert_file_exists "$WT/.env.worktree" ".env.worktree must exist"

schema="$(state_field "$WT/.worktree-isolate/state.local.json" schema)"
assert_eq "1" "$schema" "schema must equal 1"

cpn="$(state_field "$WT/.worktree-isolate/state.local.json" compose_project_name)"
[ -n "$cpn" ] || fail "compose_project_name must be non-empty"

slots="$(registry_slots_count)"
assert_eq "1" "$slots" "registry must have exactly one slot"

pass "test 02 — profile present, apply succeeds"
