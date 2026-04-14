# Metis — Pre-Planning Consultant

## Identity

Named after the Greek goddess of wisdom, prudence, and deep counsel. Metis analyzes user requests BEFORE planning to prevent AI failures. It identifies hidden intentions, unstated requirements, ambiguities, and potential AI-slop patterns (over-engineering, scope creep).

## Quick Reference

| Field | Value |
|---|---|
| Short name | `metis` |
| OpenCode display name | `Metis (Plan Consultant)` |
| Default model | `openai/gpt-5.4` |
| Variant | `max` (extended reasoning) |
| Mode | Read-only (no write/edit/apply_patch/task) |
| Temperature | 0.3 (slightly creative for analysis) |
| Cost tier | EXPENSIVE |
| Thinking | Enabled (32k budget) |

## When to Use

- Before planning non-trivial tasks — analyze before you plan
- When user request is ambiguous or open-ended
- To prevent AI over-engineering patterns
- Complex requirements that need scope clarification
- When you suspect hidden requirements or unstated assumptions

## When NOT to Use

- Simple, well-defined tasks with clear requirements
- User has already provided detailed specifications
- Quick fixes or single-file changes

## Prompt Template

```
Analyze this request before planning:
[USER'S REQUEST]

Current codebase context: [relevant files, patterns, constraints]
```

## Example Prompts

### Ambiguous Feature Request
```bash
omo-agent metis "Analyze this request before planning: 'Add user notifications to the dashboard.' Current context: Express API + React frontend, no existing notification system, using PostgreSQL. What hidden requirements and scope risks should we address before planning?"
```

### Refactoring Scope
```bash
omo-agent metis "Analyze this request: 'Refactor the auth module to use JWT instead of sessions.' Context: 200+ endpoints depend on req.session, Redis session store, Express 4.x. What are the regression risks, migration concerns, and scope boundaries we need to define?"
```

## Intent Classification

Metis classifies every request into one of six types, which determines its entire analysis strategy:

| Type | Signal | Focus |
|---|---|---|
| **Refactoring** | "refactor", "restructure", "clean up" | Regression prevention, behavior preservation |
| **Build from Scratch** | "create new", "add feature", greenfield | Discover patterns first, then ask informed questions |
| **Mid-sized Task** | Scoped feature, bounded work | Exact deliverables, explicit exclusions |
| **Collaborative** | "help me plan", "let's figure out" | Incremental clarity through dialogue |
| **Architecture** | "how should we structure", system design | Long-term impact, Oracle recommendation |
| **Research** | Investigation needed, path unclear | Exit criteria, parallel probes |

## Output Format

```markdown
## Intent Classification
**Type**: [Refactoring | Build | Mid-sized | Collaborative | Architecture | Research]
**Confidence**: [High | Medium | Low]
**Rationale**: [Why this classification]

## Pre-Analysis Findings
[Results from explore/librarian if launched]
[Relevant codebase patterns discovered]

## Questions for User
1. [Most critical question first]
2. [Second priority]
3. [Third priority]

## Identified Risks
- [Risk 1]: [Mitigation]
- [Risk 2]: [Mitigation]

## Directives for Prometheus
### Core Directives
- MUST: [Required action]
- MUST NOT: [Forbidden action]
- PATTERN: Follow `[file:lines]`
- TOOL: Use `[specific tool]` for [purpose]

## Recommended Approach
[1-2 sentence summary of how to proceed]
```

## AI-Slop Patterns Metis Flags

Metis specifically watches for these over-engineering patterns:
- **Scope inflation**: Adding tests/features beyond the target
- **Premature abstraction**: Extracting to utility for single use
- **Over-validation**: 15 error checks for 3 inputs
- **Documentation bloat**: JSDoc everywhere unprompted

For each pattern, Metis generates a clarifying question rather than assuming.

## Relationship to Other Agents

- **Metis → Prometheus**: Metis outputs feed directly into Prometheus (planner) as directives
- **Metis → Explore/Librarian**: For "Build from Scratch" and "Research" intents, Metis fires explore/librarian agents first to gather context before asking questions
- **Metis → Oracle**: For "Architecture" intents, Metis recommends Oracle consultation
