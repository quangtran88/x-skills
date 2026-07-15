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
| **Plan Gate (high-risk)** | plan/spec → `/x-mindful` (extract + walkthrough) → revised plan → `/x-do` (Mode A) → `/x-review` → merge |
| **Backlog Lifecycle** | brainstorm / `/x-research` → `/x-backlog` (doc; commit via its close-menu `[C]`, not automatic) → `/x-worktree <doc>` (branch `<type>/<slug>`, doc migrated + committed, cwd switched) → `/x-do <doc>` (Mode A) → doc archived `docs/backlog/` → `docs/<type-folder>/` → `/x-review` → merge |

## Backlog Lifecycle — handoff points

Each skill in the chain ends by offering the next link; no step assumes the user remembers
the chain. The doc is the baton — every handoff passes its path.

1. `/x-research` close → offers `[B]` capture as backlog doc.
2. `/x-backlog` close → offers `[C]` commit · `[W]` `/x-worktree <doc>` · `[P]` plan first (`superpowers:writing-plans`) · `[D]` `/x-do <doc>` here · `[N]` stop.
3. `/x-worktree` success envelope (doc runs) → suggests `/x-do <doc>` in the new worktree.
4. `/x-do` Mode A on a `docs/backlog/` doc → flips `status: in-progress` at start, archives the
   doc on completion (move + `status: done` + index-row removal + `docs:` commit) per
   `../x-do/SKILL.md` § "Backlog Doc Lifecycle (Mode A)".

Archival folder mapping lives in `../x-backlog/references/template.md` § "Archival on done".

## When to Chain vs. Skip

- **Trivial change** (rename, config edit) → just `/x-do` Mode D, skip research and review
- **High-risk plan** (touches breaking changes, schema migrations, auth, public APIs, cost cliffs) → run `/x-mindful` before `/x-do` Mode A so the user gates each impact item
- **Clear bug with stack trace** → skip research, go straight to `/x-bugfix` Mode A
- **Ambiguous bug, multi-component** → `/x-bugfix` Mode B (or `/x-research` first if codebase is unfamiliar)
- **Exploratory question** → `/x-research` only, no need to chain forward
- **Full feature** → full chain: research → do → review → merge

## Handoff

When chaining skills, include a handoff context block to help the next skill start faster. See `context-envelope.md`.
