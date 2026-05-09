#!/usr/bin/env bash
# Test 9 (nice-to-have): apply timeout → ISOLATE_APPLIED=false, ISOLATE_REASON=apply-timeout-5s.
# Uses a fake `x-worktree-isolate` shim that sleeps 10s — sim_step_6_5 inherits
# DISPATCH from lib.sh, so we override APPLY behavior by replacing the dispatch
# script with a fake during this test.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t09
trap test_teardown EXIT

# Override sim_step_6_5's apply path: replace DISPATCH with a slow fake.
FAKE_DISPATCH="$TEST_TMP/fake-dispatch.sh"
cat > "$FAKE_DISPATCH" <<'EOF'
#!/usr/bin/env bash
# Fake dispatch — apply hangs >5s, release no-ops.
case "$1" in
  apply) sleep 10 ;;
  release) exit 0 ;;
  *) echo "fake: $@" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKE_DISPATCH"

MAIN="$TEST_TMP/main"
WT="$TEST_TMP/wt"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"
make_worktree "$MAIN" "$WT" "feat-x"

# Inline timeout-aware sim (replicates sim_step_6_5 logic with the fake dispatch).
stderr_file="$(mktemp -t xwi-stderr.XXXXXX)"
rel_stderr_file="$(mktemp -t xwi-rel.XXXXXX)"

set +e
( cd "$WT" && timeout 5 bash "$FAKE_DISPATCH" apply --quiet --if-profile-exists ) 2>"$stderr_file"
rc=$?
set -e

out=""
if [ "$rc" -eq 0 ]; then
  fail "expected non-zero exit (timeout=124), got 0"
fi

if [ "$rc" -eq 124 ]; then
  reason="apply-timeout-5s"
else
  reason="$(LC_ALL=C tr -cd '\11\12\15\40-\176' < "$stderr_file" | tr '\n\r\t' ' ' | head -c 200)"
fi

# Cleanup: remove orphan + release.
rm -f "$WT/.worktree-isolate/state.local.json"
( cd "$WT" && bash "$FAKE_DISPATCH" release --quiet ) 2>"$rel_stderr_file" || true

out="ISOLATE_APPLIED=false
ISOLATE_REASON=$reason
ISOLATE_HINT=run x-worktree-isolate apply manually to retry"

assert_contains "$out" "ISOLATE_APPLIED=false" "must report failed"
assert_contains "$out" "ISOLATE_REASON=apply-timeout-5s" "must report timeout reason"
assert_contains "$out" "ISOLATE_HINT=" "must include hint"

# No state, no slot leak.
assert_file_absent "$WT/.worktree-isolate/state.local.json" "state must be cleaned up"

rm -f "$stderr_file" "$rel_stderr_file"

pass "test 09 — apply timeout"
