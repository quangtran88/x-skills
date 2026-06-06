# Available Tools

These are the building blocks. Compose them based on the situation — not every task needs every tool. Skip steps that don't add value.

**Native `Edit`/`Grep` are the default for edits/search (use OMO `explore` for semantic search) — before spawning agents:**

| Tool | When It Helps | How |
|------|--------------|-----|
| OMO `explore` (or native `Grep` for literal patterns) | **First choice** for exploring code, finding patterns, understanding flow | OMO agent — semantic; `Grep` for exact literal tokens |
| native `Edit` / `Write` | **Default** for all file edits | native tool |
| `deepwiki` → `ask_question` (or `gh search code`) | Understanding external library internals without cloning | MCP tool / CLI |
| `superpowers:brainstorming` | Requirements unclear, multiple approaches possible | Skill |
| `superpowers:writing-plans` | Need structured plan before execution | Skill |
| `superpowers:systematic-debugging` | Bug with unclear root cause | Skill |
| `superpowers:test-driven-development` | Any implementation that should have tests | Skill |
| `superpowers:verification-before-completion` | Multi-file or cross-module changes; direct tsc/eslint sufficient for < 3 files | Skill |
| `superpowers:finishing-a-development-branch` | Work complete, decide merge/PR/keep | Skill |
| `oh-my-claudecode:ralph` | 3+ tasks, needs persistence loop | Skill |
| OMC `executor` | Direct implementation (haiku=trivial, sonnet=moderate, opus=complex) | Agent |
| OMC `code-reviewer` | Post-implementation review | Agent |
| OMC `debugger` | Root cause analysis | Agent |
| OMC `tracer` | Competing hypotheses in debugging | Agent |
