# Mode Guidance

Detailed instructions for each detection mode. Referenced from SKILL.md's detection table.

**Reviewer dispatch and synthesis live in x-review.** This file never redefines the 3-reviewer fan-out — every review step below dispatches `Skill: x-skills:x-review` and honors its returned verdict. The reduced-review / mechanical-batch / parent-deference exceptions are passed as hint args.

## A: Existing Plan

1. Read the plan fully
2. **Mindfulness Gate (auto-invoke `/x-mindful` on high-risk plans).** Scan the plan content for any of: breaking-change keywords (`breaking change`, `deprecate`, `remove`, `rename`, `migrate`, `migration`, `schema change`, `drop column`, `drop table`, `incompatible`); auth/security keywords (`auth`, `authn`, `authz`, `permission`, `RBAC`, `RLS`, `session`, `token`, `secret`, `CORS`, `CSRF`); cross-boundary keywords (`public API`, `shared library`, `published`, `consumer`, `tenant`, `multi-tenant`, `feature flag rollout`, `dual-write`); cost/capacity keywords (`index`, `full scan`, `backfill`, `N+1`, `fan-out`, `queue`, `cron`, `scheduled job`). If ANY hit AND the plan is not a mechanical batch — invoke `Skill: x-skills:x-mindful` with the plan path / content as input BEFORE proceeding to step 3. Wait for the `<!-- x-mindful-envelope v1 -->` block. Apply the envelope: drop `Rejected` items from the plan, revise the plan to incorporate `Modified` directives, proceed with `Confirmed`. Skip the gate when ALL of: scope is single-file, no shared interface touched, < 3 tasks, no high-risk keywords appear. Skip is also OK for mechanical batches (same change across N files, no architectural decision).
3. **⛔ Plan Review — NON-NEGOTIABLE.** Skip ONLY for trivial plans (< 3 tasks AND single module) OR **mechanical batches** (same structural change repeated across N files — e.g., remove an import + call site identically in 4 adapters). Otherwise: announce *"N tasks across M files — running plan review (~90s) before executing."* then dispatch `Skill: x-skills:x-review <plan-path>`. x-review runs its 3-reviewer fan-out in plan-mode (no passes menu, no Fix Mode) and returns the `<!-- x-review plan-mode envelope v1 -->` block. Honor its verdict: APPROVE → step 4; REQUEST_CHANGES → revise plan and re-dispatch (or proceed under explicit user override).
   **Research-produced plan exception:** Plans generated from comprehensive x-research (Type A comparison with 10+ sources read) may pass a reduced-review hint: `Skill: x-skills:x-review <plan-path> --reduced` — x-review will run only the `--model gpt` blocker-finder lane. The research itself substitutes for broader review.
4. Execute: `ralph` for 3+ tasks, direct execution for simpler plans. **"Fix all" with 3+ tasks = ralph, not manual batch edits.** Exception: **mechanical batches** (identical change across files) may use direct execution regardless of file count — ralph overhead exceeds the risk.
   **Surgical edit exception:** Direct execution is also acceptable for 3+ tasks when ALL are: (a) single-location edits or new files, (b) no dependencies between them, (c) each describable in 1 sentence, (d) total < 30 lines changed. This is distinct from mechanical batch (same pattern repeated) — it's about *task simplicity*.
5. **Post-Implementation Review.** Dispatch `Skill: x-skills:x-review` on the changeset (no args → x-review auto-detects diff target). x-review owns the cross-model fan-out, synthesis, passes menu, and Fix Mode routing. Honor its returned verdict: APPROVE → step 6; REQUEST_CHANGES → fire the `verification-failed` reaction (re-review then re-execute on approval).
   **Trivial implementations (< 3 tasks AND single module):** Pass `--reduced` hint to x-review (1-reviewer mode, OMC `code-reviewer` on the diff).
   **Mechanical batches:** Pass `--reduced` hint to x-review (1-reviewer mode is sufficient).
   **Parent workflow deference:** When x-do runs inside x-skill-improve, skip this review — the parent's `/x-skill-review` validation step covers it. Do not run both.
6. Verify and finish branch

## B: New Feature

