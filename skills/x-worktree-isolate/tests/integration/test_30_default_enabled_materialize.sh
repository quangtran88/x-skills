#!/usr/bin/env bash
# Test 30 (F2): default_in_worktree:"enabled" singleton is materialized into
# feature-overrides.local.json on apply, and a second worktree's apply refuses.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t30
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"enabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"

# 1) wtA apply claims node-cron via the profile default AND materializes the override.
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
ovA="$WTA/.worktree-isolate/feature-overrides.local.json"
[ -f "$ovA" ] || fail "wtA apply must materialize feature-overrides.local.json"
case "$(cat "$ovA")" in
  *'"id": "node-cron"'*'"state": "enabled"'*) : ;;
  *) fail "default-enabled node-cron must be materialized as enabled in wtA override" ;;
esac

# 2) wtB apply of the same default-enabled profile must REFUSE (claim gate before materialize).
set +e
errB="$( cd "$WTB" && bash "$DISPATCH" apply --quiet 2>&1 )"
rcB=$?
set -e
assert_eq "1" "$([ "$rcB" -ne 0 ] && echo 1 || echo 0)" "wtB apply must refuse while wtA owns the default-enabled singleton"
assert_contains "$errB" "SINGLETON_CONFLICT=node-cron" "wtB apply must emit SINGLETON_CONFLICT"

pass "test 30 — default-enabled singleton materialized + second worktree refused"
