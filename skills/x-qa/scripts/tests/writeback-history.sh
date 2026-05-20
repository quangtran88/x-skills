#!/usr/bin/env bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p .x-skills/x-qa/kb/history
echo '{}' > .x-skills/x-qa/kb/index.json

for line in 1 2 3; do
  RUN=$(sed -n "${line}p" "$SKILL_DIR/scripts/tests/fixtures/ledger-with-regressions.jsonl")
  echo "$RUN" | "$SKILL_DIR/scripts/kb-writeback.sh" --stdin
done

SIG_FILE=".x-skills/x-qa/kb/history/post-a-happy.jsonl"
[[ -f "$SIG_FILE" ]] || { echo "FAIL: history file not created at $SIG_FILE"; exit 1; }
[[ $(wc -l < "$SIG_FILE") -eq 3 ]] || { echo "FAIL: expected 3 lines, got $(wc -l < "$SIG_FILE")"; exit 1; }

REG=$("$SKILL_DIR/scripts/kb-writeback.sh" --check-regression "post-a-happy")
[[ "$REG" == "true" ]] || { echo "FAIL: expected regression=true, got $REG"; exit 1; }

echo "writeback-history smoke: PASS"
