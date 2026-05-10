#!/usr/bin/env bash
# smoke.sh — script-only smoke test for x-team helpers
# Does NOT exercise live OMC TeamCreate/Task — that requires an LLM-driven session.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TEST_REPO=$(mktemp -d)
FEATURES_FIXTURE=$(mktemp -t test-features.XXXXXX)
WT_ALPHA=$(mktemp -d)
trap 'rm -rf "$TEST_REPO" "$FEATURES_FIXTURE" "$WT_ALPHA"' EXIT

cd "$TEST_REPO"
git init -q
git config user.email t@t.t
git config user.name t
echo init > a.txt && git add a.txt && git commit -qm init

# feature-map-init: alpha provisioned (worktree path exists), beta queued (worktree:null).
cat > "$FEATURES_FIXTURE" <<EOF
[
  { "task_id": "1", "name": "alpha", "spec": "s", "acceptance": [], "branch": "feat-alpha-001", "worktree": "$WT_ALPHA", "worker": "worker-1", "status": "pending", "attempts": 0, "qa_runs": [], "blocker": null, "merged_at": null },
  { "task_id": null, "name": "beta", "spec": "s", "acceptance": [], "branch": "feat-beta-002", "worktree": null, "worker": null, "status": "pending", "attempts": 0, "qa_runs": [], "blocker": null, "merged_at": null }
]
EOF
"$SKILL_DIR/scripts/feature-map-init.sh" --team-slug smoke --request "smoke" --features-json "$FEATURES_FIXTURE"

# Update phase
"$SKILL_DIR/scripts/feature-map-update.sh" --team-slug smoke --phase running

# Update one feature: status + attempt
"$SKILL_DIR/scripts/feature-map-update.sh" --team-slug smoke --task-id 1 --status in_progress --attempts 1

# Add a QA run
"$SKILL_DIR/scripts/feature-map-update.sh" --team-slug smoke --task-id 1 --qa-add '{"run_id":"r1","verdict":"pass","report":"/tmp/r1/QA_REPORT.md"}'

# Mark done
"$SKILL_DIR/scripts/feature-map-update.sh" --team-slug smoke --task-id 1 --status done --merged-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Read back
status=$("$SKILL_DIR/scripts/feature-map-read.sh" --team-slug smoke --filter '.features[] | select(.task_id == "1") | .status' | tr -d '"')
[[ "$status" == "done" ]] || { echo "FAIL: expected done, got $status"; exit 1; }

# Test merge-feature.sh against scratch branches.
# Capture original branch BEFORE the checkout — `git rev-parse HEAD@{1}` does not
# resolve on a fresh repo (no reflog history yet) and the smoke fails under set -e.
orig_branch=$(git symbolic-ref --short HEAD)
git checkout -q -b feat-merge-test
echo more > b.txt && git add b.txt && git commit -qm "feat: b"
git checkout -q "$orig_branch"
# Pass --no-protection-check because smoke runs in a local-only init repo with no remote/gh.
"$SKILL_DIR/scripts/merge-feature.sh" --branch feat-merge-test --base "$orig_branch" --no-protection-check
log_out=$(git log --oneline)
echo "$log_out" | grep -q "feat(team): merge feat-merge-test" || { echo "FAIL: merge commit missing; log:"; echo "$log_out"; exit 1; }

echo "✓ x-team smoke passed"
