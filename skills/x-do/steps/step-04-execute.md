# Step 4: Execute Plan

**Progress: Step 4 of 4** — Final step

## Rules

- **READ COMPLETELY** before acting
- **NEVER** claim completion without running verification

## Goal

Execute the reviewed plan and verify completion.

## Route Selection

| Signal | Route | Why |
|--------|-------|-----|
| 3+ tasks | `oh-my-claudecode:ralph` | Persistence loop, TDD, verification per story |
| 1-2 complex tasks | OMO `--model codex` | GPT-5.3 Codex for autonomous deep work (replaces the UNAVAILABLE `hephaestus` role agent — see `~/.claude/skills/x-omo/gotchas.md`) |
| 1-2 simple tasks | Direct execution via OMC `executor` | Fastest path |
| Plan is a superpowers plan | `superpowers:subagent-driven-development` | Fresh subagent per task |

## Forward Intelligence

Before executing, gather key constraints discovered in earlier steps and inject them into the execution prompt:

- **From step-01 (gather):** Conventions to follow, existing patterns to match, scope boundaries
- **From step-02 (plan):** Decisions already made, rejected alternatives, verification criteria
- **From step-03 (review):** Blocker resolutions, risk mitigations agreed upon

Format as a brief `[CONSTRAINTS]` block at the top of the execution prompt. This prevents the execution agent from re-discovering or contradicting decisions already made.

## Execution

1. **Select route** based on task count and complexity (use depth calibration from SKILL.md).

2. **Execute.**
   - For ralph: `Skill` tool → `oh-my-claudecode:ralph` with the plan
   - For OMO codex (autonomous deep work): `Bash` tool → `~/.claude/skills/x-omo/omo-agent --model codex "<structured prompt>"`, `timeout: 600000`
   - For executor: `Agent` tool → `subagent_type="oh-my-claudecode:executor"`
   - For subagent-driven: `Skill` tool → `superpowers:subagent-driven-development`
   - For direct execution (Mode D / surgical edits): Use `morph-mcp edit_file` for edits, `morph-mcp codebase_search` to locate targets

3. **Verify** — `superpowers:verification-before-completion` before claiming done.

4. **Finish branch** — `superpowers:finishing-a-development-branch` to decide merge/PR/keep.

## After Execution

See "After This Skill" in `../SKILL.md` for /x-review handoff and learner hook.
