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

# Case 2: capabilities file points at a different plugin_dir → upgraded
# to a new cache version, old symlinks/manifest still point at old path.
CACHED_DIR=$(jq -r '.plugin_dir // empty' "$CAPS_FILE" 2>/dev/null)
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

# Case 4: capability manifest missing the gemini_cli field entirely →
# manifest written by an older setup script. Refresh recommended.
if ! jq -e '.capabilities.gemini_cli' "$CAPS_FILE" >/dev/null 2>&1; then
  echo "[x-skills] Capability manifest is from a pre-v1.4.0 setup. Re-run: /x-skills:setup to refresh."
  exit 0
fi

exit 0
