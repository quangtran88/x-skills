#!/usr/bin/env bash
# cluster-partition.sh (test) — golden partition of obligations into ≤N cohesive
# clusters. Proves: cluster count is bounded, every obligation lands in exactly
# one cluster (no loss/dup), each cluster is well-formed, and it is deterministic.
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CP="$SKILL_DIR/scripts/explore/cluster-partition.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT; cd "$WORK"

cat > scope.json <<'JSON'
{ "obligations":[
  {"id":"field:avatar.size:max-2mb","kind":"field","ref":"avatar.size","severity":"required"},
  {"id":"inv:owner-only","kind":"invariant","ref":"owner-only","severity":"required"},
  {"id":"trans:none->active","kind":"transition","ref":"none->active","severity":"required"},
  {"id":"xtrans:active->active","kind":"illegal-transition","ref":"active->active","severity":"required"},
  {"id":"fmode:auth:bypass","kind":"failure-mode","ref":"auth:bypass","severity":"recommended"},
  {"id":"fmode:upload:oversize","kind":"failure-mode","ref":"upload:oversize","severity":"recommended"},
  {"id":"inv:balance-nonneg","kind":"invariant","ref":"balance-nonneg","severity":"required"}
] }
JSON

pass=0; fail=0
out=$("$CP" --scope scope.json --max-workers 3)

n=$(jq '.clusters | length' <<<"$out")
[[ "$n" -le 3 && "$n" -ge 1 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: cluster count $n not in 1..3"; }

total=$(jq '[.clusters[].obligations[]] | length' <<<"$out")
[[ "$total" -eq 7 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: partitioned $total/7 obligations"; }

uniq=$(jq '[.clusters[].obligations[].id] | unique | length' <<<"$out")
[[ "$uniq" -eq 7 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: $uniq unique ids (obligation duped across clusters)"; }

jq -e 'all(.clusters[]; has("id") and has("channel") and has("obligations"))' <<<"$out" >/dev/null \
  && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: cluster missing id/channel/obligations"; }

out2=$("$CP" --scope scope.json --max-workers 3)
[[ "$out" == "$out2" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: non-deterministic partition"; }

echo "cluster-partition: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
