# Step 3: Review Plan

**Progress: Step 3 of 4** — Next: Execute

## Rules

- **READ COMPLETELY** before acting
- **NEVER** proceed to execution until x-review returns a verdict
- **HALT** on REQUEST_CHANGES verdict — address blockers before continuing

## Goal

Delegate plan review to **x-review** and route on its verdict. x-review owns the cross-model fan-out (Claude opus + GPT blocker-finder + requesting-code-review + optional Gemini-pro) and synthesis — do NOT redefine reviewer dispatch here.

## When to Use

- Plan has 3+ tasks OR crosses multiple modules
- Plan has architectural decisions or high-risk changes (security, data migration, production)

## When to Skip

- Plan has < 3 tasks AND touches a single module → proceed to `step-04-execute.md`
- Mechanical batch (same structural change repeated across N files) → proceed to `step-04-execute.md`

## Execution

Dispatch via the Skill tool:

```
Skill: x-skills:x-review
args: <absolute plan path>
```

x-review will detect **Target A: Plan/Spec** from the `.md` path and run its plan-mode pipeline:
1. Cross-model dispatch (Claude `code-reviewer` opus + `--model gpt` blocker-finder + `superpowers:requesting-code-review`; Gemini-pro added if `gemini_cli` capability is pinned)
2. Synthesis filtered by scope (false assumptions, missing deps, ambiguous success criteria, verification gaps)
3. Returns the `<!-- x-review plan-mode envelope v1 -->` block with verdict + findings counts. No passes menu, no Fix Mode.

**Reduced review (1 reviewer: `--model gpt` blocker-finder only):** Plans generated from comprehensive x-research (Type A comparison with 10+ sources read) may pass a `reduced` hint to x-review in the args (e.g., `args: "<plan-path> --reduced"`).

## Verdict Handling

Parse the `<!-- x-review plan-mode envelope v1 -->` block from x-review's return:

- **`verdict: APPROVE`** → proceed to `step-04-execute.md`.
- **`verdict: REQUEST_CHANGES`** → address blocker findings, revise the plan, then either:
  - Re-dispatch `Skill: x-skills:x-review <plan-path>` for a fresh verdict, OR
  - Proceed with explicit user approval ("ship it anyway" / "I've read the blockers and accept").

## Output

A reviewed plan with APPROVE verdict (or explicit user override).

## Next Step

Proceed to `step-04-execute.md`.
