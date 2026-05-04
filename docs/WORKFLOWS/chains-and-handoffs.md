# Workflow Chains & Handoffs

Common sequences across x-skills and how to chain them together.

---

## Common Sequences

| Workflow | Sequence |
|----------|----------|
| **Bug Fix** | `/x-bugfix` (Mode A/B/C) → `/x-review` → merge |
| **Deep Bug Investigation** | `/x-research` (Type A) → `/x-bugfix` (Mode B) → `/x-review` → merge |
| **New Feature** | `/x-research` (Type F) → `/x-do` (Mode B) → `/x-review` → merge |
| **Skill Audit** | `/x-skill-review` → `/x-do` (Mode A) → `/x-skill-review` (re-audit) |
| **Skill Improve** | Use x-skill → paste session → `/x-skill-improve` → apply fixes → `/x-skill-review` |
| **Quick Fix** | `/x-do` (Mode D) → `/x-review` (Target C: last commit) |
| **Architecture Decision** | `/x-research` (Type C) → `/x-do` (Mode B) |

---

## When to Chain vs. Skip

- **Trivial change** (rename, config edit) → just `/x-do` Mode D, skip research and review
- **Clear bug with stack trace** → skip research, go straight to `/x-bugfix` Mode A
- **Ambiguous bug, multi-component** → `/x-bugfix` Mode B (or `/x-research` first if codebase is unfamiliar)
- **Exploratory question** → `/x-research` only, no need to chain forward
- **Full feature** → full chain: research → do → review → merge

---

## Handoff Context Format

When chaining skills, include a context envelope block:

```markdown
## Handoff Context
- **From:** [skill name] | **Type/Mode:** [classification used]
- **Key finding:** [one-liner summary of what was learned/decided]
- **Agents used:** [list of agents that contributed]
- **Recommendation:** [next skill + mode/type to use]
- **Artifacts:** [file paths of any documents produced]
```

---

## Orchestration Primitives in Chains

| Primitive | Use in Chains |
|-----------|---------------|
| `handoff` | Sequential steps where next skill needs previous skill's output (e.g., research → do) |
| `assign` | Parallel review passes (e.g., x-review launching 3 reviewers simultaneously) |
