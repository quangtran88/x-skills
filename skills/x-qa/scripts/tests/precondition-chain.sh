#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p .x-skills/x-qa/kb/cases

cat > .x-skills/x-qa/kb/cases/tc-login-bearer.yaml <<'YAML'
id: tc-login-bearer
endpoint: POST /api/auth/login
category: setup
coverage_signature: "POST /api/auth/login :: bearer"
steps:
  - method: POST
    path: /api/auth/login
    body: { user: "alice", pass: "secret" }
    expect: { status: 200, capture: { bearer_token: ".token" } }
YAML

cp "$SKILL_DIR/scripts/tests/fixtures/case-with-precondition.yaml" \
   .x-skills/x-qa/kb/cases/tc-feature-x.yaml

cat > .x-skills/x-qa/kb/index.json <<'JSON'
{ "schema":1, "cases":{
  "tc-login-bearer":{"file":"cases/tc-login-bearer.yaml","coverage_signature":"POST /api/auth/login :: bearer"},
  "tc-feature-x":{"file":"cases/tc-feature-x.yaml","coverage_signature":"POST /api/feature/x :: happy","precondition_case_id":"tc-login-bearer"}
}}
JSON

CHAIN=$("$SKILL_DIR/scripts/run/resolve-preconditions.sh" tc-feature-x)
LEN=$(echo "$CHAIN" | jq 'length')
[[ "$LEN" -eq 2 ]] || { echo "FAIL: expected 2 chained steps, got $LEN"; exit 1; }

FIRST=$(echo "$CHAIN" | jq -r '.[0].path')
[[ "$FIRST" == "/api/auth/login" ]] || { echo "FAIL: expected login first, got $FIRST"; exit 1; }

echo "precondition-chain smoke: PASS"
