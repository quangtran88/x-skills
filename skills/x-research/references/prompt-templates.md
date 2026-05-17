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

**Canonical fan-out (Standard Mode):** `OMO oracle ∥ morph codebase_search ∥ OMO explore` — three lanes, all `run_in_background: true`. Max Mode adds `perplexity_research` + `gemini-agent` for external context.

For `oracle` (pre-planning consult — replaces UNAVAILABLE `metis`):
```
Analyze this request before planning: {{user's request}}.
Current codebase context: {{relevant files, stack, constraints}}.
What hidden requirements, scope risks, and AI-slop patterns should we address?
```

For `morph codebase_search` (semantic local-code lane):
```
Find {{feature concept}} in the codebase. Return file:line refs with brief
descriptions. Focus on entry points, shared interfaces, and any existing
implementations that overlap with the requested scope.
```

For `OMO explore` (pattern/path lane — grep/glob/ast_grep):
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

## Type H: Local Structural (GitNexus, advisory)

Only when `mcp.gitnexus` is pinned AND the target repo is in the shared probe's indexed-path set (Bootstrap step 0a / `../../x-shared/capability-loading.md`). Not pinned OR not indexed → use the Type A codebase template against `morph-mcp codebase_search` instead (zero behavior change).

**"How does our X work" (process-grouped) — `gitnexus query`:**
```
mcp__gitnexus__query({ query: "{{structural concept / how does our X work}}" })
```
Returns process-grouped, RRF-ranked results. Synthesize the process groups; do NOT surface raw graph dumps.

**Symbol 360° (callers + callees + flows) — `gitnexus context`:**
```
mcp__gitnexus__context({ name: "{{symbolName}}" })
```
Returns callers, callees, and the execution flows the symbol participates in. Use for "what calls X / what does X call / which flows touch X".

**Staleness note (mandatory when the indexed repo is stale — C3 advisory class).** If the shared probe reports `staleness.commitsBehind > 0` for the target repo, `query`/`context` are advisory-class so they still run, but append this exact line to the synthesis:

```
(index N commits stale — results may lag HEAD)
```

Substitute `N` with the probe's `staleness.commitsBehind` for that repo. This note IS the instrumentation — it must appear verbatim in the synthesis whenever a stale indexed repo was queried.
