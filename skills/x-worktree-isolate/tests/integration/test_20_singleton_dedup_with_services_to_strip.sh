#!/usr/bin/env bash
# Test 20 (BLOCKER regression): a service that appears in BOTH services_to_strip
# (with container_name + ports) AND singletons[] (compose-service replicas-zero)
# must produce exactly ONE top-level services.<svc>: block in compose.override.yml.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t20
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slack-listener:
    image: myapp/slack:latest
    container_name: myapp_slack
    ports:
      - "127.0.0.1:9000:9000"
    environment:
      SLACK_BOT_TOKEN: xoxb-fake
YAML
mkdir -p "$MAIN/.worktree-isolate"
cat > "$MAIN/.worktree-isolate/profile.json" <<'JSON'
{
  "schema": 2,
  "stack": "docker-compose",
  "port_strategy": {"scan_range": [18000, 29999], "ports": [{"var":"SLACK_PORT","service":"slack-listener","default":9000,"container_port":9000}]},
  "services_to_strip": [{"service":"slack-listener","container_name":"myapp_slack","ports":[{"var":"SLACK_PORT","container_port":9000}]}],
  "data_dirs": [],
  "global_label_warnings": [],
  "single_worktree_profiles": [],
  "detection_guardrails": {"scan_max_depth":4,"scan_max_file_bytes":1048576,"exclude_dirs":[],"exclude_globs":[]},
  "singletons": [
    {"id":"slack-listener","kind":"compose-service","evidence":["docker-compose.yml:services.slack-listener.environment.SLACK_BOT_TOKEN"],"rationale":"Slack","default_in_worktree":"disabled","severity":"warning","compose_service":"slack-listener","disable_method":"replicas-zero"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WT="$TEST_TMP/wt20"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

ov="$WT/compose.override.yml"
slack_keys="$(grep -cE '^  slack-listener:$' "$ov" || true)"
assert_eq "1" "$slack_keys" "compose.override.yml must have EXACTLY one top-level 'slack-listener:' block"
assert_contains "$(cat "$ov")" "container_name: !reset null" "override must keep container_name reset"
assert_contains "$(cat "$ov")" "ports: !override" "override must keep ports override"
assert_contains "$(cat "$ov")" "replicas: 0" "override must include singleton replicas:0"

pass "test 20 — single services.<svc> block when service is in both lists"
