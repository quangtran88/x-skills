#!/usr/bin/env bash
# finding-merge.sh — dedup the exploratory bug-board (one finding JSON per line)
# by signature, keeping the highest-severity instance of each. Emits the unique
# set plus counts the orchestrator folds into the run envelope.
set -euo pipefail

BOARD=""
while [[ $# -gt 0 ]]; do case "$1" in
  --board) BOARD="$2"; shift 2 ;;
  *) echo "MERGE_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
[[ -f "$BOARD" ]] || { echo "MERGE_ERROR=board not found: $BOARD" >&2; exit 2; }

jq -s '
  def rank: {"blocker":3,"major":2,"minor":1}[.] // 0;
  ( map(select(type=="object")) )                           as $all
  | ( $all | group_by(.signature) | map( sort_by(.severity|rank) | last ) ) as $uniq
  | { findings:  $uniq,
      total:     ($all  | length),
      unique:    ($uniq | length),
      confirmed: ([ $uniq[] | select(.status=="confirmed") ] | length),
      novel:     ([ $uniq[] | select(.obligation=="none")  ] | length) }
' "$BOARD"
