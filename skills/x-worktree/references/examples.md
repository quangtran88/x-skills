# Output Envelope Examples

All paths below are illustrative. Real values depend on machine, repo, and provider.

## Success envelopes

**Default (no args, on `feature/auth`):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-auth-7e2af0
BASE=feature/auth
PROVIDER=git
CWD_SWITCHED=true
```

**Both args:**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=spike-redis
BASE=main
PROVIDER=wt
CWD_SWITCHED=true
```

**With auto-isolation applied (profile present in main checkout):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-auth-7e2af0
BASE=feature/auth
PROVIDER=git
CWD_SWITCHED=true
ISOLATE_APPLIED=true
```
Caller then reads `<WORKTREE_PATH>/.worktree-isolate/state.local.json` to build the DOCKER CONTEXT block. Validate `schema == 1` first.

**Auto-isolation skipped (no profile committed in repo):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=spike-redis
BASE=main
PROVIDER=wt
CWD_SWITCHED=true
ISOLATE_APPLIED=skipped
ISOLATE_REASON=no-profile
```
Worktree is fully usable; isolation simply never opted-in. No DOCKER CONTEXT block.

**Auto-isolation skipped (binary not on PATH):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-x-9a1b2c
BASE=main
PROVIDER=git
CWD_SWITCHED=true
ISOLATE_APPLIED=skipped
ISOLATE_REASON=binary-missing
```
User has not run `bin/setup`, or `~/.local/bin` is not on PATH.

**Auto-isolation failed (apply errored — blocker warning):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-y-3f4e5d
BASE=main
PROVIDER=git
CWD_SWITCHED=true
ISOLATE_APPLIED=false
ISOLATE_REASON=x-worktree-isolate apply: BLOCKED — unresolved cross-worktree footguns:   - [Makefile:42] label=app.sandbox=1
ISOLATE_HINT=run x-worktree-isolate apply manually to retry
```
Worktree itself is fine (creation succeeded). User must resolve the blocker (re-init profile, edit Makefile, etc.) and re-run apply manually. Caller asks user whether to abort or proceed without isolation.

**Auto-isolation failed (timeout):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-z-7c8d9e
BASE=main
PROVIDER=git
CWD_SWITCHED=true
ISOLATE_APPLIED=false
ISOLATE_REASON=apply-timeout-5s
ISOLATE_HINT=run x-worktree-isolate apply manually to retry
```

**Doc-driven: single PLAN.md with H1 `# feat: Add user auth`:**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feat/add-user-auth
BASE=main
PROVIDER=git
CWD_SWITCHED=true
DOCS_COMMITTED=1
DOC_COMMIT_SHA=8f3a1e2c9b...
ISOLATE_APPLIED=skipped
ISOLATE_REASON=no-profile
```
Invocation: `/x-skills:x-worktree main PLAN.md`. The doc was untracked in the original cwd; after the run it lives only in the new branch.

**Doc-driven: multiple docs share one commit:**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=refactor/extract-auth-module
BASE=main
PROVIDER=wt
CWD_SWITCHED=true
DOCS_COMMITTED=2
DOC_COMMIT_SHA=2a7d4f9c1e...
ISOLATE_APPLIED=true
```
Invocation: `/x-skills:x-worktree main PLAN.md SPEC.md`. PLAN.md (primary) drove the name; both docs landed in the same `docs: add PLAN.md, SPEC.md` commit.

**Doc-driven: doc commit failed (pre-commit hook rejected), worktree still usable:**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feat/payment-flow
BASE=main
PROVIDER=git
CWD_SWITCHED=true
DOCS_COMMITTED=0
DOCS_ERROR=commit-msg hook rejected: type 'docs' not in allowed list
```
Originals were restored to their source location (rollback). `ISOLATE_APPLIED` is omitted because the doc failure takes precedence — caller surfaces `DOCS_ERROR` to user first.

**Auto-isolation explicitly disabled (`--no-isolate`):**
```
✓ Worktree ready
WORKTREE_PATH=<absolute-path-to-new-worktree>
BRANCH=feature-x-9a1b2c
BASE=main
PROVIDER=git
CWD_SWITCHED=true
```
Note: `ISOLATE_APPLIED` line is omitted entirely when `--no-isolate` is set. Distinct from `ISOLATE_APPLIED=skipped` (which signals an automatic skip the user didn't choose).

## Failure envelopes

All failures use the same envelope shape. Callers parse `REASON` for diagnostics.

**Branch already exists at another worktree:**
```
✗ Worktree FAILED
REASON=branch 'spike-redis' already checked out at <existing-worktree-path>
PROVIDER_ATTEMPTED=git
CWD_SWITCHED=false
```

**Detached HEAD with no base arg:**
```
✗ Worktree FAILED
REASON=HEAD is detached; pass an explicit target_branch
PROVIDER_ATTEMPTED=none
CWD_SWITCHED=false
```

**Not inside a git work tree:**
```
✗ Worktree FAILED
REASON=cwd is not a git work tree
PROVIDER_ATTEMPTED=none
CWD_SWITCHED=false
```

**Invalid new branch name:**
```
✗ Worktree FAILED
REASON=branch name 'spike redis' fails git check-ref-format
PROVIDER_ATTEMPTED=none
CWD_SWITCHED=false
```

**Doc outside the repo:**
```
✗ Worktree FAILED
REASON=doc '/tmp/PLAN.md' is outside the repo work tree
PROVIDER_ATTEMPTED=none
CWD_SWITCHED=false
```

**Passed doc is tracked + modified (not safe to migrate):**
```
✗ Worktree FAILED
REASON=doc 'docs/PLAN.md' is tracked + modified; commit or stash before passing to x-worktree
PROVIDER_ATTEMPTED=none
CWD_SWITCHED=false
```
