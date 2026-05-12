#!/usr/bin/env bash
# Test 11: apply must hard-reject a schema:1 profile with a precise migration message.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t11
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 1,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": []
}
JSON
( cd "$MAIN" && git add .worktree-isolate/profile.json && git commit -q -m "legacy v1 profile" )

WT="$TEST_TMP/wt"
make_worktree "$MAIN" "$WT" "feat-x"

set +e
stderr_capture="$(cd "$WT" && bash "$DISPATCH" apply 2>&1 >/dev/null)"
rc=$?
set -e

[ "$rc" -ne 0 ] || fail "apply must non-zero exit on schema:1"
assert_contains "$stderr_capture" "schema 1 is no longer supported" "must surface schema rejection"
assert_contains "$stderr_capture" "init --rescan" "must surface migration command"
assert_file_absent "$WT/compose.override.yml" "must not write override on schema reject"
assert_file_absent "$WT/.env.worktree" "must not write env on schema reject"

pass "test 11 — schema:1 hard-rejected with migration hint"
