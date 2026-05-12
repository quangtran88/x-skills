#!/usr/bin/env bash
# topo-order.sh — read test-plan JSON on stdin, emit { "waves": [[id,...], ...] }.
# Empty plan (no test_cases) yields { "waves": [] } with exit 0.
# Exit 0 = OK, 1 = malformed input or unknown dependency id, 2 = cycle detected.
set -euo pipefail

plan=$(cat) || { echo "read failed" >&2; exit 1; }

echo "$plan" | jq -e '.test_cases' >/dev/null || { echo "missing test_cases" >&2; exit 1; }

# Pre-flight: test_case ids must be unique. Schema (test-plan-schema.md) requires
# uniqueness; aggregators key result files by id, so duplicates silently
# double-count and corrupt totals.
duplicates=$(echo "$plan" | jq -r '[.test_cases[].id] | group_by(.) | map(select(length>1)) | .[][0]' | sort -u)
if [[ -n "$duplicates" ]]; then
  echo "topo-order: duplicate test_case ids:" >&2
  echo "$duplicates" | sed 's/^/  /' >&2
  exit 1
fi

# Pre-flight: every depends_on id must reference a declared test_case id
dangling=$(echo "$plan" | jq -r '
  (.test_cases | map(.id)) as $ids
  | .test_cases[]
  | .id as $src
  | (.depends_on // [])[]
  | select(. as $d | $ids | index($d) == null)
  | "\($src) -> \(.)"
')
if [[ -n "$dangling" ]]; then
  echo "topo-order: unknown dependency ids:" >&2
  echo "$dangling" >&2
  exit 1
fi

result=$(echo "$plan" | jq -c '
  def kahn:
    . as $plan
    | ($plan.test_cases | map({ id: .id, deps: (.depends_on // []) })) as $nodes
    | { waves: [], remaining: $nodes }
    | until((.remaining|length) == 0;
        (.remaining | map(select((.deps|length) == 0)) | map(.id)) as $ready
        | if ($ready|length) == 0 then .cycle = true | .remaining = [] else . end
        | if .cycle == true then . else
            .waves += [$ready]
            | .remaining |= (
                map(select((.id as $i | $ready | index($i)) | not))
                | map(.deps |= map(select(. as $d | $ready | index($d) | not)))
              )
          end
      )
    | if .cycle == true then { cycle: true } else { waves: .waves } end;
  kahn
')

if echo "$result" | jq -e '.cycle == true' >/dev/null; then
  echo "topo-order: cycle detected in depends_on" >&2
  exit 2
fi

echo "$result"
