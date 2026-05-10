#!/usr/bin/env bash
# merge-feature.sh — safely merge a feature branch to base
# Usage: merge-feature.sh --branch <name> --base <branch> [--worktree <path>] [--no-protection-check]
set -euo pipefail

BRANCH=""
BASE=""
WORKTREE=""
NO_PROTECTION_CHECK=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    --worktree) WORKTREE="$2"; shift 2 ;;
    --no-protection-check) NO_PROTECTION_CHECK=true; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$BRANCH" && -n "$BASE" ]] || { echo "REASON=--branch and --base are required" >&2; exit 2; }

REPO_ROOT="$(git rev-parse --show-toplevel)"

# Refuse if base is checked out in another worktree — `git checkout $BASE` would fail mid-script
# and leave the lead session in an inconsistent state. With worktree-per-feature in active use,
# the lead's main session is exactly one such worktree.
base_wt=$(git -C "$REPO_ROOT" worktree list --porcelain \
  | awk -v base="refs/heads/$BASE" '/^worktree / {wt=$2} /^branch / && $2==base {print wt; exit}')
if [[ -n "$base_wt" && "$base_wt" != "$REPO_ROOT" ]]; then
  echo "✗ merge FAILED"
  echo "REASON=base branch '$BASE' is checked out in another worktree: $base_wt"
  echo "       Run merge-feature.sh from that worktree, or remove it first."
  exit 1
fi

# Refuse if the lead's REPO_ROOT (which holds $BASE) has uncommitted changes —
# `git checkout $BASE` would no-op and the merge would land on top of dirty state.
if ! git -C "$REPO_ROOT" diff --quiet || ! git -C "$REPO_ROOT" diff --cached --quiet; then
  echo "✗ merge FAILED"
  echo "REASON=base checkout has uncommitted changes; commit or stash first"
  exit 1
fi

# Conflict pre-check via merge-tree (non-destructive).
# Use the 3-dot form `merge-tree --write-tree A B`. Exit 1 = conflict; 0 = clean.
# (`--merge-base=` is also supported on git ≥ 2.40 and behaves identically — kept simple here.)
base_sha=$(git -C "$REPO_ROOT" rev-parse "$BASE")
branch_sha=$(git -C "$REPO_ROOT" rev-parse "$BRANCH")

set +e
git -C "$REPO_ROOT" merge-tree --write-tree "$base_sha" "$branch_sha" >/dev/null 2>&1
mt_rc=$?
set -e
if [[ $mt_rc -eq 1 ]]; then
  echo "✗ merge FAILED"
  echo "REASON=merge-tree reported conflicts; resolve manually"
  echo "BRANCH=$BRANCH"
  echo "BASE=$BASE"
  exit 1
elif [[ $mt_rc -ne 0 ]]; then
  echo "✗ merge FAILED"
  echo "REASON=merge-tree exited $mt_rc (unexpected error)"
  exit 1
fi

# Protected branch check — fail-CLOSED. Any non-zero `gh api` exit (auth scope,
# 401/403/404, network) is treated as "could not verify" and refuses the merge.
# Pass --no-protection-check to skip when gh is unavailable AND the operator
# accepts the risk (e.g. local-only repo, or repo with no branch protection).
# `gh api` does NOT auto-expand `:owner/:repo`; resolve them first.
if [[ "$NO_PROTECTION_CHECK" == false ]]; then
  if ! command -v gh &>/dev/null; then
    echo "✗ merge FAILED"
    echo "REASON=gh CLI not installed — cannot verify branch protection."
    echo "       Install gh, or pass --no-protection-check if you accept the risk."
    exit 1
  fi
  nwo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  if [[ -z "$nwo" ]]; then
    echo "✗ merge FAILED"
    echo "REASON=gh repo view returned empty nameWithOwner — gh auth scope or remote config missing."
    echo "       Fix gh auth, or pass --no-protection-check if you accept the risk."
    exit 1
  fi
  set +e
  api_out=$(gh api "repos/$nwo/branches/$BASE" 2>&1)
  api_rc=$?
  set -e
  if [[ $api_rc -ne 0 ]]; then
    echo "✗ merge FAILED"
    echo "REASON=could not verify branch protection (gh api rc=$api_rc): $(echo "$api_out" | head -1)"
    echo "       Fix gh auth scope (needs 'repo' for private repos), or pass --no-protection-check."
    exit 1
  fi
  protected=$(jq -r '.protected // false' <<<"$api_out")
  if [[ "$protected" == "true" ]]; then
    echo "✗ merge FAILED"
    echo "REASON=base branch '$BASE' is protected; merge manually via PR"
    exit 1
  fi
fi

# Perform merge in main checkout (NOT in feature worktree)
git -C "$REPO_ROOT" checkout "$BASE"
qa_report_hint=""
if [[ -n "$WORKTREE" && -d "$WORKTREE/.x-skills/x-qa/runs" ]]; then
  latest_run=$(ls -1t "$WORKTREE/.x-skills/x-qa/runs/" 2>/dev/null | head -1)
  [[ -n "$latest_run" ]] && qa_report_hint=".x-skills/x-qa/runs/$latest_run/QA_REPORT.md"
fi

git -C "$REPO_ROOT" merge --no-ff "$BRANCH" -m "feat(team): merge $BRANCH" \
  ${qa_report_hint:+-m "QA report: $qa_report_hint"}

echo "✓ merge complete"
echo "BRANCH=$BRANCH"
echo "BASE=$BASE"
echo "MERGED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
