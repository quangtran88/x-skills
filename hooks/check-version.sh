#!/usr/bin/env bash
# x-skills SessionStart hook — detect stale install
#
# Emits a one-line nudge to run /x-skills:setup when:
#   - capability manifest is missing (Case 1)
#   - manifest's plugin_dir doesn't match the loaded plugin (Case 2)
#   - manifest's plugin_version doesn't match plugin.json's version (Case 2b)
#   - agy-agent is in the plugin but not on PATH (Case 3)
#   - manifest predates the agy_cli capability key (Case 4)
#
# Silent when in sync. Cheap (<50ms), non-fatal — never blocks a session.
# Set XSKILLS_SUPPRESS_VERSION_CHECK=1 to mute all nudges.

set -uo pipefail

[[ "${XSKILLS_SUPPRESS_VERSION_CHECK:-0}" == "1" ]] && exit 0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
PLUGIN_JSON="$PLUGIN_DIR/.claude-plugin/plugin.json"
CAPS_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/x-skills/capabilities.json"

# Bail silently on missing tools — hooks must never break sessions.
command -v jq &>/dev/null || exit 0
[[ -f "$PLUGIN_JSON" ]] || exit 0

PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null)
[[ -z "$PLUGIN_VERSION" ]] && exit 0

# Case 1: capabilities file missing → first install or never set up.
if [[ ! -f "$CAPS_FILE" ]]; then
  echo "[x-skills] Plugin v$PLUGIN_VERSION installed but not configured. Run: /x-skills:setup"
  exit 0
fi

# Single jq call extracts all fields needed below — cheaper than N forks.
# Output format: <plugin_dir>\t<plugin_version>\t<has_agy_cli_field:true|false>
CAPS_FIELDS=$(jq -r '
  [
    (.plugin_dir // ""),
    (.plugin_version // ""),
    (if (.capabilities | has("agy_cli")) then "true" else "false" end)
  ] | @tsv
' "$CAPS_FILE" 2>/dev/null)
IFS=$'\t' read -r CACHED_DIR MANIFEST_PLUGIN_VERSION HAS_AGY_FIELD <<<"$CAPS_FIELDS"

# Case 2: capabilities file points at a different plugin_dir → upgraded
# to a new cache version, old symlinks/manifest still point at old path.
if [[ -n "$CACHED_DIR" && "$CACHED_DIR" != "$PLUGIN_DIR" ]]; then
  echo "[x-skills] Plugin upgraded (cache: $PLUGIN_DIR, manifest still points at: $CACHED_DIR). Re-run: /x-skills:setup"
  exit 0
fi

# Case 2b (M1): manifest's plugin_version differs from current plugin.json.
# Catches in-place upgrades that didn't change cache path.
if [[ -n "$MANIFEST_PLUGIN_VERSION" && "$MANIFEST_PLUGIN_VERSION" != "$PLUGIN_VERSION" ]]; then
  echo "[x-skills] Plugin upgraded ($MANIFEST_PLUGIN_VERSION → $PLUGIN_VERSION). Re-run: /x-skills:setup"
  exit 0
fi

# Case 3 (H4): agy-agent missing from PATH but binary exists in plugin →
# upgraded without re-running setup. Use `command -v`
# instead of hardcoding ~/.local/bin to honor custom LINK_DIR installs.
if [[ -f "$PLUGIN_DIR/bin/agy-agent" ]] && ! command -v agy-agent &>/dev/null; then
  echo "[x-skills] agy-agent binding missing. Run: /x-skills:setup to enable the agy backend."
  exit 0
fi

# Case 4: capability manifest lacks the agy_cli field entirely → manifest
# was written by an older setup script. (Distinct from the field being
# present-and-false, which just means agy is not installed.)
if [[ "$HAS_AGY_FIELD" != "true" ]]; then
  echo "[x-skills] Capability manifest predates the agy backend. Re-run: /x-skills:setup to refresh."
  exit 0
fi

exit 0
