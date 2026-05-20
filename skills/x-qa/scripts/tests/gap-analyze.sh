#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p .x-skills/x-qa/kb/history

cat > .x-skills/x-qa/kb/index.json <<'JSON'
{"schema":1,"cases":{
  "tc-a":{"coverage_signature":"POST /a :: happy","endpoint":"POST /a","category":"happy"},
  "tc-b":{"coverage_signature":"POST /b :: happy","endpoint":"POST /b","category":"happy"},
  "tc-c":{"coverage_signature":"POST /c :: happy","endpoint":"POST /c","category":"happy"}
}}
JSON

# tc-a: no history → untested
# tc-b: history 30 days old → stale
THIRTY=$(date -u -v-30d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
echo "{\"run_id\":\"r1\",\"timestamp\":\"$THIRTY\",\"result\":\"pass\"}" \
  > .x-skills/x-qa/kb/history/post-b-happy.jsonl

# tc-c: pass then fail → regression
echo '{"run_id":"r1","timestamp":"2026-05-19T00:00:00Z","result":"pass"}' \
  >> .x-skills/x-qa/kb/history/post-c-happy.jsonl
echo '{"run_id":"r2","timestamp":"2026-05-20T00:00:00Z","result":"fail","failure_reason":"503"}' \
  >> .x-skills/x-qa/kb/history/post-c-happy.jsonl

OUT=$("$SKILL_DIR/scripts/gap-analyze.sh" --staleness-days 7)
echo "$OUT" | jq -e '.gaps.untested | length == 1' >/dev/null   || { echo "FAIL: untested"; exit 1; }
echo "$OUT" | jq -e '.gaps.stale | length == 1' >/dev/null      || { echo "FAIL: stale"; exit 1; }
echo "$OUT" | jq -e '.gaps.regression | length == 1' >/dev/null || { echo "FAIL: regression"; exit 1; }
echo "gap-analyze smoke: PASS"
