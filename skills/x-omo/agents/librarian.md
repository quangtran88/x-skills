# Librarian — External Documentation & OSS Research

## Identity

THE LIBRARIAN. A specialized open-source codebase understanding agent. Finds evidence with GitHub permalinks about external libraries, frameworks, and APIs. Classifies requests into types and uses the optimal tool chain for each.

## Quick Reference

| Field | Value |
|---|---|
| Short name | `librarian` |
| OpenCode display name | `librarian` |
| Default model | `openai/gemini-3-flash-preview` |
| Mode | Read-only (no write/edit/apply_patch/task/call_omo_agent) |
| Temperature | 0.1 |
| Cost tier | CHEAP |

## When to Use

- "How do I use [library]?" — API docs, usage patterns
- "What's the best practice for [framework feature]?"
- "Why does [external dependency] behave this way?"
- "Show me the source code of [library function]"
- "Find examples of [library] usage in production code"
- Working with unfamiliar npm/pip/cargo packages
- Need official documentation, not Stack Overflow answers

## When NOT to Use

- Searching your own codebase (use `explore`)
- Questions about your project's internal code
- Simple API lookups you already know the answer to

## Request Classification

Librarian classifies every request before acting. You can help by prefixing with a type hint:

| Type | Trigger | Strategy |
|---|---|---|
| **TYPE A: Conceptual** | "How do I use X?", "Best practice for Y?" | Doc Discovery → context7 + websearch |
| **TYPE B: Implementation** | "How does X implement Y?", "Show me source of Z" | gh clone + read source + blame |
| **TYPE C: Context** | "Why was this changed?", "History of X?" | gh issues/PRs + git log/blame |
| **TYPE D: Comprehensive** | Complex/ambiguous, "deep dive into..." | Doc Discovery → ALL tools |

## Prompt Template

```
[TYPE X]: (optional hint — A, B, C, or D)
[CONTEXT]: What I'm implementing and why I need external guidance
[GOAL]: What decision this research will unblock
[DOWNSTREAM]: How I'll apply the findings
[REQUEST]: What to find (official docs, OSS examples, best practices). Skip tutorials — production patterns only.
[OUTPUT FORMAT]: Return ONLY the final synthesis as structured markdown with headings. Do NOT include raw tool output, directory listings, file contents, gh search results, or intermediate findings. Cite sources with GitHub permalinks.
```

**IMPORTANT:** Always include `[OUTPUT FORMAT]` — the librarian has no built-in output structure and will dump raw tool results without it.

## Example Prompts

### API Documentation (Type A)
```bash
~/.claude/skills/x-omo/omo-agent librarian "[TYPE A]: [CONTEXT]: I'm implementing real-time notifications using Server-Sent Events in our Express API. [GOAL]: Understand the correct SSE implementation pattern with proper connection handling. [DOWNSTREAM]: I'll implement the SSE endpoint in src/api/notifications.ts. [REQUEST]: Find official MDN/Express docs on SSE, proper headers, connection lifecycle, and error recovery. Focus on production patterns, not hello-world examples. [OUTPUT FORMAT]: Structured markdown with ## headings, code examples, and MDN/Express doc links."
```

### Source Code Investigation (Type B)
```bash
~/.claude/skills/x-omo/omo-agent librarian "[TYPE B]: [CONTEXT]: I'm debugging why zustand's persist middleware loses state on page refresh in our Next.js app. [GOAL]: Understand how zustand persist actually serializes/deserializes and when hydration happens. [DOWNSTREAM]: I'll fix our persist config based on the actual implementation. [REQUEST]: Clone zustand repo, find the persist middleware source, trace the hydration flow. Show me the exact code with GitHub permalinks. [OUTPUT FORMAT]: Markdown with ## headings, code snippets from source with permalinks."
```

### Comprehensive Research (Type D)
```bash
~/.claude/skills/x-omo/omo-agent librarian "[TYPE D]: [CONTEXT]: I need to understand what obra/superpowers is — purpose, architecture, features. [GOAL]: Decide whether to adopt it alongside other Claude Code plugins. [DOWNSTREAM]: Inform integration strategy. [REQUEST]: Find: README, feature list, architecture, plugin mechanism, recent releases. Focus on the GitHub repo. Skip shallow mentions. [OUTPUT FORMAT]: Structured markdown report with ## headings, tables for features, and evidence permalinks. No raw tool output."
```

## Output Format

When `[OUTPUT FORMAT]` is included, librarian returns structured markdown with:
- Section headings (##)
- Code examples with language identifiers
- GitHub permalink citations for every claim
- Tables for comparisons

The omo-agent wrapper extracts content from `<result>` tags automatically.

## Internal Behavior

### Documentation Discovery (Types A & D)
1. Find official documentation URL via websearch
2. Version check if specific version mentioned
3. Sitemap discovery to understand doc structure
4. Targeted page fetches based on sitemap

### Source Analysis (Type B)
1. Clone repo to temp directory (shallow, depth 1)
2. Get commit SHA for permalinks
3. Find implementation via grep/ast_grep
4. Construct GitHub permalinks: `https://github.com/owner/repo/blob/<sha>/path#L10-L20`

### Context/History (Type C)
1. Search issues and PRs via gh CLI
2. Clone repo and run git log/blame
3. Check releases for changelog context

### Tools Available
- **context7**: Official library docs (resolve ID → query docs)
- **websearch/webfetch**: Find and read doc pages
- **gh CLI**: Clone repos, search code/issues/PRs, view releases
- **grep/ast_grep**: Search cloned source code
- **git**: log, blame, show for history
