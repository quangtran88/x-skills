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

# (3) regression: evidence.request as string + evidence.expected/observed as integers must not crash
cat > f3.json <<'JSON'
{"id":"f3","endpoint":"/api/login","obligation":"inv:auth-required","failure_class":"authz-bypass","severity":"blocker","status":"confirmed","evidence":{"request":"oops","expected":403,"observed":200}}
JSON
mint_rc=0
mint_out=$("$MINT" --finding f3.json 2>/dev/null) || mint_rc=$?
[[ "$mint_rc" -eq 0 ]] \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: mint crashed on non-object request / integer expected+observed (exit $mint_rc)"; }
[[ -n "$mint_out" ]] \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: mint produced no YAML output for non-object evidence"; }
# YAML must contain 'observed' key (sanity check the output is parseable)
echo "$mint_out" | grep -q "observed" \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: mint YAML missing 'observed' field"; }

echo "finding-to-case: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
