# Step 04 — Walkthrough Loop (Core)

Goal: open with the "Plan at Architect Level" framing, then walk the user through the ranked queue one item at a time at architect-review level. For each item, render the impact card, present the menu, capture the decision, and advance. The decisions map is the gate's output.

## Phase 4a — Open with "Plan at Architect Level"

Before the per-item loop, render the 5-bullet architect-level framing (full template in `references/walkthrough-menu.md`). This is the user's mental model entrance — without it, individual items feel disconnected.

Derive the 5 bullets from:

- **What it builds:** scan the highest-ranked items + plan source; state the system shape in one sentence
- **What it picked over alternatives:** the highest-ranked TRADEOFF item's `tradeoff_picked` + first item in its `alternatives`
- **Top tradeoffs it took on:** the top 2 TRADEOFF items' `tradeoff_picked` fields, compressed
- **Load-bearing assumptions:** the highest-ranked ASSUMPTION item's `assumption` field
- **What gets harder later:** the highest-ranked FUTURE-DEBT item's `future_debt` field, or the highest-ranked item's `future_debt` if no FUTURE-DEBT items

If a category has zero items, replace that bullet with `• (none surfaced)`. Do NOT pad with code-level details.

NEVER include function names, fields, file paths in these bullets. If you can't say it without an identifier, re-cast.

## Phase 4b — Loop Invariant

```
WHILE queue not empty AND user has not quit:
  current = queue.pop_front()
  render(current)              # per template in references/walkthrough-menu.md
  menu()
  decision = await user input
  decisions[current.id] = decision
  IF decision == 'modify': capture modification text
  IF decision == 'quit': break (preserve unprocessed items as 'pending')
```

One item per assistant turn. Do NOT batch render. Do NOT auto-advance on a non-answer.

## Per-Item Render

Use the architect-review template in `references/walkthrough-menu.md`. Summary:

```
[<id>]  <architect-level title>     · severity: <SEV>  · score: <int>
category: <TRADEOFF|ASSUMPTION|BLIND-SPOT|SHAPE|FUTURE-DEBT>
surface: <internal|service|public>  reversibility: <reversible|costly|one-way>
scope: <scope_note one-line>

WHAT AI DID
  <what_ai_did>

[TRADEOFF IT PICKED          ← shown only if field non-empty]
  <tradeoff_picked>

[ASSUMPTION BAKED IN         ← shown only if field non-empty]
  <assumption>

[BLIND SPOT                  ← shown only if field non-empty]
  <blind_spot>

[ALTERNATIVES NOT SURFACED   ← shown only if field non-empty]
  - <alt 1>
  - <alt 2>

WHAT GETS HARDER LATER       ← always shown (required for all items)
  <future_debt>

EVIDENCE (from source)
  > <evidence_anchor>

──────  Decide:  [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit · [a]ll-confirm  ──────
```

Show only the sections whose underlying field is non-empty. Keep the whole render to one screen.

### Render Guard

NEVER let code-level identifiers reach the render. If extraction sneaked one in despite the Step-02 hard rule, strip it at render time and replace with a placeholder + `[code-detail stripped]` marker. Log the slip so the user knows extraction needs re-prompting.

## Menu Commands

| Key | Meaning | Effect |
|---|---|---|
| `c` | Confirm | Direction approved. Add to `confirmed` list. |
| `m <text>` | Modify | Capture user's replacement direction verbatim. Add to `modified` list. |
| `r <reason?>` | Reject | Drop from plan. Optional reason captured. Add to `rejected` list. |
| `s` | Skip | Defer; surface in envelope so user can revisit. |
| `q` | Quit | Stop loop; remaining items become `pending` in envelope. |
| `a` | All-confirm | Confirm every remaining item. Echo each title in next assistant turn. |
| `?` | Help | Re-print menu. |

Always accept the long form: `confirm`, `modify`, `reject`, `skip`, `quit`, `all`, `help`.

If user input does not match any command, treat the entire input as `modify` text (most common natural form) and confirm: "Captured as modification — confirm? [y/n]".

## Special Cases

- **Bundled item.** When the queue reaches a bundled item (5+ similar MEDIUM items merged in Step 03), render as one card listing the bundled item titles in `scope_note`. Decisions apply to the whole bundle.
- **CRITICAL item.** Add a one-line warning above the menu: `⚠ CRITICAL — type 'confirm' (long form) to accept; short form 'c' is disabled here.` Force the deliberate long form for CRITICAL items only.
- **Carry-over from a prior saved IMPACTS.md.** If the source already has a decision for this id, render the prior decision as a default and let the user accept with `c` or change.

## Decision Map (in-memory)

```json
{
  "<id>": {
    "decision": "confirm|modify|reject|skip|pending",
    "modification": "<text when decision==modify>",
    "reason": "<text when decision==reject>",
    "decided_at": "<iso8601>"
  }
}
```

## Exit Conditions

- Queue exhausted → proceed to `step-05-handoff.md`
- User picks `q` → proceed to `step-05-handoff.md` with remaining items marked `pending`
- User session ends without answer → freeze in-memory state, do NOT auto-decide; if x-mindful is invoked again with the same source, offer to resume from where the user paused
