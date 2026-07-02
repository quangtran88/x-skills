# Step 01 — Detect Plan Source

Goal: locate the plan content, decide its size class, and refuse fast when there is nothing to gate.

## Inputs

x-mindful receives one of:

1. **File path** — user passed something like `.x-skills/plans/foo-plan.md`, `docs/specs/payment.md`, `PRD.md`. Resolve and read with `Read`.
2. **Pasted content** — user inlined the plan in their message. Use the message text directly.
3. **Handoff envelope from x-do** — the `<!-- x-mindful-envelope-request -->` block carries `source` (path or paste id), `trigger_signal` (which keyword fired), and `mode` (`auto` / `manual`).
4. **Explicit slug** — user references an earlier saved `.x-mindful/<slug>/IMPACTS.md`. Read it as a starting point and treat decisions as carry-over candidates (user can re-confirm or change them).

## Refusal Conditions

Stop with a clear message — do NOT proceed to Phase 2 — when:

- No plan content was provided AND no file path resolves
- The "plan" is a one-line ticket title with no detail (`"add payments"`) — route to `x-research` Type F (pre-planning) instead and tell the user
- The content is a code review request, a bug report, or a finished implementation diff — route to `x-review` or `x-bugfix` and tell the user

Refusal message template:

```
x-mindful needs plan content to gate. <reason>. Recommended next step: <skill>.
```

## Size Classification

Count the plan content size after light pre-processing (strip code fences when measuring extraction load — code blocks are usually appendix, not signal):

| Size | Tokens (approx.) | Extraction route |
|---|---|---|
| Small | < 4k | claude-direct |
| Medium | 4k – 30k | claude-direct with `Agent: Explore` to fan out cross-file evidence |
| Large | 30k – 200k | `x-gemini` ingest → return structured items |
| XL | > 200k | reject and ask user to scope down (per-section, per-feature) |

Capability gating: if `agy_cli: false` in the pinned capability set, fall back to chunked claude-direct with explicit "depth reduced" note in the final envelope.

## Slug + Source ID

Derive a stable slug for this run, used only if the user later asks to save:

- File source → kebab-case the basename without extension (e.g., `payment-spec.md` → `payment-spec`)
- Paste source → first 6 hex chars of a content hash, prefixed with `paste-` (e.g., `paste-9a1f3c`)

Hold the slug in memory; do NOT create directories yet.

## Output of Step 01

Produce this internal record (in-memory):

```json
{
  "source": { "kind": "file|paste|envelope|slug", "ref": "<path-or-id>" },
  "size_class": "small|medium|large|xl",
  "slug": "<derived-slug>",
  "trigger_signal": "<keyword-list-from-x-do or 'manual'>",
  "carry_over_decisions": []
}
```

Then proceed to `step-02-extract.md`.
