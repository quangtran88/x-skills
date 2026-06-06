#!/usr/bin/env bash
# migrate.sh — convenience upgrade view: heal registry → report pre-existing
# conflicts → prompt rescan → point x-qa users at `x-qa update`. The heal also
# runs lazily on apply/enable/list/doctor, so users who never run migrate still
# get safe behavior; this is just the single "what do I need to do" summary.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=allocate-ports.sh
. "$SCRIPT_DIR/allocate-ports.sh"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "x-worktree-isolate migrate: not inside a git work tree" >&2
  exit 1
fi

xwi_acquire_lock || exit 1
trap 'xwi_release_lock' EXIT
xwi_heal_registry
REG="$(xwi_registry_file)"
SCHEMA="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("registry_schema"))' "$REG" 2>/dev/null || echo "?")"

echo "x-worktree-isolate migrate"
echo "  registry_schema = $SCHEMA (healed in place; safe to re-run)"
echo

CONFLICTS="$(xwi_preexisting_conflicts)"
if [[ -n "$CONFLICTS" ]]; then
  echo "  Pre-existing singleton conflicts (two live worktrees own the same id):"
  while IFS='|' read -r sid owners; do
    [[ -n "$sid" ]] || continue
    echo "    SINGLETON_CONFLICT_PREEXISTING=$sid owners=$owners"
  done <<<"$CONFLICTS"
  echo "    Resolve: run 'x-worktree-isolate disable <id>' in the loser worktree."
  echo
else
  echo "  No pre-existing singleton conflicts."
  echo
fi

cat <<EOF
  Next steps:
    1. Pick up new singleton patterns (e.g. WhatsApp): run from the main checkout:
         x-worktree-isolate init --rescan
       then hand-merge profile.json.new and commit.
    2. For x-qa stateful-aware channel selection, run in each worktree:
         x-qa update
EOF
