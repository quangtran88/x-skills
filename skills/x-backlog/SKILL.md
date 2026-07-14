---
name: x-backlog
description: Use when the user wants to capture a brainstormed idea, feature, or solution into a durable backlog/spec doc under docs/backlog — a human-facing reference that combines context, chosen solution, key decisions (ADR-lite), scope, acceptance criteria, and optional feature/integration/contract/use-case/handoff modules. Drafts the whole doc autonomously from the current conversation and persists docs/backlog/<slug>.md; asks the user only when blocked or a decision genuinely needs their input. NOT a low-level implementation plan (that is superpowers:writing-plans / x-do).
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
drafts and writes a markdown file. It never delegates to sub-agents.

The one exception is the **Memory Reflex** (`../x-shared/mcp-toolbox.md § Memory Reflex`): its
recall (step 2) and persist (step 6) are gated on `mcp.basic_memory` being in the
bootstrap-active capability set — the `[x-skills/capabilities]` snapshot line, or its
`~/.config/x-skills/capabilities.json` fallback (per `../x-shared/capability-loading.md`) when
the line isn't in context. Consult the pinned set for this gate only — no full
capability-loading walk, no sub-agent dispatch. When basic_memory is absent, both beats skip
silently and x-backlog behaves exactly as before.

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

## Workflow — the draft-first walk

Run these six steps in order, autonomously. The user is not interviewed section by section;
the only pause is the blocker checkpoint in step 3, and only when a blocker actually exists.

### 1. Detect & slug
- Derive a kebab-case `<slug>` from the feature name (e.g. `user-billing-portal`).
- If `docs/backlog/<slug>.md` already exists, this is an **update**: read it and merge new
  conversation material into the existing content instead of drafting from scratch.
- Announce: `Backlog doc: docs/backlog/<slug>.md (new | update).`

