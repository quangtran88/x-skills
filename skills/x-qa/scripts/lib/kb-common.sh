#!/usr/bin/env bash
# kb-common.sh — shared helpers for kb-*.sh scripts.
# Source via: . "$(dirname "$0")/lib/kb-common.sh"
set -euo pipefail

# Tunables — env vars with documented defaults (see references/kb-curation.md).
: "${X_QA_KB_PROMOTE_AFTER:=3}"
: "${X_QA_KB_DISABLE_AUTO_PROMOTE:=}"

kb_root() {
  local repo
  repo=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "✗ kb-common: not in a git repo" >&2; exit 2
  }
  echo "$repo/.x-skills/x-qa/kb"
}

kb_index_path()      { echo "$(kb_root)/index.json"; }
kb_cases_dir()       { echo "$(kb_root)/cases"; }
kb_flows_dir()       { echo "$(kb_root)/flows"; }
kb_baselines_dir()   { echo "$(kb_root)/baselines"; }
kb_ledger_path()     { echo "$(kb_root)/.ledger.jsonl"; }

# Ensure the KB directory layout exists. Idempotent.
kb_ensure_layout() {
  local root; root=$(kb_root)
  mkdir -p "$root/cases" "$root/flows" "$root/baselines"
  if [[ ! -f "$root/index.json" ]]; then
    local ts; ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local repo; repo=$(git rev-parse --show-toplevel)
    jq -n --arg ts "$ts" --arg root "$repo" '{
      schema: 1, version: "1.0.0", generated_at: $ts, repo_root: $root,
      cases: {}, flows: {}, baselines: {}
    }' > "$root/index.json"
  fi
  touch "$root/.ledger.jsonl"
}

# Refuse if schema != 1 in any KB file we touch.
kb_assert_schema() {
  local file="$1"
  local schema; schema=$(jq -r '.schema // "missing"' "$file" 2>/dev/null || echo "missing")
  if [[ "$schema" != "1" ]]; then
    echo "✗ kb-common: $file has schema=$schema (expected 1)" >&2
    exit 1
  fi
}

# Slugify endpoint "POST /api/users/me/avatar" → "post__api_users_me_avatar"
kb_endpoint_slug() {
  echo "$1" \
    | tr '[:upper:] /' '[:lower:]__' \
    | tr -c '[:alnum:]_\n' '_' \
    | sed 's/__\+/__/g; s/_\+$//'
}

# Slugify free-text "Avatar upload happy jpeg" → "avatar-upload-happy-jpeg" (max 60)
kb_text_slug() {
  echo "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -c '[:alnum:]\n' '-' \
    | sed 's/-\+/-/g; s/^-//; s/-$//' \
    | cut -c1-60
}

# Compute sha256 of a file in a portable way.
kb_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print "sha256:"$1}'
  else
    shasum -a 256 "$1" | awk '{print "sha256:"$1}'
  fi
}

# ISO-8601 UTC now.
kb_now()  { date -u +%Y-%m-%dT%H:%M:%SZ; }
