---
name: x-backlog
description: Use when the user wants to capture a brainstormed idea, feature, or solution into a durable backlog/spec doc under docs/backlog — a human-facing reference that combines context, chosen solution, key decisions (ADR-lite), scope, acceptance criteria, and optional feature/integration/contract/use-case/handoff modules. Runs an interview-first, section-by-section gated walk that seeds drafts from the current conversation, then persists docs/backlog/<slug>.md. NOT a low-level implementation plan (that is superpowers:writing-plans / x-do).
role: spec-crystallizer
---

# x-backlog — Durable Backlog / Spec Doc Builder

x-backlog turns a discussed idea into a durable, human-facing reference doc at
`docs/backlog/<slug>.md`. It sits **between** research/brainstorming and the low-level
implementation plan: it records the *why* and the *what* — context, chosen solution,
key decisions, scope, acceptance, and the relevant contracts/integrations/use-cases —
so you can return to it months later or hand it off cleanly.

x-backlog is **not** an implementation plan. It does not produce per-file, per-step,
"for an agent to execute" instructions. When the doc is ready, the next step is
`superpowers:writing-plans` or `/x-do`.

## Bootstrap (MANDATORY)

Before walking, load:

1. `references/template.md` — the canonical CORE + MODULES skeleton and the index format.
2. `gotchas.md` — known failure patterns.

No capability-loading / OMO / agy dispatch is needed. x-backlog is Claude-native: it
interviews and writes a markdown file. It never delegates to sub-agents.

## Anti-Triggers

If the request is closer to one of these, route there instead and stop:

| User intent | Route to |
|---|---|
| "Write the per-file/per-step plan to build this" | `superpowers:writing-plans` or `x-do` |
| "Just build it / implement this" | `x-do` |
| "Review this code / plan / PR / doc" | `x-review` |
| "Explain / walk me through this input" | `x-guide` |
| "Research / investigate how X works" | `x-research` |
| "Architect-review this AI-produced plan before I build" | `x-mindful` |
| "Still deciding what to build / haven't chosen a solution yet" | `superpowers:brainstorming` |

## The Doc

- **Location:** `docs/backlog/<slug>.md` (create `docs/backlog/` if absent).
- **Shape:** 5 CORE sections always; MODULE sections only when the feature has them.
- **Structure:** exactly as in `references/template.md`. Do not invent sections.
- **Dates:** use today's date (from the session's current-date context) for `created`/`updated`.

## Workflow — the gated walk

Run these six steps in order. Steps 3–4 are the interview; they are gated — advance only
on an explicit user signal per section.

### 1. Detect & slug
- Derive a kebab-case `<slug>` from the feature name (e.g. `user-billing-portal`).
- If `docs/backlog/<slug>.md` already exists, this is an **update**: read it, and in each
  step below show the *existing* content as the draft instead of harvesting fresh.
- Announce: `Backlog doc: docs/backlog/<slug>.md (new | update).`

### 2. Harvest from context
- Scan the current conversation for the material that fills the CORE sections and any
  modules: the problem, the chosen solution, decisions made and alternatives rejected,
  scope boundaries, features, integrations, contracts, use cases, open questions.
- Hold this as **draft answers**. Do not write the file yet.
- If the conversation is thin (cold start, no prior brainstorm), you will still walk every
  section — you just propose a starter draft and lean harder on the user's answers.

### 3. Walk the CORE (one section at a time)
For each CORE section in order — Context & Problem → Solution Overview → Key Decisions →
Scope & Non-Goals → Acceptance / Ready-check:

1. Present the **seeded draft** for that section (from step 2), concise and concrete.
2. Ask: **confirm / edit / skip?**
   - **confirm** → accept the draft as-is.
   - **edit** → apply the user's changes, re-show, re-ask.
   - **skip** → leave the section minimal (a one-line stub) and move on. For Acceptance,
     a skip means the doc will be marked `status: backlog` (not ready) at the end.
3. Only move to the next section after an explicit signal. Never batch all five.

Keep drafts tight. For **Key Decisions**, seed one block per decision you detected;
prompt "any other decision worth recording?" before moving on.

### 4. Offer the MODULES (yes/no each, interview the yes's)
Ask, one at a time (or as a quick checklist the user answers): *does this feature have…*
- **Feature Breakdown?** (multiple sub-capabilities worth listing)
- **Integrations?** (external services / other internal modules)
- **Contracts?** (API endpoints, events, data models to pin down)
- **Use Cases / Flows?** (concrete scenarios worth spelling out)
- **Handoff Notes / Open Questions?** (default: include — and **mandatory** if any open question, unknown, or risk surfaced during the walk; this section is the home for unresolved facts)

For each **yes**, present a seeded draft and run the same confirm/edit/skip gate.
For each **no**, omit that section from the doc entirely.

### 5. Write the doc
- Render `docs/backlog/<slug>.md` from `references/template.md` with the confirmed content.
  Include only the modules the user said yes to.
- Populate `related` with any research docs, PRs, plans, or tickets referenced in the
  conversation (leave `[]` if none).
- Set `status`: `ready` **only if real Acceptance criteria were confirmed** — a skipped or
  one-line-stub Acceptance is not ready, so use `backlog` instead.
- Create or update `docs/backlog/README.md` — add this doc's row, or **replace** the existing
  row matched by slug (never append a duplicate).

### 6. Self-review & close
- Fresh-eyes pass on the written file: any leftover `<placeholder>`, contradiction between
  sections (e.g. a scope bullet that fights a decision), or vague acceptance criterion?
  Fix inline. No re-review loop — fix and move on.
- Report the path and status, then offer the downstream handoff:

  > Backlog doc written to `docs/backlog/<slug>.md` (status: <status>).
  > Ready to plan the build? **[P]** `superpowers:writing-plans` · **[D]** `/x-do` · **[N]** stop here.

## References

- `references/template.md` — canonical CORE + MODULES skeleton, index format, status lifecycle.

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
