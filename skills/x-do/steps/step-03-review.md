# Step 3: Review Plan

**Progress: Step 3 of 4** — Next: Execute

## Rules

- **READ COMPLETELY** before acting
- **NEVER** proceed to execution until ALL reviewers return results
- **HALT** on REJECT verdict — address blockers before continuing

## Goal

Review the plan for blockers before committing to execution.

## When to Use

- Plan has 3+ tasks OR crosses multiple modules
- Plan has architectural decisions or high-risk changes (security, data migration, production)

## When to Skip

- Plan has < 3 tasks AND touches a single module → proceed to step-04-execute.md
- Mechanical batch (same structural change repeated across N files) → proceed to step-04-execute.md

## Execution

Launch all 3 reviewers in **ONE message** (ABS = Agent, Bash, Skill):

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective
2. **Bash tool:** `omo-agent --model gpt "You are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: missing dependencies, ambiguous success criteria, hidden scope, and verification gaps."`, `run_in_background: true`, `timeout: 600000` — GPT-5.4 blocker-finder (OKAY/REJECT). *Note: this replaces the former `momus` role agent, which is UNAVAILABLE due to the oh-my-opencode plugin compat bug — see `../../x-omo/gotchas.md`.*
3. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow

**Reduced review (1 reviewer: `--model gpt` blocker-finder only):** Plans generated from comprehensive x-research (Type A comparison with 10+ sources).

4. **Collect ALL results** before proceeding.

5. **If OKAY:** proceed to step-04-execute.md
6. **If REJECT:** address the blocker issues, revise the plan, then re-review or proceed with user approval.

## Output

A reviewed plan with OKAY verdict (or user-approved despite issues).

## Next Step

Proceed to `step-04-execute.md`.
