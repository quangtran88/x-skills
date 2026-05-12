#!/usr/bin/env bash
# Test 19: a compose-service singleton with disable_method=profile-gate produces
# services.<svc>.profiles: [xwi-disabled] in the override (instead of replicas:0).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t19
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  ngrok:
    image: ngrok/ngrok:latest
YAML
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
    {"id":"ngrok-tunnel","kind":"compose-service","evidence":["docker-compose.yml:services.ngrok.image"],"rationale":"public tunnel","default_in_worktree":"disabled","severity":"warning","compose_service":"ngrok","disable_method":"profile-gate"}
  ]
}
JSON
( cd "$MAIN" && git add . && git commit -q -m setup )

WT="$TEST_TMP/wt19"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

ov="$WT/compose.override.yml"
assert_file_exists "$ov" "override must be written"
assert_contains "$(cat "$ov")" "ngrok:" "override must include ngrok block"
assert_contains "$(cat "$ov")" "profiles:" "override must include profiles list"
assert_contains "$(cat "$ov")" "- xwi-disabled" "override must gate ngrok with profile=xwi-disabled"

case "$(cat "$ov")" in
  *"replicas: 0"*) fail "profile-gate singleton must NOT emit replicas:0" ;;
esac

pass "test 19 — profile-gate disable_method emits profiles:[xwi-disabled]"
