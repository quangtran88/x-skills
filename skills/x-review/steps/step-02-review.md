# Step 2: Cross-Model Review

**Progress: Step 2 of 4** — Next: Synthesize

## Rules

- **READ COMPLETELY** before acting
- **NEVER** act on step 3 until ALL reviewers complete (or fail with output assessed) and results are collected (pre-loading the step file while waiting is acceptable)
- OMO agents run via **Bash** (path from `config.json` → `omo_agent`), NOT via Agent tool
- Launch all reviewers in ONE message for true parallelism
- Wait for ALL background notifications before proceeding

## Plan Review (Target A)

Launch these 3 in ONE message:

1. **Agent tool:** `subagent_type: "superpowers:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective
2. **Bash tool:** `<omo_agent from config.json> --model gpt "You are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: missing dependencies, ambiguous success criteria, hidden scope, and verification gaps."`, `run_in_background: true`, `timeout: 600000` — GPT-5.4 blocker-finder (OKAY/REJECT verdict). *Replaces the UNAVAILABLE `momus` role agent — see `~/.claude/skills/x-omo/gotchas.md`.*
3. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow

For architecture-sensitive plans, add a 4th reviewer:
- **Bash tool:** `<omo_agent from config.json> oracle "<architecture review prompt>"`, `run_in_background: true`, `timeout: 600000`

## Code / Git Diff Review (Targets B, C, D)

Launch these 3 in ONE message — all tool calls in a single response, not sequential messages:

1. **Agent tool:** `subagent_type: "superpowers:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective
2. **Bash tool:** `<omo_agent from config.json> oracle "<review prompt with diff/file content>"`, `run_in_background: true`, `timeout: 600000` — GPT perspective
3. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow

**Example — correct (one message, three tool calls):**
```
[assistant response]
  Tool: Agent(subagent_type="superpowers:code-reviewer", model="opus", run_in_background=true, prompt="...")
  Tool: Bash(command="<omo_agent from config.json> oracle '...'", run_in_background=true, timeout=600000)
  Tool: Skill(skill="superpowers:requesting-code-review")
```
If you just sent a message with only ONE tool call, STOP — you already failed this rule. Delete nothing, just add the missing tool calls in your next message and note the deviation.

## Collecting Results

Wait for ALL background agent notifications. Do NOT:
- Generate a final answer after only some agents return
- Skip collecting results from slower agents
- Synthesize partial results as "final" output without noting the gap

## Handling Agent Failures

If an OMO agent times out (exit code 124) or fails:

1. **Check for partial output** — read the output file. Partial output is usable if it contains at least one severity-rated finding with a file/line reference. Preamble-only or truncated mid-sentence = no usable output.
2. **If usable partial output exists** — proceed, but note `(partial — agent timed out)` next to that reviewer's findings in synthesis. Check the "failure handled" box below.
3. **If no usable output** — retry once with a shorter/focused prompt (split by concern area). If retry also fails, proceed with N-1 reviewers and note the missing perspective in synthesis.
4. **For large PRs (30+ files or 3000+ changed lines)** — consider splitting the oracle prompt into 2 focused calls (e.g., frontend + backend) rather than one omnibus prompt. Each gets its own 600s budget.

## Completion Checklist (ALL required before proceeding)

- [ ] code-reviewer (Agent tool, opus, `run_in_background: true`) — result collected
- [ ] oracle (Bash tool, `omo-agent oracle`, `run_in_background: true`) — result collected OR failure handled (partial output assessed, gap noted)
- [ ] `superpowers:requesting-code-review` (Skill tool) → launches superpowers:code-reviewer — result collected
- [ ] All 3 launched in ONE message (Skill loads synchronously, then its agent runs in background)

**Do NOT proceed until every box is checked.**

## Next Step

Once ALL results are collected, read fully and follow `step-03-synthesize.md`.