### 2. Harvest from context
- [ ] **Memory recall** (only when `mcp.basic_memory` pinned in the bootstrap-active set — see the Bootstrap note): one `mcp__basic-memory__search_notes({ query: "<feature slug/name>", page_size: 5 })` call over prior `decisions/<project-slug>/` notes BEFORE drafting — surface cross-session contradictions with earlier decisions as leads for the step-3 blocker checkpoint (blocker #1 Contradiction), not verdicts, per `../x-shared/mcp-toolbox.md § Memory Reflex`. Skip silently when not pinned.
- Scan the current conversation for the material that fills the CORE sections and any
  modules: the problem, the chosen solution, decisions made and alternatives rejected,
  scope boundaries, features, integrations, contracts, use cases, open questions.
- If the conversation is thin (cold start, no prior brainstorm), draft best-effort from
  what exists and record the gaps under **Handoff Notes / Open Questions** — do not
  interview to fill them.

### 3. Blocker checkpoint (the ONLY time you ask the user)
Ask the user **only** when one of these blockers holds:

1. **Contradiction** — the conversation contains two incompatible answers to the same
   question (e.g. two different chosen solutions) and the doc cannot record both.
2. **Load-bearing decision never made** — a choice the Solution / Scope / Contracts hinge
   on is absent from the conversation and no responsible default exists. A missing detail
   that doesn't change the doc's shape is an Open Question, not a question to the user.
3. **Target ambiguity** — you cannot tell whether this updates an existing backlog doc or
   creates a new one (see slug-stability gotcha).

If any blocker exists, batch **every** question into ONE checkpoint (one message /
AskUserQuestion) before writing — never a per-section drip. If none exists, say nothing
and proceed. Default when unsure: record it under Handoff Notes / Open Questions and keep going.

### 4. Draft CORE + self-triage MODULES (autonomously)
- Draft all five CORE sections in order — Context & Problem, Solution Overview,
  Key Decisions (one block per decision detected), Scope & Non-Goals,
  Acceptance / Ready-check. Do not present them for per-section confirmation.
- Include a MODULE only when the conversation has real material for it:
  - **Feature Breakdown** — multiple sub-capabilities were actually discussed.
  - **Integrations** — external services / other internal modules are involved.
  - **Contracts** — API endpoints, events, or data models were pinned down or clearly needed.
  - **Use Cases / Flows** — concrete scenarios surfaced.
  - **Handoff Notes / Open Questions** — default: include; **mandatory** if any open
    question, unknown, or risk surfaced. This section is the home for unresolved facts.
- A module without real material is omitted entirely — never padded, never asked about.

### 5. Write the doc
- Render `docs/backlog/<slug>.md` from `references/template.md` with the drafted content.
  Include only the modules that passed triage.
- Set `type` in frontmatter from the nature of the work: `fix` for bug specs, `refactor`,
  `chore`, etc. as appropriate, `feat` otherwise. Downstream skills consume it: x-worktree
  derives the branch name `<type>/<slug>` and x-do picks the archival folder on completion.
- Populate `related` with any research docs, PRs, plans, or tickets referenced in the
  conversation (leave `[]` if none).
- Set `status`: `ready` **only if the Acceptance criteria are grounded in real conversation
  material** — criteria you had to invent from thin context are not ready, so use `backlog`.
- Create or update `docs/backlog/README.md` — if the index is in its empty state, delete the
  "no unshipped backlog items" line as you add the first row back (see `references/template.md`
  § "Index file" → Empty-state line). Then add this doc's row, or **replace** the existing
  row matched by slug (never append a duplicate).

### 6. Self-review & close
- Fresh-eyes pass on the written file: any leftover `<placeholder>`, contradiction between
  sections (e.g. a scope bullet that fights a decision), or vague acceptance criterion?
  Fix inline. No re-review loop — fix and move on.
- [ ] **Persist Key Decisions** (only when `mcp.basic_memory` pinned in the bootstrap-active set — see the Bootstrap note): for each decision block drafted in step 4, one `mcp__basic-memory__write_note({ title: "<slug>: <decision title>", directory: "decisions/<project-slug>", content: "<decision + rationale + rejected alternative>", tags: ["<project-slug>", "x-backlog", "<slug>"] })` call (project-slug = basename of cwd). Persist the decision + rationale only — not the whole doc; if this run's recall already surfaced a note for the same decision, `edit_note` it rather than writing a duplicate — per the *Update over duplicate* shape in § Memory Reflex (the recall hit's **permalink** as `identifier`, `operation: "append"`; it cannot retag or move a note, so write fresh if the surfaced note is misfiled). Placement + tagging per `../x-shared/mcp-toolbox.md § Memory Reflex` / § Consumer rules. Skip silently when not pinned.
- Report the path, status, a one-screen summary of what was drafted, and any Open Questions
  recorded — then invite edits and offer the downstream handoff:

  > Backlog doc written to `docs/backlog/<slug>.md` (status: <status>).
  > Tell me what to change and I'll update it in place.
  > Next → **[C]** commit doc on current branch · **[W]** worktree + implement (`/x-worktree <doc>`) ·
  > **[P]** plan first (`superpowers:writing-plans`) · **[D]** `/x-do <doc>` here · **[N]** stop.

  Handoff behavior per letter:
  - **[C]** — commit only this doc + the index: `docs(backlog): add <slug>` (or `update <slug>`
    on a re-run). Then re-offer **[W] / [D] / [N]** once — capture-and-park is a valid end state.
  - **[W]** — dispatch `Skill: x-skills:x-worktree docs/backlog/<slug>.md`. Two doc states carry
    cleanly: an untracked new doc is migrated + committed inside the new worktree; a committed
    clean doc is inherited via the base branch. **The third state does not:** an *update* run
    (step 1 re-rendered an already-committed doc) leaves it tracked + modified, which x-worktree
    step 2.5 hard-rejects — so on an update run, do **[C] first** to commit the change, then [W].
    Note the difference in one line when offering: [C] then [W] keeps the doc on the current
    branch too; [W] alone carries only the doc to the new branch until merge. The `README.md`
    index row from step 5 is a *separate* modified file x-worktree does not migrate — prefer
    [C] first so doc + index travel together; with bare [W] the row stays on the current branch
    and the archival row-deletion on the worktree branch harmlessly no-ops. On x-worktree's
    success envelope, follow its `/x-do` handoff suggestion.
  - **[P]** — dispatch `superpowers:writing-plans` on the doc. This path does **not** run x-do
    Mode A, so nothing auto-flips `status` or archives the doc: flip `status: in-progress` by hand
    when the build starts, and archive per `references/template.md` § "Archival on done" when it
    ships — otherwise the doc silently rots in `docs/backlog/` after implementation.
  - **[D]** — dispatch `Skill: x-skills:x-do docs/backlog/<slug>.md` in the current dir
    (x-do Mode A; it applies its Backlog Doc Lifecycle — status flip, archival on completion).

## References

- `references/template.md` — canonical CORE + MODULES skeleton, index format, status lifecycle.

## Gotchas

See `gotchas.md`.

Task: {{ARGUMENTS}}
