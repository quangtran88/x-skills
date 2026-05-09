#!/usr/bin/env bash
# Test 10 (nice-to-have): malformed profile.json → ISOLATE_APPLIED=false, sanitized reason ≤200 chars, single line.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t10
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
# Invalid JSON.
printf '%s\n' '{this is not valid json' > "$MAIN/.worktree-isolate/profile.json"
( cd "$MAIN" && git add .worktree-isolate/profile.json && git commit -q -m bad )

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

out="$(sim_step_6_5 "$WT" default)"

assert_contains "$out" "ISOLATE_APPLIED=false" "must report failed"
assert_contains "$out" "ISOLATE_REASON=" "must include reason"
assert_contains "$out" "ISOLATE_HINT=" "must include hint"

# Reason is single line, ≤200 chars.
reason_line="$(printf '%s\n' "$out" | grep '^ISOLATE_REASON=' | head -n 1)"
reason_value="${reason_line#ISOLATE_REASON=}"
reason_len="${#reason_value}"
if [ "$reason_len" -gt 200 ]; then
  fail "reason exceeds 200 chars: $reason_len"
fi
case "$reason_value" in
  *$'\n'*) fail "reason contains a newline" ;;
  *$'\t'*) fail "reason contains a tab" ;;
  *$'\r'*) fail "reason contains a CR" ;;
esac

# No slot leaked.
slots="$(registry_slots_count)"
assert_eq "0" "$slots" "registry must have zero slots"

pass "test 10 — malformed profile"
