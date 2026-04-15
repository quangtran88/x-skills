# Prompt Templates

Adapt these templates to the specific question. They provide structure — don't copy them verbatim if a simpler prompt would work.

## Type A: Comparison Research

When comparing external patterns against internal code (direct reads, no agent):

```
For each pattern found in {{external source}}:
1. What they do — describe the pattern concisely
2. Our gap — how our {{internal target}} differs or lacks this
3. Optimization — specific change to adopt the pattern
Also identify patterns NOT worth adopting, with reasons.
```

## Type A: Codebase Question

```
[CONTEXT]: Working on {{user's broader task}}.
[GOAL]: {{what decision this unblocks}}.
[DOWNSTREAM]: {{how results will be used}}.
[REQUEST]: {{specific search instructions}}.
Focus on src/ — skip tests unless requested.
```

## Type B: External Docs / Library / API

```
[TYPE B]:
[CONTEXT]: {{what user is building}}.
[GOAL]: {{what decision this unblocks}}.
[DOWNSTREAM]: {{how findings will be applied}}.
[REQUEST]: {{what to find}}.
Skip tutorials — production patterns only.
[OUTPUT FORMAT]: Structured markdown with ## headings. No raw tool output. Cite sources.
```

## Type C: Architecture / Strategy

```
[FULL CONTEXT]: {{system description + current state}}.
[SPECIFIC QUESTION]: {{the precise question}}.
[CONSTRAINTS]: {{budget, stack, timeline limitations}}.
```

## Type D: Codebase + External (parallel)

Use Type A template for `explore`, Type B template for `librarian`. Fire both with `run_in_background: true`.

## Type E: OSS Repo Internals

**Primary (OMC Explore agent w/ deepwiki MCP):**

Dispatch via Agent tool (`subagent_type: "Explore"`, `run_in_background: true`):
```
Investigate how {{owner/repo}} implements {{feature}}.

Use the deepwiki MCP tool — first call ToolSearch to fetch "mcp__deepwiki__ask_question", then invoke it with:
- repoName: "{{owner/repo}}"
- question: "{{specific question about internals}}"

After getting deepwiki results, summarize:
1. Architecture/approach used
2. Key files and components involved
3. Design decisions and trade-offs
4. How this could inform our implementation

If deepwiki returns an error (repo not indexed), report that clearly so we can fall back to librarian.
```

**Fallback (OMO librarian, when deepwiki unavailable):**
```
[TYPE B]:
[CONTEXT]: {{what user is building}}.
[GOAL]: Understand how {{repo}} implements {{feature}} internally.
[DOWNSTREAM]: {{how findings inform our implementation}}.
[REQUEST]: Clone the repo, find the implementation source code, trace the architecture. Provide GitHub permalinks.
[OUTPUT FORMAT]: Structured markdown with code snippets and GitHub permalinks.
```

## Type F: Pre-Planning Analysis

For `oracle` (pre-planning consult — replaces UNAVAILABLE `metis`):
```
Analyze this request before planning: {{user's request}}.
Current codebase context: {{relevant files, stack, constraints}}.
What hidden requirements, scope risks, and AI-slop patterns should we address?
```

For `explore` (parallel):
```
[CONTEXT]: Pre-planning for {{feature}}.
[GOAL]: Find existing patterns.
[REQUEST]: Related code, conventions, prior implementations.
```

## Type G: Visual / Document

```
{{specific extraction/analysis prompt}}
```
Always use `--file /path/to/file` flag with `multimodal-looker`.
