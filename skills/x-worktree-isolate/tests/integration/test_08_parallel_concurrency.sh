#!/usr/bin/env bash
# Test 8: parallel concurrency — two worktrees, two parallel apply calls.
# Both succeed, distinct slots, distinct ports, registry uncorrupted.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t08
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT1="$TEST_TMP/wt1"
WT2="$TEST_TMP/wt2"
make_worktree "$MAIN" "$WT1" "feat-a"
make_worktree "$MAIN" "$WT2" "feat-b"

# Run both applies in background, then wait.
( sim_step_6_5 "$WT1" default > "$TEST_TMP/out1" ) &
pid1=$!
( sim_step_6_5 "$WT2" default > "$TEST_TMP/out2" ) &
pid2=$!
wait "$pid1"
wait "$pid2"

out1="$(cat "$TEST_TMP/out1")"
out2="$(cat "$TEST_TMP/out2")"

assert_contains "$out1" "ISOLATE_APPLIED=true" "wt1 apply must succeed"
assert_contains "$out2" "ISOLATE_APPLIED=true" "wt2 apply must succeed"

# Both state files exist with schema 1.
s1="$(state_field "$WT1/.worktree-isolate/state.local.json" schema)"
s2="$(state_field "$WT2/.worktree-isolate/state.local.json" schema)"
assert_eq "1" "$s1" "wt1 schema must be 1"
assert_eq "1" "$s2" "wt2 schema must be 1"

# Distinct slots.
slot1="$(state_field "$WT1/.worktree-isolate/state.local.json" slot)"
slot2="$(state_field "$WT2/.worktree-isolate/state.local.json" slot)"
if [ "$slot1" = "$slot2" ]; then
  fail "slots collided: wt1=$slot1 wt2=$slot2"
fi

# Distinct allocated ports (no overlap).
ports1="$(python3 -c 'import json,sys; print(",".join(str(v) for v in json.load(open(sys.argv[1]))["allocated_ports"].values()))' "$WT1/.worktree-isolate/state.local.json")"
ports2="$(python3 -c 'import json,sys; print(",".join(str(v) for v in json.load(open(sys.argv[1]))["allocated_ports"].values()))' "$WT2/.worktree-isolate/state.local.json")"
overlap="$(python3 -c '
import sys
a = set(sys.argv[1].split(","))
b = set(sys.argv[2].split(","))
print(",".join(sorted(a & b)))
' "$ports1" "$ports2")"
if [ -n "$overlap" ]; then
  fail "port overlap between worktrees: $overlap (wt1=$ports1 wt2=$ports2)"
fi

# Registry has exactly 2 slots and is valid JSON.
slots="$(registry_slots_count)"
assert_eq "2" "$slots" "registry must have exactly 2 slots"

# Find the registry file and validate JSON.
reg="$(find "$XDG_CONFIG_HOME/worktree-isolate" -name registry.json -type f | head -n 1)"
[ -n "$reg" ] || fail "registry file not found"
python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$reg" || fail "registry not valid JSON"

pass "test 08 — parallel concurrency"
