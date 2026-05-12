#!/usr/bin/env bash
# Test 12 (stage A — Task 3): detect-singletons emits a compose-service candidate
# when a service env contains SLACK_BOT_TOKEN. Renderer assertion comes in Task 8/10.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t12a
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"

cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  slack-listener:
    image: myapp/slack:latest
    environment:
      SLACK_BOT_TOKEN: xoxb-fake
YAML

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
out_json="$(python3 "$DETECT" --repo "$MAIN")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
slack = [s for s in data.get("singletons", []) if s.get("compose_service") == "slack-listener" and s.get("kind") == "compose-service"]
assert len(slack) == 1, f"expected one slack-listener compose-service candidate, got {slack}"
assert slack[0]["id"] == "slack-listener", f"id must be the stable pattern id, got {slack[0]['"'"'id'"'"']}"
assert slack[0]["disable_method"] in ("replicas-zero", "profile-gate")
print("ok")
'

# Stage B (Task 7): init --non-interactive writes singletons[] into profile.json.
( cd "$MAIN" && bash "$DISPATCH" init --non-interactive >/dev/null )
assert_file_exists "$MAIN/.worktree-isolate/profile.json" "init must write profile"
schema="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("schema"))' "$MAIN/.worktree-isolate/profile.json")"
assert_eq "2" "$schema" "profile schema must equal 2"
have_singleton="$(python3 -c '
import json,sys
p=json.load(open(sys.argv[1]))
ids=[s["id"] for s in p.get("singletons",[])]
print("yes" if "slack-listener" in ids else "no")
' "$MAIN/.worktree-isolate/profile.json")"
assert_eq "yes" "$have_singleton" "init must record slack-listener candidate in singletons[]"

# Stage C (Task 10): apply renders services.slack-listener.deploy.replicas: 0.
( cd "$MAIN" && git add . && git commit -q -m "v2 profile + compose" )
WT="$TEST_TMP/wt12"
make_worktree "$MAIN" "$WT" "feat-x"
( cd "$WT" && bash "$DISPATCH" apply --quiet )

override="$WT/compose.override.yml"
assert_file_exists "$override" "override must be written"
assert_contains "$(cat "$override")" "slack-listener:" "override must include slack-listener block"
# Default disable_method is profile-gate (compose v2 standalone honors profiles
# more reliably than deploy.replicas:0 — see references/singleton-patterns.md).
assert_contains "$(cat "$override")" "profiles:" "override must include profiles list for disabled compose-service singleton"
assert_contains "$(cat "$override")" "- xwi-disabled" "override must gate slack-listener with profile=xwi-disabled"

pass "test 12 — compose-service singleton detected and gated by profile (stages A + B + C)"
