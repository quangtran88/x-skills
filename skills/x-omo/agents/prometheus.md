# Prometheus — Strategic Planner

## Identity

Named after the Titan who gave fire to humanity. Prometheus is the strategic planner that creates detailed, executable work plans. It takes analyzed requirements (from Metis or direct input) and produces structured plans with tasks, dependencies, and verification criteria.

## Quick Reference

| Field | Value |
|---|---|
| Short name | `prometheus` |
| OpenCode display name | `Prometheus (Plan Builder)` |
| Default model | `openai/gpt-5.4` |
| Variant | `max` |
| Mode | Planner (replaces OpenCode's default `plan` agent) |
| Cost tier | EXPENSIVE |

## When to Use

- Creating work plans for multi-step features
- After Metis analysis, to produce executable plan
- When tasks need to be decomposed with dependencies
- Before Atlas execution — Prometheus creates, Atlas executes

## When NOT to Use

- Single-step tasks that don't need a plan
- Plan review (use `momus`)
- Plan execution (use `atlas`)
- Quick fixes

## Prompt Template

```bash
omo-agent prometheus "Create an implementation plan for: [FEATURE DESCRIPTION]. Context: [codebase context, existing patterns, constraints]. Requirements: [specific requirements]. The plan will be executed by Atlas with category-based delegation."
```

## Example Prompt

```bash
omo-agent prometheus "Create an implementation plan for adding real-time notifications to the dashboard. Context: Express API + React frontend, PostgreSQL, no existing notification system. Requirements: 1) Server-sent events for real-time delivery 2) Notification preferences per user 3) Read/unread tracking 4) Bell icon with unread count in header. Constraints: No WebSocket — use SSE. Must work with existing auth middleware."
```

## Output Format

Prometheus produces structured plans saved to `.sisyphus/plans/`:

```markdown
# Plan: [Feature Name]

## Overview
[1-2 sentence summary]

## TODOs
- [ ] Task 1: [specific deliverable]
  - Acceptance: [executable verification]
  - Files: [exact paths]
  - Dependencies: none
- [ ] Task 2: [specific deliverable]
  - Acceptance: [executable verification]
  - Dependencies: Task 1
...

## Final Verification Wave
- [ ] F1: Code review
- [ ] F2: Build verification
- [ ] F3: Test coverage
- [ ] F4: Integration test
```

## Relationship in the Pipeline

```
User Request → Metis (analyze) → Prometheus (plan) → Momus (review) → Atlas (execute)
```

- **Receives from Metis**: Intent classification, directives, risk analysis
- **Reviewed by Momus**: Plan is checked for blocking issues before execution
- **Executed by Atlas**: Atlas reads the plan and orchestrates task completion

## Key Principles

- Every task must have executable acceptance criteria (commands, not human actions)
- Tasks should be atomic — one concern per task
- Dependencies must be explicit
- "Must NOT Have" sections prevent scope creep
- QA scenarios must be specific (tool + steps + expected result)
