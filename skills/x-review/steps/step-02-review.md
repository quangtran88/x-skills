# Step 2: Cross-Model Review

**Progress: Step 2 of 4** — Next: Synthesize

## Rules

- **READ COMPLETELY** before acting
- **NEVER** act on step 3 until ALL reviewers complete (or fail with output assessed) and results are collected (pre-loading the step file while waiting is acceptable)
- OMO agents run via **Bash** (path from `config.json` → `omo_agent`), NOT via Agent tool
- Launch all reviewers in ONE message for true parallelism
- Wait for ALL background notifications before proceeding

## Scope Guard (prepend to EVERY reviewer prompt — paste verbatim)

Read `references/scope-guard.md` and paste the SCOPE block VERBATIM at the top of every reviewer prompt below (Agent code-reviewer, omo-agent oracle, omo-agent --model gpt, agy-agent --model pro, requesting-code-review). Do NOT summarize or paraphrase — the reviewers calibrate to the literal wording.

In the prompt examples below, `<SCOPE_GUARD>` is shorthand for the full block from `references/scope-guard.md`. When you actually invoke the tool, replace it with the entire pasted block (~10 lines).

## Reduced Mode (`--reduced` hint)

If the invocation args contain `--reduced` (e.g., `Skill: x-skills:x-review <path> --reduced`), run a SINGLE-reviewer fan-out instead of the full 3/4-lane dispatch:

- **Target A (plan) + `--reduced`** → run only `<omo_agent> --model gpt` blocker-finder (lane 2 of Plan Review below). Skip Agent `code-reviewer`, skip `requesting-code-review`.
- **Targets B/C/D (code/diff) + `--reduced`** → run only Agent `oh-my-claudecode:code-reviewer` (lane 1 of Code Review below). Skip oracle, skip gemini, skip `requesting-code-review`.

Reduced mode still pastes the Scope Guard VERBATIM. It still emits the completion checklist with the unused-lane boxes marked `N/A — reduced mode`. It still routes through step-03 synthesis and step-04 verdict.

The caller (typically `x-do` for research-produced plans, trivial impls, or mechanical batches) is responsible for asserting that reduced coverage is sufficient — see `../../x-do/references/mode-guidance.md` for the trigger criteria.

## Plan Review (Target A)

Launch these 4 in ONE message (3 when `agy_cli` capability is NOT pinned). **Dispatch the Agent code-reviewer even if your parent context is already opus** — a separate context window catches what the current context misses, and self-grep does not substitute for it.

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective. Prepend the Scope Guard above.
2. **Bash tool:** `<omo_agent from config.json> --model gpt "<SCOPE_GUARD>\n\nYou are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: false assumptions in the plan, missing dependencies, ambiguous success criteria, verification gaps. Do NOT propose new features, alternative architectures, or scope additions."`, `run_in_background: true`, `timeout: 600000` — GPT-5.5 blocker-finder (OKAY/REJECT verdict). *Replaces the UNAVAILABLE `momus` role agent — see `../../x-omo/gotchas.md`.*
3. **Bash tool:** `agy-agent --model pro --grounded "<SCOPE_GUARD>\n\nYou are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: false assumptions in the plan (especially library/API claims you can verify via Google Search), missing dependencies, ambiguous success criteria, verification gaps. Do NOT propose new features, alternative architectures, or scope additions."`, `run_in_background: true`, `timeout: 600000` — agy (gemini-3-pro) plan blocker-finder. Strengths: `--grounded` Google Search grounding catches stale library claims / removed APIs / outdated framework guidance in the plan that Claude+GPT miss; 1M context handles plan + linked specs in one pass. **Skip this lane only if `agy_cli` capability is NOT pinned** (per `../../x-shared/capability-loading.md`); note the skip in synthesis.
4. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow. Prepend the Scope Guard.

For architecture-sensitive plans, add a 4th reviewer **only if the user explicitly asked for an architecture review**:
- **Bash tool:** `<omo_agent from config.json> oracle "<SCOPE_GUARD>\n\n<architecture review prompt>"`, `run_in_background: true`, `timeout: 600000`

## Code / Git Diff Review (Targets B, C, D)

Launch these 4 in ONE message — all tool calls in a single response, not sequential messages. **Every prompt below MUST start with the Scope Guard block from the top of this file.**

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective. Prepend Scope Guard.
2. **Bash tool:** `<omo_agent from config.json> oracle "<SCOPE_GUARD>\n\n<review prompt with diff/file content>"`, `run_in_background: true`, `timeout: 600000` — GPT perspective
3. **Bash tool:** `agy-agent --model pro --grounded "<SCOPE_GUARD>\n\n<review prompt with diff/file content>"`, `run_in_background: true`, `timeout: 600000` — agy perspective. Strengths: `--grounded` Google Search grounding (catches CVE / library version regressions Claude/GPT miss), 1M context (handles 50+ file diffs without paging), multimodal (handles UI screenshot diffs). **Skip this lane only if `agy_cli` capability is NOT pinned** (per `../../x-shared/capability-loading.md`); note the skip in synthesis.
4. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow. Prepend Scope Guard to the request.

**Example — correct (one message, four tool calls):**
```
[assistant response]
  Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="opus", run_in_background=true, prompt="...")
  Tool: Bash(command="<omo_agent from config.json> oracle '...'", run_in_background=true, timeout=600000)
  Tool: Bash(command="agy-agent --model pro --grounded '...'", run_in_background=true, timeout=600000)
  Tool: Skill(skill="superpowers:requesting-code-review")
```
If you just sent a message with only ONE tool call, STOP — you already failed this rule. Delete nothing, just add the missing tool calls in your next message and note the deviation.

**Pre-launch self-check (run BEFORE sending the message):**

*Presence checks (all 4 reviewers in one message — agy lane optional only when capability not pinned):*
1. Is `Agent(subagent_type="oh-my-claudecode:code-reviewer", ...)` in the call list? If no → STOP, add it.
2. Is `Bash(command="<omo_agent> oracle ...")` in the call list? If no → STOP, add it.
3. Is `Bash(command="agy-agent --model pro --grounded ...")` in the call list? If no AND `agy_cli` is pinned → STOP, add it. If `agy_cli` is NOT pinned → skip this check, note "agy lane skipped: capability unavailable" in synthesis.
4. Is `Skill(skill="superpowers:requesting-code-review")` in the call list? If no → STOP, add it.
5. Are all reviewers in the SAME message? If no → STOP, batch them.

*Content checks (right command for the target):*
6. **Target-routing check:** If target is B/C/D (code/files/diff) and your Bash command contains `--model gpt`, STOP — switch to `oracle`. `--model gpt` is the plan-only blocker-finder (Target A). Code/diff review uses `<omo_agent> oracle "..."`. Mixing them is a known compliance gap (sessions 9ba4f817, 1ba866d1).

Self-verification by reading files / running grep is NOT a substitute for the Agent code-reviewer dispatch. The Agent runs in a separate context window — its findings differ from yours.

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
- [ ] agy-agent --model pro --grounded (Bash tool, `run_in_background: true`) — result collected OR `agy_cli` capability not pinned (skip noted in synthesis) OR failure handled
- [ ] `superpowers:requesting-code-review` (Skill tool) — structured review workflow result collected
- [ ] All reviewers launched in ONE message (Skill loads synchronously, then its agent runs in background)

**Do NOT proceed until every box is checked.**

## Next Step

Once ALL results are collected, read fully and follow `step-03-synthesize.md`.
