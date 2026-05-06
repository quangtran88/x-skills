# x-guide — Progressive Comprehension-Gated Tutor

> **Purpose:** Turn complex inputs (file, function, directory, PRD, plan, spec, URL, pasted prose, or vague feature name) into a progressive, resumable walkthrough. Produces `.x-guide/<slug>/GUIDE.md` and walks the user one part at a time with a menu-driven command loop.

---

## Workflow (5 Phases)

```
1. DETECT
   ├─ Classify input: file / dir / url / paste / vague
   ├─ Compute kebab-case slug (collision-safe: append -2, -3, ...)
   └─ If .x-guide/<slug>/ exists → prompt resume / restart / new-slug (HALT)

2. INGEST
   ├─ vague target → x-research (multi-source synthesis)
   ├─ size > 50k tokens AND gemini_cli active → x-gemini ingest → _ingest.md
   └─ otherwise → Claude direct (no cache file)

3. OUTLINE
   ├─ Draft 5–15 parts ordered foundations → mechanics → edges
   ├─ Write GUIDE.md skeleton (full TOC + 1-line teasers + empty Part bodies)
   ├─ Write progress.json (initial state, current = 1)
   └─ Confirmation gate: [g] go / [a] adjust / [r] regenerate (HALT)

4. WALK (the core loop)
   ├─ Render current part (Part Template: What / Why / How / Mental model / Try it)
   ├─ Post menu: [n][b][s][d][l][e][q][j N][x] + 3 generated follow-ups
   ├─ Parse user command (free text → answer inline, do NOT advance)
   ├─ Mutate progress.json + GUIDE.md Roadmap checkboxes
   └─ Loop until all parts done/skipped, OR user types [x]

5. WRAP
   ├─ Mark progress.json.completed_at
   ├─ Append "Summary" to GUIDE.md (key takeaways, glossary, code refs)
   └─ Suggest 3 next guides (HALT for [c] close / [d] delete)
```

---

## Inputs

| Input form | Detection | Example |
|---|---|---|
| File path | exists + readable | `src/auth.ts` |
| Directory path | exists + is dir | `src/auth/` |
| URL | starts with `http(s)://` | `https://stripe.com/docs/api/payment_intents` |
| Pasted text | inline block in chat | PRD pasted in code fences |
| Vague feature name | no path/URL match | `"the auth flow"` |

---

## Outputs

```
.x-guide/<slug>/
├── GUIDE.md          # full TOC + lazily-rendered parts
├── progress.json     # state (status, current, level_used, timestamps)
└── _ingest.md        # ingest cache (only for x-gemini / x-research routes)
```

Recommend adding `.x-guide/` to `.gitignore` — guides are personal artifacts.

---

## Menu Commands (Phase 4)

| Cmd | Effect |
|---|---|
| `n` / `next` | mark current `done`, advance, render at `level=mid` |
| `b` / `back` | re-render previous part |
| `s` / `skip` | mark current `skipped`, advance |
| `d` / `deeper` | re-render same part with more technical depth |
| `l` / `simpler` | re-render same part with more analogy, less jargon |
| `e` / `example` | append a worked example to current body |
| `q` / `quiz` | 2 MCQs, grade, re-explain wrong sub-points |
| `j N` | jump to Part N (intermediate parts → `skipped`) |
| `x` / `exit` | flush state, print resume command, end |
| `1` / `2` / `3` | answer that follow-up inline (does NOT advance) |
| free text | answer inline (does NOT advance) |
| `rewrite outline` | regenerate TOC; preserve `done` parts by title match |

**Per-part depth decay**: every new part starts at `level=mid`. The user must signal `d` or `l` again per part if they want a different level.

---

## Capability Gates

| Capability | Used for | Fallback when missing |
|---|---|---|
| `gemini_cli` | Phase 2 ingest of large input | Claude direct; warn user once if size > 150k |
| `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` | Phase 2 vague-target via x-research | x-research falls back to repo-only `Agent(Explore)` lanes |
| `omo_plugin` + `oracle` | Optional `q deep` accuracy cross-check | Skip cross-check; continue without it |

Per-part teaching prose stays Claude-native regardless of capability set — pedagogy voice is the priority.

---

## Anti-Triggers

x-guide routes elsewhere when the user's intent is closer to:

| User intent | Route to |
|---|---|
| "Find me how X works across the codebase" (open investigation) | `x-research` |
| "Review this code / plan / PR" | `x-review` |
| "Debug / fix this bug" | `x-bugfix` |
| "Build / implement / execute this plan" | `x-do` |

---

## When to Use

- Onboarding a teammate (or yourself) to an unfamiliar file, module, or feature
- Internalizing a long PRD or spec one section at a time, with comprehension checks
- Walking through a complex code file (auth flow, payment pipeline, parser) without skimming over hard parts
- Building a personal study plan around a fuzzy topic (`"the x-shared capability loading flow"`)

---

## When NOT to Use

- You just want a one-line explanation → ask Claude directly, skip x-guide
- You need exhaustive multi-source research → use `x-research`
- You need to debug a failing test → use `x-bugfix`
- You're reviewing someone else's diff → use `x-review`
- The target is too small (< 5 parts of conceptual weight) → x-guide will offer to inline-explain instead

---

## State Persistence

Every command in Phase 4 writes back to `progress.json` and updates `GUIDE.md` Roadmap checkboxes. The user can leave at any time (typing `x` is the clean exit; closing the session is also safe — state is on disk). Re-invoking x-guide on the same target hits the resume prompt in Phase 1.

---

## See Also

- Design spec: [x-guide-design.md](x-guide-design.md)
- Implementation plan: [x-guide-plan.md](x-guide-plan.md)
- Skill source: `skills/x-guide/`
