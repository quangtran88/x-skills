# x-mindful — Pre-Implementation Impact Gate

> **Role:** *(not declared)*
> **Purpose:** Walk the user through high-impact decisions in a plan or spec — one item at a time — before any code is written.

---

## When It Triggers

| Signal | Action |
|--------|--------|
| User invokes `/x-skills:x-mindful` directly | Run on the referenced plan/spec |
| `x-do` Mode A detects a high-risk plan (auto-invocation) | Hand off to `x-mindful` before execution |
| User pastes a PRD/RFC/spec and asks for a "sanity check" | Run extract → rank → walk |

---

## Pipeline

1. **Extract** — Scan the input for items in four categories:
   - **ARCH** — architectural decisions (new module, schema change, dependency change)
   - **BREAK** — backwards-incompatible changes (API, schema, config, behavior)
   - **SEC** — security / auth / permission impacts
   - **PERF** — performance / cost / resource shifts
2. **Rank** — Score each item by `severity × blast_radius × (1 / reversibility)`. Higher score = walked first.
3. **Walk** — Present items one at a time with a `confirm / modify / reject / skip` menu. Capture decisions.
4. **Emit** — Produce a decision envelope (JSON) downstream skills (`x-do`, `x-team`) consume to gate execution.

---

## Outputs

- One-screen impact summary up front (count per category, highest-severity items).
- Per-item dialog with rationale and the user's verdict.
- Decision envelope persisted in the conversation for downstream skills.
- Suggested handoffs (`/x-research` for unanswered questions, `/x-do` to proceed).

---

## Capability Notes

- Standalone — no external dependencies required.
- Better with `opencode` and `x-gemini` for second-opinion review on ranked items.

---

## Source

- Skill source: [`skills/x-mindful/SKILL.md`](../../skills/x-mindful/SKILL.md)
