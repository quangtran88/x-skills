#!/usr/bin/env bash
# channels.sh — doctor.sh channels[] validation, run in --template-mode
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DOCTOR="$SKILL_DIR/scripts/doctor.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

pass=0; fail=0
expect() { # <desc> <expected-exit> <profile-file>
  local desc="$1" want="$2" file="$3" got=0
  "$DOCTOR" --template-mode "$file" >/dev/null 2>&1 || got=$?
  if [[ "$got" == "$want" ]]; then pass=$((pass+1)); else
    fail=$((fail+1)); echo "FAIL: $desc (want exit $want, got $got)"; fi
}

base='{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}]'

# valid: http channel + browser channel + external chat channel
jq -n "$base, \"channels\":[
  {\"name\":\"admin-api\",\"driver\":\"http\",\"audience\":\"admin\",\"entry_point\":\"api\",
   \"base_url_template\":\"http://localhost:1\",\"base_url_fallback\":\"http://localhost:1\",
   \"auth\":{\"kind\":\"bearer\",\"token_source\":\"env:ADMIN_TOKEN\"}},
  {\"name\":\"dashboard\",\"driver\":\"browser\",\"audience\":\"user\",\"entry_point\":\"api\",
   \"base_url_template\":\"http://localhost:1\",\"base_url_fallback\":\"http://localhost:1\"},
  {\"name\":\"telegram-bot\",\"driver\":\"computer-use\",\"audience\":\"external\",\"entry_point\":\"external\"}
] }" > valid.json
expect "valid channels pass" 0 valid.json

# bad driver
jq '.channels[1].driver="grpc"' valid.json > bad-driver.json
expect "bad driver fails" 1 bad-driver.json

# bad audience
jq '.channels[0].audience="superuser"' valid.json > bad-aud.json
expect "bad audience fails" 1 bad-aud.json

# dangling entry_point ref
jq '.channels[0].entry_point="ghost"' valid.json > bad-ref.json
expect "dangling entry_point fails" 1 bad-ref.json

# literal secret in channel auth (security)
jq '.channels[0].auth.token_source="sk-live-abc123"' valid.json > bad-secret.json
expect "literal secret in channel auth fails" 1 bad-secret.json

# browser driver missing base_url
jq 'del(.channels[1].base_url_template)' valid.json > bad-url.json
expect "browser channel missing base_url fails" 1 bad-url.json

# C5 regression: path-traversal in channel auth token_source must be rejected
jq '.channels[0].auth.token_source="file:../../etc/passwd"' valid.json > bad-traversal.json
expect "path traversal in channel auth token_source fails" 1 bad-traversal.json

# C8: valid singleton_id resolving against an isolate profile → no extra warning
ISO=$(mktemp -d); cd "$ISO"; git init -q; ISO=$(git rev-parse --show-toplevel); mkdir -p .worktree-isolate .x-skills/x-qa
cat > .worktree-isolate/profile.json <<'JSON'
{"schema":2,"singletons":[{"id":"gh-webhook","tier":"compose-service"}]}
JSON
jq '.repo_root="'"$ISO"'" | .channels[0].singleton_id="gh-webhook"' "$WORK/valid.json" > .x-skills/x-qa/profile.json
out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1); rc=$?
if [[ $rc -eq 0 ]] && ! grep -q "first_failure=C8" <<<"$out"; then pass=$((pass+1)); else
  fail=$((fail+1)); echo "FAIL: valid singleton_id should pass doctor (rc=$rc)"; fi

# C8: dangling singleton_id → PASS overall but warnings incremented (never hard-fail)
jq '.repo_root="'"$ISO"'" | .channels[0].singleton_id="ghost-singleton"' "$WORK/valid.json" > .x-skills/x-qa/profile.json
out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1); rc=$?
warn=$(awk -F= '/^warnings=/{print $2}' <<<"$out")
if [[ $rc -eq 0 ]] && [[ "${warn:-0}" -ge 1 ]]; then pass=$((pass+1)); else
  fail=$((fail+1)); echo "FAIL: dangling singleton_id should warn not fail (rc=$rc warn=$warn)"; fi

# Info-nudge: channels present, none DECLARE singleton_id key → info= line on PASS
jq '.repo_root="'"$ISO"'"' "$WORK/valid.json" > .x-skills/x-qa/profile.json  # valid.json channels have no singleton_id key
out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1)
if grep -q "^info=" <<<"$out"; then pass=$((pass+1)); else
  fail=$((fail+1)); echo "FAIL: expected info= nudge when no channel declares singleton_id"; fi

# F5: migrated-stateless — channel carries explicit singleton_id:null → key present → NO nudge.
jq '.repo_root="'"$ISO"'" | .channels[0].singleton_id=null' "$WORK/valid.json" > .x-skills/x-qa/profile.json
out=$("$DOCTOR" .x-skills/x-qa/profile.json 2>&1)
if ! grep -q "^info=" <<<"$out"; then pass=$((pass+1)); else
  fail=$((fail+1)); echo "FAIL: explicit singleton_id:null (migrated stateless) must NOT emit info= nudge"; fi

# C8 no-op under --template-mode with no isolate profile (must not error)
jq '.channels[0].singleton_id="anything"' "$WORK/valid.json" > template-sid.json
cd "$WORK"
expect "singleton_id under template-mode (no isolate) passes" 0 "$ISO/template-sid.json"
rm -rf "$ISO"

# --- update preserves user-edited channels + warns on stale QA_MEMORY.md ---
UP=$(mktemp -d)
up_out=$( cd "$UP"; git init -q; mkdir -p .x-skills/x-qa
  jq '. + {repo_root:"'"$UP"'"}' "$WORK/valid.json" > .x-skills/x-qa/profile.json
  # reconciled scan drops the dashboard channel; user marked it auto_managed:false
  jq '.channels[1].auto_managed=false' .x-skills/x-qa/profile.json > .x-skills/x-qa/profile.json.tmp \
    && mv .x-skills/x-qa/profile.json.tmp .x-skills/x-qa/profile.json
  jq 'del(.channels[1])' .x-skills/x-qa/profile.json > reconciled.json
  if "$SKILL_DIR/scripts/update.sh" --reconciled-json reconciled.json >/dev/null 2>&1; then
    echo "FAIL upd: dropped a user-edited channel without --allow-overwrite-user-edits"
  else echo "OK upd"; fi
)
rm -rf "$UP"
echo "$up_out"
grep -q "FAIL upd" <<<"$up_out" && fail=$((fail+1)) || pass=$((pass+1))

# Example profile must carry a stateful channel with a non-null singleton_id
EX="$SKILL_DIR/templates/profile.example.json"
if [[ "$(jq -r '[.channels[]? | select(.singleton_id != null)] | length' "$EX")" -ge 1 ]]; then
  pass=$((pass+1))
else
  fail=$((fail+1)); echo "FAIL: profile.example.json has no channel with a non-null singleton_id"
fi
# Stateless channels must explicitly carry singleton_id:null (derived statefulness)
if jq -e '[.channels[]? | select(has("singleton_id") | not)] | length == 0' "$EX" >/dev/null; then
  pass=$((pass+1))
else
  fail=$((fail+1)); echo "FAIL: profile.example.json has a channel missing the singleton_id key"
fi

echo "channels: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
