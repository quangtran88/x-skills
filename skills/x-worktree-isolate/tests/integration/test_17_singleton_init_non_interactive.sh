#!/usr/bin/env bash
# Test 17: init --non-interactive scans + writes all candidates without prompting.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t17
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
( cd "$MAIN" && git add docker-compose.yml && git commit -q -m compose )

( cd "$MAIN" && bash "$DISPATCH" init --non-interactive >/dev/null )

profile="$MAIN/.worktree-isolate/profile.json"
assert_file_exists "$profile" "profile must be written"

python3 - "$profile" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
assert p["schema"] == 2, p["schema"]
ids = {s["id"] for s in p.get("singletons", [])}
assert "slack-listener" in ids, f"expected slack-listener, got {ids}"
PY

pass "test 17 — init --non-interactive scans + writes candidates"
