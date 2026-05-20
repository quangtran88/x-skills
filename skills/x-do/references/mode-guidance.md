# Mode Guidance

Detailed instructions for each detection mode. Referenced from SKILL.md's detection table.

**Reviewer dispatch and synthesis live in x-review.** This file never redefines the 3-reviewer fan-out — every review step below dispatches `Skill: x-skills:x-review` and honors its returned verdict. The reduced-review / mechanical-batch / parent-deference exceptions are passed as hint args.

## A: Existing Plan

1. Read the plan fully
2. **Mindfulness Gate (auto-invoke `/x-mindful` on high-risk plans).** Scan the plan against the auto-gate signal list in `skills/x-mindful/SKILL.md` → "When x-mindful Triggers" (covers tradeoff signals, boundary/contract signals, trust/security signals, operational/cost signals, and architectural-decision keywords). If ANY signal hits AND the plan is not a mechanical batch — invoke `Skill: x-skills:x-mindful` with the plan path / content as input BEFORE proceeding to step 3. Wait for the `<!-- x-mindful-envelope v1 -->` block (taxonomy v2: item ids use `TRADEOFF` / `ASSUMPTION` / `BLIND-SPOT` / `SHAPE` / `FUTURE-DEBT` prefixes; section layout unchanged). Apply the envelope: drop `Rejected` items from the plan, revise the plan to incorporate `Modified` directives, proceed with `Confirmed`. Skip the gate when ALL of: scope is single-file, no shared interface touched, < 3 tasks, no signals appear. Skip is also OK for mechanical batches (same change across N files, no architectural decision).
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

## E (Visual) and F (Refactor) — collapsed

These modes are no longer separate branches. Per `../SKILL.md § Detection`:

- **Visual input** (image / PDF / screenshot / diagram) → Claude is multimodal. Read the artifact directly inside Mode B brainstorming (`superpowers:brainstorming`); for dense diagrams or complex PDFs, dispatch OMO `multimodal-looker` in parallel during step-01. No separate Mode E branch.
- **Refactor with plan ref** → Mode A (treat the plan as authoritative). **Refactor without plan ref** → Mode B (brainstorm scope → write plan → execute). The external `/refactor` skill is no longer a default route; it can still be invoked explicitly by the user, but x-do does not auto-delegate to it.
- **Enumerated review-feedback** on an existing commit → Mode A. The numbered feedback list IS the plan.