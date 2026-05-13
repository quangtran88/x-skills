#!/usr/bin/env bash
# kb-promote.sh — auto-promote KB entries based on the ledger.
# Usage:
#   kb-promote.sh --auto                  (default; reads ledger, promotes)
#   kb-promote.sh --dry-run               (print what would change, no writes)
#   kb-promote.sh --force <case-id>       (promote even without streak)
#
# Reads:  kb/.ledger.jsonl, kb/index.json, <run-dir>/plan-cases/*.yaml
# Writes: kb/cases/*.yaml, kb/flows/*.yaml, kb/index.json
# Output: KB_PROMOTED=<n> KB_PROMOTE_STATUS=ok|disabled|error
#
# Streak math is done in jq for bash-3.2 portability (no associative arrays).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=lib/kb-common.sh
. "$SCRIPT_DIR/lib/kb-common.sh"

# Hardcoded — flow promotion requires chain length >= 2 (single-step "flow"
# is just a case). The original X_QA_KB_FLOW_MIN_LENGTH tunable was cut.
FLOW_MIN_LENGTH=2

MODE="auto"
FORCE_ID=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)     MODE="auto"; shift ;;
    --dry-run)  DRY_RUN=true; shift ;;
    --force)    MODE="force"; FORCE_ID="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$X_QA_KB_DISABLE_AUTO_PROMOTE" && "$MODE" == "auto" ]]; then
  echo "KB_PROMOTED=0"
  echo "KB_PROMOTE_STATUS=disabled"
  exit 0
fi

kb_ensure_layout
INDEX=$(kb_index_path)
LEDGER=$(kb_ledger_path)
CASES_DIR=$(kb_cases_dir)
FLOWS_DIR=$(kb_flows_dir)

kb_assert_schema "$INDEX"

promoted=0

update_index() {
  local filter="$1"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] would update index with: $filter" >&2
    return
  fi
  local tmp; tmp=$(mktemp)
  jq "$filter" "$INDEX" > "$tmp"
  mv "$tmp" "$INDEX"
}

