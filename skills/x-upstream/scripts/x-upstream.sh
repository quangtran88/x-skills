#!/usr/bin/env bash
# x-upstream — manage research/<owner>/<repo> submodules pinned to latest stable release
set -euo pipefail

die() { echo "✗ $*" >&2; exit 1; }
warn() { echo "⚠ $*" >&2; }
log() { echo "$*"; }

require_repo_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git work tree"
  cd "$root"
}

parse_github_url() {
  # echoes "<owner> <repo>" or returns 1
  local url="$1"
  url="${url%.git}"
  url="${url%/}"
  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
    printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    return 0
  fi
  return 1
}

resolve_latest_stable() {
  # echoes a tag name to stdout, or returns 1 if none found
  local url="$1" owner="$2" repo="$3" tag=""

  # GitHub's /releases/latest endpoint returns the most recent non-prerelease,
  # non-draft release server-side — no pagination window to miss.
  if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    tag=$(gh api "repos/$owner/$repo/releases/latest" --jq '.tag_name // empty' 2>/dev/null || true)
    if [[ -n "$tag" && "$tag" != "null" ]]; then
      printf '%s\n' "$tag"
      return 0
    fi
  fi

  # Fallback: semver tags via git ls-remote, drop prereleases (-alpha/-beta/-rc/-pre/-dev/-snapshot)
  tag=$(git ls-remote --tags --refs "$url" 2>/dev/null \
        | awk '{print $2}' \
        | sed 's|refs/tags/||' \
        | grep -E '^v?[0-9]+\.[0-9]+(\.[0-9]+)?$' \
        | sort -V \
        | tail -1 || true)
  if [[ -n "$tag" ]]; then
    printf '%s\n' "$tag"
    return 0
  fi
  return 1
}

# Guard: confirm $path is its own initialized git submodule, NOT an empty/uninit dir
# whose `git -C` would resolve up to the superproject.
xup_is_initialized_submodule() {
  local path="$1"
  # Submodule .git is a file pointing at .git/modules/<path>; an uninitialized
  # submodule has no .git entry, and `git -C <path>` walks up to the parent.
  [[ -e "$path/.git" ]]
}

list_research_paths() {
  [[ -f .gitmodules ]] || return 0
  git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null \
    | awk '{print $2}' \
    | grep '^research/' || true
}

submodule_url_for_path() {
  local path="$1"
  git config -f .gitmodules --get "submodule.${path}.url"
}

