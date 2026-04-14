# Step 2: Create Plan

**Progress: Step 2 of 4** — Next: Review

## Rules

- **READ COMPLETELY** before acting
- **NEVER** skip to execution without creating a plan first
- Choose ONE route — do not mix planning approaches

## Goal

Create a structured implementation plan from the gathered requirements and context.

## Input

- Requirements + context summary from step-01 (or user-provided clear requirements)

## Route Selection

Choose the planning tool based on preference and complexity:

| Signal | Route | Why |
|--------|-------|-----|
| Implementation-focused (build features, write code) | `superpowers:writing-plans` | TDD-oriented, bite-sized tasks, saves to docs/ |
| Complex dependency graph (ordering matters, integration points) | `prometheus` via Bash | Task DAG with dependencies, ordering constraints |
| Simple plan (2-3 tasks) | Write inline | No tool needed — just list the tasks |

## Execution

### Option A: Superpowers Plan
1. Invoke `superpowers:writing-plans` with the requirements summary
2. Plan is saved to `docs/plan-YYYY-MM-DD-<feature>.md`

### Option B: Prometheus Plan
1. Feed requirements summary to prometheus:
   ```
   Create a structured implementation plan for: {{requirements summary}}.
   Codebase context: {{explore findings}}.
   Metis directives: {{metis findings}}.
   ```
2. Capture the plan output

### Option C: Inline Plan
1. List 2-3 tasks with files, approach, and verification steps
2. No external tool needed

## Output

A plan document (file or inline) ready for review or execution.

## Next Step

- Plan has 5+ tasks → proceed to `step-03-review.md`
- Plan has < 5 tasks → skip review, proceed to `step-04-execute.md`
