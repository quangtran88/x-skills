#!/usr/bin/env bash
# Test 25: dead owner (worktree_path removed) → next claim auto-steals (SINGLETON_LOCK_STOLEN).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t25
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
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# Simulate a crashed/removed worktree: nuke wtA's dir, then seed a present-in-registry-but-
# path-gone owner and claim directly so the auto-steal branch is deterministic.
rm -rf "$WTA"
( cd "$WTB" && bash -c '
  . "'"$SKILL_DIR"'/scripts/allocate-ports.sh"
  reg="$(xwi_registry_file)"
  python3 - "$reg" "'"$WTA"'" <<PY
import json,sys
reg,wta=sys.argv[1],sys.argv[2]
d=json.load(open(reg))
d.setdefault("singleton_owners",{})["node-cron"]={"worktree_path":wta,"branch":"feat-a","claimed_at":"2026-01-01T00:00:00Z"}
json.dump(d,open(reg,"w"),indent=2)
PY
  xwi_acquire_lock
  xwi_claim_singleton node-cron "'"$WTB"'" feat-b env-flag "" 0
  xwi_release_lock
' 2>"$TEST_TMP/err25" )
assert_contains "$(cat "$TEST_TMP/err25")" "SINGLETON_LOCK_STOLEN=node-cron" "dead owner must be auto-stolen"

reg="$(cd "$WTB" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
owner_path="$(python3 -c '
import json,sys
o=json.load(open(sys.argv[1]))["singleton_owners"].get("node-cron",{})
print(o.get("worktree_path",""))
' "$reg")"
assert_eq "$WTB" "$owner_path" "after auto-steal, wtB must own node-cron"

pass "test 25 — dead-lock auto-steal on path-gone owner"