resolve_path_from_arg() {
  # accepts <repo>, <owner>/<repo>, or research/<owner>/<repo>
  local arg="$1" match
  if [[ -d "$arg" ]] && [[ "$arg" == research/* ]]; then
    printf '%s\n' "${arg%/}"
    return 0
  fi
  match=$(list_research_paths | awk -v a="$arg" '
    {
      if ($0 == "research/" a) { print; exit }
      n = split($0, p, "/")
      if (p[n] == a) { print; exit }
    }')
  if [[ -n "$match" ]]; then
    printf '%s\n' "$match"
    return 0
  fi
  return 1
}

# ---------- commands ----------

cmd_add() {
  local url="${1:-}" owner_override="${2:-}"
  [[ -z "$url" ]] && die "usage: x-upstream add <github-url> [owner]"

  local upstream_owner upstream_repo
  if ! read -r upstream_owner upstream_repo < <(parse_github_url "$url"); then
    die "cannot parse GitHub URL: $url"
  fi

  # Release lookup ALWAYS queries the upstream repo. owner_override only
  # changes the destination path under research/.
  local tag
  if ! tag=$(resolve_latest_stable "$url" "$upstream_owner" "$upstream_repo"); then
    die "no stable release found for $upstream_owner/$upstream_repo (no GitHub release + no semver tag)"
  fi

  local dest_owner="${owner_override:-$upstream_owner}"
  local target="research/$dest_owner/$upstream_repo"
  [[ -e "$target" ]] && die "$target already exists"

  mkdir -p "research/$dest_owner"
  if ! git submodule add -- "$url" "$target" >&2; then
    die "git submodule add failed for $url"
  fi
  # Rollback registration if fetch/checkout fails — otherwise the user is
  # left with a half-added submodule that subsequent `add` refuses to retry.
  if ! git -C "$target" fetch --tags --quiet 2>/dev/null \
     || ! git -C "$target" checkout --quiet "$tag" 2>/dev/null; then
    warn "checkout of $tag failed; rolling back submodule registration"
    git submodule deinit -f -- "$target" 2>/dev/null || true
    git rm -f --cached -- "$target" 2>/dev/null || true
    rm -rf "$target" ".git/modules/$target" 2>/dev/null || true
    die "could not check out $tag in $target — rollback complete; investigate and retry"
  fi
  git add .gitmodules "$target"
  log "✓ added $target @ $tag"
  log "  next: git commit -m \"chore: vendor $upstream_owner/$upstream_repo @ $tag\""
}

update_one() {
  local path="$1" url tag current
  url=$(submodule_url_for_path "$path") || { warn "no submodule config for $path"; return; }

  # Hard guard: if $path has no .git entry, `git -C $path` would walk up to the
  # parent repo and the subsequent `checkout` would detach the superproject.
  # An uninitialized submodule needs `git submodule update --init` first.
  if ! xup_is_initialized_submodule "$path"; then
    warn "$path: submodule is not initialized (no .git entry) — run 'git submodule update --init -- $path' first; skipping"
    return
  fi

  local owner repo
  if ! read -r owner repo < <(parse_github_url "$url"); then
    warn "$path: non-GitHub URL, skipping stable detection"; return
  fi

  git -C "$path" fetch --tags --quiet
  if ! tag=$(resolve_latest_stable "$url" "$owner" "$repo"); then
    warn "$path: no stable release available"; return
  fi

  current=$(git -C "$path" describe --tags --exact-match 2>/dev/null \
            || git -C "$path" rev-parse --short HEAD)
  if [[ "$current" == "$tag" ]]; then
    log "= $path @ $tag (current)"
    return
  fi
  git -C "$path" checkout --quiet "$tag"
  git add "$path"
  log "↑ $path: $current → $tag"
}

cmd_update() {
  local target="${1:-all}"
  local paths=()
  if [[ "$target" == "all" ]]; then
    while IFS= read -r p; do paths+=("$p"); done < <(list_research_paths)
    [[ ${#paths[@]} -eq 0 ]] && die "no research submodules found"
  else
    local resolved
    if ! resolved=$(resolve_path_from_arg "$target"); then
      die "no research submodule matching '$target'"
    fi
    paths=("$resolved")
  fi
  for p in "${paths[@]}"; do update_one "$p"; done
  log ""
  log "review changes with: git diff --cached"
}

cmd_list() {
  local paths=()
  while IFS= read -r p; do paths+=("$p"); done < <(list_research_paths)
  [[ ${#paths[@]} -eq 0 ]] && { log "(no research submodules)"; return; }

  printf '%-44s %-18s %s\n' "PATH" "PINNED" "URL"
  for path in "${paths[@]}"; do
    local pinned url
    pinned=$(git -C "$path" describe --tags --exact-match 2>/dev/null \
             || git -C "$path" rev-parse --short HEAD 2>/dev/null \
             || echo "?")
    url=$(submodule_url_for_path "$path" 2>/dev/null || echo "?")
    printf '%-44s %-18s %s\n' "$path" "$pinned" "$url"
  done
}

cmd_remove() {
  local target="${1:-}"
  [[ -z "$target" ]] && die "usage: x-upstream remove <repo>"
  local path
  if ! path=$(resolve_path_from_arg "$target"); then
    die "no research submodule matching '$target'"
  fi
  # Hardening: rm -rf takes an absolute target only when the path is
  # under research/<owner>/<repo>. Refuse any other shape defensively.
  [[ "$path" == research/*/* ]] || die "refusing to remove non-research submodule path: $path"
  git submodule deinit -f -- "$path"
  git rm -f -- "$path"
  rm -rf ".git/modules/${path}"
  log "✓ removed $path"
  log "  next: git commit -m \"chore: drop $path\""
}

usage() {
  cat <<'EOF'
x-upstream — pin upstream repos as research/<owner>/<repo> submodules at latest stable release

usage:
  x-upstream add <github-url> [owner]    add submodule, checkout latest stable
  x-upstream update <repo|all>           bump pinned tag to latest stable
  x-upstream list                        show pinned submodules and tags
  x-upstream remove <repo>               deinit and remove a submodule

stable detection: gh release list (non-prerelease) → semver tag fallback (sort -V)
EOF
}

main() {
  local cmd="${1:-}"
  [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]] && { usage; exit 0; }
  shift
  require_repo_root
  case "$cmd" in
    add)    cmd_add    "$@" ;;
    update) cmd_update "$@" ;;
    list)   cmd_list   "$@" ;;
    remove) cmd_remove "$@" ;;
    *)      usage; exit 2 ;;
  esac
}

main "$@"
