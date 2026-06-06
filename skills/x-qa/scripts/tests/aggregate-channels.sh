#!/usr/bin/env bash
# aggregate-channels.sh — aggregate-results.sh must emit CHANNELS_TESTED /
# CHANNELS_SKIPPED from <run-dir>/channels.json (empty when absent).
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGG="$SKILL_DIR/scripts/aggregate-results.sh"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"; git init -q

mk_run() { # writes a minimal run-dir + plan into $1, returns plan path on stdout
  local rd="$1"; mkdir -p "$rd/cases"
  cat > "$rd/plan.yaml" <<'YAML'
feature: ch-test
entry_point: api
test_cases:
  - id: tc-1
    category: smoke
YAML
  cat > "$rd/cases/tc-1.json" <<'JSON'
{"id":"tc-1","verdict":"pass","runner":"x","attempts":1,"duration_ms":1,"evidence":{},"error":""}
JSON
  echo "$rd/plan.yaml"
}

pass=0; fail=0
field() { awk -F= -v k="$2" '$1==k{sub(/^[^=]*=/,""); print; exit}' <<<"$1"; }

# 1. channels.json present → CSV + name:reason list, --no-kb to avoid KB side effects
RD="$WORK/run-1"; PLAN=$(mk_run "$RD")
cat > "$RD/channels.json" <<'JSON'
{"tested":["admin-api","webhook"],"skipped":[{"name":"tg","reason":"stateful-not-owned"},{"name":"dash","reason":"stateful-unverifiable"}]}
JSON
set +e; out=$("$AGG" --run-dir "$RD" --plan "$PLAN" --no-kb); rc=$?; set -e
[[ "$rc" -eq 0 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: aggregate-results.sh exited nonzero (rc=$rc) — fields below are unreliable"; }
[[ "$(field "$out" CHANNELS_TESTED)" == "admin-api,webhook" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_TESTED got=[$(field "$out" CHANNELS_TESTED)]"; }
[[ "$(field "$out" CHANNELS_SKIPPED)" == "tg:stateful-not-owned,dash:stateful-unverifiable" ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_SKIPPED got=[$(field "$out" CHANNELS_SKIPPED)]"; }

# 2. channels.json absent → both keys present and empty (back-compat)
RD="$WORK/run-2"; PLAN=$(mk_run "$RD")
set +e; out=$("$AGG" --run-dir "$RD" --plan "$PLAN" --no-kb); rc=$?; set -e
[[ "$rc" -eq 0 ]] && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: aggregate-results.sh exited nonzero (rc=$rc) on absent-channels run"; }
[[ "$(field "$out" CHANNELS_TESTED)" == "" ]] && grep -q '^CHANNELS_TESTED=' <<<"$out" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_TESTED should be present+empty"; }
[[ "$(field "$out" CHANNELS_SKIPPED)" == "" ]] && grep -q '^CHANNELS_SKIPPED=' <<<"$out" && pass=$((pass+1)) || { fail=$((fail+1)); echo "FAIL: CHANNELS_SKIPPED should be present+empty"; }

echo "aggregate-channels: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
