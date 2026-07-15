# Step 05 — Emit Decision Envelope and Hand Off

Goal: render the final decision envelope, present a next-step menu, and (only on user request) persist to disk.

## Envelope (canonical form)

Render exactly this Markdown block. x-do Mode A and any other consumer reads `x-mindful-envelope v1` — that marker is preserved for backward compatibility. The taxonomy upgrade is signaled by the `taxonomy: v2` line and the new item id prefixes (`TRADEOFF` / `ASSUMPTION` / `BLIND-SPOT` / `SHAPE` / `FUTURE-DEBT`). Section headers are unchanged so existing consumers keep working.

```markdown
<!-- x-mindful-envelope v1 -->
<!-- taxonomy: v2 (TRADEOFF / ASSUMPTION / BLIND-SPOT / SHAPE / FUTURE-DEBT) -->
**Source:** <path-or-paste-id>
**Slug:** <slug-from-step-01>
**Reviewed:** <ISO date> · items=<N> (C=<c> / M=<m> / R=<r> / S=<s> / P=<p>)

### Confirmed (proceed as written)
- [<id>] <architect-level title> — severity: <SEV>

### Modified (revise plan before executing)
- [<id>] <architect-level title>
  - **Original plan:** <plan quote>
  - **User direction:** <verbatim user text>

### Rejected (drop from plan)
- [<id>] <architect-level title>
  - **Reason:** <user reason or "unspecified">

### Skipped (revisit later)
- [<id>] <architect-level title>

### Pending (user quit before deciding)
- [<id>] <architect-level title>
<!-- /x-mindful-envelope -->
```

Section headers must match exactly (consumers grep for them). Empty sections may be omitted. Item titles are architect-level — no code identifiers — same hard rule as extraction.

## Validity Checks

Before rendering:

- Every queued item appears in exactly one section. No drops, no duplicates.
- Modified items have non-empty `User direction`.
- Source path is present and matches Step 01.

If any check fails, stop and surface the inconsistency rather than rendering a malformed envelope.

## Persist Architectural Lessons (always-run, gated)

Run this **immediately after the validity checks pass and BEFORE presenting the Next-Step
Menu** — option 1 hands control to x-do and never returns to this file, so a persist placed
after the menu would silently skip on the recommended path. Firing here guarantees it has
already run no matter which option the user picks (including option 1, the x-do handoff, and
option 4, stop). Per § Memory Reflex, the `mcp.basic_memory` pin and the durability gate
(a confirmed/rejected arch lesson actually worth keeping) are the only two things that stop
the write.

- [ ] **Persist arch lesson** (only when `mcp.basic_memory` pinned in the bootstrap-active set): for each envelope item flagged as a new architectural lesson confirmed or rejected by the walkthrough, one `mcp__basic-memory__write_note({ title: "<slug> arch lesson", directory: "lessons/<project-slug>", content: "<one-sentence arch lesson confirmed/rejected by walkthrough>", tags: ["<project-slug>", "x-mindful", "architecture"] })` call (project-slug per § Consumer rules). Persist confirmed/rejected architectural lessons only — not the whole envelope. Placement, tagging, and *Update over duplicate* (append via the recall hit's permalink — same-kind only) per `../../x-shared/mcp-toolbox.md § Memory Reflex` / § Consumer rules. Skip silently when not pinned.

## Verifier Slot

Before presenting the menu, dispatch the verifier slot per the SKILL.md `Completion (MANDATORY)`
section. x-verify confirms envelope completeness and section integrity, NOT implementation
correctness — there is no implementation in x-mindful. Running it here — before the menu, and
thus before any option-1 control transfer — means the handoff is already unblocked when offered.

```
Dispatching verifier slot → resolved to x-verify via skill frontmatter
```

If x-verify returns `done`, every menu option is unblocked. Other verdicts follow standard
cascade rules.

## Next-Step Menu

After the envelope, present:

```
Next step:
  1. /x-do Mode A — execute the revised plan with the envelope as guidance  (Recommended)
  2. /x-review — review the plan again with these decisions baked in
  3. Save envelope to .x-mindful/<slug>/IMPACTS.md (one-shot, no progress.json)
  4. Stop here — copy the envelope for human review
```

The user picks. If they pick (1), build a handoff context per `../x-shared/context-envelope.md` containing:

- `from: x-mindful`
- `to: x-do`
- `mode_hint: A`
- `revised_plan_directive: "apply Modified entries before plan review"`
- `dropped_items: [<rejected ids>]`
- `envelope: <the envelope markdown>`

Then invoke `Skill: x-skills:x-do` with that handoff in args. (The persist beat and verifier
slot above have already run by this point — do not defer them past this dispatch.)

## Persistence (only on explicit request)

If the user picks (3):

1. Create `.x-mindful/<slug>/` if it does not exist
2. Write the envelope verbatim to `IMPACTS.md`
3. Suggest adding `.x-mindful/` to `.gitignore` if not already gitignored — do NOT add it for them
4. Confirm the path back to the user

Do NOT write `progress.json` or any state beyond the single `IMPACTS.md`. Persistence is a one-shot export, not a session.
