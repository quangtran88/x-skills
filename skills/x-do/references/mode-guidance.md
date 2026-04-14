# Mode Guidance

Detailed instructions for each detection mode. Referenced from SKILL.md's detection table.

## A: Existing Plan

1. Read the plan fully
2. **⛔ Plan Review (cross-model, parallel) — NON-NEGOTIABLE.** Skip ONLY for trivial plans (< 3 tasks AND single module) OR **mechanical batches** (same structural change repeated across N files — e.g., remove an import + call site identically in 4 adapters). For everything else, launch all 3 reviewers immediately — do NOT ask the user for permission, just announce: *"N tasks across M files — running quick plan review (~90s) before executing."* Then launch reviewers in ONE message. If the user said "fix all" / "just do it" — that means execute everything, NOT skip the review. Collect all results before proceeding.
   **Research-produced plan exception:** Plans generated from comprehensive x-research (Type A comparison with 10+ sources read) may use reduced plan review (1 reviewer: momus only) instead of full 3-reviewer ceremony. The research itself provides grounding that substitutes for broader review.
3. Execute: `ralph` for 3+ tasks, direct execution for simpler plans. **"Fix all" with 3+ tasks = ralph, not manual batch edits.** Exception: **mechanical batches** (identical change across files) may use direct execution regardless of file count — ralph overhead exceeds the risk.
   **Surgical edit exception:** Direct execution is also acceptable for 3+ tasks when ALL are: (a) single-location edits or new files, (b) no dependencies between them, (c) each describable in 1 sentence, (d) total < 30 lines changed. This is distinct from mechanical batch (same pattern repeated) — it's about *task simplicity*.
4. **Post-Implementation Review (cross-model, parallel):** Use the exact post-implementation review tool calls from `cross-model-review.md`. All 3 in one message.
   Collect all results, synthesize, flag contradictions.
   **Trivial implementations (< 3 tasks AND single module):** Reduce to 1 reviewer (OMC `code-reviewer` on the diff). Full 3-reviewer ceremony is disproportionate for small changes.
   **Mechanical batches:** Post-impl review is still required (reduced to 1 reviewer: OMC `code-reviewer` on the diff is sufficient).
   **Parent workflow deference:** When x-do runs inside x-skill-improve, defer post-impl review to the parent skill's validation step (`/x-skill-review`). Do not run both.
5. Verify and finish branch

## B: New Feature

1. **If requirements are clear:** brainstorm approaches, then plan
2. **If requirements are vague or cross 3+ modules:** follow the step files in `../steps/` (read one at a time, start with `step-01-gather.md`)
3. **⛔ Plan Review (cross-model, parallel) — NON-NEGOTIABLE.** Same rules as Mode A step 2, including mechanical batch and research-produced plan exceptions.
4. Execute based on scope:
   - 3+ tasks → `ralph` (persistence, TDD, verification loop) — **never manual batch edits**
   - 1-2 tasks → OMO `hephaestus` or direct execution
   - **Mechanical batch** or **surgical edits** → direct execution regardless of count (same exceptions as Mode A step 3)
5. **Post-Implementation Review (cross-model, parallel):** Same as Mode A step 4, including trivial/mechanical/parent-deference exceptions.
6. Verify and finish branch

## C: Bug Fix

**Delegate to `/x-bugfix`** — it has structured investigation phases, evidence hierarchy, competing hypotheses for ambiguous bugs, and produces verified fixes with debug reports.

Route: hand off the user's bug description to x-bugfix via `Skill("x-bugfix", args="<bug description>")`. It will handle investigation, fix, and verification internally.

After x-bugfix completes:
1. **Post-Fix Review (cross-model, parallel):** Use the exact post-implementation review tool calls from `cross-model-review.md`. All 3 in one message. Collect all results, synthesize, flag contradictions.
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

**Delegate to `/refactor`** — it has a 6-phase workflow (intent gate → codebase analysis → codemap → test assessment → plan → execute with per-step verification → final verification). Uses AST-grep, LSP, and Morph codebase_search for structural precision.

Route: hand off the user's refactoring description to refactor via `Skill("refactor", args="<target and scope>")`. It will handle analysis, planning, and execution internally.

**Enumerated review-feedback exception:** When the user provides specific, numbered changes on an existing commit (e.g., "I have feedback for commit abc123: 1. use csv lib, 2. extract method, 3. fix error type..."), treat as **Mode A** instead — the feedback list IS the plan. `/refactor`'s discovery phases (intent gate, codemap) add ceremony that duplicates what the user already scoped. Route to Mode A and follow its plan review → execute → post-impl review pipeline.

After refactor completes:
1. **Post-Refactor Review (cross-model, parallel):** Use the exact post-implementation review tool calls from `cross-model-review.md`. All 3 in one message. Collect all results, synthesize, flag contradictions.
   **Small-scope refactors (single module, < 3 files):** Reduce to 1 reviewer (OMC `code-reviewer` on the diff).
2. Verify and finish branch
