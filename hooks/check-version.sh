#!/usr/bin/env bash
# x-skills SessionStart hook — detect stale install
#
# Compares plugin version (from plugin.json) against capability manifest's
# generated version. If mismatch (or capability file missing), prints a
# one-line nudge to run /x-skills:setup. Silent when in sync.
#
# Designed to be cheap (<50ms) and noise-free. Failure is non-fatal —
# never blocks a session.

set -uo pipefail

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

# Single jq call extracts both fields needed below — cheaper than 2 forks.
# Output format: <plugin_dir>\t<has_gemini_cli_field:true|false>
CAPS_FIELDS=$(jq -r '
  [
    (.plugin_dir // ""),
    (if (.capabilities | has("gemini_cli")) then "true" else "false" end)
  ] | @tsv
' "$CAPS_FILE" 2>/dev/null)
IFS=$'\t' read -r CACHED_DIR HAS_GEMINI_FIELD <<<"$CAPS_FIELDS"

# Case 2: capabilities file points at a different plugin_dir → upgraded
# to a new cache version, old symlinks/manifest still point at old path.
if [[ -n "$CACHED_DIR" && "$CACHED_DIR" != "$PLUGIN_DIR" ]]; then
  echo "[x-skills] Plugin upgraded (cache: $PLUGIN_DIR, manifest still points at: $CACHED_DIR). Re-run: /x-skills:setup"
  exit 0
fi

# Case 3: gemini-agent symlink missing but binary exists in new version →
# upgraded from a pre-1.4.0 install without re-running setup.
if [[ -f "$PLUGIN_DIR/bin/gemini-agent" && ! -L "$HOME/.local/bin/gemini-agent" ]]; then
  echo "[x-skills] gemini-agent binding missing (added in v1.4.0). Run: /x-skills:setup to enable x-gemini skill."
  exit 0
fi

# Case 4: capability manifest lacks the gemini_cli field entirely → manifest
# was written by an older setup script. (Distinct from the field being
# present-and-false, which just means gemini is not installed.)
if [[ "$HAS_GEMINI_FIELD" != "true" ]]; then
  echo "[x-skills] Capability manifest is from a pre-v1.4.0 setup. Re-run: /x-skills:setup to refresh."
  exit 0
fi

exit 0
