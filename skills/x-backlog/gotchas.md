# x-backlog — Gotchas

Known failure patterns for the backlog-doc draft-first walk.

## It is a reference doc, not an execution plan
The single most common drift: turning the doc into a step-by-step implementation plan
(per-file changes, TDD micro-cycles, exact commands). That belongs to
`superpowers:writing-plans` / `x-do`. Keep x-backlog at the "why + what" altitude:
context, chosen solution, decisions, contracts. If you catch yourself writing
`### Task 1: create foo.ts`, stop — wrong doc.

## Draft-first means don't interview
The walk is autonomous by design. Do **not** present sections one at a time asking
confirm/edit/skip, do not run a yes/no module checklist, and do not ask "shall I proceed?".
Draft the whole doc, write it, report it. The only permitted questions are the three
blockers in SKILL.md step 3 (contradiction, load-bearing decision never made, target
ambiguity) — everything else is either draftable or an Open Question.

## One question checkpoint, not a drip
When blockers do exist, collect **all** of them and ask once, before writing. Asking one
question, drafting a bit, then asking another recreates the interview this skill removed.

## Don't ask what you can record
A missing fact that doesn't change the doc's shape (an unchosen library, an unknown rate
limit, an unvalidated assumption) is a bullet under **Handoff Notes / Open Questions**,
not a question to the user. Asking anyway is the most common regression — when unsure
whether something is load-bearing, record it and keep going.

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
`status: ready` is a promise the doc is safe to hand to implementation. If the Acceptance
criteria are not grounded in real conversation material — you had to invent them from thin
context — it is **not** ready: set `status: backlog`. Don't mark ready just because the
walk finished, and don't pad Acceptance with plausible-sounding criteria to reach `ready`.

## Date source
Use the session's current-date context for `created` / `updated`. Do not guess or hardcode a
date, and do not shell out for it inside the walk — the harness provides it.

## docs/backlog/ may not exist yet
On the very first run in a repo, create the `docs/backlog/` directory (and its `README.md`
index) before writing. Don't assume it exists.
