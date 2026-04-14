# Workflow Chains

Common sequences across x-skills. Not every task needs a full chain — use judgment.

| Workflow | Sequence |
|----------|----------|
| **Bug Fix** | `/x-bugfix` (Mode A/B/C) → `/x-review` → merge |
| **Deep Bug Investigation** | `/x-research` (Type A: codebase) → `/x-bugfix` (Mode B: deep investigation) → `/x-review` → merge |
| **New Feature** | `/x-research` (Type F: pre-planning) → `/x-do` (Mode B: new feature) → `/x-review` → merge |
| **Skill Audit** | `/x-skill-review` → `/x-do` (Mode A: implement fixes) → `/x-skill-review` (re-audit) |
| **Skill Improve** | Use x-skill → paste session into `/x-skill-improve` → apply fixes → `/x-skill-review` (validate) |
| **Quick Fix** | `/x-do` (Mode D: quick task) → `/x-review` (Target C: last commit) |
| **Architecture Decision** | `/x-research` (Type C: architecture) → `/x-do` (Mode B: implement decision) |

## When to Chain vs. Skip

- **Trivial change** (rename, config edit) → just `/x-do` Mode D, skip research and review
- **Clear bug with stack trace** → skip research, go straight to `/x-bugfix` Mode A
- **Ambiguous bug, multi-component** → `/x-bugfix` Mode B (or `/x-research` first if codebase is unfamiliar)
- **Exploratory question** → `/x-research` only, no need to chain forward
- **Full feature** → full chain: research → do → review → merge

## Handoff

When chaining skills, include a handoff context block to help the next skill start faster. See `context-envelope.md`.
