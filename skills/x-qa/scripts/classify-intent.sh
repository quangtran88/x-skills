#!/usr/bin/env bash
# classify-intent.sh <raw-input>
# Emits intent.json on stdout. Pure bash + jq. No LLM.
set -euo pipefail

RAW="${1:-}"
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROFILE="$REPO_ROOT/.x-skills/x-qa/profile.json"

intent=""; confidence="high"
pr_number=""; branch=""; service=""; spec=""; artifact=""; prose=""

# strip leading/trailing whitespace via parameter expansion (no subshell)
trim="${RAW#"${RAW%%[![:space:]]*}"}"; trim="${trim%"${trim##*[![:space:]]}"}"

# Resolve path-style inputs relative to REPO_ROOT (not cwd) so callers from
# subdirectories don't fall through to prose for valid repo-relative paths.
resolve_in_repo() {
  local rel="$1"
  if [[ "$rel" = /* ]]; then
    printf '%s' "$rel"
  else
    printf '%s/%s' "$REPO_ROOT" "$rel"
  fi
}

if [[ -z "$trim" ]]; then
  intent="branch"
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
elif [[ "$trim" =~ ^(PR[[:space:]]*#?|#)([0-9]+)$ ]]; then
  intent="pr"; pr_number="${BASH_REMATCH[2]}"
elif [[ "$trim" =~ github\.com/[^/]+/[^/]+/pull/([0-9]+) ]]; then
  intent="pr"; pr_number="${BASH_REMATCH[1]}"
elif [[ -f "$PROFILE" ]] && jq -e --arg n "$trim" '.entry_points[] | select(.name==$n)' "$PROFILE" >/dev/null 2>&1; then
  intent="service"; service="$trim"
elif _abs=$(resolve_in_repo "$trim") && [[ -f "$_abs" ]]; then
  case "$trim" in
    docs/*|specs/*|*.md|*.txt|*.rst) intent="spec"; spec="$trim" ;;
    *)                                intent="artifact"; artifact="$trim" ;;
  esac
elif [[ -d "$_abs" ]]; then
  intent="artifact-dir"; artifact="$trim"
elif git show-ref --verify --quiet "refs/heads/$trim" 2>/dev/null \
     || git show-ref --verify --quiet "refs/remotes/origin/$trim" 2>/dev/null; then
  intent="branch"; branch="$trim"
else
  intent="prose"; prose="$trim"
  # short OR slug-only inputs are likely typos / accidental tokens → low
  if [[ "$trim" =~ ^[A-Za-z0-9_-]+$ ]] || [[ ${#trim} -lt 8 ]]; then
    confidence="low"
  else
    confidence="medium"
  fi
fi

jq -n \
  --arg intent "$intent" --arg raw "$RAW" --arg confidence "$confidence" \
  --arg pr "$pr_number" --arg branch "$branch" --arg service "$service" \
  --arg spec "$spec" --arg artifact "$artifact" --arg prose "$prose" \
  '{
     intent: $intent,
     raw: $raw,
     confidence: $confidence,
     resolved: {
       pr_number: (if $pr=="" then null else ($pr|tonumber) end),
       branch:    (if $branch=="" then null else $branch end),
       service_name: (if $service=="" then null else $service end),
       spec_path:    (if $spec=="" then null else $spec end),
       artifact_path:(if $artifact=="" then null else $artifact end),
       prose:        (if $prose=="" then null else $prose end)
     },
     candidates: []
   }'
