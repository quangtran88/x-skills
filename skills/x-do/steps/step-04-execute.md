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

### Standing Constraints (always include — not optional)

In addition to the run-specific `[CONSTRAINTS]` block above, every executor dispatch (ralph, `--model codex`, OMC `executor`, OMO agents, direct execution) MUST carry a `[STANDING CONSTRAINTS]` block with the three rules from `../../x-shared/instrument-and-verify.md`. These constraints are NOT derived from steps 1-3 — they apply to every implementation regardless of task type:

```
[STANDING CONSTRAINTS — always apply, per ../../x-shared/instrument-and-verify.md]
1. LOG ON FIRST PASS. Ship structured logs at decision points (entry/exit, branches,
   state transitions, error catches, external boundaries) in the SAME DIFF as the
   implementation. Log decision variables (IDs, flags, lengths) — not "got here" strings.
   Use the project's existing logger (read 2-3 nearby files to find it). Logs stay
   after the task lands; downgrade to debug level if noisy, do NOT strip.

2. TEST-FIRST FOR UNKNOWNS. Before calling any unfamiliar lib / API / upstream-path,
   FIRST run a scratch experiment: REPL, `node -e "..."`, `python -c "..."`, `curl -v`,
   or a 10-line `/tmp/scratch.{ts,py,sh}`. Observe the REAL return shape and error class.
   Cite the artifact in the commit message or inline rationale when behavior is
   non-obvious. Delete the scratch after copying the knowledge into the implementation —
   do NOT commit `/tmp/scratch.*`.

3. NEVER GUESS. Every claim about library behavior, API shape, or runtime semantics
   needs a citation: file:line, test output, log line, doc URL, or a re-readable tool
   call result. Phrases like "probably", "I think", "should work", "usually" are STOP
   signals — go produce evidence (rule 2) instead of writing code on top of an assumption.
```

This block is mandatory for Modes A/B/F and for any 3+ task ralph run. For Mode D (quick tasks), rules 2 and 3 still apply; rule 1 scales down (a one-line config edit does not need a log).

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
- `min_commits: N` → skip if range has fewer than N commits (default 2; safety floor — primary decision is concern-based, see table below)
- `auto: true` → recompose without prompting; `auto: false` → show plan, wait for OK

Inspect the range:

```bash
git log --oneline ${BASE_SHA}..HEAD
```

| Range shape | Action |
|---|---|
| 0 / 1 commit (or fewer than `min_commits`) | Skip |
| All commits share `(type, scope)` — e.g. all `feat(x-qa):` | Recompose into 1 |
| Mixed scopes/types | Recompose to N = unique `(scope, intent)` tuples; aim for fewest atomic groups |
| Range crosses a merge commit | Abort, surface to user |

The goal is **fewest atomic commits where each commit is one logical concern** (one feature, one fix, one domain) — not a fixed count. Drop count-based heuristics; classify by concern boundary.

### Skip conditions (auto-skip, no prompt)

- Branch already pushed AND has remote tracking AND any pushed commit is in the range — warn the user, offer "squash on merge via PR" instead. Never rewrite published history without explicit confirmation.
- User explicitly requested per-step commits preserved (e.g., "keep the granular commits", "don't squash") — surfaced in step-01 gather or in-prompt.
- Step-01 gather captured `commit_recompose_hint: "preserve"` in run state — explicit user opt-out persisted from gather.
- Range crosses a merge commit — abort recomposition, surface to user.

### Recompose procedure

1. **Show the user the range** with `git log --oneline ${BASE_SHA}..HEAD` and a one-line plan: "N commits → propose M groups". Wait for user OK unless `commit_recompose.auto: true` in `config.json`.
2. **Soft-reset to baseline:**
   ```bash
   git reset --soft "${BASE_SHA}"
   ```
   All changes now staged on the working tree; original commits live in reflog.
