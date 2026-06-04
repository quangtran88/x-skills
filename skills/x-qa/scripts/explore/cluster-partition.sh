#!/usr/bin/env bash
# cluster-partition.sh — deterministically partition scope.json.obligations[]
# into ≤ --max-workers cohesive clusters (one exploratory worker per cluster).
# Obligations are grouped by "topic" (the entity/area they belong to) so a worker
# owns a coherent slice; topics are then bin-packed round-robin into the cap.
# bash 3.2 + jq only (no assoc arrays). Deterministic: jq `unique` sorts.
set -euo pipefail

SCOPE="" MAXW=6 CHANNEL="default"
while [[ $# -gt 0 ]]; do case "$1" in
  --scope)       SCOPE="$2";   shift 2 ;;
  --max-workers) MAXW="$2";    shift 2 ;;
  --channel)     CHANNEL="$2"; shift 2 ;;
  *) echo "CLUSTER_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
[[ -f "$SCOPE" ]] || { echo "CLUSTER_ERROR=scope not found: $SCOPE" >&2; exit 2; }

jq --argjson maxw "$MAXW" --arg channel "$CHANNEL" '
  # topic = the cohesive area an obligation belongs to
  def topic:
    .id as $i
    | if   ($i|startswith("field:"))  then ($i|ltrimstr("field:")|split(".")[0])
      elif ($i|startswith("inv:"))    then "invariant"
      elif ($i|startswith("trans:")) or ($i|startswith("xtrans:")) then "state"
      elif ($i|startswith("fmode:"))  then ($i|ltrimstr("fmode:")|split(":")[0])
      else "misc" end;
  [ .obligations[]? | . + {topic: topic} ]          as $obs0
  | ([ $obs0[].topic ] | unique)                    as $topics   # sorted ⇒ deterministic
  | ([ ($topics|length), $maxw ] | min)             as $nbins
  # bind each obligation'"'"'s bin via a captured topic var — jq'"'"'s `index()` evaluates
  # its arg against the piped-in array, so `.topic` must be hoisted out first
  # (else `$topics|index(.topic)` indexes the array with the string "topic").
  | [ $obs0[] | (.topic) as $t | . + {bin: (($topics|index($t)) % $nbins)} ] as $obs
  | [ range(0; $nbins) as $b
      | { id: ("cluster-" + ($b|tostring)),
          channel: $channel,
          obligations: [ $obs[] | select(.bin == $b) | del(.bin) ] }
      | select(.obligations | length > 0)
      | . + { topics: ([.obligations[].topic] | unique) } ]
  | { clusters: . }
' "$SCOPE"
