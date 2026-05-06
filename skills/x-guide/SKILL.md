---
name: x-guide
description: Use when the user wants a complex input (file, function, directory, PRD, plan, spec, URL, pasted prose, or vague feature name) explained step by step in a comprehension-gated walkthrough — produces a persistent .x-guide/<slug>/GUIDE.md with full TOC and walks the user one part at a time, supports resume across sessions
role: progressive-tutor
---

# x-guide — Progressive Comprehension-Gated Tutor

x-guide turns complex inputs into linear, comprehension-gated tutorials. The user supplies a target; x-guide produces `.x-guide/<slug>/GUIDE.md` (full TOC upfront, parts generated lazily as the user advances), persists progress in `progress.json`, and walks the user one part at a time with a menu-driven command loop.

x-guide is **not** an explorer or graph viewer. It enforces linear comprehension: render one part, wait for command, advance only on signal. Compare to `Lum1104/Understand-Anything` (graph + dashboard) — x-guide stays markdown + chat.

## Bootstrap (MANDATORY)

Before any phase dispatch, load:

0. `../x-shared/capability-loading.md` — pin the active capability set for this session. Trust the bootstrap-pinned set; do not re-verify per dispatch.
1. `gotchas.md` — known failure patterns.

Lazy-load only when needed:
- `../x-gemini/SKILL.md` — when Phase 2 routes large input to gemini ingest.
- `../x-research/SKILL.md` — when Phase 2 routes a vague-target input to research.

## Anti-Triggers

If the request is closer to one of these, route there instead and stop:

| User intent | Route to |
|---|---|
| "Find me how X works across the codebase" (open investigation) | `x-research` |
| "Review this code / plan / PR" | `x-review` |
| "Debug / fix this bug" | `x-bugfix` |
| "Build / implement / execute this plan" | `x-do` |
| "Audit / improve a skill itself" | `x-skill-improve` |

## Phase Dispatch

x-guide runs five phases in order. Each phase has a step file under `steps/`. Read the step file for that phase before executing it.

| Phase | Step file | Purpose |
|---|---|---|
| 1 | `steps/step-01-detect.md` | Classify input, compute slug, handle resume |
| 2 | `steps/step-02-ingest.md` | Route to gemini / research / claude based on size + clarity |
| 3 | `steps/step-03-outline.md` | Write TOC + teasers to GUIDE.md, init progress.json |
| 4 | `steps/step-04-walk.md` | Render-menu-command loop until user exits or completes |
| 5 | `steps/step-05-wrap.md` | Mark complete, write summary, suggest next topics |

Phase 4 is the core loop. It iterates internally; phases 1–3 and 5 are linear.

## State Location

All state is per-project, in repo root:

```
.x-guide/<slug>/
├── GUIDE.md          # tutorial — TOC + parts
├── progress.json     # state (schema in references/progress-schema.md)
└── _ingest.md        # cached ingest output (when ingest_method != claude-direct)
```

Recommend `.gitignore` add `.x-guide/`. Suggest this on first use if not already gitignored.

## References

- `references/menu-commands.md` — Phase 4 command table
- `references/progress-schema.md` — progress.json schema + state machine
- `references/routing-matrix.md` — Phase 2 routing tree
- `references/part-template.md` — per-part render template

## Modes (v1)

Single mode. No `max` / `prism` flags. Adaptive depth happens per-part inside Phase 4 via `d` / `l` commands, not as a top-level mode.
