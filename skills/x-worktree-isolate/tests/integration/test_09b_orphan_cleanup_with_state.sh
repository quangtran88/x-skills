#!/usr/bin/env bash
# Test 9b: orphan cleanup with REAL state.local.json written before SIGTERM.
#
# Reproduces the race window apply.sh:382 → :406 (state file written, then
# registry claim). If `timeout 5` SIGTERMs between the two, state.local.json
# exists on disk but no registry claim — making the next step 6.5 run falsely
# report ISOLATE_APPLIED=true (it sees the file).
#
# Test 9 verified the timeout path emits the right envelope but used a fake
# that never wrote state.local.json. This test fills that gap: fake apply
# writes the state file AND THEN sleeps; after timeout, verify the orphan
# cleanup actually removed the file from disk.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t09b
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
WT="$TEST_TMP/wt"
make_repo "$MAIN"
write_profile "$MAIN"
commit_profile "$MAIN"
make_worktree "$MAIN" "$WT" "feat-x"

# Fake dispatch: writes state.local.json (mimicking apply.sh:382), then sleeps.
# The sleep is what timeout 5 kills — simulating SIGTERM mid-apply, AFTER the
# state write but BEFORE the registry claim.
FAKE_DISPATCH="$TEST_TMP/fake-dispatch.sh"
cat > "$FAKE_DISPATCH" <<EOF
#!/usr/bin/env bash
case "\$1" in
  apply)
    mkdir -p "$WT/.worktree-isolate"
    cat > "$WT/.worktree-isolate/state.local.json" <<JSON
{
  "schema": 1,
  "slot": 0,
  "branch": "feat-x",
  "compose_project_name": "fake-feat-x",
  "allocated_ports": {"POSTGRES_PORT": 18000},
  "data_dir_var": "",
  "data_dir_path": "",
  "applied_at": "2026-01-01T00:00:00Z"
}
JSON
    sleep 10
    ;;
  release) exit 0 ;;
  *) echo "fake: \$@" >&2; exit 1 ;;
esac
EOF
chmod +x "$FAKE_DISPATCH"

# Pre-condition: state file does NOT exist before run.
assert_file_absent "$WT/.worktree-isolate/state.local.json" "pre-condition: no state file"

stderr_file="$(mktemp -t xwi-stderr.XXXXXX)"
rel_stderr_file="$(mktemp -t xwi-rel.XXXXXX)"

# Run with timeout. Expect rc=124 AND state.local.json on disk (fake wrote it).
set +e
( cd "$WT" && timeout 5 bash "$FAKE_DISPATCH" apply --quiet --if-profile-exists ) 2>"$stderr_file"
rc=$?
set -e

[ "$rc" -eq 124 ] || fail "expected rc=124 (timeout), got $rc"
assert_file_exists "$WT/.worktree-isolate/state.local.json" "fake apply wrote state file before SIGTERM"

# Step 6.5 orphan cleanup invariant: on non-zero exit, ALWAYS rm state file.
rm -f "$WT/.worktree-isolate/state.local.json"
( cd "$WT" && bash "$FAKE_DISPATCH" release --quiet ) 2>"$rel_stderr_file" || true

# Post-condition: orphan state file removed by cleanup. This is the gap test_09
# left open — verifying the rm -f actually happens against a real file, not a
# never-written one.
assert_file_absent "$WT/.worktree-isolate/state.local.json" "orphan state file removed by cleanup"

# Envelope shape (mirrors test_09 — ensures consistency).
reason="apply-timeout-5s"
out="ISOLATE_APPLIED=false
ISOLATE_REASON=$reason
ISOLATE_HINT=run x-worktree-isolate apply manually to retry"

assert_contains "$out" "ISOLATE_APPLIED=false" "must report failed"
assert_contains "$out" "ISOLATE_REASON=apply-timeout-5s" "must report timeout reason"

rm -f "$stderr_file" "$rel_stderr_file"

pass "test 09b — orphan cleanup with real state.local.json"
