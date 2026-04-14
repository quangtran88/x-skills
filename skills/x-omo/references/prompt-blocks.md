# Prompt Blocks for OMO Agents

Composable XML-tagged blocks for structuring prompts to OMO agents (oracle, hephaestus, etc.) and `--model` routing. Select blocks based on the task type. Wrap each in the XML tag shown in its heading.

## When to Use

You do NOT need these for simple, well-scoped questions. Use them when:
- The task is multi-step or ambiguous
- You need structured output (review findings, plans, recommendations)
- Past prompts to the same agent produced vague or incomplete results
- You're chaining output to another skill (x-do consuming oracle advice)

## Core — Use in Nearly Every Prompt

### `<task>`

```xml
<task>
[Concrete job description. Include: what system/code is involved, what's broken or needed, and the expected end state.]
</task>
```

## Output Shape

### `<structured_output_contract>`

Use when the response shape matters (reviews, plans, diagnostics).

```xml
<structured_output_contract>
Return exactly:
1. [first section]
2. [second section]
3. [third section]
Keep compact. Highest-value findings first.
</structured_output_contract>
```

### `<compact_output_contract>`

Use when you want concise prose, not a schema.

```xml
<compact_output_contract>
Keep the final answer compact and structured. No scene-setting or recap.
</compact_output_contract>
```

## Follow-Through

### `<default_follow_through_policy>`

Use when the agent should act without asking routine questions.

```xml
<default_follow_through_policy>
Default to the most reasonable low-risk interpretation and keep going.
Only stop to ask when a missing detail changes correctness, safety, or an irreversible action.
</default_follow_through_policy>
```

### `<completeness_contract>`

Use for debugging, implementation, or multi-step tasks that should not stop early.

```xml
<completeness_contract>
Resolve the task fully before stopping.
Do not stop at the first plausible answer.
Check for follow-on fixes, edge cases, or cleanup needed for a correct result.
</completeness_contract>
```

### `<verification_loop>`

Use when correctness matters.

```xml
<verification_loop>
Before finalizing, verify the result against the task requirements and changed files or tool outputs.
If a check fails, revise instead of reporting the first draft.
</verification_loop>
```

## Grounding

### `<missing_context_gating>`

Use when the agent might otherwise guess.

```xml
<missing_context_gating>
Do not guess missing repository facts.
If required context is absent, retrieve it with tools or state exactly what remains unknown.
</missing_context_gating>
```

### `<grounding_rules>`

Use for review, research, or root-cause analysis.

```xml
<grounding_rules>
Ground every claim in the provided context or tool outputs.
Do not present inferences as facts. Label hypotheses clearly.
</grounding_rules>
```

### `<citation_rules>`

Use for external research.

```xml
<citation_rules>
Back important claims with citations or explicit references to inspected sources.
Prefer primary sources.
</citation_rules>
```

## Safety and Scope

### `<action_safety>`

Use for write-capable tasks (hephaestus, atlas).

```xml
<action_safety>
Keep changes tightly scoped to the stated task.
Avoid unrelated refactors, renames, or cleanup unless required for correctness.
Call out risky or irreversible actions before taking them.
</action_safety>
```

### `<tool_persistence_rules>`

Use for long-running, tool-heavy tasks.

```xml
<tool_persistence_rules>
Keep using tools until you have enough evidence to finish the task confidently.
Do not abandon the workflow after a partial read when another targeted check would change the answer.
</tool_persistence_rules>
```

## Task-Specific

### `<dig_deeper_nudge>`

Use for review and adversarial inspection.

```xml
<dig_deeper_nudge>
After the first plausible issue, check for second-order failures, empty-state behavior, retries, stale state, and rollback paths before finalizing.
</dig_deeper_nudge>
```

### `<research_mode>`

Use for exploration, comparisons, recommendations.

```xml
<research_mode>
Separate observed facts, reasoned inferences, and open questions.
Prefer breadth first, then depth only where evidence changes the recommendation.
</research_mode>
```

---

## Task-Type Selection Guide

| Task Type | Required Blocks | Optional Blocks |
|---|---|---|
| **Debugging / diagnosis** | `task`, `completeness_contract`, `verification_loop`, `missing_context_gating` | `compact_output_contract` |
| **Code review / adversarial** | `task`, `grounding_rules`, `structured_output_contract`, `dig_deeper_nudge` | `verification_loop` |
| **Research / recommendation** | `task`, `research_mode`, `citation_rules` | `structured_output_contract` |
| **Implementation (write)** | `task`, `action_safety`, `default_follow_through_policy`, `completeness_contract` | `verification_loop` |
| **Architecture advice** | `task`, `grounding_rules` | `compact_output_contract` |
| **Plan review** | `task`, `grounding_rules`, `structured_output_contract` | `dig_deeper_nudge` |

## Anti-Patterns

Avoid these when composing prompts:

| Anti-Pattern | Fix |
|---|---|
| "Take a look and let me know" | Use `<task>` with concrete scope and end state |
| "Investigate and report back" | Add `<structured_output_contract>` with exact sections |
| "Debug this failure" (no follow-through) | Add `<default_follow_through_policy>` |
| "Think harder" / raise reasoning | Tighten `<verification_loop>` or `<completeness_contract>` instead |
| Mixing unrelated jobs in one run | One `<task>` per agent invocation |
