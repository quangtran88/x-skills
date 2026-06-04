#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$SKILL_DIR/scripts/lib/scan-helpers.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src"
cat > "$WORK/package.json" <<'JSON'
{ "dependencies": { "telegraf": "^4.0.0", "next": "^14" } }
JSON
cat > "$WORK/next.config.js" <<'JS'
module.exports = {}
JS

out=$(scan_channels "$WORK")
pass=0; fail=0
check() { if echo "$out" | jq -e "$1" >/dev/null; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $2"; fi; }

check 'map(select(.name=="telegram"))|length==1' "telegram bot-sdk hint"
check 'map(select(.driver=="computer-use"))|length>=1' "chat hint uses computer-use driver"
check 'map(select(.name=="dashboard" and .driver=="browser"))|length==1' "dashboard browser hint"
check 'all(.[]; has("confidence"))' "every hint has confidence"

echo "scan-channels: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
