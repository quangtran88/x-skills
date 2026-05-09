# Step 04 — Walkthrough Loop (Core)

Goal: walk the user through the ranked queue one item at a time. For each item, render the impact card, present the menu, capture the decision, and advance. The decisions map is the gate's output.

## Loop Invariant

```
WHILE queue not empty AND user has not quit:
  current = queue.pop_front()
  render(current)
  menu()
  decision = await user input
  decisions[current.id] = decision
  IF decision == 'modify': capture modification text
  IF decision == 'quit': break (preserve unprocessed items as 'pending')
```

One item per assistant turn. Do NOT batch render. Do NOT auto-advance on a non-answer.

## Render Template (per item)

```
─────────────────────────────────────────
[<id>]  <title>     · severity: <SEV>  · score: <int>
category: <ARCH|BREAK|SEC|PERF>     surface: <internal|package|service|public>
reversibility: <reversible|hard|irreversible>     blast: files=<n> callers=<n> services=<n>

PROPOSED (from plan)
> <plan quote, evidence_anchor>

IMPACT
- <what changes for users / operators / callers>
- <second-order effects, especially when not_in_plan: true>

ALTERNATIVES (if any)
- <alt 1>
- <alt 2>

──────────  Decide:  [c]onfirm · [m]odify · [r]eject · [s]kip · [q]uit · [a]ll-confirm  ──────────
```

Keep it to one screen. If `alternatives` is empty, omit that block entirely.

## Menu Commands

| Key | Meaning | Effect |
|---|---|---|
| `c` | Confirm | Item proceeds as written. Add to `confirmed` list. |
| `m <text>` | Modify | Item proceeds with the user's replacement direction. Capture text verbatim. Add to `modified` list. |
| `r <reason?>` | Reject | Item is dropped from the plan. Optional reason captured. Add to `rejected` list. |
| `s` | Skip | Defer this item; move to `skipped`. Surface in envelope so user can revisit. |
| `q` | Quit | Stop the loop; remaining items become `pending` in the envelope. |
| `a` | All-confirm | Confirm every remaining item in one go. Echo each title in the next assistant turn so the user sees what they accepted. |
| `?` | Help | Re-print the menu without changing state. |

Always accept the long form too: `confirm`, `modify`, `reject`, `skip`, `quit`, `all`, `help`.

If the user's input does not match any command, treat the entire input as a `modify` text (most common natural form) and confirm: "Captured as modification — confirm? [y/n]".

## Special Cases

- **Low-bundle item.** When the queue reaches the trailing `LOW-bundle`, render it as one card listing the bundled item titles. Decisions there apply to the whole bundle (e.g., `c` confirms all bundled items).
- **CRITICAL item.** Add a one-line warning above the menu: `⚠ CRITICAL — extra confirmation recommended`. Do not change the menu, just flag it.
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
