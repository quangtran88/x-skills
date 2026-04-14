# x-do Gotchas

Known failure patterns specific to x-do. For shared OMO patterns, see `../x-shared/common-gotchas.md`.

- **Ralph sometimes re-executes completed stories on resume.** Always check `ralph-state.json` for story status before resuming.
- **hephaestus works best with a structured prompt** (context, goal, constraints, existing code, expected output, verification steps, output format). Underspecified prompts lead to hallucinated requirements.
- **Brainstorming on trivial tasks wastes time.** If the implementation path is obvious, skip straight to execution.
- **momus sometimes flags non-issues as blockers.** Cross-reference with your own judgment — if a "blocker" is actually a known constraint, proceed.
- **Don't force the planning pipeline on small tasks.** A single rename or config change doesn't need metis → prometheus → momus. Use Mode D.
- **Mechanical batch detection:** A task qualifies as a "mechanical batch" when ALL changes follow the same structural pattern (e.g., delete import + remove call site in N files). Test: if you could describe the change as a template applied N times, it's mechanical. If any file requires unique logic or decisions, it's NOT mechanical — use full ceremony.

## Review Feedback Misclassified as Mode F

**Symptom:** User provides numbered feedback on an existing commit (e.g., "I have feedback: 1. use X, 2. extract Y, 3. fix Z"). x-do classifies as Mode F (Refactor) and attempts to delegate to `/refactor`, which adds unnecessary discovery ceremony since the user already scoped every change.

**Root cause:** The detection table matches "refactor" keywords in individual feedback items, ignoring that the overall pattern is "apply enumerated changes" — which is Mode A (existing plan).

**Fix:** When the user provides specific, numbered changes on an existing commit/implementation, route to Mode A. The feedback list IS the plan. See the "Review feedback → Mode A" rule in the Detection section of SKILL.md.

## File Count ≠ Complexity

**Symptom:** A 3-file change gets Mode D (quick task) treatment but touches auth, DB schema, and an API endpoint. Or a 6-file rename gets full brainstorm + plan review ceremony.

**Root cause:** Using file count as the primary complexity signal. A mechanical 10-file rename is simpler than a 2-file auth change.

**Fix:** Use the Depth Calibration table in SKILL.md. Assess scope, risk, novelty, and dependencies — not just file count. A change touching payments or auth is Heavy regardless of file count.

## Post-Impl Review ≠ TypeScript Verification

**Symptom:** `tsc --noEmit` passes → session claims done without running post-implementation review.

**Root cause:** Confusing TypeScript verification (mandatory compilation/lint gate) with post-implementation review (cross-model quality assessment). They are separate gates with different purposes.

**Fix:** Both are mandatory. tsc/eslint verifies the code compiles and passes lint. Post-impl review (3 reviewers: Agent + Bash + Skill) checks design quality, missed edge cases, dead code, and contract correctness. Run tsc/eslint first, THEN launch post-impl review.

## 3rd Reviewer (Skill Tool) Consistently Dropped

**Symptom:** Plan or post-impl review launches only 2 reviewers (Agent + Bash OMO) instead of 3.

**Root cause:** The Skill tool call for `superpowers:requesting-code-review` is the easiest to forget because it's a different invocation pattern from Agent and Bash.

**Fix:** Cross-model review = exactly 3 calls in ONE message: **A**gent, **B**ash, **S**kill. Mnemonic: ABS. If you only see 2 tool calls, you're missing one.

## Spinning Without Delegating

**Symptom:** Claude attempts the same fix 2+ times with minor variations, or reads the same files repeatedly without making progress.

**Root cause:** Claude is trying to solve a problem that would benefit from a different model's perspective or a specialized agent's tool access.

**Fix:** After 2 failed attempts at the same issue, proactively delegate to `oracle` (for debugging/architecture advice) or `hephaestus` (for implementation). State the delegation reason to the user. See "Proactive OMO Delegation" in SKILL.md.
