#!/usr/bin/env bash
# Test 15: running apply from the main checkout must short-circuit even when a
# singleton is present (so the exemption is actually exercised, not vacuously true).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t15
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"sched","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

( cd "$MAIN" && bash "$DISPATCH" apply --if-profile-exists --quiet )
assert_file_absent "$MAIN/compose.override.yml" "main checkout must not get compose override"
assert_file_absent "$MAIN/.env.worktree" "main checkout must not get .env.worktree"

pass "test 15 — main checkout exempt from singleton disable (singleton present, exemption exercised)"
