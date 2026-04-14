---
name: x-skill-review
description: Use when creating, editing, or auditing a Claude Code skill — reviews against Anthropic's published best practices and outputs actionable findings with severity ratings
---

# x-skill-review — Skill Best Practice Reviewer

Reviews a Claude Code skill against Anthropic's official best practices and outputs a structured audit with actionable findings.

## Invocation

For how to invoke skills and agents, see `../x-shared/invocation-guide.md`.

**Example:** `/x-skill-review ~/.claude/skills/my-skill`

## Detection

Trigger when the user asks to:
- Review, audit, or check a skill
- Validate a skill before publishing/sharing
- Improve an existing skill
- Check if a skill follows best practices

## Workflow

1. **Locate the skill.** If the user provides a path, use it. Otherwise, ask which skill to review.
2. **Read the full skill folder** — not just `SKILL.md`. Use `ls -la` on the skill directory to discover all files, then read each one. If chained from x-skill-improve in the same session, files recently read/edited in context don't need re-reading — still run `ls -la` to discover any new or deleted files.
3. **Mechanical pre-checks.** Run deterministic validations using native tools (Bash, Read, Grep) — no LLM judgment needed. See `references/checklist.md` items marked `[M]`. Key checks:
   - YAML frontmatter exists with `name` and `description` fields
   - `name` ≤ 64 chars, `description` ≤ 1024 chars
   - SKILL.md line count (flag if > 500, note if > 120)
   - Referenced files actually exist (grep for file paths like `references/`, `../x-shared/`, `gotchas.md`, then verify each resolves)
   - No hardcoded secrets (grep for `sk-`, `api_key`, `token`, `secret`, `password` patterns)
4. **Score subjective items** from `references/checklist.md` items marked `[J]` — these require LLM analysis. Each gets a verdict: PASS, FAIL, or N/A.
5. **Classify the skill type** using `references/skill-types.md`. If it straddles multiple types, flag as MEDIUM with a recommendation to split or clarify primary type.
6. **Present findings** using the severity guide below. Merge mechanical + subjective results into one table.
7. **Offer to fix** — routing depends on context:
   - **Local skills** (`~/.claude/skills/`, `.claude/skills/`): `Issues found. Fix them now? [A] All [P] Pick which [N] Done`
   - **External plugin skills** (`~/.claude/plugins/`): Present findings as **advisory only**. Do not modify plugin cache files — recommend the user update the upstream plugin instead.
   - **Inline fixes** (frontmatter, description, gotcha entries, wording): apply directly in this step. **Use `morph-mcp edit_file` as the default edit tool** — partial edits with `// ... existing code ...` markers preserve context. Fall back to native `Edit` only if `edit_file` errors.
   - **Structural fixes** (splitting files, creating references/, reorganizing content): chain to `/x-do` — too complex for inline edits.

## Severity Guide

All findings use the [shared severity scale](../x-shared/severity-guide.md). Quick reference:

| Severity | Meaning |
|----------|---------|
| **CRITICAL** | Skill will malfunction or confuse the model |
| **HIGH** | Significant gap vs. best practices |
| **MEDIUM** | Missing recommended element |
| **LOW** | Polish and optimization |

## Output Format

```
## Skill Review: {{skill name}}

**Type:** {{category from skill-types.md}}
**Files:** {{count}} ({{list}})
**SKILL.md size:** {{lines}} lines

### Checklist Scoring

| Check | Verdict | Notes |
|-------|---------|-------|
| Folder, not just a file | **PASS** | ... |
| Progressive disclosure | **PASS** | ... |
| ... | ... | ... |

### Findings

| # | Severity | Check | Finding |
|---|----------|-------|---------|
| 1 | HIGH | Folder structure | Single-file skill, no references/ or supporting files |
| 2 | MEDIUM | Gotchas | No gotchas section — add known failure patterns |
| ... | ... | ... | ... |

### Summary
- {{X}} CRITICAL, {{X}} HIGH, {{X}} MEDIUM, {{X}} LOW
- Top 3 improvements by impact: ...
```

## Dependencies

This skill references shared infrastructure in `../x-shared/`:
- `invocation-guide.md` — tool invocation patterns
- `severity-guide.md` — finding severity scale
- `workflow-chains.md` — cross-skill chaining
- `common-gotchas.md` — shared operational pitfalls

## After This Skill

Small fixes (wording, adding exceptions, gotchas) → apply inline via step 7. Complex multi-file fixes → `/x-do`, then re-audit with `/x-skill-review`. See `../x-shared/workflow-chains.md`.

## Gotchas

See `gotchas.md` for known review pitfalls — update when you encounter new ones.

Task: {{ARGUMENTS}}
