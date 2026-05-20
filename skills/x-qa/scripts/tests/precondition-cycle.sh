#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p .x-skills/x-qa/kb/cases

cp "$SKILL_DIR/scripts/tests/fixtures/case-with-cycle-a.yaml" \
   .x-skills/x-qa/kb/cases/tc-a.yaml
cp "$SKILL_DIR/scripts/tests/fixtures/case-with-cycle-b.yaml" \
   .x-skills/x-qa/kb/cases/tc-b.yaml

cat > .x-skills/x-qa/kb/index.json <<'JSON'
{ "schema":1, "cases":{
  "tc-a":{"file":"cases/tc-a.yaml","precondition_case_id":"tc-b"},
  "tc-b":{"file":"cases/tc-b.yaml","precondition_case_id":"tc-a"}
}}
JSON

set +e
ERR=$("$SKILL_DIR/scripts/run/resolve-preconditions.sh" tc-a 2>&1 >/dev/null)
STATUS=$?
set -e

[[ "$STATUS" -ne 0 ]] || { echo "FAIL: resolver should have exited non-zero on cycle"; exit 1; }
echo "$ERR" | grep -q "precondition cycle detected" || {
  echo "FAIL: expected 'precondition cycle detected' in stderr, got: $ERR"; exit 1; }

echo "precondition-cycle smoke: PASS"
