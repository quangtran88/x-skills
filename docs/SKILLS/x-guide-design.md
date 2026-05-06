# x-guide — Design Spec

**Status**: design approved, pending implementation
**Date**: 2026-05-06
**Owner**: x-skills plugin
**Slug source**: brainstorming session 2026-05-06

## 1. Purpose

`x-guide` turns complex inputs into progressive, comprehension-gated tutorials. The user gives a target (file, function, directory, PRD, plan, spec, URL, pasted prose, or vague feature name); `x-guide` produces a `GUIDE.md` with a full table of contents and walks the user through one part at a time. Progress persists per-project so the user can leave and resume.

Differentiator vs `Lum1104/Understand-Anything`: lighter, broader inputs (not just codebases), markdown + chat (no graph viewer / dashboard), enforces linear comprehension gating instead of free graph exploration.

## 2. Inputs

| Input form | Detection | Example |
|---|---|---|
| File path | exists + readable | `src/auth.ts` |
| Directory path | exists + is dir | `src/auth/` |
| URL | starts with `http(s)://` | `https://stripe.com/docs/...` |
| Pasted text | inline block in user message | PRD pasted into chat |
| Vague feature name | none of above match a real path/URL | `"the auth flow"` |

## 3. Workflow — five phases

```
Phase 1: DETECT  → classify input type, compute topic slug, handle resume
Phase 2: INGEST  → route to gemini / x-research / claude based on size + clarity
Phase 3: OUTLINE → write full TOC + 1-line teasers to GUIDE.md, init progress.json
Phase 4: WALK    → loop: render part → menu → command → advance/branch
Phase 5: WRAP    → mark complete, write summary, suggest next topic
```

### 3.1 Phase 1 — DETECT

1. Classify input type (table above).
2. Compute slug: `kebab-case(topic)` from filename, first heading, or user-supplied label. Collisions append `-2`, `-3`, ...
3. If `.x-guide/<slug>/` already exists → **prompt user**: `resume from part N` / `restart from scratch` / `start a new topic with different slug`. Never auto-resume.
4. On `bad input` (missing file, 404 URL, empty paste) → fail fast, no directory created.

### 3.2 Phase 2 — INGEST

Routing tree:

```
detect_input(target)
├─ vague-target → x-research → cache to _ingest.md
├─ size > 50k tokens OR whole-dir
│   ├─ gemini_cli active → x-gemini ingest → _ingest.md
│   └─ else            → Claude direct (warn user if >150k tokens)
└─ size ≤ 50k → Claude direct, no _ingest.md cache
```

**Why x-gemini for large local input, not always x-research?**
`x-research` is multi-source synthesis (web + repo + MCP). For known-local large input, that is overkill. `x-gemini` handles single-source long-context ingest cheaply (1M context, gemini-3.x). `x-research` already wraps `x-gemini` internally for vague-target lanes.

**Stale ingest**: if source `mtime` is newer than `_ingest.md`, prompt re-ingest or keep cached.

### 3.3 Phase 3 — OUTLINE

- Generate 5–15 parts ordered for progressive build-up: foundations → mechanics → edges.
- Write `GUIDE.md` skeleton: TOC + 1-line teaser per part + empty `## Part N` placeholders (content lazy).
- Init `progress.json` (schema in §5).
- Show TOC to user. Ask: start now, or adjust outline first?

### 3.4 Phase 4 — WALK (the core loop)

Per-part render template (written to `GUIDE.md` and shown in chat):

```markdown
## Part N: <title>

> 📍 Part N of M · Level: <mid|deeper|simpler>

### What
<2-4 sentence plain explanation. Concrete, no jargon dump.>

### Why it matters
<1-2 sentences tying back to user's stated goal.>

### How it works
<step-by-step or annotated code/diagram. Mermaid where useful.>

### Mental model
<1 metaphor or analogy. Skip if forced.>

### Try it (optional)
<small exercise: "predict what happens if X" or "find Y in the file">
```

After rendering, Claude posts a **menu in chat** (not in file):

```
What next?
  [n] next part        [b] back        [s] skip
  [d] deeper           [l] simpler     [e] more example
  [q] quiz me          [j N] jump to part N
  [x] exit (resume later)

Or pick a follow-up:
  1. <generated Q1 specific to this part>
  2. <generated Q2>
  3. <generated Q3>

Or type any question.
```

**Command handlers**

| Cmd | Effect |
|---|---|
| `n` / `next` | mark part `done` in `progress.json`, render Part N+1 at level `mid` |
| `b` | render previous part |
| `s` | mark `skipped`, advance |
| `d` / `deeper` | re-render same part with `level=deeper` (more technical, internals) |
| `l` / `simpler` | re-render with `level=simpler` (more analogy, less jargon) |
| `e` | append worked example to current part |
| `q` | generate 2–3 MCQ on current part, grade answers, then offer `next` |
| `j N` | jump to part N (mark intermediate parts as `skipped`) |
| `x` | flush `progress.json`, print resume command, end |
| follow-up `#` / free text | answer inline; do NOT advance; re-show menu |

**Adaptive depth**: per-part decay. Each new part starts at `mid`. User must signal `d` / `l` again per part if they want adjustment. Decision: never sticky — forces re-signal so we never run away from where the user is.

**Quiz grading**: Claude grades its own MCQs. Wrong answer → re-explain the weak sub-point before allowing `next`. Right answer → offer `next`.

### 3.5 Phase 5 — WRAP

- Mark `progress.json.completed_at`.
- Append a "Summary" section to `GUIDE.md` covering key takeaways.
- Suggest related guides (other files in same module, dependent specs, linked docs).

## 4. File layout

Per-topic, in repo root (project-local, not user-global):

