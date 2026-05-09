# x-mindful — Gotchas

Known failure patterns. Update when you encounter new ones.

## Extraction Phase

- **Plan re-summarization, not impact extraction.** A common failure is bullet-listing what the plan already says. x-mindful must surface what the plan does NOT make obvious — second-order effects, hidden contracts, dependent callers, performance cliffs. If an item just rephrases a plan line, drop it.
- **Hallucinated items.** If a category has no real signal (e.g., the plan touches no auth code), do not invent a SEC item to fill the slot. Empty categories are fine.
- **Missing the "no API change" lie.** Plans often claim "internal refactor, no API change" while moving exported symbols. Extraction MUST grep for exports / public surface even when the plan denies it.
- **Tool-output drift in extraction.** When delegating to oracle / `--model codex`, give them the exact item schema (`references/item-schema.md`) and a JSON-only output contract. Free-form prose merges items.

## Ranking Phase

- **Severity inflation.** Marking everything CRITICAL defeats the gate. The rubric requires at least one of: data loss / auth bypass / public contract break / irreversible migration to qualify as CRITICAL.
- **Reversibility overlooked.** A medium-severity but irreversible item (e.g., dropping a column) outranks a high-severity reversible one (e.g., changing an internal function signature). Always compute the full score, do not anchor on severity alone.
- **Blast-radius from imports only.** `grep -r` import counts undercount runtime callers (reflection, dynamic dispatch, cross-service). Note the limitation in the item evidence rather than reporting a falsely-precise number.

## Walkthrough Phase

- **Batching items.** The user said "Confirm / Modify / Reject / Skip per item". Do NOT collapse the walkthrough into a single Go/No-Go list. One item per turn, wait for the user reply.
- **Skipping the menu render.** Phase 4 must show the menu after every item, even when user is fast — the gate is the point. If the user types "confirm all", treat that as an explicit override and confirm the remaining queue, but echo each item title so they see what they accepted.
- **Forgetting the modification text.** When user picks `m`, capture their replacement text verbatim into the decision map — do not paraphrase it.
- **Auto-advance on no-answer.** If the user does not respond, do not auto-confirm. Stop the loop and surface the partial envelope with `[paused]` markers.

## Auto-Gate from x-do

- **Trigger keyword false positives.** "Migration" appears in framework names (e.g., "EntityFramework migration"). Confirm the keyword is in the plan's intent, not a noun referring to existing tooling. When unsure, run x-mindful — over-gating is cheaper than missed-gating.
- **Plan-review interaction.** x-mindful runs BEFORE plan review (cross-model review). If x-mindful rejects items, the plan is revised, and THEN plan review runs on the revised plan. Don't double-gate the original plan.
- **Mechanical-batch exception.** When x-do classifies the work as a mechanical batch (same change across N files, no architectural decision), x-mindful is overkill. Skip the gate, let the batch run.

## Envelope Hand-off

- **Envelope drift.** The envelope is a contract with x-do. Renaming sections or fields breaks the consumer. If you change the schema, bump `x-mindful-envelope vN` and update x-do Mode A in the same change.
- **Modify without revising the plan.** When an item is `modify`, x-do MUST revise the plan file before plan review. Surfacing the modification only in the envelope and proceeding silently breaks the gate.

## Persistence

- **Default is transient.** Do NOT auto-write `.x-mindful/<slug>/` on every run. Only when the user explicitly asks to save. Otherwise the envelope lives in conversation only.
- **Slug collisions.** If saving, derive the slug from the source plan path or a short hash of pasted content. Two simultaneous "review-this-plan" runs against unrelated specs must not overwrite each other.

## Capability-Set Edge Cases

- **No opencode available.** Fall back to claude-direct extraction with `subagent_type: Explore` for evidence gathering. Do not silently degrade the rubric — note in the envelope that depth-of-analysis was reduced.
- **Spec too large for one Claude turn.** Route to gemini (`x-gemini`) for ingest, then summarize per category back into Claude for ranking. Do not chunk-and-merge inside x-mindful itself — call the right tool.
