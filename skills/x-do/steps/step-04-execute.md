# Step 4: Execute Plan

**Progress: Step 4 of 4** — Final step

## Rules

- **READ COMPLETELY** before acting
- **NEVER** claim completion without running verification

## Goal

Execute the reviewed plan and verify completion.

## Route Selection

| Signal | Route | Why |
|--------|-------|-----|
| 3+ tasks | `oh-my-claudecode:ralph` | Persistence loop, TDD, verification per story |
| 1-2 complex tasks | OMO `--model codex` | GPT-5.3 Codex for autonomous deep work (replaces the UNAVAILABLE `hephaestus` role agent — see `../../x-omo/gotchas.md`) |
| 1-2 simple tasks | Direct execution via OMC `executor` | Fastest path |
| Plan is a superpowers plan | `superpowers:subagent-driven-development` | Fresh subagent per task |

## Forward Intelligence

Before executing, gather key constraints discovered in earlier steps and inject them into the execution prompt:

- **From step-01 (gather):** Conventions to follow, existing patterns to match, scope boundaries
- **From step-02 (plan):** Decisions already made, rejected alternatives, verification criteria
- **From step-03 (review):** Blocker resolutions, risk mitigations agreed upon

Format as a brief `[CONSTRAINTS]` block at the top of the execution prompt. This prevents the execution agent from re-discovering or contradicting decisions already made.

## Execution

1. **Select route** based on task count and complexity (use depth calibration from SKILL.md).

2. **Capture baseline HEAD.** Before dispatch, record `BASE_SHA=$(git rev-parse HEAD)` and the upstream `BASE_UPSTREAM=$(git rev-parse @{u} 2>/dev/null || echo "")`. Needed for commit recomposition (step 5).

3. **Execute.**
   - For ralph: `Skill` tool → `oh-my-claudecode:ralph` with the plan
   - For OMO codex (autonomous deep work): `Bash` tool → `omo-agent --model codex "<structured prompt>"`, `timeout: 600000`
   - For executor: `Agent` tool → `subagent_type="oh-my-claudecode:executor"`
   - For subagent-driven: `Skill` tool → `superpowers:subagent-driven-development`
   - For direct execution (Mode D / surgical edits): Use `morph-mcp edit_file` for edits, `morph-mcp codebase_search` to locate targets

4. **Verify** — `superpowers:verification-before-completion` before claiming done.

5. **Recompose commits** (see "Commit Recomposition" below) — runs after verification passes, before branch finish.

6. **Finish branch** — `superpowers:finishing-a-development-branch` to decide merge/PR/keep.

## Commit Recomposition (executor / ralph routes)

OMC `executor` and `ralph` commit frequently — often one per file or micro-step. Recompose into atomic, domain-grouped commits before handoff so reviewers see intent, not keystrokes.

### When to run

Run after verification passes, before branch finish. Read `config.json` → `commit_recompose`:

- `enabled: false` → skip entirely
- `min_commits: N` → skip if range has fewer than N commits (default 3)
- `auto: true` → recompose without prompting; `auto: false` → show plan, wait for OK

Inspect the range:

```bash
git log --oneline ${BASE_SHA}..HEAD
```

| New commit count | Action |
|------------------|--------|
| 0 (executor amended / nothing committed) | Skip |
| 1 | Skip — already atomic |
| 2 | Recompose only if both touch overlapping concerns |
| `>= min_commits` | **Recompose** — default behavior |

### Skip conditions (auto-skip, no prompt)

- Branch already pushed AND has remote tracking AND any pushed commit is in the range — warn the user, offer "squash on merge via PR" instead. Never rewrite published history without explicit confirmation.
- User explicitly requested per-step commits preserved (e.g., "keep the granular commits", "don't squash") — surfaced in step-01 gather or in-prompt.
- Range crosses a merge commit — abort recomposition, surface to user.

### Recompose procedure

1. **Show the user the range** with `git log --oneline ${BASE_SHA}..HEAD` and a one-line plan: "N commits → propose M groups". Wait for user OK unless `commit_recompose.auto: true` in `config.json`.
2. **Soft-reset to baseline:**
   ```bash
   git reset --soft "${BASE_SHA}"
   ```
   All changes now staged on the working tree; original commits live in reflog.
3. **Dispatch `Skill` tool → `commit`.** That skill analyzes staged changes, groups them by domain/concern, and creates atomic commits using the repo's existing message style (it reads `git log` first).
4. **Verify the rewrite:** `git log --oneline ${BASE_SHA}..HEAD` should now show the grouped commits. `git diff ${BASE_SHA}..HEAD` against the pre-reset HEAD must be empty (zero net change in tree contents) — if non-empty, abort and `git reset --hard ORIG_HEAD` to restore.
5. **Surface the result** to the user as a before/after diff of `git log` output. Do NOT force-push. Branch finish (`superpowers:finishing-a-development-branch`) handles push/PR.

### Failure recovery

If `Skill commit` fails, errors, or produces an empty tree:

```bash
git reset --hard ORIG_HEAD
```

`ORIG_HEAD` is set by `git reset --soft` and points to the original tip. Report the failure to the user and skip recomposition for this run.

## After Execution

See "After This Skill" in `../SKILL.md` for /x-review handoff and learner hook.
