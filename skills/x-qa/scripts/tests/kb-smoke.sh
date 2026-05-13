#!/usr/bin/env bash
# kb-smoke.sh — KB layer smoke: writeback + auto-promote + idempotence + flow promo.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_REPO=$(mktemp -d)
TEST_REPO=$(cd "$TEST_REPO" && pwd -P)
trap 'rm -rf "$TEST_REPO"' EXIT

cd "$TEST_REPO"
git init -q

mkrun() {
  local rid="$1" verdict="$2"
  local rdir="$TEST_REPO/.x-skills/x-qa/runs/$rid"
  mkdir -p "$rdir/cases" "$rdir/plan-cases"
  cat > "$rdir/plan.yml" <<EOF
feature: kb-smoke
entry_point: stub
acceptance: ["smoke"]
test_cases:
  - id: tc-login
    category: auth
    complexity: simple
    description: login
    endpoint: "POST /login"
    request: { method: POST, path: /login }
    assertions: [ { kind: status, expr: "", op: eq, value: 200 } ]
  - id: tc-fetch
    category: happy
    complexity: simple
    description: fetch
    endpoint: "GET /me"
    depends_on: [tc-login]
    request: { method: GET, path: /me }
    assertions: [ { kind: status, expr: "", op: eq, value: 200 } ]
EOF
  cp "$rdir/plan.yml" "$rdir/plan-cases/tc-login.yaml"
  cp "$rdir/plan.yml" "$rdir/plan-cases/tc-fetch.yaml"
  cat > "$rdir/cases/tc-login.json" <<EOF
{"id":"tc-login","verdict":"$verdict","runner":"gemini-flash","attempts":1,"evidence":{"response":{"status":200},"latency_ms":42},"duration_ms":42,"error":""}
EOF
  cat > "$rdir/cases/tc-fetch.json" <<EOF
{"id":"tc-fetch","verdict":"$verdict","runner":"gemini-flash","attempts":1,"evidence":{"response":{"status":200},"latency_ms":150},"duration_ms":150,"error":""}
EOF
  "$SKILL_DIR/scripts/aggregate-results.sh" --run-dir "$rdir" --plan "$rdir/plan.yml" --entry-point stub > "$rdir/envelope.txt"
}

assert_env() {
  local rdir="$TEST_REPO/.x-skills/x-qa/runs/$1" key="$2" expected="$3"
  local actual; actual=$(awk -F= -v k="$key" '$1==k{print $2}' "$rdir/envelope.txt")
  [[ "$actual" == "$expected" ]] || { echo "FAIL: run $1 expected $key=$expected got $actual"; exit 1; }
}

echo "→ run 1 (pass)"; mkrun r1 pass
echo "→ run 2 (pass)"; mkrun r2 pass
echo "→ run 3 (pass) — expect promote=3 (2 cases + 1 flow)"
mkrun r3 pass

assert_env r3 KB_PROMOTED 3
assert_env r3 KB_PROMOTE_STATUS ok

n_cases=$(jq -r '.cases | length' "$TEST_REPO/.x-skills/x-qa/kb/index.json")
n_flows=$(jq -r '.flows | length' "$TEST_REPO/.x-skills/x-qa/kb/index.json")
[[ "$n_cases" == "2" ]] || { echo "FAIL: expected 2 cases in corpus, got $n_cases"; exit 1; }
[[ "$n_flows" == "1" ]] || { echo "FAIL: expected 1 flow in corpus, got $n_flows"; exit 1; }

# Idempotence: re-running promotion must not double-count.
"$SKILL_DIR/scripts/kb-promote.sh" --auto > /tmp/idem.txt
grep -q '^KB_PROMOTED=0$' /tmp/idem.txt || { echo "FAIL: not idempotent"; cat /tmp/idem.txt; exit 1; }

# A 4th passing run must not re-promote anything.
echo "→ run 4 (pass) — expect promote=0"
mkrun r4 pass
assert_env r4 KB_PROMOTED 0

# Force-promote a hypothetical id from a runs-tree body — sanity for manual override.
echo "→ force-promote a fresh id"
mkdir -p "$TEST_REPO/.x-skills/x-qa/runs/r4/plan-cases"
cat > "$TEST_REPO/.x-skills/x-qa/runs/r4/plan-cases/tc-fake.yaml" <<'EOF'
schema: 1
id: tc-fake
category: happy
description: "fake"
endpoint: "GET /fake"
request: { method: GET, path: /fake }
assertions: [ { kind: status, expr: "", op: eq, value: 200 } ]
EOF
"$SKILL_DIR/scripts/kb-promote.sh" --force tc-fake >/dev/null
has_fake=$(jq -r '.cases | has("tc-fake")' "$TEST_REPO/.x-skills/x-qa/kb/index.json")
[[ "$has_fake" == "true" ]] || { echo "FAIL: --force did not land tc-fake"; exit 1; }

# kb-list works
"$SKILL_DIR/scripts/kb-list.sh" >/dev/null

# kb-prune --orphans is dry-run by default
"$SKILL_DIR/scripts/kb-prune.sh" --orphans >/dev/null

echo "✓ kb-smoke passed"
