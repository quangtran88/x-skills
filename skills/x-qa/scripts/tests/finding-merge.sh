#!/usr/bin/env bash
# finding-merge.sh (test) — golden dedup of the bug-board. Proves duplicate
# signatures collapse to one (keeping the highest severity) and novel findings
# (obligation:"none") are counted.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
FM="$SKILL_DIR/scripts/explore/finding-merge.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > board.jsonl <<'JSONL'
{"id":"f1","signature":"default|/api/avatar|inv:owner-only|authz-bypass","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"major","status":"confirmed"}
{"id":"f2","signature":"default|/api/avatar|inv:owner-only|authz-bypass","obligation":"inv:owner-only","failure_class":"authz-bypass","severity":"blocker","status":"confirmed"}
{"id":"f3","signature":"default|/api/avatar|none|false-case","obligation":"none","failure_class":"false-case","severity":"major","status":"confirmed"}
{"id":"f4","signature":"default|/api/avatar|fmode:upload:oversize|crash","obligation":"fmode:upload:oversize","failure_class":"crash","severity":"minor","status":"rejected"}
JSONL

pass=0; fail=0
out=$("$FM" --board board.jsonl)

[[ "$(jq '.total'  <<<"$out")" -eq 4 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: total != 4"; }
[[ "$(jq '.unique' <<<"$out")" -eq 3 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: unique != 3 (dup not merged)"; }
jq -e '.findings[] | select(.signature|endswith("authz-bypass")) | select(.severity=="blocker")' <<<"$out" >/dev/null \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: dedup did not keep highest severity"; }
[[ "$(jq '.novel'  <<<"$out")" -eq 1 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: novel != 1"; }

echo "finding-merge: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
