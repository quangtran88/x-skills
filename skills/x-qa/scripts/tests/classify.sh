#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURES="$SKILL_DIR/scripts/tests/fixtures/intent-cases.txt"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

# Minimal profile with one entry named "api"
mkdir -p .x-skills/x-qa
cat > .x-skills/x-qa/profile.json <<'JSON'
{ "schema":1, "version":"1.0.0", "primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200},
    "primary":true,"verified":false}]}
JSON

pass=0; fail=0
while IFS='|' read -r expected input setup; do
  [[ "$expected" =~ ^# ]] || [[ -z "$expected" ]] && continue
  case "$setup" in
    create-file-*) path="${setup#create-file-}"; mkdir -p "$(dirname "$path")"; touch "$path" ;;
    create-dir-*)  mkdir -p "${setup#create-dir-}" ;;
  esac
  result=$("$SKILL_DIR/scripts/classify-intent.sh" "$input")
  got=$(echo "$result" | jq -r '.intent')
  err=""
  if [[ "$got" != "$expected" ]]; then
    err="intent: expected=$expected got=$got"
  elif [[ "$expected" == "pr" ]]; then
    pr=$(echo "$result" | jq -r '.resolved.pr_number')
    [[ "$pr" == "42" || "$pr" == "null" ]] || err="pr_number unexpected: $pr"
    [[ "$pr" == "42" ]] || err="pr_number missing: $pr"
  elif [[ "$expected" == "prose" && "$input" == "qwertyfoobar" ]]; then
    conf=$(echo "$result" | jq -r '.confidence')
    [[ "$conf" == "low" ]] || err="confidence for slug expected=low got=$conf"
  fi
  if [[ -z "$err" ]]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: input=[$input] $err"
  fi
done < "$FIXTURES"

# --- channel selection ---
CH=$(mktemp -d)
ch_out=$( cd "$CH"; git init -q
  mkdir -p .x-skills/x-qa
  cat > .x-skills/x-qa/profile.json <<'JSON'
{ "schema":1,"version":"1.0.0","primary_entry_point":"api",
  "entry_points":[{"name":"api","type":"http","auto_managed":true,"primary":true,"verified":false,
    "launch":{"kind":"command","command":"true"},
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1",
    "health":{"method":"GET","path":"/","expected_status":200}}],
  "channels":[{"name":"dashboard","driver":"browser","audience":"user","entry_point":"api",
    "base_url_template":"http://localhost:1","base_url_fallback":"http://localhost:1"}] }
JSON
  c1=$("$SKILL_DIR/scripts/classify-intent.sh" "test the avatar feature via dashboard" | jq -r '.resolved.channel')
  c2=$("$SKILL_DIR/scripts/classify-intent.sh" "dashboard" | jq -r '.resolved.channel')
  c3=$("$SKILL_DIR/scripts/classify-intent.sh" "test something via ghostchannel" | jq -r '.resolved.channel')
  [[ "$c1" == "dashboard" ]] && echo "OK c1" || echo "FAIL c1 got=$c1"
  [[ "$c2" == "dashboard" ]] && echo "OK c2" || echo "FAIL c2 got=$c2"
  [[ "$c3" == "null" ]] && echo "OK c3" || echo "FAIL c3 got=$c3"
)
rm -rf "$CH"
echo "$ch_out"
grep -q "FAIL" <<<"$ch_out" && { echo "channel selection FAILED"; exit 1; } || true

echo "classify smoke: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
