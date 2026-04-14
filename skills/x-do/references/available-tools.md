# Available Tools

These are the building blocks. Compose them based on the situation — not every task needs every tool. Skip steps that don't add value.

**Morph-MCP tools are the DEFAULT for search and edits — use them before spawning agents:**

| Tool | When It Helps | How |
|------|--------------|-----|
| `morph-mcp` → `codebase_search` | **First choice** for exploring code, finding patterns, understanding flow | MCP tool — semantic, no agent overhead |
| `morph-mcp` → `edit_file` | **Default** for all file edits — partial edits with `// ... existing code ...` | MCP tool |
| `morph-mcp` → `github_codebase_search` | Understanding external library internals without cloning | MCP tool |
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