3. **Dispatch `Skill` tool → `commit` with grouping directive.** Pass this payload in the args slot:

   > "Group staged changes by `${target_axis}`. Target the fewest atomic commits where each commit is one logical concern (one feature, one fix, one domain). Preserve dependency order: `feat` before its `fix`. Read `git log` for repo message style."

   `target_axis` resolves in priority order:
   1. In-prompt override (e.g., user typed "group by feature")
   2. `commit_recompose_hint: "axis:<value>"` from step-01 run state
   3. `config.json` → `commit_recompose.target_axis`
   4. Default: `domain`

   Allowed axis values: `topic` | `domain` | `feature` | `item`.

3.5. **Preview before committing** (when `auto: false`): Ask the `commit` skill for a plan-only summary first — one line per proposed commit in the form `<type>(<scope>): <subject> — <files touched>`. Surface to the user. Wait for one of:
   - `y` → proceed to write the commits
   - `tweak: <new directive>` → re-plan with the tweak (e.g., "tweak: split x-team into skeleton and integration")
   - `n` → abort, leave changes staged, no commits written

   Skip 3.5 only when `auto: true` is set in config AND no in-prompt override requested preview.
4. **Verify the rewrite:**
   - **Tree equivalence:** `git log --oneline ${BASE_SHA}..HEAD` should now show the grouped commits. `git diff ${BASE_SHA}..HEAD` against the pre-reset HEAD must be empty (zero net change in tree contents) — if non-empty, abort and `git reset --hard ORIG_HEAD` to restore.
   - **Group count match** (when `auto: false`): actual commit count must equal the previewed plan's count. Mismatch → abort + `git reset --hard ORIG_HEAD` and report which group was dropped/merged.
5. **Surface the result** to the user as a before/after diff of `git log` output. Do NOT force-push. Branch finish (`superpowers:finishing-a-development-branch`) handles push/PR.

### Post-recomposition scope check (advisory)

After recomposition completes (the soft-reset → `Skill commit` → tree-equivalence verify above), run an OPTIONAL gitnexus scope sanity check. Gate: `mcp.gitnexus` pinned **AND** the repo indexed **AND** the index **fresh**, read from the shared session-pinned probe (`../../x-shared/capability-loading.md` § "Shared GitNexus Indexed+Fresh Probe"). `detect_changes` is **correctness-sensitive** per the use-class index in `../../x-shared/mcp-toolbox.md` — **stale or unindexed → skip silently** (`git diff` already covers file scope; no fallback call).

When gated-in, call `gitnexus detect_changes` with **`scope: "compare"`, `base_ref: <BASE_SHA>`** — the `BASE_SHA` captured pre-dispatch in Execution step 2. The default `scope: "unstaged"` returns the empty-state stub on a clean post-recomposition tree (`if (fileDiffs.length === 0)` returns `changed_count: 0` / empty `changed_symbols` / empty `affected_processes` — `research/abhigyanpatwari/GitNexus/gitnexus/src/mcp/local/local-backend.ts:2163-2173`), so `compare` against `BASE_SHA` is mandatory here, not the default scope.

Report the result as an advisory line: `recomposition touched flows: <affected-process names>` (changed symbols + affected processes). State the explicit delta over `git diff`: **flow membership** — `git diff` shows files/hunks; `detect_changes` maps those hunks to indexed symbols and the execution flows they participate in, which `git diff` cannot produce.

This is **advisory only — it NEVER blocks the commit**. Recomposition has already produced a verified zero-net-diff tree; this line is a scope-sanity readout for the user, not a gate. A surprising flow in the readout is a prompt for the user to eyeball, not a recomposition failure.

### Failure recovery

If `Skill commit` fails, errors, or produces an empty tree:

```bash
git reset --hard ORIG_HEAD
```

`ORIG_HEAD` is set by `git reset --soft` and points to the original tip. Report the failure to the user and skip recomposition for this run.

## After Execution

See "After This Skill" in `../SKILL.md` for /x-review handoff and learner hook.
