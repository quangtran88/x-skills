#!/usr/bin/env bash
# calibrate-judge.sh — measure judge↔human agreement (Cohen's kappa) on a gold set.
# Flags: --gold <file.jsonl> --rubric-id <id> [--threshold <0.8>] --out-dir <dir>
# Env:   X_QA_JUDGE_CMD (injectable; same contract as score-case), X_QA_JUDGE_MODEL.
# Writes <out-dir>/<rubric_id>.json: { kappa, n, agreement, judge_model, threshold, gold_checksum, computed_at }
# stdout: same JSON.
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
GOLD="" RUBRIC="" THRESH="0.8" OUT_DIR=""
while [[ $# -gt 0 ]]; do case "$1" in
  --gold) GOLD="$2"; shift 2 ;;
  --rubric-id) RUBRIC="$2"; shift 2 ;;
  --threshold) THRESH="$2"; shift 2 ;;
  --out-dir) OUT_DIR="$2"; shift 2 ;;
  *) echo "calibrate-judge: unknown arg $1" >&2; exit 2 ;;
esac; done
[[ -f "$GOLD" ]] || { echo "calibrate-judge: gold not found: $GOLD" >&2; exit 2; }
[[ -n "$RUBRIC" && -n "$OUT_DIR" ]] || { echo "calibrate-judge: --rubric-id and --out-dir required" >&2; exit 2; }
JUDGE_MODEL="${X_QA_JUDGE_MODEL:-agy-flash}"
JUDGE_CMD="${X_QA_JUDGE_CMD:-}"
run_judge() { if [[ -n "$JUDGE_CMD" ]]; then sh -c "$JUDGE_CMD"; else agy-agent --model flash "$(cat)"; fi }

pairs='[]'
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  output=$(jq -r '.output' <<<"$line")
  reference=$(jq -r '.reference // ""' <<<"$line")
  human=$(jq -r '.human' <<<"$line")
  prompt=$(printf 'Score 0.0-1.0 how well OUTPUT meets the rubric (reference may be empty). Reply ONLY JSON {"score":<0..1>}.\n\nREFERENCE:\n%s\n\nOUTPUT:\n%s\n' "$reference" "$output")
  jraw=$(printf '%s' "$prompt" | run_judge || echo '{"score":0}')
  s=$(jq -r '.score // 0' <<<"$jraw" 2>/dev/null || echo 0)
  [[ "$s" =~ ^-?[0-9]+(\.[0-9]+)?$ ]] || s=0
  jlabel=$(awk "BEGIN{print ($s >= $THRESH) ? \"pass\" : \"fail\"}")
  pairs=$(jq --arg j "$jlabel" --arg h "$human" '. + [{judge:$j, human:$h}]' <<<"$pairs")
done < "$GOLD"

kstats=$(printf '%s' "$pairs" | "$SCRIPT_DIR/cohens-kappa.sh")
checksum=$(shasum -a 256 "$GOLD" | cut -d' ' -f1)
# computed_at injectable for deterministic tests; default to host time.
now="${X_QA_NOW:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
result=$(jq -n --argjson k "$kstats" --arg model "$JUDGE_MODEL" --argjson t "$THRESH" \
  --arg cs "sha256:$checksum" --arg at "$now" \
  '{ kappa:$k.kappa, n:$k.n, agreement:$k.agreement, judge_model:$model,
     threshold:$t, gold_checksum:$cs, computed_at:$at }')
mkdir -p "$OUT_DIR"
printf '%s' "$result" > "$OUT_DIR/$(printf '%s' "$RUBRIC" | tr '/:' '__').json"
printf '%s\n' "$result"
