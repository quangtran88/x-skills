# Walkthrough Menu Reference

Phase 4 menu commands. Both short (one letter) and long forms work. Case-insensitive.

| Short | Long | Argument | Effect |
|---|---|---|---|
| `c` | `confirm` | — | Item proceeds as written. Add to `confirmed`. |
| `m` | `modify` | `<text>` (required) | Capture user's replacement direction verbatim. Add to `modified`. |
| `r` | `reject` | `<reason>` (optional) | Drop item from plan. Add to `rejected`. |
| `s` | `skip` | — | Defer item; surface in envelope `Skipped` section. |
| `q` | `quit` | — | Stop loop; remaining queue → `pending`. |
| `a` | `all` / `all-confirm` | — | Confirm every remaining queued item. Echo each title in next turn. |
| `?` | `help` | — | Re-print menu without changing state. |

## Input Heuristics

- A bare letter `c|m|r|s|q|a|?` matches the short form.
- Long words match the long form.
- A line that starts with one of the long forms followed by text → that text is the argument (`modify use deprecation alias instead` → command=modify, arg=`use deprecation alias instead`).
- A line that does not match any command is treated as a `modify` argument and the agent must confirm: `Captured as modification — confirm? [y/n]`.
- `y` / `yes` / `ok` after a captured modification commits it; anything else cancels and re-renders the menu.

## CRITICAL-Item Confirmation

For items at severity `CRITICAL`, the renderer adds:

```
⚠ CRITICAL — type 'confirm' (long form) to accept; short form 'c' is disabled here.
```

Force the long form on critical items so the user is opting in deliberately. `m` / `r` / `s` / `q` work normally.

## All-Confirm Echo

When user picks `a`, the next turn must echo each remaining item:

```
Confirmed remaining queue:
  - [BREAK-002] Rename getUser → fetchUser
  - [PERF-001] Add Redis cache
  - [ARCH-003] Adopt event-driven inventory
Proceeding to envelope render.
```

Then jump straight to Step 05.

## Pause / Resume

If the user closes the chat mid-loop, the in-memory state is lost. Resume requires re-extraction from the original source (Steps 01-03 are cheap). The new run can detect a prior `IMPACTS.md` (only if the user previously persisted) and pre-load decisions as defaults.

## Bad-Input Recovery

| Input | Response |
|---|---|
| Empty / whitespace-only | Re-print the current item's menu, no state change |
| Multi-command (`c then m foo`) | Reject: "one command per turn" |
| `modify` without text | Prompt: "modify needs a directive — provide replacement text or pick a different command" |
| Unknown short letter | Treat as modify-text (heuristic above) and confirm |
