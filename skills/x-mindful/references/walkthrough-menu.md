# Walkthrough Render & Menu (v2 — architect-review)

Phase 4 walks the user through the ranked queue one item at a time. This file specifies the opening framing, the per-item render template, and the menu commands.

## Phase 4 Opening — "AI's Plan at Architect Level"

Before the per-item loop, render a 5-bullet framing so the user enters the gate with the same mental model the extractor used. This is NOT a plan summary — it's the architect-level read of what AI built, what it picked, and what it took on.

```
─────────────────────────────────────────
PLAN AT ARCHITECT LEVEL — <slug>

What it builds:
  • <1-sentence — the system shape AI proposed>

What it picked over alternatives:
  • <1-sentence — the load-bearing pattern/tech choice + the alternative
    AI didn't take, e.g., "Event-driven inventory propagation over an
    outbox pattern or CDC.">

Top tradeoffs it took on:
  • <1-sentence — the axis with the highest cost AI accepted>
  • <1-sentence — the second-highest>

Load-bearing assumptions:
  • <1-sentence — the assumption that, if wrong, changes the whole design>

What gets harder later if this ships:
  • <1-sentence — the future-debt narrative>

──────  N items to review (CRITICAL=<a> HIGH=<b> MEDIUM=<c>)  ──────
Walking most-important-first. Menu after each item: [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit
─────────────────────────────────────────
```

The 5 bullets are derived from the highest-ranked items + a scan of the source. NEVER reference function names, fields, or file paths here. If you can't say it without an identifier, re-cast or drop the bullet.

Then enter the per-item loop.

## Per-Item Render Template

```
─────────────────────────────────────────
[<id>]  <architect-level title>     · severity: <SEV>  · score: <int>
category: <TRADEOFF|ASSUMPTION|BLIND-SPOT|SHAPE|FUTURE-DEBT>
surface: <internal|service|public>     reversibility: <reversible|costly|one-way>
scope: <scope_note one-line>

WHAT AI DID
  <what_ai_did — architect framing, no identifiers>

TRADEOFF IT PICKED                    ← shown when field is non-empty
  <tradeoff_picked — axis optimized + cost accepted>

ASSUMPTION BAKED IN                   ← shown when field is non-empty
  <assumption — the load-bearing claim>

BLIND SPOT                            ← shown when field is non-empty
  <blind_spot — what a senior expects but the plan skips>

ALTERNATIVES NOT SURFACED             ← shown when field is non-empty
  - <alt 1>
  - <alt 2>

WHAT GETS HARDER LATER
  <future_debt — the 6-12 month narrative>

EVIDENCE (from source)
  > <evidence_anchor — verbatim quote>

──────  Decide:  [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit · [a]ll-confirm  ──────
```

### Rendering rules

- Show **only** the sections whose underlying field is non-empty. Don't render an empty "TRADEOFF IT PICKED" header.
- The fields are required *per category* (see `references/item-schema.md` — TRADEOFF requires `tradeoff_picked`, ASSUMPTION requires `assumption`, etc.), but ANY item may have any optional fields populated.
- `WHAT GETS HARDER LATER` is required for every item and always renders.
- Keep the whole render to one screen. If the item is long, prioritize: WHAT AI DID → the category's signature field → WHAT GETS HARDER LATER → menu. Push EVIDENCE to the bottom.
- NEVER include code identifiers (function names, params, fields, file paths) in any rendered field. If extraction sneaks one in, strip it at render time and add a `[code-detail stripped]` marker so the user knows.

## Menu Commands

| Short | Long | Argument | Effect |
|---|---|---|---|
| `c` | `confirm` | — | Direction approved. Add to `confirmed`. |
| `m` | `modify` | `<text>` (required) | Capture user's replacement direction verbatim. Add to `modified`. |
| `r` | `reject` | `<reason>` (optional) | Drop item from plan. Add to `rejected`. |
| `s` | `skip` | — | Defer item; surface in envelope `Skipped` section. |
| `q` | `quit` | — | Stop loop; remaining queue → `pending`. |
| `a` | `all` / `all-confirm` | — | Confirm every remaining queued item. Echo each title in next turn. |
| `?` | `help` | — | Re-print menu without changing state. |

## Input Heuristics

- A bare letter `c|m|r|s|q|a|?` matches the short form.
- Long words match the long form.
- A line that starts with a long form followed by text → that text is the argument (`modify use outbox pattern instead` → command=modify, arg=`use outbox pattern instead`).
- A line that does not match any command is treated as a `modify` argument and the agent must confirm: `Captured as modification — confirm? [y/n]`.
- `y` / `yes` / `ok` after a captured modification commits it; anything else cancels and re-renders the menu.

## CRITICAL-Item Confirmation

For items at severity `CRITICAL`, the renderer adds:

```
⚠ CRITICAL — type 'confirm' (long form) to accept; short form 'c' is disabled here.
```

Force the long form on critical items so the user opts in deliberately. `m` / `r` / `s` / `q` work normally.

## All-Confirm Echo

When user picks `a`, the next turn must echo each remaining item:

```
Confirmed remaining queue:
  - [TRADEOFF-002] Pick message bus over outbox pattern
  - [SHAPE-001] Microservice for a small bounded context
  - [FUTURE-DEBT-003] Single-region routing hardcoded
Proceeding to envelope render.
```

Then jump straight to Step 05.

## Pause / Resume

If the user closes the chat mid-loop, in-memory state is lost. Resume requires re-extraction from the original source (Steps 01-03 are cheap). The new run can detect a prior `IMPACTS.md` (only if the user previously persisted) and pre-load decisions as defaults.

## Bad-Input Recovery

| Input | Response |
|---|---|
| Empty / whitespace-only | Re-print the current item's menu, no state change |
| Multi-command (`c then m foo`) | Reject: "one command per turn" |
| `modify` without text | Prompt: "modify needs a directive — provide replacement text or pick a different command" |
| Unknown short letter | Treat as modify-text (heuristic above) and confirm |
