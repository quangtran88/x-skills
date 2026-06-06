#!/usr/bin/env bash
# Test 24: env-flag singleton — claim → second worktree refuse → --force steal → release clears.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t24
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

# 1) wtA claims node-cron.
( cd "$WTA" && bash "$DISPATCH" enable node-cron --quiet )

# 2) wtB enable refuses (live owner) → SINGLETON_CONFLICT on stderr, nonzero exit, NO override written for wtB.
set +e
errB="$( cd "$WTB" && bash "$DISPATCH" enable node-cron --quiet 2>&1 )"
rcB=$?
set -e
assert_eq "1" "$([ "$rcB" -ne 0 ] && echo 1 || echo 0)" "wtB enable must fail while wtA owns the lock"
assert_contains "$errB" "SINGLETON_CONFLICT=node-cron" "must emit SINGLETON_CONFLICT"
# wtB feature-overrides must NOT show node-cron enabled (invariant: enabled⇒owned).
ovB="$WTB/.worktree-isolate/feature-overrides.local.json"
if [ -f "$ovB" ]; then
  case "$(cat "$ovB")" in
    *'"id": "node-cron"'*'"state": "enabled"'*) fail "refused claim must not leave node-cron enabled in wtB" ;;
  esac
fi

# 3) wtB --force steals the live lock.
errB2="$( cd "$WTB" && bash "$DISPATCH" enable node-cron --force --quiet 2>&1 )"
assert_contains "$errB2" "SINGLETON_LOCK_STOLEN=node-cron" "force must steal with SINGLETON_LOCK_STOLEN"
reg="$XDG_CONFIG_HOME/worktree-isolate"
owner_path="$(python3 -c '
import json,os,sys
root=sys.argv[1]
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    o=json.load(open(f)).get("singleton_owners",{}).get("node-cron")
    if o: print(o.get("worktree_path",""))
' "$reg")"
assert_eq "$(cd "$WTB" && pwd -P)" "$owner_path" "after --force, wtB must own node-cron"
# F1: --force must have cleared the loser (wtA) override so heal won't re-conflict.
ovA="$WTA/.worktree-isolate/feature-overrides.local.json"
if [ -f "$ovA" ]; then
  case "$(cat "$ovA")" in
    *'"id": "node-cron"'*'"state": "enabled"'*) fail "force-steal must clear node-cron in loser wtA override" ;;
  esac
fi

# 4) release clears wtB ownership.
( cd "$WTB" && bash "$DISPATCH" release --quiet )
owner_after="$(python3 -c '
import json,os,sys
root=sys.argv[1]; out=""
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    if "node-cron" in json.load(open(f)).get("singleton_owners",{}): out="present"
print(out)
' "$reg")"
assert_eq "" "$owner_after" "release must clear node-cron ownership"

pass "test 24 — enforced claim: refuse / --force steal / release clears"
