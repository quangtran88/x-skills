#!/usr/bin/env bash
# inspect.sh — scan the repo for QA-relevant entry points
# Outputs JSON to stdout. No writes. No prompts.
# Usage: inspect.sh [--repo-root <path>] [--cache-dir <path>]
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
CACHE_DIR="$REPO_ROOT/.x-skills/x-qa/cache"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --cache-dir) CACHE_DIR="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# shellcheck source=lib/scan-helpers.sh
source "$(dirname "$0")/lib/scan-helpers.sh"

mkdir -p "$CACHE_DIR"

# Collect findings into a single JSON document.
findings_http=$(scan_http "$REPO_ROOT")
findings_cli=$(scan_cli "$REPO_ROOT")
findings_grpc=$(scan_grpc "$REPO_ROOT")
findings_graphql=$(scan_graphql "$REPO_ROOT")
findings_workers=$(scan_workers "$REPO_ROOT")
findings_websocket=$(scan_websocket "$REPO_ROOT")

jq -n \
  --arg root "$REPO_ROOT" \
  --argjson http "$findings_http" \
  --argjson cli "$findings_cli" \
  --argjson grpc "$findings_grpc" \
  --argjson graphql "$findings_graphql" \
  --argjson workers "$findings_workers" \
  --argjson websocket "$findings_websocket" \
  '{
    schema: 1,
    scanned_at: (now | todate),
    repo_root: $root,
    findings: {
      http: $http,
      cli: $cli,
      grpc: $grpc,
      graphql: $graphql,
      worker: $workers,
      websocket: $websocket
    }
  }'
