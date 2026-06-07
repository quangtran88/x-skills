#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
SUT="$DIR/aggregate-results.sh"
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }
work=$(mktemp -d); mkdir -p "$work/cases"

cat > "$work/plan.yml" <<'YML'
feature: eval-demo
entry_point: api
acceptance: ["llm answers are faithful"]
qa_strategy: {}
test_cases:
  - { id: tc-eval-advisory, category: happy, complexity: complex, description: "rubric", assertions: [{kind: llm-rubric, threshold: 0.8}] }
YML

# One advisory eval case (would-fail downgraded): verdict pass + eval.advisory true
cat > "$work/cases/tc-eval-advisory.json" <<'JSON'
{ "id":"tc-eval-advisory","verdict":"pass","runner":"judge-fake","attempts":3,"duration_ms":0,"error":"",
  "eval":{"kind":"llm-rubric","rubric_id":"r1","samples":3,"passes":0,"pass_rate":0,"mean_score":0.2,"threshold":0.8,"scores":[0.2,0.1,0.3],"kappa":null,"advisory":true,"uncalibrated":true,"reason":"uncalibrated"} }
JSON

env -u CI -u GITHUB_ACTIONS "$SUT" --run-dir "$work" --plan "$work/plan.yml" --no-kb > "$work/env.out"
verdict=$(awk -F= '/^QA_VERDICT=/{print $2}' "$work/env.out")
check "advisory -> warn" "warn" "$verdict"

# Mixed run: a FAILING HTTP case + an advisory eval case, no declared gates.
# The HTTP failure MUST still block (tests.passRate) even though the eval is advisory.
work2=$(mktemp -d); mkdir -p "$work2/cases"
cat > "$work2/plan.yml" <<'YML'
feature: mixed
entry_point: api
acceptance: ["both"]
qa_strategy: {}
test_cases:
  - { id: tc-http-fail, category: happy, complexity: simple, description: http, assertions: [{kind: status, expr: "", op: eq, value: 200}] }
  - { id: tc-eval-adv, category: happy, complexity: complex, description: rubric, assertions: [{kind: llm-rubric, threshold: 0.8}] }
YML
echo '{"id":"tc-http-fail","verdict":"fail","runner":"gemini-flash","attempts":1,"duration_ms":5,"error":"status 500","evidence":{}}' > "$work2/cases/tc-http-fail.json"
cat > "$work2/cases/tc-eval-adv.json" <<'JSON'
{ "id":"tc-eval-adv","verdict":"pass","runner":"judge-fake","attempts":3,"duration_ms":0,"error":"",
  "eval":{"kind":"llm-rubric","rubric_id":"r1","samples":3,"passes":0,"pass_rate":0,"mean_score":0.2,"threshold":0.8,"scores":[0.2,0.1,0.3],"kappa":null,"advisory":true,"uncalibrated":true,"reason":"uncalibrated"} }
JSON
env -u CI -u GITHUB_ACTIONS "$SUT" --run-dir "$work2" --plan "$work2/plan.yml" --no-kb > "$work2/env.out"
check "mixed http-fail blocks -> fail" "fail" "$(awk -F= '/^QA_VERDICT=/{print $2}' "$work2/env.out")"

rm -rf "$work" "$work2"
exit $fail
