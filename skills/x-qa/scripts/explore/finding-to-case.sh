#!/usr/bin/env bash
# finding-to-case.sh — mint a YAML **repro stub** (a red, currently-failing case)
# from a confirmed finding, to hand to x-bugfix. It is NOT promoted to the KB now
# (the KB is the green corpus); it becomes a regression case only after the fix
# lands and it goes green via the existing auto-promote path. Novel findings
# (obligation:"none") also mint a new obligation id (printed to stderr) so the
# scout's coverage grows next run. Reads one finding JSON via --finding or stdin.
set -euo pipefail

FINDING=""
while [[ $# -gt 0 ]]; do case "$1" in
  --finding) FINDING="$2"; shift 2 ;;
  *) echo "MINT_ERROR=unknown arg: $1" >&2; exit 2 ;;
esac; done
src=$( [[ -n "$FINDING" ]] && cat "$FINDING" || cat )

# the obligation this case covers — minted for novel findings
covers=$(jq -r '
  def slug: gsub("[^a-zA-Z0-9]+";"-") | ltrimstr("-") | rtrimstr("-") | ascii_downcase;
  if (.obligation == "none") or (.obligation == null)
  then "fmode:" + ((.endpoint // "x")|slug) + ":" + ((.failure_class // "bug")|slug)
  else .obligation end' <<<"$src")

if jq -e '(.obligation == "none") or (.obligation == null)' <<<"$src" >/dev/null; then
  echo "MINTED_OBLIGATION=$covers" >&2
fi

jq -c --arg covers "$covers" '
  { id:            ("explore-" + (.id // "x")),
    feature:       "exploratory",
    category:      "error",
    complexity:    "complex",
    origin:        "explore",
    covers:        [$covers],
    failure_class: (.failure_class // "bug"),
    severity:      (.severity // "major"),
    request:       ((.evidence.request | if type=="object" then . else {} end) + { path: (.endpoint // "/") }),  # carry full repro (method/headers/body) from evidence
    assertions:    [ { kind: "note",
                       expr: ("expected: " + ((.evidence.expected // "") | tostring)
                              + " | observed: " + ((.evidence.observed // "") | tostring)) } ] }
' <<<"$src" | yq -p=json -o=yaml '[.]'
