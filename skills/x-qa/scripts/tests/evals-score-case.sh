#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
FIX="$DIR/tests/fixtures/evals"
SUT="$DIR/evals/score-case.sh"
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }

chmod +x "$FIX/fake-output.sh" "$FIX/fake-judge.sh"
work=$(mktemp -d)
mkdir -p "$work/cases" "$work/calib"

# A case with an llm-rubric eval assertion
cat > "$work/case.json" <<'JSON'
{ "id":"tc-capital-rubric", "request":{"method":"GET","path":"/ask?q=capital-of-france"},
  "assertions":[{"kind":"llm-rubric","rubric_id":"r-geo","criteria":"States that Paris is the capital of France.","threshold":0.8,"samples":3}] }
JSON

# (a) No calibration present → judge passes (0.9>=0.8) → verdict pass, not advisory
out=$(X_QA_OUTPUT_CMD="$FIX/fake-output.sh" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$SUT" --case "$work/case.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work")
check "pass verdict" "pass" "$(jq -r '.verdict' <<<"$out")"
check "eval block present" "3" "$(jq -r '.eval.samples' <<<"$out")"
check "result file written" "pass" "$(jq -r '.verdict' "$work/cases/tc-capital-rubric.json")"

# (b) Judge scores below threshold, uncalibrated → advisory pass (would-fail downgraded)
out=$(FAKE_SCORE=0.2 X_QA_OUTPUT_CMD="$FIX/fake-output.sh" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$SUT" --case "$work/case.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work")
check "advisory verdict" "pass" "$(jq -r '.verdict' <<<"$out")"
check "advisory flag" "true" "$(jq -r '.eval.advisory' <<<"$out")"
check "uncalibrated flag" "true" "$(jq -r '.eval.uncalibrated' <<<"$out")"

# (c) Judge below threshold, calibrated kappa=0.93 → hard fail
echo '{"kappa":0.93,"n":50,"judge_model":"fake","computed_at":"2026-06-06T00:00:00Z"}' > "$work/calib/r-geo.json"
out=$(FAKE_SCORE=0.2 X_QA_JUDGE_MODEL=fake X_QA_OUTPUT_CMD="$FIX/fake-output.sh" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$SUT" --case "$work/case.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work")
check "calibrated fail" "fail" "$(jq -r '.verdict' <<<"$out")"
check "calibrated not-advisory" "false" "$(jq -r '.eval.advisory' <<<"$out")"

# (d) Default curl path (no X_QA_OUTPUT_CMD): a body-less GET must NOT send a
#     request body/Content-Type; a case WITH a body must send --data-raw. Shadow
#     `curl` on PATH to capture argv. This is the ONE test that exercises the real
#     curl branch — regression guard for the `// {}` always-send-body bug.
shim="$work/bin"; mkdir -p "$shim"
cat > "$shim/curl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CURL_ARGV_LOG"
printf '%s' '{"answer":"Paris"}'
SH
chmod +x "$shim/curl"

cat > "$work/case-get.json" <<'JSON'
{ "id":"tc-get","request":{"method":"GET","path":"/ask"},
  "assertions":[{"kind":"llm-rubric","rubric_id":"r-geo","criteria":"x","threshold":0.8,"samples":1}] }
JSON
export CURL_ARGV_LOG="$work/curl-get.log"; : > "$CURL_ARGV_LOG"
PATH="$shim:$PATH" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$SUT" --case "$work/case-get.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work" >/dev/null
if grep -q -- '--data-raw' "$CURL_ARGV_LOG" || grep -q 'Content-Type' "$CURL_ARGV_LOG"; then
  echo "FAIL: body-less GET sent a request body"; fail=1; else echo "ok: body-less GET has no request body"; fi

cat > "$work/case-post.json" <<'JSON'
{ "id":"tc-post","request":{"method":"POST","path":"/ask","body":{"q":"capital"}},
  "assertions":[{"kind":"llm-rubric","rubric_id":"r-geo","criteria":"x","threshold":0.8,"samples":1}] }
JSON
export CURL_ARGV_LOG="$work/curl-post.log"; : > "$CURL_ARGV_LOG"
PATH="$shim:$PATH" X_QA_JUDGE_CMD="$FIX/fake-judge.sh" \
  "$SUT" --case "$work/case-post.json" --base-url http://x --calibration-dir "$work/calib" --run-dir "$work" >/dev/null
grep -q -- '--data-raw' "$CURL_ARGV_LOG" && echo "ok: POST with body sends --data-raw" || { echo "FAIL: POST body not sent"; fail=1; }

rm -rf "$work"
exit $fail
