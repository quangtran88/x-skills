#!/usr/bin/env bash
# Test 4: idempotent re-apply → byte-identical state modulo applied_at, same ports, same slot.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t04
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out1="$(sim_step_6_5 "$WT" default)"
assert_contains "$out1" "ISOLATE_APPLIED=true" "first run must succeed"

cp "$WT/.worktree-isolate/state.local.json" "$TEST_TMP/state1.json"
cp "$WT/compose.override.yml" "$TEST_TMP/over1.yml"
cp "$WT/.env.worktree" "$TEST_TMP/env1.worktree"

# Sleep 1s so applied_at has a chance to differ — re-apply should still produce
# byte-identical content modulo applied_at.
sleep 1

out2="$(sim_step_6_5 "$WT" default)"
assert_contains "$out2" "ISOLATE_APPLIED=true" "second run must also succeed"

# Compare files. compose.override + .env.worktree must be byte-identical.
if ! diff -q "$TEST_TMP/over1.yml" "$WT/compose.override.yml" >/dev/null; then
  fail "compose.override.yml drifted between runs"
fi
if ! diff -q "$TEST_TMP/env1.worktree" "$WT/.env.worktree" >/dev/null; then
  fail ".env.worktree drifted between runs"
fi

# state.local.json must match modulo applied_at.
strip_at() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
d.pop("applied_at", None)
print(json.dumps(d, sort_keys=True))
' "$1"
}
s1="$(strip_at "$TEST_TMP/state1.json")"
s2="$(strip_at "$WT/.worktree-isolate/state.local.json")"
assert_eq "$s1" "$s2" "state.local.json drifted in non-applied_at field"

# Single registry slot.
slots="$(registry_slots_count)"
assert_eq "1" "$slots" "registry must still have exactly one slot"

pass "test 04 — idempotent re-apply"
