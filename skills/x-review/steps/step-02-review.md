# Step 2: Cross-Model Review

**Progress: Step 2 of 4** — Next: Synthesize

## Rules

- **READ COMPLETELY** before acting
- **NEVER** act on step 3 until ALL reviewers complete (or fail with output assessed) and results are collected (pre-loading the step file while waiting is acceptable)
- OMO agents run via **Bash** (path from `config.json` → `omo_agent`), NOT via Agent tool
- **Never hardcode a model.** The OMO lanes come from the user's `review_models` list (see below). When that list is empty, the single `oracle` agent lane is the fallback. x-review picks the role and the prompt; the user picks the models.
- Code-reviewer inherits the parent session model: pass `model: "<parent session model>"` explicitly — the agent's frontmatter pins opus, so omitting `model` silently falls back to opus
- Launch all reviewers in ONE message for true parallelism
- Wait for ALL background notifications before proceeding

## Scope Guard (prepend to EVERY reviewer prompt — paste verbatim)

Read `references/scope-guard.md` and paste the SCOPE block VERBATIM at the top of every reviewer prompt below (Agent code-reviewer, omo-agent oracle, agy-agent --model pro, requesting-code-review). Do NOT summarize or paraphrase — the reviewers calibrate to the literal wording.

In the prompt examples below, `<SCOPE_GUARD>` is shorthand for the full block from `references/scope-guard.md`. When you actually invoke the tool, replace it with the entire pasted block (~10 lines).

## OMO Lanes — resolved from `review_models`

Read `review_models` from the capability manifest pinned at bootstrap (`~/.config/x-skills/capabilities.json`, project override `.x-skills/capabilities.json` wins). It is an array of full model IDs the user chose during `bin/setup`, e.g. `["openai/gpt-5.6-sol", "openai/qwen3.7-max", "openai/deepseek-v4-pro"]`.

