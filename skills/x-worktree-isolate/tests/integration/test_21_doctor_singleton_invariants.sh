#!/usr/bin/env bash
# Test 21: doctor reports PASS for env-flag echo and FAIL when override file is tampered.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t21
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range":[18000,29999],"ports":[]},
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
WT="$TEST_TMP/wt21"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

# 1) Doctor reports PASS for singleton invariant.
out="$(cd "$WT" && bash "$DISPATCH" doctor 2>&1)"
assert_contains "$out" "singleton-invariants" "doctor must include singleton invariant section"
assert_contains "$out" "PASS" "doctor must report PASS on a clean apply"

# 2) Tamper with .env.worktree — doctor reports FAIL.
sed -i.bak '/RUN_SCHEDULER=/d' "$WT/.env.worktree" && rm -f "$WT/.env.worktree.bak"
set +e
out2="$(cd "$WT" && bash "$DISPATCH" doctor 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "doctor must non-zero exit when invariant violated"
assert_contains "$out2" "RUN_SCHEDULER=false" "doctor must name the missing env-flag line"

pass "test 21 — doctor validates singleton env-flag invariant"
