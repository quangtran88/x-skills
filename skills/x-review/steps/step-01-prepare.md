# Step 1: Prepare Review Content

**Progress: Step 1 of 4** — Next: Review

## Rules

- **READ COMPLETELY** before acting
- Complete detection BEFORE loading review content
- For large targets, summarize scope — don't attempt to review everything at once
- **NEVER** skip to step 3 — step 2 (cross-model review) is mandatory

## Detection

Classify the target from user input:

| Target | Signals | Action |
|--------|---------|--------|
| **A: Plan/Spec** | `.md` in specs/plans/docs, "review the plan" | Read the document fully |
| **B: Code/Files** | File paths, "review the code/implementation" | Use `morph-mcp codebase_search` to understand context around the files, then read key files |
| **C: Git Diff** | "last commit", "staged", "this PR", "branch diff" | Construct the diff |
| **D: No Target** | Just says "review" | Auto-detect from git state |

### Git Diff Commands (Target C)

| User Says | Command |
|-----------|---------|
| `last commit` / `latest` | `git diff HEAD~1` |
| `last N commits` | `git diff HEAD~N` |
| `staged` | `git diff --staged` |
| `this PR` / `vs main` | `git diff main...HEAD` |
| `<sha1>..<sha2>` | `git diff <sha1>..<sha2>` |

### Auto-Detection (Target D)

Check in priority order: staged changes → uncommitted changes → branch diff vs main → nothing to review.

## Output

A clear description of WHAT is being reviewed and the content/diff ready for reviewers.

## Next Step

Read fully and follow `step-02-review.md` with the prepared content.
