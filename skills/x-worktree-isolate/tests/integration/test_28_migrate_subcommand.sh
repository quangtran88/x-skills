#!/usr/bin/env bash
# Test 28: migrate heals registry, reports pre-existing conflicts, prints x-qa update pointer.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t28
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
    {"id":"node-cron","kind":"env-flag","evidence":["x"],"rationale":"s","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )
# Illegal pre-existing dual-enable.
for WT in "$WTA" "$WTB"; do
  cat > "$WT/.worktree-isolate/feature-overrides.local.json" <<JSON
{"schema":1,"overrides":[{"id":"node-cron","state":"enabled"}],"updated_at":"2026-01-01T00:00:00Z"}
JSON
done

out="$( cd "$WTA" && bash "$DISPATCH" migrate 2>&1 )"
assert_contains "$out" "registry_schema" "migrate must confirm registry healed to schema 2"
assert_contains "$out" "SINGLETON_CONFLICT_PREEXISTING=node-cron" "migrate must report pre-existing conflicts"
assert_contains "$out" "x-qa update" "migrate must point x-qa users at x-qa update"
assert_contains "$out" "init --rescan" "migrate must prompt a rescan for new patterns"

reg="$(cd "$WTA" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
schema="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("registry_schema"))' "$reg")"
assert_eq "2" "$schema" "migrate must persist registry_schema:2"

pass "test 28 — migrate heals + reports conflicts + pointers"
