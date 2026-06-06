#!/usr/bin/env bash
# channel-select.sh — unit-test the stateless-first / stateful-aware decision table.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
SEL="$SKILL_DIR/scripts/lib/channel-select.sh"
pass=0; fail=0
ok() { if [[ "$2" == "$3" ]]; then pass=$((pass+1)); else
  fail=$((fail+1)); echo "FAIL: $1 (want '$3', got '$2')"; fi; }

mkprofile() { # writes profile.json with the given channels[] JSON into $1
  cat > "$1" <<JSON
{ "schema":1,"version":"1.3.0","primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}],
  "channels": $2 }
JSON
}
enable_singleton() { # <worktree> <id> <state>
  mkdir -p "$1/.worktree-isolate"
  cat > "$1/.worktree-isolate/feature-overrides.local.json" <<JSON
{"schema":1,"overrides":[{"id":"$2","state":"$3"}],"updated_at":"2026-06-06T00:00:00Z"}
JSON
}

CH_STATELESS='[{"name":"admin-api","driver":"http","audience":"admin","entry_point":"api","singleton_id":null,"base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}]'
CH_HTTP_STATEFUL='[{"name":"webhook","driver":"http","audience":"system","entry_point":"api","singleton_id":"gh-webhook","base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}]'
CH_CHAT_STATEFUL='[{"name":"tg","driver":"computer-use","audience":"external","entry_point":"external","singleton_id":"telegram-bot"}]'

# A. stateless channel always tested, isolate absent
W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_STATELESS"
out=$("$SEL" --profile "$P" --worktree "$W")
ok "stateless tested" "$(jq -rc '.tested' <<<"$out")" '["admin-api"]'
ok "stateless no skips" "$(jq -rc '.skipped' <<<"$out")" '[]'

# B. http stateful, NOT owned (isolate absent) → unverifiable skip
W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"
out=$("$SEL" --profile "$P" --worktree "$W")
ok "http stateful isolate-absent skip" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"webhook","reason":"stateful-unverifiable"}]'
ok "http stateful unverifiable not tested" "$(jq -rc '.tested' <<<"$out")" '[]'

# C. http stateful, isolate present but disabled → not-owned skip
W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"; enable_singleton "$W" "gh-webhook" "disabled"
out=$("$SEL" --profile "$P" --worktree "$W")
ok "http stateful not-owned skip" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"webhook","reason":"stateful-not-owned"}]'

# D. http stateful, OWNED → tested (R1 carve-out)
W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_HTTP_STATEFUL"; enable_singleton "$W" "gh-webhook" "enabled"
out=$("$SEL" --profile "$P" --worktree "$W")
ok "http stateful owned tested" "$(jq -rc '.tested' <<<"$out")" '["webhook"]'
ok "http stateful owned no skip" "$(jq -rc '.skipped' <<<"$out")" '[]'

# E. chat stateful, OWNED → deferred skip
W=$(mktemp -d); P="$W/profile.json"; mkprofile "$P" "$CH_CHAT_STATEFUL"; enable_singleton "$W" "telegram-bot" "enabled"
out=$("$SEL" --profile "$P" --worktree "$W")
ok "chat stateful owned deferred" "$(jq -rc '.skipped' <<<"$out")" '[{"name":"tg","reason":"stateful-owned-chat-driver-deferred"}]'

# F. back-compat: no channels[] → implicit primary http channel tested, nothing skipped
W=$(mktemp -d); P="$W/profile.json"
cat > "$P" <<'JSON'
{ "schema":1,"version":"1.0.0","primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}] }
JSON
out=$("$SEL" --profile "$P" --worktree "$W")
ok "no channels → implicit primary tested" "$(jq -rc '.tested' <<<"$out")" '["api"]'
ok "no channels → no skips" "$(jq -rc '.skipped' <<<"$out")" '[]'

# G. --channel selects a single named channel only
W=$(mktemp -d); P="$W/profile.json"
mkprofile "$P" "$(jq -c '. + '"$CH_HTTP_STATEFUL" <<<"$CH_STATELESS")"
out=$("$SEL" --profile "$P" --worktree "$W" --channel admin-api)
ok "--channel narrows to one tested" "$(jq -rc '.tested' <<<"$out")" '["admin-api"]'
ok "--channel ignores other channels" "$(jq -rc '.skipped' <<<"$out")" '[]'

echo "channel-select: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
