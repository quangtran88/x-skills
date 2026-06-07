#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
FIX="$DIR/tests/fixtures/evals"
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }
chmod +x "$FIX/fake-output.sh" "$FIX/fake-judge.sh"
work=$(mktemp -d); mkdir -p "$work/cases" "$work/calib"

cat > "$work/case.json" <<'JSON'
{ "id":"tc-e2e","request":{"method":"GET","path":"/ask"},
  "assertions":[{"kind":"llm-rubric","rubric_id":"r-e2e","criteria":"mentions Paris","threshold":0.8,"samples":3}] }
JSON
cat > "$work/plan.yml" <<'YML'
feature: e2e
entry_point: api
acceptance: ["ok"]
qa_strategy: {}
test_cases:
  - { id: tc-e2e, category: happy, complexity: complex, description: rubric, assertions: [{kind: llm-rubric, threshold: 0.8}] }
YML

# Calibrated judge (kappa 0.95) + failing score → hard fail end-to-end
echo '{"kappa":0.95,"n":50,"judge_model":"fake"}' > "$work/calib/r-e2e.json"
FAKE_SCORE=0.1 X_QA_JUDGE_MODEL=fake X_QA_OUTPUT_CMD="$FIX/fake-output.sh" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$DIR/evals/score-case.sh" --case "$work/case.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work" >/dev/null
env -u CI -u GITHUB_ACTIONS "$DIR/aggregate-results.sh" --run-dir "$work" --plan "$work/plan.yml" --no-kb > "$work/env.out"
check "calibrated fail -> run fail" "fail" "$(awk -F= '/^QA_VERDICT=/{print $2}' "$work/env.out")"

rm -rf "$work"
exit $fail
