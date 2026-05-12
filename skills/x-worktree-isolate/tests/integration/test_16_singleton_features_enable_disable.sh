#!/usr/bin/env bash
# Test 16: features lists; enable/disable round-trip toggles .env.worktree + override.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t16
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
    {"id":"node-cron","kind":"env-flag","evidence":["src/jobs.js:1"],"rationale":"scheduler","default_in_worktree":"disabled","severity":"warning","env_var":"RUN_SCHEDULER","env_disabled_value":"false"}
  ]
}
JSON
commit_profile "$MAIN"

WT="$TEST_TMP/wt16"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# 1) features lists with state=disabled (default).
out="$(cd "$WT" && bash "$DISPATCH" features)"
assert_contains "$out" "node-cron" "features must list node-cron"
assert_contains "$out" "disabled" "default state must be disabled"
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" "default: env-flag disabled"

# 2) enable flips state + rewrites .env.worktree.
( cd "$WT" && bash "$DISPATCH" enable node-cron --quiet )
env_after="$(cat "$WT/.env.worktree")"
case "$env_after" in
  *"RUN_SCHEDULER=false"*) fail "after enable, RUN_SCHEDULER=false must be removed" ;;
esac

# 3) disable flips back.
( cd "$WT" && bash "$DISPATCH" disable node-cron --quiet )
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" "after disable, RUN_SCHEDULER=false must reappear"

# Stage B (Task 12): enabling a singleton records ownership in the registry.
( cd "$WT" && bash "$DISPATCH" enable node-cron --quiet )
reg="$XDG_CONFIG_HOME/worktree-isolate"
owners="$(python3 -c '
import json, os, sys
root=sys.argv[1]
out={}
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    out.update(json.load(open(f)).get("singleton_owners",{}))
print(json.dumps(out))
' "$reg")"
echo "$owners" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert "node-cron" in o, f"expected node-cron owner, got {o}"
print("ok")
'

# Stage C: release clears the singleton owners for this worktree.
( cd "$WT" && bash "$DISPATCH" release --quiet )
owners_after="$(python3 -c '
import json, os, sys
root=sys.argv[1]
out={}
for rid in os.listdir(root):
    f=os.path.join(root,rid,"registry.json")
    if not os.path.isfile(f): continue
    out.update(json.load(open(f)).get("singleton_owners",{}))
print(json.dumps(out))
' "$reg")"
echo "$owners_after" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert "node-cron" not in o, f"release must clear node-cron ownership, got {o}"
print("ok")
'

pass "test 16 — features/enable/disable round-trip + registry owners"
