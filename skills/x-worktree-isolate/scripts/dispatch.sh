#!/usr/bin/env bash
# dispatch.sh — single CLI entry point for x-worktree-isolate.
# Routes subcommands to scripts/<name>.sh siblings.

set -euo pipefail

if (( BASH_VERSINFO[0] < 3 || ( BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] < 2 ) )); then
  echo "x-worktree-isolate: bash 3.2+ required (running ${BASH_VERSION})" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
export XWI_SKILL_DIR="$SKILL_DIR"
export XWI_SCRIPT_DIR="$SCRIPT_DIR"

VERSION="0.1.0"

usage() {
  cat <<'EOF'
x-worktree-isolate — per-worktree docker-compose isolation

Usage:
  x-worktree-isolate <subcommand> [options]

Subcommands:
  init [--rescan|--dry-run]         Phase 1: inspect repo, write profile.json
                                    (default writes; --dry-run prints to stdout).
  apply [--quiet|--if-profile-exists|--ignore-warnings|--dry-run]
                                    Phase 2: write override + .env.worktree.
  release [--quiet]                 Free this worktree's registry slot.
  doctor                            Run validation suite.
  list                              Show all claimed slots from registry.
  version                           Print version.

See SKILL.md for full documentation.
EOF
}

cmd="${1:-}"
[[ $# -gt 0 ]] && shift || true

case "$cmd" in
  init)
    # Fix #3: init writes profile + patches .gitignore by default.
    # `inspect.sh` defaults WRITE=1; flags pass through (--rescan / --dry-run).
    exec bash "$SCRIPT_DIR/inspect.sh" "$@"
    ;;
  apply)
    exec bash "$SCRIPT_DIR/apply.sh" "$@"
    ;;
  release)
    exec bash "$SCRIPT_DIR/release.sh" "$@"
    ;;
  doctor)
    exec bash "$SCRIPT_DIR/doctor.sh" "$@"
    ;;
  list)
    exec bash "$SCRIPT_DIR/allocate-ports.sh" list "$@"
    ;;
  version|--version|-v)
    echo "x-worktree-isolate $VERSION"
    ;;
  -h|--help|help|"")
    usage
    [[ -z "$cmd" ]] && exit 1 || exit 0
    ;;
  *)
    echo "x-worktree-isolate: unknown subcommand: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
