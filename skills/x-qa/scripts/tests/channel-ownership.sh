#!/usr/bin/env bash
# channel-ownership.sh — unit-test the ownership read helper (R2: reads only
# feature-overrides.local.json, never the global registry).
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
OWN="$SKILL_DIR/scripts/lib/channel-ownership.sh"
pass=0; fail=0
expect() { # <desc> <expected-stdout> <worktree-root> <singleton-id>
  local desc="$1" want="$2" wt="$3" id="$4" got
  got=$(bash "$OWN" --singleton-id "$id" --worktree "$wt" 2>/dev/null || true)
  if [[ "$got" == "$want" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: $desc (want '$want', got '$got')"; fi
}

# 1. isolate absent → unverifiable
W1=$(mktemp -d)
expect "no .worktree-isolate dir → unverifiable" "unverifiable" "$W1" "slack-listener"

# 2. isolate present, singleton enabled → owned
W2=$(mktemp -d); mkdir -p "$W2/.worktree-isolate"
cat > "$W2/.worktree-isolate/feature-overrides.local.json" <<'JSON'
{"schema":1,"overrides":[{"id":"slack-listener","state":"enabled"}],"updated_at":"2026-06-06T00:00:00Z"}
JSON
expect "enabled → owned" "owned" "$W2" "slack-listener"

# 3. isolate present, singleton disabled → not-owned
W3=$(mktemp -d); mkdir -p "$W3/.worktree-isolate"
cat > "$W3/.worktree-isolate/feature-overrides.local.json" <<'JSON'
{"schema":1,"overrides":[{"id":"slack-listener","state":"disabled"}],"updated_at":"2026-06-06T00:00:00Z"}
JSON
expect "disabled → not-owned" "not-owned" "$W3" "slack-listener"

# 4. isolate present, host singleton acknowledged → not-owned (ack ≠ owned)
W4=$(mktemp -d); mkdir -p "$W4/.worktree-isolate"
cat > "$W4/.worktree-isolate/feature-overrides.local.json" <<'JSON'
{"schema":1,"overrides":[{"id":"host-crontab","state":"acknowledged"}],"updated_at":"2026-06-06T00:00:00Z"}
JSON
expect "acknowledged → not-owned" "not-owned" "$W4" "host-crontab"

# 5. isolate present but no entry for this id → not-owned (absent = default disabled)
expect "absent entry → not-owned" "not-owned" "$W2" "telegram-bot"

# 6. isolate dir present but overrides file missing → not-owned (set up, nothing enabled)
W6=$(mktemp -d); mkdir -p "$W6/.worktree-isolate"
expect "dir present, no overrides file → not-owned" "not-owned" "$W6" "slack-listener"

rm -rf "$W1" "$W2" "$W3" "$W4" "$W6"
echo "channel-ownership: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
