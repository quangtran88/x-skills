#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")/.." && pwd)
FIX="$DIR/tests/fixtures/evals"
SUT="$DIR/evals/calibrate-judge.sh"
fail=0
check() { if [[ "$2" != "$3" ]]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi }
work=$(mktemp -d)

# Perfect judge: score 0.95 for outputs containing "Paris", else 0.1.
cat > "$work/judge.sh" <<'JS'
#!/usr/bin/env bash
set -euo pipefail
p=$(cat)
if printf '%s' "$p" | grep -qi 'paris'; then jq -n '{score:0.95}'; else jq -n '{score:0.1}'; fi
JS
chmod +x "$work/judge.sh"

out=$(X_QA_JUDGE_MODEL=fake X_QA_JUDGE_CMD="$work/judge.sh" \
  "$SUT" --gold "$FIX/gold-r-geo.jsonl" --rubric-id r-geo --threshold 0.8 --out-dir "$work")
check "kappa perfect" "1" "$(jq -r '.kappa' <<<"$out")"
check "n" "4" "$(jq -r '.n' <<<"$out")"
check "model recorded" "fake" "$(jq -r '.judge_model' <<<"$out")"
check "file written" "1" "$(jq -r '.kappa' "$work/r-geo.json")"

rm -rf "$work"
exit $fail
