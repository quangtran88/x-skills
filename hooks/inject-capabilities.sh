#!/usr/bin/env bash
# x-skills SessionStart hook — print a one-line capabilities snapshot.
# Skills read this line instead of running jq each time they need to know
# what's available. Output is a system-reminder line consumed by Claude.
#
# Format: [x-skills/capabilities] active=<comma-list> | merged-from=<sources>
# Stays under 3 lines. Silent if no manifest (first install).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
USER_CAPS="${XDG_CONFIG_HOME:-$HOME/.config}/x-skills/capabilities.json"
PROJECT_CAPS=".x-skills/capabilities.json"

command -v jq &>/dev/null || exit 0
[[ -f "$USER_CAPS" ]] || exit 0

# Build active set from user manifest. Project overrides applied per-key.
# Output keys whose merged value is `true`.
active=$(jq -r '
  def truthy: . == true;
  [
    (.capabilities.opencode | select(truthy) | "opencode"),
    (.capabilities.gemini_cli | select(truthy) | "gemini_cli"),
    (.capabilities.mcp.perplexity | select(truthy) | "mcp.perplexity"),
    (.capabilities.mcp.deepwiki | select(truthy) | "mcp.deepwiki"),
    (.capabilities.mcp.exa | select(truthy) | "mcp.exa"),
    (.capabilities.mcp.context7 | select(truthy) | "mcp.context7"),
    (.capabilities.mcp.morph | select(truthy) | "mcp.morph"),
    (.capabilities.plugins.oh_my_claudecode | select(truthy) | "plugin.omc"),
    (.capabilities.plugins.superpowers | select(truthy) | "plugin.superpowers"),
    (.capabilities.plugins.claude_mem | select(truthy) | "plugin.claude_mem")
  ] | map(select(. != null)) | join(",")
' "$USER_CAPS" 2>/dev/null)

[[ -z "$active" ]] && exit 0

sources="user"
if [[ -f "$PROJECT_CAPS" ]]; then
  # Apply project override: re-derive active list from merged JSON.
  merged=$(jq -s '.[0] * .[1]' "$USER_CAPS" "$PROJECT_CAPS" 2>/dev/null)
  if [[ -n "$merged" ]]; then
    active=$(echo "$merged" | jq -r '
      def truthy: . == true;
      [
        (.capabilities.opencode | select(truthy) | "opencode"),
        (.capabilities.gemini_cli | select(truthy) | "gemini_cli"),
        (.capabilities.mcp.perplexity | select(truthy) | "mcp.perplexity"),
        (.capabilities.mcp.deepwiki | select(truthy) | "mcp.deepwiki"),
        (.capabilities.mcp.exa | select(truthy) | "mcp.exa"),
        (.capabilities.mcp.context7 | select(truthy) | "mcp.context7"),
        (.capabilities.mcp.morph | select(truthy) | "mcp.morph"),
        (.capabilities.plugins.oh_my_claudecode | select(truthy) | "plugin.omc"),
        (.capabilities.plugins.superpowers | select(truthy) | "plugin.superpowers"),
        (.capabilities.plugins.claude_mem | select(truthy) | "plugin.claude_mem")
      ] | map(select(. != null)) | join(",")
    ')
    sources="user+project"
  fi
fi

echo "[x-skills/capabilities] active=$active | merged-from=$sources"
exit 0