| `review_models` | OMO lanes to launch |
|---|---|
| Non-empty (N entries, max 4) | **N lanes**, one per entry: `<omo_agent> --model <id> "<prompt>"` |
| Empty / absent / manifest missing | **1 lane (the default)**: `<omo_agent> oracle "<prompt>"` (model comes from the user's OMO agent config) |

The single-`oracle` row is a deliberate default, not a degraded mode: it is the shipped behavior for anyone who never opens the picker, and it needs no stagger, no per-lane budget, and no `review_models` key to exist. Never warn the user that they "should" configure models — offer it, don't nag.

Every lane gets the SAME prompt — the scope guard plus the target-appropriate framing below. The point is N independent models answering one question, not N different questions.

**`--model` lanes are not read-only by construction.** `omo-agent --model` runs opencode's generic `build` agent, which has write tools; the `oracle` agent is read-only by charter. x-review is a reviewer, so append this line verbatim to every `--model` lane prompt:

`You are read-only. Do not edit or create files, and do not run any state-mutating command. Report findings only.`

**Lane labels:** name each lane by its model ID (`openai/qwen3.7-max`), not "GPT" / "the OMO lane" — step-03 attributes findings per reviewer and you will have several.

**MANDATORY stagger — concurrent `opencode run` processes corrupt each other's startup.** Launching N lanes at the same instant makes opencode's SQLite store throw `Error: Unexpected error / database is locked`, and the lane dies in ~1 second with no output. Verified: 3 simultaneous lanes → 1 died on the lock; the same 3 lanes staggered 3s apart → 3/3 success; the killed model then ran fine alone. Still send every lane in ONE message — put the delay *inside* each command instead:

```
lane 1: <omo_agent> --model <id-1> '...'
lane 2: sleep 3 && <omo_agent> --model <id-2> '...'
lane 3: sleep 6 && <omo_agent> --model <id-3> '...'
lane 4: sleep 9 && <omo_agent> --model <id-4> '...'
```

3 seconds per lane index. The lanes still overlap for the whole review (each takes minutes), so this costs ~9s of wall-clock, not parallelism. A `database is locked` failure is NOT a model problem — retry that lane alone before reporting it as a missing perspective.

## Reduced Mode (`--reduced` hint)

If the invocation args contain `--reduced` (e.g., `Skill: x-skills:x-review <path> --reduced`), run a SINGLE-reviewer fan-out instead of the full 3/4-lane dispatch:

- **Target A (plan) + `--reduced`** → run only ONE OMO blocker-finder lane: the FIRST entry in `review_models`, or `oracle` when the list is empty. Skip the other model lanes, skip Agent `code-reviewer`, skip `requesting-code-review`.
- **Targets B/C/D (code/diff) + `--reduced`** → run only Agent `oh-my-claudecode:code-reviewer` (lane 1 of Code Review below). Skip oracle, skip gemini, skip `requesting-code-review`.

Reduced mode still pastes the Scope Guard VERBATIM. It still emits the completion checklist with the unused-lane boxes marked `N/A — reduced mode`. It still routes through step-03 synthesis and step-04 verdict.

The caller (typically `x-do` for research-produced plans, trivial impls, or mechanical batches) is responsible for asserting that reduced coverage is sufficient — see `../../x-do/references/mode-guidance.md` for the trigger criteria.

## Plan Review (Target A)

Launch ALL lanes in ONE message: Claude + every OMO lane from `review_models` (or the single `oracle` fallback) + agy + `requesting-code-review`. **Dispatch the Agent code-reviewer even if your parent context is already opus** — a separate context window catches what the current context misses, and self-grep does not substitute for it.

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"`, `run_in_background: true` — Claude perspective. Prepend the Scope Guard above.
2. **Bash tool — one call per `review_models` entry** (or a single `oracle` call when the list is empty): `<omo_agent from config.json> --model <id> "<SCOPE_GUARD>\n\nYou are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: false assumptions in the plan, missing dependencies, ambiguous success criteria, verification gaps. Do NOT propose new features, alternative architectures, or scope additions.\n\nYou are read-only. Do not edit or create files, and do not run any state-mutating command. Report findings only."`, `run_in_background: true`, `timeout: 600000` — non-Claude blocker-finders (OKAY/REJECT verdict each). *Replaces the UNAVAILABLE `momus` role agent — see `../../x-omo/gotchas.md`.*
3. **Bash tool:** `agy-agent --model pro --grounded "<SCOPE_GUARD>\n\nYou are a plan blocker-finder. Review the plan at <plan-path>. Return at most 3 blockers ranked by severity, then OKAY or REJECT. Focus on: false assumptions in the plan (especially library/API claims you can verify via Google Search), missing dependencies, ambiguous success criteria, verification gaps. Do NOT propose new features, alternative architectures, or scope additions."`, `run_in_background: true`, `timeout: 600000` — agy (gemini-3-pro) plan blocker-finder. Strengths: `--grounded` Google Search grounding catches stale library claims / removed APIs / outdated framework guidance in the plan that Claude+GPT miss; 1M context handles plan + linked specs in one pass. **Skip this lane only if `agy_cli` capability is NOT pinned** (per `../../x-shared/capability-loading.md`); note the skip in synthesis.
4. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow. Prepend the Scope Guard.

For architecture-sensitive plans, **only if the user explicitly asked for an architecture review**, extend the OMO lane prompts with the architecture-review framing — do NOT add an extra lane for it.

## Code / Git Diff Review (Targets B, C, D)

Launch ALL lanes in ONE message — all tool calls in a single response, not sequential messages. **Every prompt below MUST start with the Scope Guard block from the top of this file.**

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "<parent session model>"`, `run_in_background: true` — Claude perspective. Prepend Scope Guard.
2. **Bash tool — one call per `review_models` entry** (or a single `oracle` call when the list is empty): `<omo_agent from config.json> --model <id> "<SCOPE_GUARD>\n\n<review prompt with diff/file content>\n\nYou are read-only. Do not edit or create files, and do not run any state-mutating command. Report findings only."`, `run_in_background: true`, `timeout: 600000` — one independent non-Claude perspective per model
3. **Bash tool:** `agy-agent --model pro --grounded "<SCOPE_GUARD>\n\n<review prompt with diff/file content>"`, `run_in_background: true`, `timeout: 600000` — agy perspective. Strengths: `--grounded` Google Search grounding (catches CVE / library version regressions Claude/GPT miss), 1M context (handles 50+ file diffs without paging), multimodal (handles UI screenshot diffs). **Skip this lane only if `agy_cli` capability is NOT pinned** (per `../../x-shared/capability-loading.md`); note the skip in synthesis.
4. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow. Prepend Scope Guard to the request.

**Example — correct (one message, all lanes; here `review_models` has 3 entries):**
```
[assistant response]
  Tool: Agent(subagent_type="oh-my-claudecode:code-reviewer", model="<parent session model>", run_in_background=true, prompt="...")
  Tool: Bash(command="<omo_agent> --model openai/gpt-5.6-sol '...'",             run_in_background=true, timeout=600000)
  Tool: Bash(command="sleep 3 && <omo_agent> --model openai/qwen3.7-max '...'",  run_in_background=true, timeout=600000)
  Tool: Bash(command="sleep 6 && <omo_agent> --model openai/deepseek-v4-pro '...'", run_in_background=true, timeout=600000)
  Tool: Bash(command="agy-agent --model pro --grounded '...'", run_in_background=true, timeout=600000)
  Tool: Skill(skill="superpowers:requesting-code-review")
```
With an empty `review_models`, lines 2-4 collapse to one `Bash(command="<omo_agent> oracle '...'")`.

If you just sent a message with only ONE tool call, STOP — you already failed this rule. Delete nothing, just add the missing tool calls in your next message and note the deviation.

**Pre-launch self-check (run BEFORE sending the message):**

*Presence checks (every lane in one message — agy lane optional only when capability not pinned):*
1. Is `Agent(subagent_type="oh-my-claudecode:code-reviewer", ...)` in the call list? If no → STOP, add it.
2. **Lane-count check:** count the `<omo_agent>` Bash calls. It MUST equal `review_models.length`, or exactly 1 (`oracle`) when the list is empty. Fewer = you silently dropped a model the user chose → STOP, add the missing lanes.
3. Is `Bash(command="agy-agent --model pro --grounded ...")` in the call list? If no AND `agy_cli` is pinned → STOP, add it. If `agy_cli` is NOT pinned → skip this check, note "agy lane skipped: capability unavailable" in synthesis.
4. Is `Skill(skill="superpowers:requesting-code-review")` in the call list? If no → STOP, add it.
5. Are all reviewers in the SAME message? If no → STOP, batch them.

*Content checks (right command for the target):*
6. **No invented models.** Every `--model <id>` you pass MUST be copied verbatim from `review_models`. If you typed an alias (`gpt`, `codex`, `gemini-pro`) or any ID not in that list, STOP — x-review does not choose models. Hardcoding one is a known compliance gap (sessions 9ba4f817, 1ba866d1). *(`agy-agent --model pro` is a different binary and is unaffected by this check.)*
7. **Read-only line present.** Every `--model` lane prompt ends with the read-only instruction — `--model` lanes run opencode's write-capable `build` agent, unlike the read-only `oracle` agent.
8. **Stagger applied.** Lane 2 starts `sleep 3 &&`, lane 3 `sleep 6 &&`, lane 4 `sleep 9 &&`. Without it, simultaneous lanes die on opencode's `database is locked`. Single-lane dispatch (empty `review_models`, or `--reduced`) needs no stagger.

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
3. **If no usable output** — retry once with a shorter/focused prompt (split by concern area). If retry also fails, proceed with N-1 reviewers and note the missing perspective in synthesis. **Name the model that dropped out** (`openai/deepseek-v4-pro produced no usable output`) — "one reviewer failed" is not enough when several models ran.
4. **For large PRs (30+ files or 3000+ changed lines)** — consider splitting each OMO lane's prompt into 2 focused calls (e.g., frontend + backend) rather than one omnibus prompt. Each gets its own 600s budget. With several models configured this multiplies lanes fast — split only the models you most need on that PR, and say in synthesis which ones you split.
5. **A model that is no longer available** (provider removed it, key revoked) fails immediately rather than timing out. Note it and tell the user to re-run `bin/setup` to re-pick — do NOT silently substitute a different model.

## Completion Checklist (ALL required before proceeding)

- [ ] code-reviewer (Agent tool, parent session model, `run_in_background: true`) — result collected
- [ ] **One box per `review_models` entry** — write the model ID out (e.g. `- [ ] openai/qwen3.7-max — result collected`). Every entry gets its own box; a lane you never launched is a FAIL, not a skip. When `review_models` is empty, this is a single `oracle` box instead.
- [ ] Each OMO lane above — result collected OR failure handled (partial output assessed, gap noted)
- [ ] agy-agent --model pro --grounded (Bash tool, `run_in_background: true`) — result collected OR `agy_cli` capability not pinned (skip noted in synthesis) OR failure handled
- [ ] `superpowers:requesting-code-review` (Skill tool) — structured review workflow result collected
- [ ] All reviewers launched in ONE message (Skill loads synchronously, then its agent runs in background)

**Do NOT proceed until every box is checked.**

## Next Step

Once ALL results are collected, read fully and follow `step-03-synthesize.md`.
