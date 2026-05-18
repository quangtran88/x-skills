# Done Format — Compact Completion Output

All x-skills MUST use this format when presenting results to the user. Applies to x-do and x-review. **This governs ONLY user-facing output** — internal workflow steps, safety checks, and structured envelopes are unaffected.

## Shape 1 — DONE (no blockers, no pending decisions)

```
✓ DONE: [skill] — [one-line result]
- [bullet for key result — omit if self-evident]
- [second bullet if needed; max 3 total]

Next → [A] [first option] · [B] [second option] · [N] done
```

x-do only: append `· [L] save as skill` when OMC plugin is available and the workflow was complex (3+ steps, multi-agent). Skip silently otherwise.

## Shape 2 — BLOCKED (hard stop, user must act before work continues)

```
⛔ BLOCKED: [one sentence — no jargon, no code symbols]

[A] [fix option — one line, user-visible outcome]
[B] [alt option — one line, user-visible outcome]
[N] skip

Reply with letter.
```

Rule: if both BLOCKED and DECIDE apply simultaneously, surface BLOCKED first.

## Shape 3 — DECIDE (NEEDS_DIRECTION finding requires user input)

Surface **one decision at a time**. Wait for user reply before surfacing the next.

```
⚠ DECIDE #[N]: [Bottom line — ≤2 plain sentences, user-visible stake + tradeoff. No code symbols.]
Axis: [impl | security | product | compliance] · Severity: [CRITICAL | HIGH | MEDIUM | LOW]

[A] [option name] — [user impact, one line, no code symbols]
[B] [option name] — [user impact, one line, no code symbols]
[C] Defer — requires tracker + owner + deadline before proceeding
[D] Reject framing — the plan itself should change

→ Recommended: [A / B / C / D]
Reply: `[N]: A` (multiple answers OK in one message, e.g. `2: A`, `5: B`)
```

**Safety rules that MUST carry through into every DECIDE block:**
- axis = `security` or `compliance`: Option C MUST NOT say "keep as-is" or "ship dead gate." Replace option C text with: "Fix in immediate follow-up PR — tracker link required before this PR merges."
- axis = `product`: always append footer: `Decider: product owner — implementer should not pick alone.`
- Effort label (S/M/L): OMIT entirely when axis = security or compliance.

## Passes Line (x-review only)

Replaces the 8-line verbatim passes menu block. Emit on one line after the verdict summary.

```
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [N] done
```

Letter assignments are fixed (same as `references/review-passes.md`) — do NOT redefine. [P]/[C]/[D] are scope-expanders. If user picks [A] All, confirm once before launching: "All passes includes refactor + perf suggestions beyond bugs/security — proceed?"

## Follow-up Options Line (x-review NEEDS_DIRECTION only)

Replaces the 6-line verbatim follow-up menu. Emit on one line after the last DECIDE block.

```
→ [Y] all recommended · [P] per-decision · [R] review-only · [S] skip flagged · [X] re-dispatch · [N] done
```

Letter assignments are fixed — do NOT redefine. Branching logic for each letter is unchanged from `steps/step-04-act.md § Clarification Gate`.

## Suppression Rules

| Element | Default | Override |
|---------|---------|----------|
| Handoff context block | Suppressed | Include only when next skill explicitly requires it |
| Progress banners ("Step N of M — Next: X") | Suppressed | Never include in output |
| Learner hook multi-line block | Compressed to `· [L] save as skill` in Next line | None |
| Plan-mode envelope (`<!-- x-review plan-mode envelope v1 -->`) | Always emit AFTER human-readable block | Never suppress |
| Out-of-scope filtered count | One line: `Filtered: N out-of-scope (reason)` | None |

## Examples

**x-review APPROVE, no decisions:**
```
✓ APPROVE — 0 bugs · 3 filtered (style/perf)
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [N] done
```

**x-review REQUEST_CHANGES, 1 HIGH needing decision:**
```
⚠ DECIDE #2: Tool call cards may show wrong results when two tools run at once. Slow them down (safe, slight delay) or accept occasional wrong cards (fast, subtle bug)?
Axis: impl · Severity: HIGH

[A] Serialize tool calls — users never see wrong data; slight delay for concurrent tools
[B] Accept race — fastest path; ~5% chance of wrong card shown

→ Recommended: A
Reply: `2: A`

---
REQUEST_CHANGES — 1 HIGH · 2 MEDIUM · 2 filtered (style)
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [N] done
```

**x-do DONE:**
```
✓ DONE: x-do Mode B — RBAC implemented, 3 roles across 47 files
- admin / editor / viewer roles; auth middleware updated
- All existing tests pass; tsc clean

Next → [A] commit · [B] x-review · [N] done · [L] save as skill
```
