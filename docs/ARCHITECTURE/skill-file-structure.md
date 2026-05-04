# Skill File Structure

Standard layout and conventions for all x-skills.

---

## Standard Skill Directory Layout

```
skills/<name>/
├── SKILL.md              # Entry point — frontmatter + workflow instructions (MANDATORY)
├── config.json           # Skill configuration (paths, flags, defaults)
├── gotchas.md            # Known failure patterns — update when new ones encountered
├── steps/                # Sequential step files (for step-file architecture skills)
│   ├── step-01-xxx.md
│   ├── step-02-xxx.md
│   └── ...
├── references/           # Reference documentation loaded on-demand
│   ├── mode-b-deep.md
│   ├── backward-tracing.md
│   └── ...
└── data/                 # Optional runtime data (e.g., alignment-log.jsonl)
```

---

## Frontmatter Schema

```yaml
---
name: x-example                      # Skill name
description: "One-line description"  # What it does
role: router                         # (04) router | reviewer | verifier
slots:                               # (05) pluggable slots
  workspace: current-dir
  verifier: x-verify
reactions:                           # (02) declarative event handlers
  implementation-complete:
    action: menu
    options: [commit, review, done]
    auto: false
triggers:                            # (optional) Fuzzy trigger phrases
  - "keyword"
matching: fuzzy                      # Trigger matching mode
---
```

---

## Skill Discovery Rules

- Claude Code skill loader registers a directory as a skill **only when it contains a `SKILL.md`**
- `x-shared/` intentionally omits `SKILL.md` to stay invisible to skill discovery
- Skills reference sibling skills via relative paths: `../x-shared/<file>.md`, `../x-omo/SKILL.md`

---

## Intra-Frontmatter Precedence

When `role`, `slots`, and `reactions` overlap:

| Block | Answers | Scope |
|-------|---------|-------|
| `role` | "What kind of skill is this? What is it forbidden from doing?" | Architectural contract — cannot be overridden by slots or reactions |
| `slots` | "Which concrete implementation fills this role's dependency?" | Config — picks between candidate implementations |
| `reactions` | "What happens when event X occurs?" | Event handling — names trigger and action |

**Canonical rule:** `role` > `slots` > `reactions`
