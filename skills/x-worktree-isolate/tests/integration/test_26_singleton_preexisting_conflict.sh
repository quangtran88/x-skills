#!/usr/bin/env bash
# Test 26: two live worktrees both enabled same singleton → heal leaves unowned +
# SINGLETON_CONFLICT_PREEXISTING; claim refused until one runs disable.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t26
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

# Simulate the pre-upgrade illegal state: BOTH worktrees' feature-overrides enable node-cron,
# bypassing the claim (write the override files directly).
for WT in "$WTA" "$WTB"; do
  cat > "$WT/.worktree-isolate/feature-overrides.local.json" <<JSON
{"schema":1,"overrides":[{"id":"node-cron","state":"enabled"}],"updated_at":"2026-01-01T00:00:00Z"}
JSON
done

# A third claim (wtA re-apply) must REFUSE node-cron with the pre-existing notice.
set +e
errA="$( cd "$WTA" && bash "$DISPATCH" apply --quiet 2>&1 )"
rcA=$?
set -e
assert_eq "1" "$([ "$rcA" -ne 0 ] && echo 1 || echo 0)" "apply must refuse on pre-existing conflict"
assert_contains "$errA" "SINGLETON_CONFLICT_PREEXISTING=node-cron" "must emit pre-existing notice"
assert_contains "$errA" "owners=" "notice must list both owners"

# Heal left it unowned.
reg="$(cd "$WTA" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
unowned="$(python3 -c 'import json,sys; print("node-cron" not in json.load(open(sys.argv[1])).get("singleton_owners",{}))' "$reg")"
assert_eq "True" "$unowned" "pre-existing conflict id must be left unowned"

# Loser disables → wtA can now claim.
( cd "$WTB" && bash "$DISPATCH" disable node-cron --quiet )
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
owner="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["singleton_owners"].get("node-cron",{}).get("worktree_path",""))' "$reg")"
assert_eq "$(cd "$WTA" && pwd -P)" "$owner" "after loser disables, wtA claims node-cron"

pass "test 26 — pre-existing conflict refuse-until-resolved"
