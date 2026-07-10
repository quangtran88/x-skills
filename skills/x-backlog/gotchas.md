# x-backlog — Gotchas

Known failure patterns for the backlog-doc gated walk.

## It is a reference doc, not an execution plan
The single most common drift: turning the doc into a step-by-step implementation plan
(per-file changes, TDD micro-cycles, exact commands). That belongs to
`superpowers:writing-plans` / `x-do`. Keep x-backlog at the "why + what" altitude:
context, chosen solution, decisions, contracts. If you catch yourself writing
`### Task 1: create foo.ts`, stop — wrong doc.

## Interview-first means walk every CORE section — even when context already covers it
The user chose interview-first deliberately. Do **not** silently auto-fill the whole doc
from the conversation and skip the gate. Seed each section from context, but still present
it and wait for confirm/edit/skip. The seeding makes it fast; it does not replace the gate.

## Gate per section — never batch the content
Present ONE section, wait for a signal, then advance. Dumping all five CORE sections at once
defeats the point and produces docs the user rubber-stamps without reading. CORE sections
(step 3) and each *authored* module (step 4) are one-at-a-time. The one exception is the
step-4 module **triage** — the yes/no "does it have integrations / contracts / …?" questions
— which may be asked as a single quick checklist; it is the *content* authoring that must
stay gated, not the triage.

## Omit irrelevant modules — do not write "N/A"
A module the user says "no" to is left OUT of the file entirely. Empty or "N/A" module
sections are noise and make the doc look half-finished. The core+modules shape exists
precisely so small features stay short.

## No placeholders in a shipped doc
Never leave `<Feature name>`, `<bullet>`, `TBD`, or `TODO` in the written file. If a fact is
genuinely unknown, that is not a placeholder — record it as a bullet under **Handoff Notes /
Open Questions** ("Open question: …"). The self-review step (6) exists to catch stragglers.

## Slug stability on updates
On a re-run, derive the same slug and detect the existing `docs/backlog/<slug>.md` so it
**updates in place** instead of creating a near-duplicate (`user-billing.md` vs
`user-billing-portal.md`). When unsure, list existing backlog files and ask which one this is.

## Keep the index in sync
Every write must add or refresh the doc's row in `docs/backlog/README.md` — match the
existing row by slug and replace it; never append a duplicate. A stale index
(missing rows, wrong status) is the thing that makes "go back later" fail. Update `updated`
and `status` on every re-run, not just on creation.

## Status honesty
`status: ready` is a promise the doc is safe to hand to implementation. If the user skipped
Acceptance criteria, it is **not** ready — set `status: backlog`. Don't mark ready just
because the walk finished.

## Date source
Use the session's current-date context for `created` / `updated`. Do not guess or hardcode a
date, and do not shell out for it inside the walk — the harness provides it.

## docs/backlog/ may not exist yet
On the very first run in a repo, create the `docs/backlog/` directory (and its `README.md`
index) before writing. Don't assume it exists.
