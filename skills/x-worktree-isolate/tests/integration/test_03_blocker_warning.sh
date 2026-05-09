#!/usr/bin/env bash
# Test 3: profile.json with severity:blocker → apply exits 1 → ISOLATE_APPLIED=false.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t03
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

# Profile with a blocker warning.
blocker_profile='{
  "schema": 1,
  "stack": "compose",
  "port_strategy": {
    "scan_range": [18000, 29999],
    "ports": [
      {"var": "POSTGRES_PORT", "service": "db", "default": 5432, "container_port": 5432}
    ]
  },
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [
    {"label": "app.sandbox=1", "found_in": "Makefile:42", "severity": "blocker", "fix_hint": "scope the label to COMPOSE_PROJECT_NAME"}
  ],
  "single_worktree_profiles": []
}'
write_profile "$MAIN" "$blocker_profile"
commit_profile "$MAIN"

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out="$(sim_step_6_5 "$WT" default)"

assert_contains "$out" "ISOLATE_APPLIED=false" "envelope must contain ISOLATE_APPLIED=false"
assert_contains "$out" "ISOLATE_HINT=" "hint must be present"
# stderr should mention BLOCKED or blocker.
case "$out" in
  *BLOCKED*|*blocker*) ;;
  *) fail "reason should contain BLOCKED or blocker text; got: $out" ;;
esac

# Worktree creation succeeded (wt path exists, branch checked out).
[ -d "$WT" ] || fail "worktree dir must exist"

# No slot leaked.
slots="$(registry_slots_count)"
assert_eq "0" "$slots" "registry must have zero slots after blocker (cleanup ran)"

# Orphan state file removed.
assert_file_absent "$WT/.worktree-isolate/state.local.json" "state.local.json must be cleaned up"

pass "test 03 — blocker warning"
