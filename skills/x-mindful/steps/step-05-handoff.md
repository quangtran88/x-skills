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

Then invoke `Skill: x-skills:x-do` with that handoff in args.

## Persistence (only on explicit request)

If the user picks (3):

1. Create `.x-mindful/<slug>/` if it does not exist
2. Write the envelope verbatim to `IMPACTS.md`
3. Suggest adding `.x-mindful/` to `.gitignore` if not already gitignored — do NOT add it for them
4. Confirm the path back to the user

Do NOT write `progress.json` or any state beyond the single `IMPACTS.md`. Persistence is a one-shot export, not a session.

## Verifier Slot

Before declaring done, dispatch the verifier slot per the SKILL.md `Completion (MANDATORY)` section. x-verify confirms envelope completeness and section integrity, NOT implementation correctness — there is no implementation in x-mindful.

```
Dispatching verifier slot → resolved to x-verify via skill frontmatter
```

If x-verify returns `done`, the handoff path is unblocked. Other verdicts follow standard cascade rules.
