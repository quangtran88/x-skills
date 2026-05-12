#!/usr/bin/env bash
# Test 14 (stage A — Task 5): detect a repo-tracked crontab artifact.
# Stage B (apply blocker) added in Task 10. Stage C (post-ack apply) added in Task 11.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

test_setup t14a
trap test_teardown EXIT

MAIN="$TEST_TMP/main"
make_repo "$MAIN"
mkdir -p "$MAIN/infra/cron"
cat > "$MAIN/infra/cron/dispatcher.crontab" <<'CRON'
*/5 * * * * /usr/bin/dispatcher run
CRON

DETECT="$SKILL_DIR/scripts/detect-singletons.py"
out_json="$(python3 "$DETECT" --repo "$MAIN")"

echo "$out_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
host = [s for s in data.get("singletons", []) if s["kind"] == "host"]
assert any(s["id"] == "host-crontab" for s in host), f"expected host-crontab id, got {[s['"'"'id'"'"'] for s in host]}"
ct = next(s for s in host if s["id"] == "host-crontab")
assert ct["severity"] == "blocker", f"host tier must default severity=blocker, got {ct['"'"'severity'"'"']}"
assert "manual_fix_hint" in ct
print("ok")
'

# Stage B (Task 10): apply blocks when host singleton present + no ack.
cat > "$MAIN/docker-compose.yml" <<'YAML'
services:
  app:
    image: alpine:latest
YAML
( cd "$MAIN" && bash "$DISPATCH" init --non-interactive )
( cd "$MAIN" && git add . && git commit -q -m "v2 profile" )
WT="$TEST_TMP/wt14"
make_worktree "$MAIN" "$WT" "feat-x"

set +e
out="$(cd "$WT" && bash "$DISPATCH" apply 2>&1)"; rc=$?
set -e
[ "$rc" -ne 0 ] || fail "apply must block when host singleton present + no ack"
assert_contains "$out" "host-crontab" "blocker message must name the host singleton"
assert_contains "$out" "ack-host-singletons" "blocker message must mention ack subcommand"

# Stage C (Task 11): after ack, apply succeeds and writes .env.worktree.
( cd "$WT" && bash "$DISPATCH" ack-host-singletons --quiet )
( cd "$WT" && bash "$DISPATCH" apply --quiet )
assert_file_exists "$WT/.env.worktree" "apply must succeed after host ack"

# --quiet contract regression: ack-host-singletons --quiet must produce no stdout.
ack_stdout="$(cd "$WT" && bash "$DISPATCH" ack-host-singletons --quiet 2>&1)"
[ -z "$ack_stdout" ] || fail "ack-host-singletons --quiet must produce no stdout (got: $ack_stdout)"

pass "test 14 — host-tier crontab detected, blocks apply, succeeds after ack (stages A + B + C)"
