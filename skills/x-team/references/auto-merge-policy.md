# Auto-merge Policy

Auto-merge is OPT-IN via `--auto-merge`. Default behavior: queue passing features for human review.

## Pre-merge Safety Gates

Before merging a feature branch:
1. Feature has `status: done` in feature-map.
2. Latest QA run for the feature: `verdict: pass`.
3. `git diff <base>...<branch>` produces clean conflict-free merge (`git merge-tree` or trial merge in scratch worktree).
4. No other feature in this team has merged conflicting paths since this feature was branched.

If any gate fails: SKIP auto-merge for this feature. Surface to user in final summary.

## Merge Strategy

Always `git merge --no-ff <branch>` against the team's base branch. Preserves feature boundary in history.

Commit message follows convention:
```
feat(team:<team-slug>): merge <feature-name>

QA: pass (<n>/<n>) — see .x-skills/x-qa/runs/<run-id>/QA_REPORT.md
Branch: <branch>
```

## Worktree Cleanup After Merge

After successful merge, prompt user:
```
Feature {name} merged. Remove worktree {worktree}? [Y/N/keep-all]
```

`keep-all`: stop asking for the rest of this team's features.

## Disabling Auto-merge for a Single Feature

If user wants auto-merge for most features but NOT one (e.g. needs human review of architectural change):
- Worker emits SendMessage with `summary: feature_done:{TASK_ID}` and includes `"skip_auto_merge": true` inside the content's JSON-fence payload.
- Lead's classifier extracts the payload from `content` (no `metadata` field exists on OMC SendMessage), checks `payload.skip_auto_merge`, skips merge-feature.sh and queues for review.

## Post-merge x-qa on Base

Optional: after all features merge, run `x-qa run` once against `base` branch to detect integration failures (cross-feature interactions). Default OFF (slow). Enable with `--post-integrate-qa`.

## Anti-patterns

- Don't auto-merge if QA was skipped (`--no-launch` or `--skip-doctor`).
- Don't auto-merge to protected branches (main with branch protection). Detect via `gh repo view --json nameWithOwner -q .nameWithOwner` then `gh api "repos/<owner>/<repo>/branches/<base>"` if `gh` available; refuse if `protected: true`. (Literal `:owner/:repo` placeholders are NOT expanded by `gh api` and silently 404 — always resolve owner/repo first.)
- Don't auto-merge during a release freeze (out-of-band concern; user responsibility to not invoke x-team during freezes).
