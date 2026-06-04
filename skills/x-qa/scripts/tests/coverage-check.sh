#!/usr/bin/env bash
# coverage-check.sh (test) — golden pass/fail fixtures for the coverage gate.
# Proves the gate (a) passes a plan covering every required obligation and
# (b) fails a plan that drops one, naming the uncovered id.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CC="$SKILL_DIR/scripts/coverage-check.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > scope.json <<'JSON'
{ "obligations":[
  {"id":"field:avatar.size:max-2mb","kind":"field","severity":"required"},
  {"id":"inv:owner-only","kind":"invariant","severity":"required"},
  {"id":"trans:none->active","kind":"transition","severity":"required"},
  {"id":"xtrans:active->active","kind":"illegal-transition","severity":"required"},
  {"id":"fmode:auth:bypass","kind":"failure-mode","severity":"recommended"}
] }
JSON

# complete: covers all REQUIRED (the recommended fmode is intentionally omitted)
cat > complete.yml <<'YML'
feature: avatar
entry_point: api
test_cases:
  - id: tc-happy
    covers: ["trans:none->active", "inv:owner-only"]
  - id: tc-oversize
    covers: ["field:avatar.size:max-2mb"]
  - id: tc-illegal
    covers: ["xtrans:active->active"]
YML

# incomplete: drops xtrans:active->active
cat > incomplete.yml <<'YML'
feature: avatar
entry_point: api
test_cases:
  - id: tc-happy
    covers: ["trans:none->active", "inv:owner-only"]
  - id: tc-oversize
    covers: ["field:avatar.size:max-2mb"]
YML

pass=0; fail=0

# (1) complete plan → exit 0, verdict pass
out=$("$CC" --scope scope.json --plan complete.yml) && rc=0 || rc=$?
if [[ "$rc" -eq 0 ]] && jq -e '.verdict=="pass"' <<<"$out" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: complete should pass (rc=$rc): $out"; fi

# (2) incomplete plan → non-zero, uncovered names the dropped illegal transition
out=$("$CC" --scope scope.json --plan incomplete.yml) && rc=0 || rc=$?
if [[ "$rc" -ne 0 ]] && jq -e '.uncovered | index("xtrans:active->active")' <<<"$out" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: incomplete should fail naming xtrans (rc=$rc): $out"; fi

# (3) recommended-only gap does NOT block (complete plan omits fmode:auth:bypass yet passes)
if jq -e '.verdict=="pass"' <<<"$("$CC" --scope scope.json --plan complete.yml)" >/dev/null; then
  pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: recommended gap must not block"; fi

echo "coverage-check: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
