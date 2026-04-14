# Search Patterns

Per-skill query patterns for session discovery. Run all variants for a skill in parallel.

## Discovery Queries

| Skill | Search Queries |
|-------|---------------|
| x-do | `"/x-do"`, `"Mode A"` or `"Mode B"` etc., `"x-do skill"` |
| x-research | `"/x-research"`, `"Type A"` or `"Type B"` etc., `"x-research skill"` |
| x-review | `"/x-review"`, `"x-review skill"`, `"Target A"` etc. |
| x-skill-review | `"/x-skill-review"`, `"x-skill-review skill"` |
| x-bugfix | `"/x-bugfix"`, `"x-bugfix skill"`, `"Mode B"` etc. |
| x-skill-improve | `"/x-skill-improve"`, `"x-skill-improve skill"`, `"skill alignment"`, `"UPDATE SKILL"` |

## Auto-Detection Queries

When no skill name is provided, run discovery queries for ALL supported skills in parallel. The skill that returns matches is the one to analyze.

## Discovery Parameters

From config.json — use these for discovery searches:
- `contextChars: 500`
- `limit: 10`

For deep extraction within a selected session:
- `contextChars: 1000`
- `limit: 20`
