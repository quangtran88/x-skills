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
[E] Split this fix off — fix this finding in this PR; defer the others (include only when 2+ unresolved findings exist)

→ Recommended: [A / B / C / D / E]
Reply: `[N]: A` (multiple answers OK in one message, e.g. `2: A`, `5: B`)
```

**Safety rules that MUST carry through into every DECIDE block:**
- axis = `security` or `compliance`: Option C MUST NOT say "keep as-is" or "ship dead gate." Replace option C text with: "Fix in immediate follow-up PR — tracker link required before this PR merges."
- Effort label (S/M/L): OMIT entirely when axis = security or compliance.
- [E] Split: include only when 2+ unresolved findings exist in the same review (omit for single-finding reviews — there's nothing to split off).
- **Decider footer (always append, axis-aware — from `../x-review/steps/step-03-synthesize.md` axis table):**
  - axis = `impl`: `Decider: implementer`
  - axis = `security`: `Decider: security owner + implementer`
  - axis = `product`: `Decider: product owner — implementer should not pick alone.`
  - axis = `compliance`: `Decider: owner of contract (legal / security / PM)`
  - mixed-axis finding: `Decider: mixed — list each axis's decider explicitly`

## Passes Line (x-review only)

Replaces the 8-line verbatim passes menu block. Emit on one line after the verdict summary.

```
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [A]ll · [N] done
```

Letter assignments are fixed (same as `../x-review/references/review-passes.md`) — do NOT redefine. [P]/[C]/[D] are scope-expanders. If user picks [A] All, confirm once before launching: "All passes includes refactor + perf suggestions beyond bugs/security — proceed?"

## Follow-up Options Line (x-review NEEDS_DIRECTION only)

Replaces the 6-line verbatim follow-up menu. Emit on one line after the last DECIDE block.

```
→ [Y] all recommended · [M] manual · [R] review-only · [K] skip flagged · [Z] re-dispatch · [N] done
```

Letter assignments are fixed — do NOT redefine. Branching logic for each letter is unchanged from `../x-review/steps/step-04-act.md § Clarification Gate`. Letters chosen to avoid collision with Shape 3 ([A][B][C][D][E]) and Passes ([S][P][C][X][V][D][A]) — `[N]` means "done / stop" in every menu it appears in.

## Letter Namespace Map

Letters are scoped to one menu each; no letter is reused with different meaning across menus.

| Menu | Letters | Reply form |
|------|---------|-----------|
| Shape 3 DECIDE (per-finding) | `[A][B][C][D][E]` | `<finding#>: A` (e.g. `2: A`) |
| Passes line (review code paths) | `[S][P][C][X][V][D][A][N]` | bare letter (e.g. `S`) |
| Follow-up line (procedural route) | `[Y][M][R][K][Z][N]` | bare letter (e.g. `Y`) |

`[N] = done / stop` is the only letter that carries the same meaning in two menus (Passes and Follow-up); never use `N` for anything else.

## Suppression Rules

| Element | Default | Override |
|---------|---------|----------|
| Handoff context block (final After-This-Skill output) | Suppressed | Include only when next skill explicitly requires it, OR when the Clarification Gate branched through `[R]` Review-only / `[K]` Skip-flagged / `[N]` Done / Lock-direction / Skipped-finding states — those branches still REQUIRE emission |
| Progress banners ("Step N of M — Next: X") | Suppressed | Never include in output |
| Learner hook multi-line block | Compressed to `· [L] save as skill` in Next line | None |
| Plan-mode envelope (`<!-- x-review plan-mode envelope v1 -->`) | Always emit AFTER human-readable block | Never suppress |
| Out-of-scope filtered count | One line: `Filtered: N out-of-scope (reason)` | None |

## Examples

**x-review APPROVE, no decisions:**
```
✓ APPROVE — 0 bugs · 3 filtered (style/perf)
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [A]ll · [N] done
```

**x-review REQUEST_CHANGES, 1 HIGH needing decision:**
```
⚠ DECIDE #2: Tool call cards may show wrong results when two tools run at once. Slow them down (safe, slight delay) or accept occasional wrong cards (fast, subtle bug)?
Axis: impl · Severity: HIGH

[A] Serialize tool calls — users never see wrong data; slight delay for concurrent tools
[B] Accept race — fastest path; ~5% chance of wrong card shown

→ Recommended: A
Decider: implementer
Reply: `2: A`

---
REQUEST_CHANGES — 1 HIGH · 2 MEDIUM · 2 filtered (style)
Passes: [S]ec [P]erf [C]omplex [X]cross [V]isual [D]eslop · [A]ll · [N] done
→ [Y] all recommended · [M] manual · [R] review-only · [K] skip flagged · [Z] re-dispatch · [N] done
```

**x-do DONE:**
```
✓ DONE: x-do Mode B — RBAC implemented, 3 roles across 47 files
- admin / editor / viewer roles; auth middleware updated
- All existing tests pass; tsc clean

Next → [A] commit · [B] x-review · [N] done · [L] save as skill
```
