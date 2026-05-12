#!/usr/bin/env bash
# Test 13 (stage A — Task 9): renderer emits env_lines for env-flag singletons.
# Stage B (apply writes RUN_SCHEDULER=false into .env.worktree) added in Task 10.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t13a
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
    {
      "id": "node-cron", "kind": "env-flag", "evidence": ["src/jobs.js:1"],
      "rationale": "node-cron scheduler", "default_in_worktree": "disabled", "severity": "warning",
      "env_var": "RUN_SCHEDULER", "env_disabled_value": "false"
    }
  ]
}
JSON

out_json="$(python3 "$SKILL_DIR/scripts/render-singletons.py" --profile "$MAIN/.worktree-isolate/profile.json")"

echo "$out_json" | python3 -c '
import json,sys
data=json.load(sys.stdin)
assert "RUN_SCHEDULER=false" in data["env_lines"], data
print("ok")
'

# Stage B (Task 10): apply writes RUN_SCHEDULER=false into .env.worktree.
( cd "$MAIN" && git add .worktree-isolate/profile.json && git commit -q -m "v2 profile" )
WT="$TEST_TMP/wt13"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )
assert_contains "$(cat "$WT/.env.worktree")" "RUN_SCHEDULER=false" ".env.worktree must include disabled env-flag"

pass "test 13 — env-flag renderer emits RUN_SCHEDULER=false (stages A + B)"
