# Step 1: Gather Requirements & Context

**Progress: Step 1 of 4** — Next: Plan

## Rules

- **READ COMPLETELY** before acting — do not start executing mid-read
- **FOLLOW SEQUENCE** — complete sections in order
- **NEVER** synthesize partial research results — wait for x-research's full envelope
- **HALT** at the user validation checkpoint — wait for confirmation before proceeding

## Goal

Gather requirements analysis and codebase context before planning. **x-research owns the dispatch and synthesis** — this step delegates and consumes the envelope.

## When to Use This Step

- Requirements are vague, open-ended, or cross 3+ modules
- User provides only a rough idea without clear scope
- You need both "what should we build?" and "what exists already?"

## When to Skip

- **x-research handoff already exists in this session** → requirements already collected, go to `step-02-plan.md`
- Requirements are already clear and scoped → go to `step-02-plan.md`
- User already brainstormed in a prior session → go to `step-02-plan.md`
- Single-task work → skip the pipeline entirely, use `--model codex` or direct execution

## Execution

### 1. Delegate to x-research (Pre-planning lane)

Dispatch via the Skill tool — x-research runs the canonical Pre-planning fan-out (`OMO oracle ∥ morph codebase_search ∥ OMO explore`) per `../x-research/references/prompt-templates.md` § Type F (also indexed in `../x-research/SKILL.md` Detection table row `Pre-planning`) and synthesizes the three lanes into a single envelope:

```
Skill: x-skills:x-research
args: Pre-planning consult for: {{user's request}}.
      Current codebase context: {{relevant files, stack, constraints}}.
      Identify hidden requirements, scope risks, AI-slop patterns,
      existing related code, and conventions to follow.
```

x-research will:
1. Run `oracle` (strategic consult) — surfaces hidden requirements, scope risks, AI-slop patterns
2. Run `morph codebase_search` — semantic local code search for related implementations
3. Run `OMO explore` — pattern/path discovery via grep/glob/ast_grep for conventions and prior implementations
4. Synthesize into a single context envelope (per `../x-research/references/synthesis-rules.md`)

**Why delegate instead of dispatching inline:** Reviewer + research fan-out lives in canonical owner skills (x-review, x-research). x-do is a router — it does NOT redefine multi-agent dispatch. Inline duplication has historically drifted away from the canonical lane shape.

### 2. Consume x-research's envelope

Read the returned synthesis. Extract for downstream steps:
- **Requirements:** what oracle identified (scope, risks, hidden requirements)
- **Context:** what morph + explore found (related code, conventions, patterns to follow)
- **Constraints:** anything that limits the approach
- **Commit recompose hint** (optional, router-only): if the user mentioned a preference for how to group commits at the end (e.g., "keep granular commits", "squash by feature", "one commit per domain"), persist as `commit_recompose_hint` in run state. Allowed values: `"preserve"` (skip recompose) or `"axis:<topic|domain|feature|item>"` (force axis). Step-04 reads this before dispatching the `commit` skill.

### 3. Present to user for validation (router-level gate)

> Here's what x-research found. Does this match your intent? Anything to add or change before I create a plan?

**Wait for explicit confirmation** before proceeding to `step-02-plan.md`.

## Output

A validated requirements + context summary (sourced from x-research's envelope) ready to feed into `step-02-plan.md`.

## Next Step

Proceed to `step-02-plan.md` with the validated summary.