force_promote() {
  local case_id="$1"
  local repo; repo=$(git rev-parse --show-toplevel)
  local body
  body=$(find "$repo/.x-skills/x-qa/runs" -type f \
           \( -name "$case_id.yaml" -o -name "$case_id.yml" \) \
           -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 || true)
  if [[ -z "$body" || ! -f "$body" ]]; then
    echo "✗ kb-promote --force: no body found for $case_id under runs/*/plan-cases/" >&2
    exit 1
  fi
  local dest="$CASES_DIR/$case_id.yaml"
  cp "$body" "$dest"
  local checksum; checksum=$(kb_sha256 "$dest")
  local now; now=$(kb_now)
  update_index "
    .cases[\"$case_id\"] = {
      file: \"cases/$case_id.yaml\",
      endpoint: (.cases[\"$case_id\"].endpoint // \"unknown\"),
      category: (.cases[\"$case_id\"].category // \"unknown\"),
      promoted_at: \"$now\",
      promoted_from_run: (.cases[\"$case_id\"].promoted_from_run // \"manual\"),
      green_streak: 0,
      last_run_id: (.cases[\"$case_id\"].last_run_id // \"\"),
      last_verdict: \"pass\",
      checksum: \"$checksum\"
    }
  "
  promoted=$((promoted + 1))
}

# ---- mode dispatch ----------------------------------------------------------

if [[ "$MODE" == "force" ]]; then
  [[ -z "$FORCE_ID" ]] && { echo "--force requires <case-id>" >&2; exit 2; }
  force_promote "$FORCE_ID"
  echo "KB_PROMOTED=$promoted"
  echo "KB_PROMOTE_STATUS=ok"
  exit 0
fi

if [[ ! -s "$LEDGER" ]]; then
  echo "KB_PROMOTED=0"
  echo "KB_PROMOTE_STATUS=ok"
  exit 0
fi

window=$((X_QA_KB_PROMOTE_AFTER * 2))
RECENT=$(tail -n "$window" "$LEDGER" | jq -s '.')

# Streak computation in jq: fold the ledger chronologically per case id.
#   pass             → streak + 1
#   flaky-recovered  → unchanged (neither extends nor resets)
#   anything else    → reset to 0
STREAK_JSON=$(jq -c '
  [ .[] as $line
    | $line.cases[]?
    | . + {run_id: $line.run_id}
  ] as $rows
  | ($rows | map(.id) | unique) as $ids
  | [
      $ids[] as $id
      | $rows
      | map(select(.id == $id))
      | reduce .[] as $r ({streak:0, ep:"unknown", cat:"unknown", body:null, run:null};
          .ep  = ($r.endpoint   // .ep)
          | .cat = ($r.category // .cat)
          | .body = ($r.body_path // .body)
          | .run = ($r.run_id    // .run)
          | .streak = (
              if   $r.verdict == "pass" then .streak + 1
              elif $r.verdict == "flaky-recovered" then .streak
              else 0
              end
            )
        )
      | . + {id:$id}
    ]
' <<<"$RECENT")

while IFS= read -r row; do
  cid=$(jq -r '.id'     <<<"$row")
  s=$(jq -r   '.streak' <<<"$row")
  body=$(jq -r '.body  // ""' <<<"$row")
  ep=$(jq -r   '.ep'   <<<"$row")
  cat=$(jq -r  '.cat'  <<<"$row")
  run=$(jq -r  '.run  // "unknown"' <<<"$row")
  in_index=$(jq -r --arg id "$cid" '.cases | has($id)' "$INDEX")
  if (( s >= X_QA_KB_PROMOTE_AFTER )) && [[ "$in_index" != "true" ]]; then
    if [[ -z "$body" || ! -f "$body" ]]; then
      echo "[skip] $cid: streak=$s but no body file recorded in ledger" >&2
      continue
    fi
    dest="$CASES_DIR/$cid.yaml"
    if [[ "$DRY_RUN" == true ]]; then
      echo "[dry-run] would promote $cid (streak=$s) from $body" >&2
    else
      cp "$body" "$dest"
      checksum=$(kb_sha256 "$dest")
      now=$(kb_now)
      update_index "
        .cases[\"$cid\"] = {
          file: \"cases/$cid.yaml\",
          endpoint: \"$ep\",
          category: \"$cat\",
          promoted_at: \"$now\",
          promoted_from_run: \"$run\",
          green_streak: $s,
          last_run_id: \"$run\",
          last_verdict: \"pass\",
          checksum: \"$checksum\"
        }
      "
    fi
    promoted=$((promoted + 1))
  fi
done < <(jq -c '.[]' <<<"$STREAK_JSON")

# ---- Flow promotion ---------------------------------------------------------
while IFS= read -r flow_line; do
  [[ -z "$flow_line" || "$flow_line" == "null" ]] && continue
  chain_json=$(jq -c '.chain'              <<<"$flow_line")
  consec=$(jq    -r '.consecutive_pass'    <<<"$flow_line")
  all_pass=$(jq  -r '.all_pass'            <<<"$flow_line")
  [[ "$all_pass" == "true" ]] || continue
  (( consec >= X_QA_KB_PROMOTE_AFTER )) || continue
  chain_len=$(jq 'length' <<<"$chain_json")
  (( chain_len >= FLOW_MIN_LENGTH )) || continue

  ok=$(jq -nr --slurpfile idx "$INDEX" --argjson chain "$chain_json" '
    $chain | all(. as $c | ($idx[0].cases[$c] // null) != null)
  ')
  [[ "$ok" == "true" ]] || continue

  first_id=$(jq -r '.[0]'  <<<"$chain_json")
  last_id=$(jq  -r '.[-1]' <<<"$chain_json")
  first_ep=$(jq -r --arg id "$first_id" '.cases[$id].endpoint // "x"' "$INDEX")
  last_ep=$(jq  -r --arg id "$last_id"  '.cases[$id].endpoint // "y"' "$INDEX")
  slug="fl-$(kb_text_slug "$first_ep-then-$last_ep")"

  exists=$(jq -r --arg id "$slug" '.flows | has($id)' "$INDEX")
  [[ "$exists" == "true" ]] && continue

  dest="$FLOWS_DIR/$slug.yaml"
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] would promote flow $slug (consec=$consec)" >&2
  else
    {
      echo "schema: 1"
      echo "id: $slug"
      echo "provenance:"
      echo "  source: generated"
      echo "  promoted_at: $(kb_now)"
      echo "  author: x-qa-planner"
      echo "description: \"Auto-promoted from $consec consecutive green runs\""
      echo "endpoint_set:"
      while IFS= read -r c; do
        ep=$(jq -r --arg id "$c" '.cases[$id].endpoint // ""' "$INDEX")
        echo "  - \"$ep\""
      done < <(jq -r '.[]' <<<"$chain_json")
      echo "steps:"
      prev=""
      while IFS= read -r c; do
        echo "  - case_id: $c"
        [[ -n "$prev" ]] && echo "    depends_on: [$prev]"
        prev="$c"
      done < <(jq -r '.[]' <<<"$chain_json")
      echo "tags: [auto-promoted]"
    } > "$dest"
    checksum=$(kb_sha256 "$dest")
    update_index "
      .flows[\"$slug\"] = {
        file: \"flows/$slug.yaml\",
        case_ids: $chain_json,
        promoted_at: \"$(kb_now)\",
        promoted_from_run: \"auto\",
        green_streak: $consec,
        last_verdict: \"pass\",
        checksum: \"$checksum\"
      }
    "
  fi
  promoted=$((promoted + 1))
done < <(jq -c '.[].flow_observations[]?' <<<"$RECENT")

echo "KB_PROMOTED=$promoted"
echo "KB_PROMOTE_STATUS=ok"
