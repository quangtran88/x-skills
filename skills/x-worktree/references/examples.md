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
