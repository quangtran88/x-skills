# x-do Gotchas

> Replacement mapping for UNAVAILABLE role agents (`metis`, `prometheus`, `momus`, `hephaestus`) lives in **[../x-shared/omo-routing.md § Unavailable Agents](../x-shared/omo-routing.md#unavailable-agents)**. Do not re-inline that mapping in entries below; refer to role agents by their replacement (e.g., `--model codex`, `--model gpt`, `oracle`) directly.

Known failure patterns specific to x-do. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **Ralph sometimes re-executes completed stories on resume.** Always check `ralph-state.json` for story status before resuming.
- **`--model codex` works best with a structured prompt** (context, goal, constraints, existing code, expected output, verification steps, output format). Underspecified prompts lead to hallucinated requirements.
- **Brainstorming on trivial tasks wastes time.** If the implementation path is obvious, skip straight to execution.
- **`--model gpt` blocker-finder sometimes flags non-issues as blockers.** Cross-reference with your own judgment — if a "blocker" is actually a known constraint, proceed.
- **Don't force the planning pipeline on small tasks.** A single rename or config change doesn't need `oracle` pre-plan → `--model gpt` plan → `--model gpt` blocker-finder. Use Mode D.
- **Mechanical batch detection:** A task qualifies as a "mechanical batch" when ALL changes follow the same structural pattern (e.g., delete import + remove call site in N files). Test: if you could describe the change as a template applied N times, it's mechanical. If any file requires unique logic or decisions, it's NOT mechanical — use full ceremony.
- **basic-memory project targeting.** When wiring basic-memory calls in this skill, tool selection and placement/tagging conventions are canonical in `../x-shared/mcp-toolbox.md § basic-memory`. Tools take an optional `project` — omit for the session default; wrong-project writes succeed silently into the wrong store. Do not duplicate; do not work around the capability gate.

## Review Feedback Misclassified (was: as Mode F)

**Symptom:** User provides numbered feedback on an existing commit (e.g., "I have feedback: 1. use X, 2. extract Y, 3. fix Z"). x-do treats it as new-work brainstorming (Mode B) and re-runs design discovery, ignoring that the user already scoped every change.

**Root cause:** The detection table matches "refactor" / "fix" keywords in individual feedback items rather than recognizing the overall "apply enumerated changes" pattern.

**Fix:** When the user provides specific, numbered changes on an existing commit/implementation, route to **Mode A** — the feedback list IS the plan. See the "Review feedback → Mode A" rule in the Detection section of SKILL.md. (Mode F has been removed; refactors with no plan go through Mode B, with plan go through Mode A.)

## File Count ≠ Complexity

**Symptom:** A 3-file change gets Mode D (quick task) treatment but touches auth, DB schema, and an API endpoint. Or a 6-file rename gets full brainstorm + plan review ceremony.

**Root cause:** Using file count as the primary complexity signal. A mechanical 10-file rename is simpler than a 2-file auth change.

**Fix:** Mode D's "≤ 10 lines, single file, no ambiguity" rule is strict — if a change touches auth/payments/migrations or crosses modules, it is NOT Mode D regardless of line count. Route to Mode A or B and let the plan + reviewer decide ceremony. The previous Depth Calibration ladder has been replaced by the 3-axis Routing Signals (mode + task count + walk-away) in SKILL.md.

## Post-Impl Review ≠ TypeScript Verification

**Symptom:** `tsc --noEmit` passes → session claims done without dispatching post-implementation review.

**Root cause:** Confusing TypeScript verification (mandatory compilation/lint gate) with post-implementation review (cross-model quality assessment via x-review). They are separate gates with different purposes.

**Fix:** Both are mandatory. tsc/eslint verifies the code compiles and passes lint. Post-impl review is delegated to `Skill: x-skills:x-review` — x-review owns the cross-model reviewer fan-out, synthesis, and verdict. Run tsc/eslint first, THEN dispatch x-review on the changeset.

## Reimplementing x-review or x-research Dispatch Inline

**Symptom:** Step 1 (gather) or step 3 (review) writes its own oracle/explore/code-reviewer fan-out instead of delegating. Mode-guidance.md regrows "launch 3 reviewers in ONE message" recipes. A `cross-model-review.md` file reappears under `references/`.

**Root cause:** A previous version of x-do owned both reviewer dispatch and pre-planning research. Logic drifted between the inline copies and the canonical owners (x-review, x-research). The 2026-05 refactor centralized reviewer dispatch in x-review and pre-planning fan-out in x-research; x-do is a pure router for those axes.

**Fix:** When you reach for a multi-agent fan-out in x-do, STOP. Plan review and post-impl review → `Skill: x-skills:x-review`. Pre-planning context gathering → `Skill: x-skills:x-research` (Pre-planning lane). x-do reads their returned envelopes and routes on the verdict. If you find yourself writing `Agent + Bash omo-agent + Skill` triple-dispatch inside x-do, that is the drift signal — delete it and delegate instead.

## Granular Commits from executor / ralph

**Symptom:** After `oh-my-claudecode:executor` (or `ralph`) finishes, `git log` shows 8-20 micro-commits — one per file or per intermediate step. Reviewers can't reason about intent; squash-on-merge loses the structure.

**Root cause:** `executor` commits aggressively to checkpoint progress; `ralph` commits per story. Neither groups by domain/concern.

**Fix:** Run commit recomposition after verification, before branch finish. Capture `BASE_SHA=$(git rev-parse HEAD)` BEFORE dispatching the executor, then post-execution: `git reset --soft $BASE_SHA` → `Skill` tool → `commit` (groups staged changes by domain). Verify `git diff $BASE_SHA..HEAD` against pre-reset `ORIG_HEAD` is empty before claiming done. See `steps/step-04-execute.md` § "Commit Recomposition" for the full procedure and skip conditions.

**Do not** rewrite history if any commit in the range is already pushed to a shared remote — offer squash-on-merge in the PR instead.

## Spinning Without Delegating

**Symptom:** Claude attempts the same fix 2+ times with minor variations, or reads the same files repeatedly without making progress.

**Root cause:** Claude is trying to solve a problem that would benefit from a different model's perspective or a specialized agent's tool access.

**Fix:** After 2 failed attempts at the same issue, proactively delegate to `oracle` (for debugging/architecture advice) or `--model codex` (for implementation). State the delegation reason to the user. See "Proactive OMO Delegation" in SKILL.md.

## Implementing Against an Unfamiliar Lib Without a Scratch-Test First

**Symptom:** Executor (or direct-execution path) writes code calling a library or upstream module it hasn't observed. Result: the call signature is wrong, the returned shape doesn't match, the error class is the wrong one. tsc may pass (if types are loose or `any` leaks in), but the code throws at runtime — or worse, silently does the wrong thing.

**Root cause:** Skipping rule 2 of `../x-shared/instrument-and-verify.md` — implementing against an assumed API shape rather than an observed one. The executor's training data may be stale, the lib may have changed, or the docs may be ambiguous. Without a scratch verification, every assumption is a guess.

**Fix:** Before any implementation call into unfamiliar territory, run a scratch script: `node -e "..."`, `python -c "..."`, `curl -v`, or a 10-line `/tmp/scratch.{ts,py,sh}`. Paste the real output into the implementation rationale. Delete the scratch after copying the knowledge into code. This is mandatory for: unfamiliar libs, upstream modules you haven't traced, external APIs, anything where you can't cite a `file:line` or doc URL for the behavior you're depending on.

## Stripping Logs After the Bug Is Fixed

**Symptom:** A bugfix lands with comprehensive logs at every decision point on the affected call chain. PR review (or the executor itself) then "cleans up" by deleting those logs before merge. Three months later the same code path breaks again — and there is no observability.

**Root cause:** Treating diagnostic logs as scaffolding to remove rather than production-survivable instrumentation to keep. The "clean diff" instinct wins over the "next debugger will thank me" instinct.

**Fix:** Logs added during a bugfix STAY. Downgrade noisy ones to debug level (`logger.debug(...)` or equivalent) if they would spam the production log stream, but do NOT delete them. See `../x-shared/instrument-and-verify.md` § rule 1.
