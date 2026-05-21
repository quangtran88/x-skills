# x-mindful — Gotchas

Known failure patterns. Update when you encounter new ones.

## Extraction Phase

- **Code-level details slipping in.** The #1 v2 failure: extractor returns items that name functions, fields, params, or files. Strip those at extraction time. If extraction repeatedly returns code-level items, re-prompt with the failure-recovery template in `references/extraction-prompts.md`. Architect-level only — the human is reviewing direction, not implementation.
- **Plan re-summarization instead of impact extraction.** Bullet-listing what the plan already says is a common failure. Each item must surface what the plan does NOT make obvious — the silent tradeoff, the unstated assumption, the missing blind spot, the future-debt narrative.
- **Hallucinated items.** If a category has no real signal (e.g., a UI tweak plan with no tradeoffs), do not invent an item to fill the slot. Empty categories are fine. Target 5-12 high-signal items, not 30 padded ones.
- **Best-practice reminders that don't belong.** "Make sure to add input validation" is not an item — AI follows common best practice in implementation. The human reads plan-level direction.
- **Missing the "no API change" lie.** Plans often claim "internal refactor, no API change" while moving exported symbols or changing event shapes. Extraction MUST verify crossed boundaries even when the plan denies it. The BLIND-SPOT category captures "no deprecation story" when this happens.
- **Tool-output drift in extraction.** When delegating to oracle / `--model codex`, give them the exact item schema (`references/item-schema.md`), the no-code-level rule, and a JSON-only output contract. Free-form prose merges items and re-introduces identifiers.

## Filter Phase (Senior-Weigh-In)

- **Filter too lenient → drown the user.** If you produce more than 15 items after filter, the senior-weigh-in threshold is too loose. Re-apply more strictly — drop items where reasonable engineers would not disagree.
- **Filter too strict → empty queue.** If zero items survive, render a "no senior-grade decisions found — direction looks routine" message and offer `--no-filter` recovery. Don't fail silently.
- **Filtering by severity alone.** `senior_weigh_in` is independent of severity. A LOW-severity item can still qualify if it's a one-way door; a HIGH-severity item that's purely local doesn't.

## Ranking Phase

- **Severity inflation.** Marking everything CRITICAL defeats the gate. The rubric requires at least one of: data loss / auth bypass / public-contract break / one-way migration / cross-tenant leak / vendor lock-in on a mission-critical path to qualify as CRITICAL. > 30% CRITICAL = re-rank with stricter gating.
- **Reversibility overlooked.** A medium-severity but one-way item (e.g., publishing an event consumed by others) outranks a high-severity reversible one (e.g., a behind-a-flag rollout). Always compute the full score, do not anchor on severity alone.
- **Code-level scope_note.** `scope_note` should be a 1-line architect narrative ("affects 3 downstream consumers and the UI read path"), not a file/caller count alone. Numbers without narrative are code-level.

## Walkthrough Phase

- **Skipping the "Plan at Architect Level" opener.** Phase 4 must open with the 5-bullet framing BEFORE the per-item loop. Without it, individual items feel disconnected and the user can't tell what the overall direction is.
- **Batching items.** "Confirm / Modify / Reject / Skip per item." Do NOT collapse the walkthrough into a single Go/No-Go list. One item per turn, wait for user reply.
- **Skipping the menu render.** Phase 4 must show the menu after every item, even when user is fast — the gate is the point. If user types "confirm all", treat that as explicit override and confirm remaining queue, but echo each item title in the next turn.
- **Forgetting the modification text.** When user picks `m`, capture their replacement text verbatim into the decision map — do not paraphrase.
- **Auto-advance on no-answer.** If user does not respond, do not auto-confirm. Stop the loop and surface the partial envelope with `[paused]` markers.
- **Rendering empty optional sections.** Per-item render must omit sections whose underlying field is empty. Don't show an empty "TRADEOFF IT PICKED" header for an ASSUMPTION item.
- **Code identifiers in render.** If extraction sneaked one in despite Step-02 filters, strip at render time and add `[code-detail stripped]` marker. Don't pass it through to the user.

## Auto-Gate from x-do

- **Trigger keyword false positives.** "Migration" appears in framework names (e.g., "EntityFramework migration"). "Pattern" appears in "design pattern docs". Confirm the keyword is in the plan's intent, not a noun referring to existing tooling. When unsure, run x-mindful — over-gating is cheaper than missed-gating.
- **Plan-review interaction.** x-mindful runs BEFORE plan review (cross-model review). If x-mindful rejects items, the plan is revised, and THEN plan review runs on the revised plan. Don't double-gate the original plan.
- **Mechanical-batch exception.** When x-do classifies the work as a mechanical batch (same change across N files, no architectural decision), x-mindful is overkill. Skip the gate, let the batch run.
- **Broadened v2 keyword list.** The v2 auto-gate triggers on architectural-decision keywords (`architecture`, `RFC`, `pattern`, `tradeoff`) and operational signals (`SLO`, `runbook`, `pager`) that v1 missed. Expect more gates to fire on design docs.

## Envelope Hand-off

- **Envelope drift.** The envelope is a contract with x-do. Section headers (`Confirmed / Modified / Rejected / Skipped / Pending`) are stable across v1 and v2. The `<!-- taxonomy: v2 -->` marker signals new item id prefixes. Don't rename section headers without coordinating with x-do.
- **Item titles with code identifiers.** Envelope item titles are architect-level — same hard rule as extraction. If a v1 envelope or carry-over had code-level titles, re-cast on the v2 path.
- **Modify without revising the plan.** When an item is `modify`, x-do MUST revise the plan file before plan review. Surfacing the modification only in the envelope and proceeding silently breaks the gate.

## Persistence

- **Default is transient.** Do NOT auto-write `.x-mindful/<slug>/` on every run. Only when the user explicitly asks to save. Otherwise the envelope lives in conversation only.
- **Slug collisions.** If saving, derive the slug from the source plan path or a short hash of pasted content. Two simultaneous "review-this-plan" runs against unrelated specs must not overwrite each other.
- **v1 IMPACTS.md carry-over.** If loading a prior IMPACTS.md with v1 categories (ARCH/BREAK/SEC/PERF), translate at load time: ARCH → TRADEOFF, BREAK → BLIND-SPOT (when no deprecation story), SEC → BLIND-SPOT (when no threat model), PERF → SHAPE (when about scaffolding) or FUTURE-DEBT (when about cost curve). Re-cast titles at architect level.

## Capability-Set Edge Cases

- **No opencode available.** Use claude-direct extraction with `subagent_type: Explore` for evidence gathering. Note in the envelope that depth-of-analysis was reduced — do not silently degrade the rubric.
- **Spec too large for one Claude turn.** Route to gemini (`x-gemini`) for ingest, then summarize per category back into Claude for ranking. Do not chunk-and-merge inside x-mindful itself — call the right tool.
- **No GitNexus.** Blast-radius / surface scoring falls back to plan-text heuristics. `scope_note` becomes a judgment call rather than a graph-derived count. Flag the routing decision inline.
- **agentmemory two-tier dependency.** When wiring agentmemory calls in this skill, the standalone-vs-proxy mode behavior is canonical in `../x-shared/capability-loading.md § Shared agentmemory.server_up Probe` and `../x-shared/mcp-toolbox.md § agentmemory`. Do not duplicate; do not work around the capability gate.
