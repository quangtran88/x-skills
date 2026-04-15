# Explore — Codebase Search Specialist

## Identity

A contextual grep agent for codebases. Answers "Where is X?", "Which file has Y?", "Find the code that does Z". Fires 3+ search tools in parallel on first action for maximum coverage.

## Quick Reference

| Field | Value |
|---|---|
| Short name | `explore` |
| OpenCode display name | `explore` |
| Default model | `openai/gemini-3-flash-preview` |
| Mode | Read-only (no write/edit/apply_patch/task/call_omo_agent) |
| Temperature | 0.1 |
| Cost tier | FREE |

## When to Use

- Multiple search angles needed across the codebase
- Unfamiliar module structure — need to map out where things live
- Cross-layer pattern discovery (how frontend connects to backend, etc.)
- 2+ modules involved in the task
- Need to understand existing conventions before implementing

## When NOT to Use

- You know exactly what to search for (use Grep/Glob directly)
- Single keyword/pattern suffices
- Known file location — just Read it
- External docs/libraries needed (use `librarian` instead)

## Prompt Template

```
[CONTEXT]: What task I'm working on, which files/modules involved, what approach I'm taking
[GOAL]: Specific outcome needed — what decision or action the results will unblock
[DOWNSTREAM]: How I will use the results — what I'll build/decide based on what's found
[REQUEST]: Concrete search instructions — what to find, what format to return, what to SKIP
```

**Key principle:** Give explore broad, multi-faceted search goals — not narrow single-keyword queries. It's designed to flood with parallel searches and cross-validate findings.

## Example Prompts

### Pattern Discovery
```bash
~/.claude/skills/x-omo/omo-agent explore "I'm implementing JWT auth for the REST API in src/api/routes/. I need to match existing auth conventions so my code fits seamlessly. I'll use this to decide middleware structure and token flow. Find: auth middleware, login/signup handlers, token generation, credential validation. Focus on src/ — skip tests. Return file paths with pattern descriptions."
```

### Cross-Layer Search
```bash
~/.claude/skills/x-omo/omo-agent explore "I'm debugging a data inconsistency between the dashboard UI and the API response. The dashboard shows stale user counts. I need to trace the data flow from API → cache → frontend store. Find: the API endpoint that returns user counts, any caching layer in between, the frontend store/hook that consumes it, and any transform/mapping logic. Focus on src/ — return the full chain with file paths and line numbers."
```

### Convention Mapping
```bash
~/.claude/skills/x-omo/omo-agent explore "I'm about to add a new database migration for a 'teams' table. I need to follow the existing migration patterns exactly. Find: existing migration files, the migration runner/config, naming conventions, any seed data patterns, and how migrations are tested. Return file paths with explanations of the pattern to follow."
```

## Output Format

Explore returns structured XML:

```xml
<results>
<files>
- /absolute/path/to/file1.ts — [why this file is relevant]
- /absolute/path/to/file2.ts — [why this file is relevant]
</files>

<answer>
[Direct answer to the actual need, not just a file list]
[Explains the patterns, flows, or conventions found]
</answer>

<next_steps>
[What to do with this information]
</next_steps>
</results>
```

The omo-agent wrapper automatically extracts `<files>` and `<answer>` tags.

## Internal Behavior

1. **Intent analysis** — before any search, analyzes literal request vs actual need
2. **Parallel execution** — launches 3+ tools simultaneously on first action
3. **Tool strategy**:
   - Semantic search (definitions, references) → LSP tools
   - Structural patterns (function shapes, class structures) → ast_grep_search
   - Text patterns (strings, comments, logs) → grep
   - File patterns (find by name/extension) → glob
   - History/evolution (when added, who changed) → git commands
4. **Cross-validation** — verifies findings across multiple tools

## Success Criteria

- ALL paths are **absolute** (start with /)
- Find ALL relevant matches, not just the first one
- Caller can proceed **without asking follow-up questions**
- Addresses the **actual need**, not just the literal request
