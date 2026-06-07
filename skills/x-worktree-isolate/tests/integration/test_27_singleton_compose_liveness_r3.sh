#!/usr/bin/env bash
# Test 27 (R3): compose-tier owner with zero running containers reads dead → auto-stolen.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t27
trap test_teardown EXIT

if ! have_docker; then
  skip "test 27" "docker compose not available"
  exit 0
fi

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slackbot:
    image: alpine:3
    environment:
      SLACK_BOT_TOKEN: xoxb-test
YAML
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2, "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": []},
  "services_to_strip": [], "data_dirs": [], "global_label_warnings": [], "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"slack-listener","kind":"compose-service","evidence":["docker-compose.yml:services.slackbot.environment.SLACK_BOT_TOKEN"],"rationale":"slack","default_in_worktree":"disabled","severity":"warning","compose_service":"slackbot","disable_method":"profile-gate"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WTA="$TEST_TMP/wtA"; make_worktree "$MAIN" "$WTA" "feat-a"
WTB="$TEST_TMP/wtB"; make_worktree "$MAIN" "$WTB" "feat-b"
( cd "$WTA" && bash "$DISPATCH" apply --quiet )
( cd "$WTB" && bash "$DISPATCH" apply --quiet )

# wtA owns slack-listener. Its COMPOSE_PROJECT_NAME has NO running containers (we never `up`).
( cd "$WTA" && bash "$DISPATCH" enable slack-listener --quiet )

# wtB enable: compose-tier owner with zero running containers = DEAD (R3) → auto-steal.
errB="$( cd "$WTB" && bash "$DISPATCH" enable slack-listener --quiet 2>&1 )"
assert_contains "$errB" "SINGLETON_LOCK_STOLEN=slack-listener" "stopped-stack compose owner must be auto-stolen (R3)"
reg="$(cd "$WTB" && . "$SKILL_DIR/scripts/allocate-ports.sh" && xwi_registry_file)"
owner="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["singleton_owners"].get("slack-listener",{}).get("worktree_path",""))' "$reg")"
assert_eq "$(cd "$WTB" && pwd -P)" "$owner" "after R3 auto-steal, wtB must own slack-listener"

pass "test 27 — compose-tier R3 stopped-stack auto-steal"
