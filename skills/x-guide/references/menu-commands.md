# Phase 4 Menu Commands — Reference

Single source of truth for what each menu command does. Step 4 quotes a summary; this file is authoritative.

## Command Table

| Cmd | Aliases | State change | Render change | Notes |
|---|---|---|---|---|
| `n` | `next` | `parts[current].status = done`, `current += 1`, `parts[new_current].status = current` | Render new current at `level=mid` | At final part, jumps to Phase 5 WRAP |
| `b` | `back` | None | Re-render previous part | If at Part 1, ignore with a message |
| `s` | `skip` | `parts[current].status = skipped`, `current += 1` | Render new current at `level=mid` | At final part, jumps to Phase 5 WRAP |
| `d` | `deeper` | `parts[current].level_used = deeper` | Re-render same part with more technical depth | Persists to `progress.json` |
| `l` | `simpler` | `parts[current].level_used = simpler` | Re-render same part with more analogy, less jargon | Persists to `progress.json` |
| `e` | `example` | None | Append a worked example below current body | Body grows; menu re-shows |
| `q` | `quiz` | None until graded; failed sub-points trigger inline re-explain | Quiz block, then re-show menu | See Quiz Subroutine in step-04 |
| `j N` | `jump N` | Intermediate parts `pending → skipped`; `current = N` | Render Part N at `level=mid` | If `N > M` or `N < 1`, error |
| `x` | `exit` | Flush state | None — print resume hint, end | Skill invocation ends here |
| `1`/`2`/`3` | (follow-up index) | None | Inline answer to that follow-up, then re-show menu | Numbers refer to the 3 generated follow-ups |
| (free text) | — | None | Inline answer, then re-show menu | Goes to Q&A path |
| `rewrite outline` | `regenerate outline` | TOC regenerated; `done` parts preserved by title match | New roadmap + re-render current | See step-04 Outline Regeneration |

## Status State Machine

```
pending ──n──► current
pending ──s──► skipped         (only via `j N` jumping past it)
current ──n──► done   (and next pending becomes current)
current ──s──► skipped (and next pending becomes current)
done    ──b──► current (when user goes back; previous current becomes pending)
skipped ──j──► current (when user jumps back to it)
```

Invariant: at most one part is `current` at any time. All others are `pending`, `done`, or `skipped`.

## Disallowed Transitions

- `done → pending` directly. Use `b` (back) which sets the previous part to `current` and the current to `pending`.
- Two parts `current` simultaneously.
- `current` set to a part beyond the final index unless WRAP entry conditions are met.

If the user requests a disallowed transition, show a one-line error and re-show the menu.
