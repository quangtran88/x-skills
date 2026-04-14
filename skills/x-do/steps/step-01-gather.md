# Step 1: Gather Requirements & Context

**Progress: Step 1 of 4** — Next: Plan

## Rules

- **READ COMPLETELY** before acting — do not start executing mid-read
- **FOLLOW SEQUENCE** — complete sections in order
- **NEVER** skip to step 2 without collecting both agent results
- **HALT** at the user validation checkpoint — wait for confirmation before proceeding

## Goal

Gather requirements analysis and codebase context in parallel before planning.

## When to Use This Step

- Requirements are vague, open-ended, or cross 3+ modules
- User provides only a rough idea without clear scope
- You need both "what should we build?" and "what exists already?"

## When to Skip

- **x-research handoff exists** → requirements already collected via `/x-research`, go to step-02-plan.md
- Requirements are already clear and scoped → go to step-02-plan.md
- User already brainstormed in a prior session → go to step-02-plan.md
- Single-task work → skip the pipeline entirely, use hephaestus or direct execution

## Execution

1. **Fire two agents in parallel** (`run_in_background: true`):

   **Agent A — metis** (requirements analysis via Bash/OMO):
   ```
   Analyze this request before planning: {{user's request}}.
   Current codebase context: {{relevant files, stack, constraints}}.
   What hidden requirements, scope risks, and AI-slop patterns should we address?
   ```

   **Agent B — OMC Explore** (codebase context via Agent tool, NOT OMO explore):
   ```
   subagent_type: "Explore"
   prompt: "Find existing patterns, conventions, and related code for {{feature}}.
   Use morph-mcp codebase_search for semantic queries like 'auth flow' or 'payment handling'.
   Search for related implementations, interfaces, tests.
   Return file paths with pattern descriptions."
   ```

   **Why OMC Explore over OMO explore:** OMC Explore agents inherit all session MCPs including `morph-mcp codebase_search` (semantic code search). OMO explore only has grep/glob/ast_grep. Semantic search is significantly better for pre-planning context gathering ("find the auth flow" vs. pattern-matching for "auth").

2. **Collect both results** before proceeding. Never synthesize from partial results.

3. **Synthesize findings** into a brief summary:
   - Requirements: what metis identified (scope, risks, hidden requirements)
   - Context: what explore found (related code, conventions, patterns to follow)
   - Constraints: anything that limits the approach

4. **Present to user** for validation before planning:
   > Here's what I found. Does this match your intent? Anything to add or change before I create a plan?

## Output

A validated requirements + context summary ready to feed into step-02-plan.md.

## Next Step

Proceed to `step-02-plan.md` with the validated summary.
