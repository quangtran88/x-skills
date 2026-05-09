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
