#!/usr/bin/env bash
# kb-export.sh — tar+gz the KB for sharing across teams.
# Usage: kb-export.sh <out.tgz>
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/lib/kb-common.sh"

OUT="${1:-}"
[[ -z "$OUT" ]] && { echo "Usage: kb-export.sh <out.tgz>" >&2; exit 2; }

ROOT=$(kb_root)
[[ -d "$ROOT" ]] || { echo "✗ no KB at $ROOT" >&2; exit 1; }

# Bundle the KB layout but omit transient files.
tar -C "$(dirname "$ROOT")" -czf "$OUT" \
  --exclude='kb/.ledger.jsonl' \
  kb
echo "✓ exported $(du -sh "$OUT" | awk '{print $1}') → $OUT"
