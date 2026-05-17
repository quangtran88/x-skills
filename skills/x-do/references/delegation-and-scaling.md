# Proactive OMO Delegation & Complexity Scaling

## Proactive OMO Delegation

During execution, Claude should autonomously delegate to OMO agents when it detects these signals — do not wait for the user to ask:

| Signal | Delegate To | Why |
|---|---|---|
| 2+ failed fix attempts on the same issue | `oracle` | Fresh perspective, different model reasoning |
| Implementation stalled (see iteration-patterns.md §2 escalation ladder) | `oracle` at 5, `--model codex` if oracle insufficient (replaces UNAVAILABLE `hephaestus`) | Different model, different approach |
| Quick API syntax question mid-implementation | `context7` or `deepwiki` MCP directly | 5s lookup vs. 30-60s agent spawn. Use context7 for library API docs, deepwiki for repo internals |
| Comprehensive library understanding needed | `librarian` | Multi-source research with GitHub permalinks. Use when quick lookup isn't enough |
| Architecture uncertainty blocking a design choice | `oracle` | Read-only strategic advice |
| Complex multi-file change with unclear blast radius | `oracle` | Risk assessment before proceeding |

**Rules for proactive delegation:**
- Only delegate substantial work — not simple lookups Claude can do with Grep/Read
- State why you're delegating: "I've tried X twice without success, getting a second opinion from oracle"
- Return to the main execution flow after incorporating the agent's advice
- Do NOT delegate and then repeat the same work yourself — trust the agent's output

## Complexity Scaling

Scale ceremony to match the task:

| Signal | Less Ceremony | More Ceremony |
|--------|--------------|---------------|
| Single file change | Skip brainstorming, direct execute | — |
| 2-5 files | Brief brainstorm, light plan | — |
| 5+ files | — | Full brainstorm + detailed plan |
| Cross-module | — | Full pipeline + OMO plan review |
| Mechanical batch (same pattern repeated across N files) | Direct execution, plan review optional, post-impl review still required | — |
| Security-sensitive | — | Add `security-reviewer` pass |

## Depth Calibration — gitnexus grounding gate (counts → ceremony)

The Depth Calibration heuristic table in `../SKILL.md` § "Depth Calibration" is the default. An OPTIONAL grounding step bumps the heuristic ceremony level using **raw gitnexus impact counts** (never the `risk` label — C1). This table is the canonical counts→ceremony mapping referenced from that section.

**Gate (ALL must hold, else heuristic path unchanged):**

| Condition | Requirement |
|---|---|
| Mode | ∈ {A, B, F} — never D, never C (no `impact` call ever fires on D or C) |
| Named-symbol set | non-empty via ONE pinned mechanism: Mode A = plan-file symbols; Mode F = refactor-prompt symbols; Mode B = handoff-envelope symbols OR backtick identifiers resolving to existing graph nodes (Mode B greenfield with no resolvable existing symbol ⇒ gate OUT) |
| Task 1 gate | "pinned + indexed + fresh" read from the shared session-pinned probe (`../../x-shared/capability-loading.md`); `impact` is correctness-sensitive per `../../x-shared/mcp-toolbox.md` use-class index → stale hard-degrades OUT |
| C5 dedup | symbols already covered by a `<!-- x-mindful-envelope v1 -->` item are NOT re-grounded (surface `[covered]`, do not call `impact`) |

**Counts → ceremony bump** (depth-1 caller count + affected-process count ONLY, taken from `gitnexus impact` on the gated-in symbols — never the `risk` field):

| Depth-1 callers | Affected processes | Effect on heuristic ceremony level |
|---|---|---|
| 0 | 0 | No bump — heuristic level stands |
| ≥1 and <20 | ≥1 and <3 | Bump one level: Light → Standard, Standard → Heavy |
| ≥20 | ≥3 | Bump to Heavy (clamp — never exceeds Heavy) |

A bump is applied at most once (the higher of the caller-driven and process-driven row wins; Heavy is the ceiling). The heuristic majority-column score still computes first; this only raises it, never lowers it.

**Surfaced line** (see `../SKILL.md` § "Depth Calibration" for the exact byte format): `Depth grounding: gitnexus.impact (N callers, M processes) [direct] symbols=[…]` when self-grounded; `Depth grounding: x-mindful envelope [covered] symbols=[…]` when the symbol set was already analyzed by x-mindful; `Depth grounding: heuristic` (no `symbols=` field) when gated out.
