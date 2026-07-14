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

# Project-local override is resolved against the project root, not cwd.
# Prefer $CLAUDE_PROJECT_DIR (set by Claude Code), fall back to git toplevel,
# then cwd. This prevents an unrelated project's caps from leaking in when
# Claude is launched from a subdirectory.
project_root() {
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "$CLAUDE_PROJECT_DIR" ]]; then
    echo "$CLAUDE_PROJECT_DIR"; return 0
  fi
  if command -v git &>/dev/null; then
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null) || true
    [[ -n "$top" && -d "$top" ]] && { echo "$top"; return 0; }
  fi
  pwd
}
PROJECT_CAPS="$(project_root)/.x-skills/capabilities.json"

command -v jq &>/dev/null || exit 0
[[ -f "$USER_CAPS" ]] || exit 0

# Active-set extraction. One filter, used in both the user-only and merged
# branches. truthy() accepts `true` for booleans, plus "partial"/"full" for
# string-valued capabilities like omo_plugin.
read -r -d '' JQ_FILTER <<'JQ' || true
def truthy: . == true or . == "partial" or . == "full";
[
  (.capabilities.opencode             | select(truthy) | "opencode"),
  (.capabilities.omo_plugin           | select(truthy) | "omo_plugin"),
  (.capabilities.omo_mode_all         | select(truthy) | "omo_mode_all"),
  (.capabilities.agy_cli              | select(truthy) | "agy_cli"),
  (.capabilities.mcp.perplexity       | select(truthy) | "mcp.perplexity"),
  (.capabilities.mcp.deepwiki         | select(truthy) | "mcp.deepwiki"),
  (.capabilities.mcp.exa              | select(truthy) | "mcp.exa"),
  (.capabilities.mcp.context7         | select(truthy) | "mcp.context7"),
  (.capabilities.mcp.gitnexus         | select(truthy) | "mcp.gitnexus"),
  (.capabilities.mcp.basic_memory     | select(truthy) | "mcp.basic_memory"),
  (.capabilities.plugins.oh_my_claudecode | select(truthy) | "plugin.omc"),
  (.capabilities.plugins.superpowers  | select(truthy) | "plugin.superpowers"),
  (.capabilities.companion_skills.ui_ux_pro_max  | select(truthy) | "skill.ui_ux_pro_max"),
  (.capabilities.companion_skills.x_skill_review | select(truthy) | "skill.x_skill_review"),
  (.capabilities.security_tools.schemathesis | select(truthy) | "tool.schemathesis"),
  (.capabilities.security_tools.nuclei       | select(truthy) | "tool.nuclei"),
  (.capabilities.security_tools.sqlmap       | select(truthy) | "tool.sqlmap"),
  (.capabilities.security_tools.spectral     | select(truthy) | "tool.spectral"),
  (.capabilities.security_tools.interactsh   | select(truthy) | "tool.interactsh")
] | map(select(. != null)) | join(",")
JQ

# Project caps file is treated as SUBTRACTIVE only — it can disable a
# capability the user has, but cannot grant new capabilities. This bounds
# trust: a hostile repo cannot upgrade routing posture by lying.
# Also size-bounded: large/deeply-nested JSON would DoS the SessionStart hook.
project_size_ok() {
  [[ -f "$PROJECT_CAPS" ]] || return 1
  local size
  if size=$(stat -f%z "$PROJECT_CAPS" 2>/dev/null); then :;
  elif size=$(stat -c%s "$PROJECT_CAPS" 2>/dev/null); then :;
  else return 1; fi
  [[ "$size" -le 16384 ]]
}

fallback_to_user_only() {
  local active
  active=$(jq -r "$JQ_FILTER" "$USER_CAPS" 2>/dev/null)
  [[ -n "$active" ]] && echo "[x-skills/capabilities] active=$active | merged-from=user"
}

# H1: project file present but invalid/oversized must NOT silently nuke the
# whole snapshot — fall through to user-only with a one-line warning.
# M6: depth cap (leaf_paths < 200) bounds jq recursion cost on hostile input.
# M3: full filter rendered to a tmpfile to avoid shell-concat quoting fragility.
if [[ -f "$PROJECT_CAPS" ]]; then
  if ! project_size_ok; then
    echo "[x-skills] WARNING: $PROJECT_CAPS exceeds 16 KiB cap — using user manifest only" >&2
    fallback_to_user_only
    exit 0
  fi
  if ! jq -e . "$PROJECT_CAPS" >/dev/null 2>&1; then
    echo "[x-skills] WARNING: $PROJECT_CAPS has invalid JSON — using user manifest only" >&2
    fallback_to_user_only
    exit 0
  fi
  if ! jq -e '[paths] | length < 500' "$PROJECT_CAPS" >/dev/null 2>&1; then
    echo "[x-skills] WARNING: $PROJECT_CAPS exceeds nesting cap (500 paths) — using user manifest only" >&2
    fallback_to_user_only
    exit 0
  fi

  FILTER_FILE=$(mktemp -t x-skills-filter.XXXXXX 2>/dev/null) || {
    fallback_to_user_only
    exit 0
  }
  trap 'rm -f "$FILTER_FILE"' EXIT
  cat >"$FILTER_FILE" <<'JQ_MERGE'
def all_false:
  if type == "object" then map_values(all_false)
  elif type == "array" then map(all_false)
  else false end;
def disable_if_project_false($pj):
  if $pj == null then .
  elif $pj == false then all_false
  elif (type == "object") and (($pj | type) == "object") then
    . as $self
    | reduce ($pj | keys[]) as $k ($self;
        .[$k] = ($self[$k] | disable_if_project_false($pj[$k])))
  else .
  end;
.capabilities |= disable_if_project_false($p[0].capabilities // {}) |
JQ_MERGE
  printf '%s\n' "$JQ_FILTER" >>"$FILTER_FILE"

  active=$(jq -r --slurpfile p "$PROJECT_CAPS" -f "$FILTER_FILE" "$USER_CAPS" 2>/dev/null)
  if [[ -n "$active" ]]; then
    echo "[x-skills/capabilities] active=$active | merged-from=user+project"
  else
    fallback_to_user_only
  fi
else
  fallback_to_user_only
fi

exit 0
