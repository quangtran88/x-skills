#!/usr/bin/env bash
# finding-to-case.sh (test) — a confirmed finding mints a red repro stub that
# the coverage gate accepts for its obligation; a novel finding mints a new
# obligation id. Also asserts the triage gate doc exists.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
MINT="$SKILL_DIR/scripts/explore/finding-to-case.sh"
CC="$SKILL_DIR/scripts/coverage-check.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"
pass=0; fail=0

grep -qF "independently verify" "$SKILL_DIR/references/triage-verify.md" \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: triage-verify.md missing gate clause"; }

# (1) a finding tied to a known obligation mints a case covering it
cat > f1.json <<'JSON'
{"id":"f1","endpoint":"/api/avatar","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"blocker","status":"confirmed","evidence":{"request":{"method":"GET"},"expected":"403","observed":"200 with other user's avatar"}}
JSON
case_yaml=$("$MINT" --finding f1.json)
{ echo "feature: x"; echo "entry_point: api"; echo "test_cases:"; echo "$case_yaml" | sed 's/^/  /'; } > plan.yml
cat > scope.json <<'JSON'
{ "obligations":[ {"id":"inv:owner-only","severity":"required"} ] }
JSON
if "$CC" --scope scope.json --plan plan.yml | jq -e '.verdict=="pass"' >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: minted case does not satisfy its obligation"; fi

# (2) a novel finding (obligation:"none") mints a NEW obligation id on stderr
cat > f2.json <<'JSON'
{"id":"f2","endpoint":"/api/orders","obligation":"none","failure_class":"false-case","severity":"major","status":"confirmed","evidence":{"expected":"total=20","observed":"total=18"}}
JSON
minted=$("$MINT" --finding f2.json 2>&1 >/dev/null | grep MINTED_OBLIGATION || true)
[[ -n "$minted" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: novel finding did not mint an obligation"; }

echo "finding-to-case: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
