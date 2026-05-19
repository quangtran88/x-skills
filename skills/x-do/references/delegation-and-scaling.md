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

## Depth Calibration — REMOVED

This section previously held the `gitnexus impact` counts→ceremony grounding gate. It has been removed along with the Depth Calibration section in `../SKILL.md`. Routing is now governed by the **3-axis Routing Signals** in `../SKILL.md § Routing Signals` (Mode + Task count + Walk-away signal) — no scoring, no grounding gate, no ceremony ladder.

`gitnexus impact` remains available for manual escalation (e.g., the user asks "what calls this function?") but is no longer auto-invoked during x-do dispatch. The x-mindful envelope consumption rule (Mode A handoff — do NOT re-invoke `impact` on already-analyzed symbols) is preserved as a cheap dedup, not as a routing input.
