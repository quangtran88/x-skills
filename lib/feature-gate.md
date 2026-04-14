# Feature Gate — Runtime Dependency Detection

This document is loaded by x-skills at bootstrap to determine which capabilities are available. Skills read this to decide routing paths.

## How to Check

Run this command at bootstrap to load the capability manifest:

```bash
cat ~/.config/x-skills/capabilities.json 2>/dev/null || echo '{"capabilities":{}}'
```

If the file doesn't exist, the user hasn't run setup yet. Treat all optional deps as unavailable and use Claude-only fallback routing.

## Capability Checks

### omo-agent (multi-model dispatch)

**Check:** `command -v omo-agent` or read `capabilities.json → opencode`

**If available:** Dispatch to OMO agents (oracle, explore, librarian, multimodal-looker) via:
```bash
omo-agent <agent> "<prompt>"
```

**If unavailable — Claude-only fallback:**
- Replace `oracle` dispatch → use `Agent` tool with `model=opus` and the oracle's role in the prompt
- Replace `explore` dispatch → use `Agent` tool with `subagent_type=Explore`
- Replace `librarian` dispatch → use `Agent` tool with web search MCP tools
- Replace `multimodal-looker` dispatch → use `Read` tool on images directly (Claude is multimodal)
- Replace `--model` dispatch → use `Agent` tool with appropriate model parameter

### oh-my-claudecode (OMC agents)

**Check:** Read `capabilities.json → plugins.oh_my_claudecode`

**If available:** Dispatch to OMC agents via `Agent` tool with `subagent_type="oh-my-claudecode:<agent>"`:
- `executor` — code implementation
- `code-reviewer` — review
- `debugger` — debugging
- `tracer` — evidence-driven tracing

**If unavailable — Claude-only fallback:**
- Replace `executor` → use `Agent` tool with `mode=auto` and implementation instructions
- Replace `code-reviewer` → use `Agent` tool with `subagent_type="superpowers:code-reviewer"` or plain `Agent`
- Replace `debugger` → use `Agent` tool with debugging instructions
- Replace `tracer` → use `Agent` tool with tracing instructions

### superpowers (workflow skills)

**Check:** Read `capabilities.json → plugins.superpowers`

**If available:** Invoke via `Skill` tool:
- `superpowers:brainstorming`
- `superpowers:writing-plans`
- `superpowers:test-driven-development`
- `superpowers:verification-before-completion`
- `superpowers:requesting-code-review`
- `superpowers:finishing-a-development-branch`

**If unavailable — inline fallback:**
- Skip skill invocation, apply the workflow principles inline
- Brainstorming → ask clarifying questions before implementing
- Writing plans → write a structured plan in markdown
- TDD → write tests before implementation
- Verification → run tests/typecheck before claiming done

### MCP Servers

**Check:** Read `capabilities.json → mcp.*`

Each MCP is independently optional. Skills should check before dispatching:

| MCP | Used by | Fallback |
|-----|---------|----------|
| perplexity | x-research | Skip web search, note limitation |
| deepwiki | x-research | Use `github_codebase_search` via morph-mcp |
| exa | x-research | Skip code context search |
| context7 | x-research | Skip library docs lookup |
| morph | x-do, x-research, x-bugfix, x-review | Fall back to native `Grep` + `Edit` |

### claude-mem (cross-session memory)

**Check:** Read `capabilities.json → plugins.claude_mem`

**If available:** Use `mcp__plugin_claude-mem_*` tools for session search
**If unavailable:** Skip session search, note limitation to user

## Fallback Priority

When a dependency is missing, skills degrade in this order:
1. Use the next-best available tool (e.g., Agent tool instead of OMO agent)
2. Inline the workflow (e.g., brainstorm inline instead of invoking skill)
3. Skip the step entirely and note the limitation
4. Never error out — always produce useful output with whatever is available
