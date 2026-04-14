# Cross-Model Review — Exact Tool Calls

**CRITICAL:** OMO agents are NOT OMC agents. OMO agents run via **Bash** (`omo-agent`), NOT via the Agent tool.

**MANDATORY:** Do NOT generate any synthesis until ALL reviewers complete and results are collected.

## Plan Review — launch these 3 in ONE message:

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective
2. **Bash tool:** `omo-agent momus "<plan-path>"`, `run_in_background: true`, `timeout: 600000` — GPT blocker-finder (OKAY/REJECT). Works with ANY path.
3. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow

## Post-Implementation Review — launch these 3 in ONE message:

1. **Agent tool:** `subagent_type: "oh-my-claudecode:code-reviewer"`, `model: "opus"`, `run_in_background: true` — Claude perspective
2. **Bash tool:** `omo-agent oracle "<review prompt>"`, `run_in_background: true`, `timeout: 600000` — GPT perspective
3. **Skill tool:** `superpowers:requesting-code-review` — structured review workflow

## After All Reviewers Return

Collect results, synthesize, deduplicate overlaps.

**When reviewers contradict each other**, use evidence tiering to prioritize:

| Evidence Tier | Trust Level | Examples |
|---------------|-------------|----------|
| **T1: Verifiable** | Highest — can be checked | "This function throws on null" (run it), "Missing import" (compile it) |
| **T2: Authoritative** | High — cites docs/specs | "API requires auth header per docs" (check the docs) |
| **T3: Reasoning** | Medium — logical argument | "This approach won't scale because..." (evaluate the logic) |
| **T4: Opinion** | Lowest — stylistic preference | "I'd use a different pattern here" (note but don't block on it) |

For T1/T2 conflicts: verify the claim before choosing. For T3 conflicts: present both arguments to the user. For T4 conflicts: ignore unless both agree.