1. **If requirements are clear:** brainstorm approaches, then plan
2. **If requirements are vague or cross 3+ modules:** follow the step files in `../steps/` (read one at a time, start with `step-01-gather.md`)
3. **Mindfulness Gate (auto-invoke `/x-mindful` on high-risk plans).** Same trigger keywords and skip rules as Mode A step 2 above. Run AFTER plan creation, BEFORE plan review. The envelope feeds the revised plan into step 4.
4. **⛔ Plan Review — NON-NEGOTIABLE.** Same rules as Mode A step 3: dispatch `Skill: x-skills:x-review <plan-path>`. Same trivial / mechanical / research-produced reduced-review exceptions apply.
5. Execute based on scope:
   - 3+ tasks → `ralph` (persistence, TDD, verification loop) — **never manual batch edits**
   - 1-2 tasks → OMO `--model codex` (GPT-5.3 Codex, replaces UNAVAILABLE `hephaestus`) or direct execution
   - **Mechanical batch** or **surgical edits** → direct execution regardless of count (same exceptions as Mode A step 3)
6. **Post-Implementation Review.** Same as Mode A step 5: dispatch `Skill: x-skills:x-review` on the changeset. Same reduced-review / parent-deference exceptions apply.
7. Verify and finish branch

## C: Bug Fix

**Delegate to `/x-bugfix`** — it has structured investigation phases, evidence hierarchy, competing hypotheses for ambiguous bugs, and produces verified fixes with debug reports.

Route: hand off the user's bug description to x-bugfix via `Skill("x-bugfix", args="<bug description>")`. It will handle investigation, fix, and verification internally.

After x-bugfix completes:
1. **Post-Fix Review.** Dispatch `Skill: x-skills:x-review` on the changeset. Honor verdict per `verification-failed` reaction.
2. Verify and finish branch

## D: Quick Task

1. Execute directly — no agent spawn needed for trivial changes (rename, config edit, single-line fix). Use `morph-mcp edit_file` as the default edit tool; fall back to Edit/Write only if `edit_file` errors.
   - Use `morph-mcp codebase_search` if you need to locate the target code first
   - Only spawn OMC `executor` if the quick task still benefits from isolation (e.g., touches multiple files or needs exploration first)
2. Still verify — even quick tasks need evidence

## E: Visual Input

1. **If image is already in the conversation** (user attached it): Claude can analyze it directly first — no agent needed for simple screenshots or UI mockups.
2. **For complex visual analysis** (dense diagrams, PDFs, detailed UI extraction): dispatch OMO `multimodal-looker` (Gemini 3.1 Pro, better vision for complex visuals) + OMC Explore in parallel for related code.
3. Synthesize, then route to A/B/C based on what the visual reveals

## F: Refactor

**Detect first.** `/refactor` is an external skill (not in this plugin). Check the available-skills list at session start (or `~/.claude/skills/refactor/` and the harness's skill registry). If present → delegate. If absent → fall back to Mode A (treat as a multi-task plan): brainstorm scope, write a plan, dispatch executor, post-impl review. Do NOT silently call `Skill("refactor", ...)` and hope it resolves.

**Delegate to `/refactor`** (when available) — it has a 6-phase workflow (intent gate → codebase analysis → codemap → test assessment → plan → execute with per-step verification → final verification). Uses AST-grep, LSP, and Morph codebase_search for structural precision.

Route: hand off the user's refactoring description to refactor via `Skill("refactor", args="<target and scope>")` — primitive: `handoff` (sync, depends on result). Include a [handoff context](../../x-shared/context-envelope.md) block: from x-do Mode F, target/scope, files in scope, why-now reason. It will handle analysis, planning, and execution internally.

**Enumerated review-feedback exception:** When the user provides specific, numbered changes on an existing commit (e.g., "I have feedback for commit abc123: 1. use csv lib, 2. extract method, 3. fix error type..."), treat as **Mode A** instead — the feedback list IS the plan. `/refactor`'s discovery phases (intent gate, codemap) add ceremony that duplicates what the user already scoped. Route to Mode A and follow its plan review → execute → post-impl review pipeline.

After refactor completes:
1. **Post-Refactor Review.** Dispatch `Skill: x-skills:x-review` on the changeset. Honor verdict per `verification-failed` reaction.
   **Small-scope refactors (single module, < 3 files):** Pass `--reduced` hint to x-review.
2. Verify and finish branch

> **Verdict-envelope vs Fix Mode contract:** x-review returns a structured `plan-mode envelope` (with `verdict: APPROVE | REQUEST_CHANGES`) only for **Target A (plan/spec)**. For code/diff targets (B/C/D), x-review applies fixes inline via its own Fix Mode (`superpowers:receiving-code-review` + `verification-before-completion`) and returns after fixes are on disk. x-do should treat code-target review as "x-review owns the fix loop" — re-run tsc/eslint/tests on the resulting tree rather than routing on a verdict token. The `verification-failed` reaction below applies to **plan-review** REQUEST_CHANGES and to code-target reviews where the user explicitly picked Review-Only Mode (no inline fixes).