```
.x-guide/
└── <topic-slug>/
    ├── GUIDE.md          # the tutorial — full TOC + parts (some empty until walked)
    ├── progress.json     # state
    └── _ingest.md        # cached ingest output (gemini / research / raw)
```

**`.gitignore` recommendation**: add `.x-guide/` — guides are personal artifacts, not source. Setup script (or skill on first use) suggests this.

`GUIDE.md` layout:

```markdown
# x-guide: <topic title>

Source: <ref>  ·  Started: <date>  ·  Slug: <slug>

## Roadmap
- [ ] Part 1 — Token shape · *teaser line*
- [x] Part 2 — Verify path · *teaser line*
- [ ] Part 3 — Refresh · *teaser line*

---

## Part 1: Token shape
<full content — written when user reaches part>

## Part 2: Verify path
<full content>

## Part 3: Refresh
*Not yet generated. Reach this part to expand.*
```

Roadmap checkboxes stay synced with `progress.json` on each `next`.

## 5. State schema (`progress.json`)

```json
{
  "slug": "auth-flow",
  "source": {
    "type": "file|dir|url|paste|vague",
    "ref": "src/auth.ts",
    "ingest_method": "claude-direct|x-gemini|x-research",
    "ingested_at": "2026-05-06T20:14:00Z"
  },
  "parts": [
    {"n": 1, "title": "Token shape", "status": "done",     "level_used": "mid",    "completed_at": "..."},
    {"n": 2, "title": "Verify path", "status": "done",     "level_used": "deeper", "completed_at": "..."},
    {"n": 3, "title": "Refresh",     "status": "current",  "level_used": null,     "completed_at": null},
    {"n": 4, "title": "Edge cases",  "status": "pending",  "level_used": null,     "completed_at": null}
  ],
  "current": 3,
  "started_at": "2026-05-06T20:00:00Z",
  "completed_at": null,
  "level_default": "mid",
  "version": 1
}
```

**Status values**: `pending` / `current` / `done` / `skipped` / `revisit`.

## 6. Capability gates

Per `skills/x-shared/capability-loading.md`. Read once at session start from the `[x-skills/capabilities]` SessionStart line; do not re-check per dispatch.

| Capability | Used for | Fallback when missing |
|---|---|---|
| `gemini_cli` | Phase 2 ingest of large input | Read into Claude directly; warn if >150k tokens |
| `mcp.perplexity` / `mcp.exa` / `mcp.deepwiki` | Phase 2 vague-target via x-research | Claude `Agent(Explore)` searches repo only |
| `omo_plugin` + `oracle` | Optional `q deep` accuracy cross-check | Skip cross-check, note in part footer |

Per-part generation stays Claude-native (pedagogy voice matters most). Oracle/GPT only on user-triggered deep verification.

## 7. Skill structure

Hybrid layout (#3 from approaches):

```
skills/x-guide/
├── SKILL.md             # router — phase dispatch, menu, frontmatter
├── ingest-routing.md    # Phase 2 detail — gemini vs claude vs research
├── walkthrough-loop.md  # Phase 4 detail — menu commands, adaptive depth, follow-ups
└── progress-state.md    # slug rules, dir layout, resume logic
```

Frontmatter triggers (`SKILL.md`): "explain", "guide me through", "teach me", "walk me through", "help me understand", "onboard me to", combined with a target.

Anti-triggers (delegates instead): pure research → `x-research`; review → `x-review`; bug → `x-bugfix`.

Diagrams default to mermaid (renders in most markdown viewers). No ASCII fallback in v1.

## 8. Edge cases

- **Stale ingest** — source `mtime` newer than `_ingest.md` → prompt re-ingest.
- **Slug collision** — same target re-invoked → resume prompt (§3.1). Different target colliding on slug → append `-2`.
- **Outline mid-flight edit** — user types "rewrite outline" → regenerate TOC; preserve `done` parts by title match; mark new parts `pending`.
- **Bad input** — file unreadable / URL 404 / paste empty → fail fast, no `.x-guide/` dir.
- **Oversized rendered part** — auto-split into sub-parts when >8k tokens.
- **No network** — `x-research` / `x-gemini` unavailable → fallback chain (§6). Never block.
- **Wrong quiz answer** — re-explain weak area before `next`.
- **Exit/resume** — `x` flushes state, prints `/x-skills:x-guide --resume <slug>`.

## 9. Out of scope (v1, YAGNI)

- Web dashboard / GUI viewer
- Multi-user shared progress
- Audio / video generation
- Auto-translation
- Spaced repetition / scheduled re-quiz
- Knowledge graph visualization (Understand-Anything territory — explicit non-goal)
- Cross-topic linking ("see also Part 3 of other-guide")
- User-global guides (`~/.x-guide/`) — project-local only in v1

## 10. Open questions

None at design time. All decisions logged in §3–§9.

## 11. Implementation skeleton (informational — for plan phase)

- `skills/x-guide/SKILL.md` — frontmatter, phase dispatch, capability bootstrap call
- `skills/x-guide/ingest-routing.md` — input classification, size estimation, dispatch matrix, `_ingest.md` cache rules
- `skills/x-guide/walkthrough-loop.md` — menu rendering, command parser, adaptive level rules, follow-up question generation, MCQ generator + grader
- `skills/x-guide/progress-state.md` — slug computation, `progress.json` schema validation, roadmap-checkbox sync
- Update `.claude-plugin/marketplace.json` and `.claude-plugin/plugin.json` to register `x-guide`
- Update `package.json` skill list and `bin/setup` capability checks if any new dependency
- Update root `CLAUDE.md` skills table and `docs/SKILLS_OVERVIEW.md`
- No new external CLI dependency required (gemini already gated, no fresh tooling)
