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

# ── Regression: malformed board lines must not abort the merge ──────────────
# The board below has: a stray prose line, a ```json fence line, and 2 valid
# finding objects sharing a signature (should dedup down to 1 unique).
cat > board-malformed.jsonl <<'JSONL'
This line is plain prose that is not JSON at all.
```json
{"id":"m1","signature":"svc|/foo|none|crash","obligation":"none","failure_class":"crash","severity":"major","status":"confirmed"}
{"id":"m2","signature":"svc|/foo|none|crash","obligation":"none","failure_class":"crash","severity":"blocker","status":"confirmed"}
JSONL

merge_rc=0
merge_out=$("$FM" --board board-malformed.jsonl 2>/dev/null) || merge_rc=$?
[[ "$merge_rc" -eq 0 ]] \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: merge aborted on malformed board (exit $merge_rc)"; }
[[ "$(jq '.unique' <<<"$merge_out" 2>/dev/null)" -eq 1 ]] \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: malformed board — unique != 1 (got: $merge_out)"; }

echo "finding-merge: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
