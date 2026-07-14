# Backlog Doc Template

Canonical skeleton rendered into `docs/backlog/<slug>.md`. **CORE** sections are always
present. **MODULE** sections are included only when the feature actually has them (decided
by self-triage during the draft-first walk). Omit a module entirely rather than writing "N/A".

Fill every section with real content harvested from the conversation. Never ship a
`<placeholder>` — if a fact is genuinely unknown, capture it as a bullet under
**Handoff Notes / Open Questions** instead.

---

```markdown
---
title: <Feature name>
slug: <kebab-slug>
type: feat               # feat | fix | chore | refactor | … — drives x-worktree branch naming (<type>/<slug>) and the archival folder on done
status: backlog          # backlog | ready | in-progress | done — set ready only when Acceptance is grounded in real conversation material
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
related: []              # links to research docs, PRs, plans, tickets
---

# <Feature name>

## Context & Problem
<!-- CORE. Why this exists: the pain, the current state, who's affected, why now.
     2-5 short paragraphs. Enough that a reader returning in 3 months knows the "why". -->

## Solution Overview
<!-- CORE. The chosen approach at altitude — what we're building and how it hangs together.
     A "in a nutshell" paragraph, then a few more on the shape of the solution.
     NOT step-by-step implementation (that's writing-plans / x-do). -->

## Key Decisions
<!-- CORE. One block per significant decision. Add as many blocks as there are decisions. -->

### Decision: <short name>
- **Choice:** <what was decided>
- **Why:** <the driver / rationale>
- **Alternatives:** <options considered> — rejected because <reason>
- **Consequences:** <tradeoffs, what this makes easier/harder later>

## Scope & Non-Goals
<!-- CORE. Fence the work. -->

**In scope**
- <bullet>

**Non-goals** (explicitly out, so nobody assumes otherwise)
- <bullet>

## Acceptance / Ready-check
<!-- CORE. Testable "done" criteria. This is the ready-for-implementation gate. -->
- [ ] <criterion phrased so it can be checked true/false>
- [ ] <criterion>

<!-- ================= MODULES (include only the relevant ones) ================= -->

## Feature Breakdown
<!-- MODULE. Only if the feature decomposes into multiple sub-capabilities. -->
| Feature | What it does | Priority |
|---|---|---|
| <name> | <one-liner> | must / should / could |

## Integrations
<!-- MODULE. Only if it touches external services or other internal modules. -->
| System | Direction | What flows | Notes |
|---|---|---|---|
| <name> | in / out / both | <data or calls> | <auth, rate limits, etc.> |

## Contracts
<!-- MODULE. Only if there are API/data shapes worth pinning before build. -->
- **Endpoint / event:** `<METHOD /path or event name>`
  - Request: <shape>
  - Response: <shape>
- **Data model:** `<Entity>` — <fields / relationships>

## Use Cases / Flows
<!-- MODULE. Only if concrete scenarios clarify behavior. -->
### <Use case name>
As a <role>, I want <goal> so that <benefit>.
1. <step>
2. <step>

## Handoff Notes / Open Questions
<!-- MODULE. Default: include — mandatory if any open question or risk surfaced during the walk. -->
- **Open question:** <unresolved decision needing an answer before/during build>
- **Risk:** <what could go wrong> — <mitigation or "accepted">
- **Deferred:** <thing intentionally left for later>
- **Gotcha:** <non-obvious constraint the implementer will hit>
```

---

## Index file: `docs/backlog/README.md`

Auto-maintained table so the whole backlog is scannable at a glance. Create it on first run;
append/update the row on every write.

```markdown
# Backlog

Durable, human-facing spec docs. Each is a ready-to-implement reference — the "why + what",
not the low-level "how" (that's the implementation plan).

| Doc | Status | Updated | Summary |
|---|---|---|---|
| [<title>](<slug>.md) | <status> | <YYYY-MM-DD> | <one-line> |
```

## Status lifecycle

`backlog` → `ready` → `in-progress` → `done`

- **backlog** — idea captured, not yet fleshed out enough to build (conversation too thin).
- **ready** — CORE complete + acceptance criteria **grounded in real conversation material** (not invented from thin context); safe to hand to writing-plans / x-do. A completed walk that had to invent Acceptance stays `backlog`.
- **in-progress** — implementation started (set by hand or by the downstream skill — x-do Mode A flips this when it picks the doc up).
- **done** — shipped; archived out of `docs/backlog/` per "Archival on done" below. Kept as a reference record.

## Archival on done

When implementation completes (x-do Mode A finishes on this doc), the doc leaves the
backlog: `git mv` it out of `docs/backlog/` into the folder matching its `type`, flip
frontmatter to `status: done` + fresh `updated`, and delete its row from
`docs/backlog/README.md` — the backlog index lists only unshipped work.

| `type` | Destination |
|---|---|
| `feat` | `docs/feature/` |
| `fix` | `docs/bugs/` |
| anything else (`chore`, `refactor`, `perf`, …) | `docs/<type>/` |

Create the destination folder if absent. Commit the move as
`docs: archive <slug> — done, moved to <destination>`. When `type` is missing from
frontmatter (docs predating this field), derive it via the detection order in
`../../x-worktree/references/doc-naming.md` (H1 prefix → filename prefix → fallback `feat`).
