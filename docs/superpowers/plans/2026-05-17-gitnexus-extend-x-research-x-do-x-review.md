# GitNexus Integration — Extend to x-research / x-do / x-review

**Status:** revised post-plan-review (REQUEST_CHANGES → F1/F2/F3 resolved; ARCH-002 + ARCH-003 closed)
**Date:** 2026-05-17
**Predecessor:** `docs/superpowers/plans/2026-05-16-gitnexus-optional-integration.md` (shipped in v1.10.0 — wired `mcp.gitnexus` into `x-mindful` + `x-api-pentest`)
**Scope:** Generalize the established gitnexus-optional pattern to three more router skills, with source-verified guardrails.

---

## Why (evidence-grounded)

Source audit of `research/abhigyanpatwari/GitNexus/` confirms gitnexus is real static analysis, not heuristics:

- `impact` is a bounded BFS over a typed call graph (`gitnexus/src/mcp/local/local-backend.ts:2751-2801`) — per-edge confidence, cycle-safe, direction-aware, process/module enrichment.
- `query` is hybrid BM25 + vector via RRF (`ARCHITECTURE.md:469`), process-grouped — a strict upgrade over morph keyword search **when the repo is indexed**.
- `detect_changes` maps live `git diff` hunks → indexed symbols → execution flows (`local-backend.ts:2161-2189, 2232-2248`) — a real delta over `git diff` (flow membership) that `git diff` cannot produce.

The value is **precision of structural facts**, NOT judgment. Three source-derived constraints become inviolable design rules below.

---

## Inviolable Design Constraints (derived from source — do NOT relax)

**C1 — Counts, not labels.** gitnexus risk labels are hardcoded threshold buckets (`detectChanges` risk: `0→low, ≤5→medium, ≤15→high, else critical` at `local-backend.ts:2255-2262`; `apiImpact` follows the same hardcoded-bucket pattern on a different scale — `<4→LOW, 4–9→MEDIUM, ≥10→HIGH` on consumer count, plus a one-level mismatch bump — at `:3736-3747`). Consume the raw counts (depth-1 callers, affected processes); map to skill-native ceremony/severity ourselves. NEVER surface or branch on gitnexus's `risk` field as authoritative.

**C2 — Static graph misses dynamic dispatch.** Tier-3 global resolution is confidence 0.5 (`ARCHITECTURE.md:391`); reflection / metaprogramming / string-keyed dispatch are under-resolved. `impact` has **false negatives**. Any reviewer/user-facing surfacing of impact MUST carry the disclaimer "static call graph — may miss dynamic dispatch." NEVER phrase a 0-caller result as "safe to change."

**C3 — Freshness gate, asymmetric by use class.** `detect_changes` reads live diff but maps against the *indexed* symbol ranges — a stale index produces **silently wrong** symbol/flow mappings, no error. The gate is `mcp.gitnexus` pinned **AND** target repo indexed **AND** index fresh — but freshness strictness depends on use class:
  - **Correctness-sensitive** (impact counts feeding x-do ceremony; detect_changes feeding scope check; x-review safety context): stale → **hard-degrade to fallback**. Do not use stale graph output.
  - **Advisory** (x-research `query`/`context` exploratory search): stale → **usable with a one-line staleness note**; stale search beats no search, user reads raw results.
  **Concrete signal (verified):** the `gitnexus list` (`list_repos`) response carries per-repo `staleness: { commitsBehind: number, hint?: string }` (`gitnexus/src/mcp/local/local-backend.ts:536, 578-579`; backed by `StalenessInfo { isStale, commitsBehind, hint? }` in `core/git-staleness.ts:14-17`). `staleness` ABSENT or `commitsBehind === 0` ⇒ fresh; present with `commitsBehind > 0` ⇒ stale. The single once-per-session `gitnexus list` probe (Task 2a) yields BOTH indexed-set membership AND freshness — no per-response key hunting.

**C4 — No ad-hoc branching.** Every gitnexus call routes through a Primary/Fallback row in `x-shared/mcp-toolbox.md`. Skills consult the table; they do not branch on `mcp.gitnexus` inline (the v1.10.0 pattern — keep it).

**C5 — Consume, don't re-run.** x-do Mode A already triggers x-mindful, which routes BREAK/ARCH through `gitnexus impact` during its run (surfacing a per-run `Impact source: gitnexus.impact | heuristic ranking` audit line at `skills/x-mindful/SKILL.md:33`, OUTSIDE the envelope) and emits a `<!-- x-mindful-envelope v1 -->` block (canonical emitter `skills/x-mindful/steps/step-05-handoff.md:9-39`). That block carries `**Source:**`, aggregate counts, and per-item `[<id>] <title> — severity: <SEV>` lines only — it does NOT carry a per-item `Impact source:` field or per-item blast-radius data. x-do MUST treat every symbol named in an envelope item as already-analyzed and NOT re-invoke `impact` on those symbols (a no-re-run dedup keyed on symbol membership, not a numbers-reuse).

---

## Plan-Review Resolutions (post-REQUEST_CHANGES, v1)

Cross-model plan review (Claude + GPT + Gemini) returned REQUEST_CHANGES with 3 HIGH plan-internal inconsistencies. User-directed resolutions, folded into the tasks below:

- **F1 (Finding #1 — Task 6.4 unmeasurable):** the grounding log lines (Task 3a/3b) now carry an explicit `symbols=[<comma-separated names>]` field. Task 6 step 4 greps that field. Resolution: **add `symbols=[…]` to the emitted line.**
- **F2 (Finding #2 — Task 4a depends on a class Task 1 never emits):** Task 1 now emits a single greppable **use-class index** covering BOTH the 4 new rows AND the v1.10.0 rows (`impact`, `detect_changes`, `route_map`/`api_impact`/`shape_check` → correctness-sensitive; `query`, `context` → advisory). This also closes the ARCH-002 "no single greppable index" gap.
- **F3 (Finding #3 — probe is x-research-only):** the once-per-session `gitnexus list` indexed+fresh probe is a **shared** step documented in `skills/x-shared/capability-loading.md`, consumed identically by x-research, x-do, and x-review. This closes the ARCH-003 divergence risk.

> **Reduced re-review follow-up (v2):** the F1/F3 fold introduced two verification-procedure inconsistencies, both fixed in Task 6 with a single correct patch each: (6.3) the fresh-index test must re-pin the shared probe after `gitnexus analyze` since F3 made it session-pinned; (6.4) the `symbols=` grep is scoped to non-heuristic (`[covered]`/`[direct]`-tagged) lines since heuristic lines carry no `symbols=` field by design.

> **Implementation-time follow-up (v3):** Task 1's original Verify line asserted `grep -c "Fallback"` increases by exactly the new-row count (4). This rests on a false premise about the canonical v1.10.0 table format — "Fallback" appears only as a column header / prose token, NEVER as a per-row cell, so 4 canonical rows add 0 "Fallback" lines and the grep delta is not a valid row-count proxy. Forcing +4 would require inventing a per-row "Fallback:" token, which the binding canonical-format constraint + regression guard (cross-model-review-locked) forbid. Verify line corrected below to a measurable form (count rows + zero v1.10.0 row deletions); the substantive 4-row deliverable is unaffected.

> **Post-impl code-review follow-up (v4):** the 3-model post-implementation review (Claude/GPT/Gemini) on the committed diff found 5 verified-real issues, all fixed inline: (A) x-review/SKILL.md Bootstrap never consumed the shared probe though step-01 assumed it (added the F3 consume clause mirroring x-do/x-research); (B) `../x-shared/…` refs in the nested files x-review/steps/step-01-prepare.md + x-research/references/prompt-templates.md resolved wrong — corrected to `../../x-shared/…`; (C) x-do "exactly one Depth grounding line" broke the mixed envelope-covered+self-grounded case — changed to one line per applicable grounding class so C5's Task 6.4 grep still sees both; (D) mcp-toolbox Capability gate vs Freshness gate contradiction on the advisory stale path — Capability gate now defers the freshness leg to the Freshness gate; (E) the v1.10.0 `rename` row was unclassified in the F2 use-class index though the index claims to classify every tool — `rename` added as correctness-sensitive (stale call graph → missed rename targets). The plan had under-enumerated the tool set as "7"; it is **8** (incl. `rename`).

---

## File Map

| File | Change |
|------|--------|
| `skills/x-shared/mcp-toolbox.md` | **Foundation.** Extend GitNexus section: freshness-aware gate, use-class asymmetry (C3), new rows for `query`/`context` exploratory + impact-counts-for-ceremony, **plus a use-class index (F2) covering new + v1.10.0 rows**. |
| `skills/x-shared/capability-loading.md` | **Foundation (F3).** Document the shared once-per-session `gitnexus list` indexed+fresh probe (derivation, session-pinned, NOT a `bin/setup` capability key). Consumed by x-research/x-do/x-review. |
| `skills/x-research/SKILL.md` | Bootstrap: consume the shared indexed+fresh probe (F3). Detection table: add gitnexus rows for local structural / symbol-context signals, morph fallback column. |
| `skills/x-research/references/prompt-templates.md` | Add gitnexus `query`/`context` invocation templates + staleness-note wording. |
| `skills/x-do/SKILL.md` | Bootstrap: consume the shared probe (F3). Depth Calibration: optional impact-counts grounding gated by discriminator (C1), grounding log line carries `symbols=[…]` (F1). Commit Recomposition: `detect_changes` scope check. Mode A: consume x-mindful envelope, do not re-run (C5). |
| `skills/x-do/steps/step-04-execute.md` | § Commit Recomposition holds the full recomposition procedure (per `SKILL.md:230-232`) — Task 3c's `detect_changes` scope check is wired HERE, not only in SKILL.md. |
| `skills/x-do/references/delegation-and-scaling.md` | Document the Depth Calibration discriminator gate + counts→ceremony mapping. |
| `skills/x-review/steps/step-01-prepare.md` | Bootstrap: consume the shared probe (F3). Optional blast-radius enrichment of changed symbols, gated, summarized (depth-1 only). |
| `skills/x-review/SKILL.md` | Scope Contract block: add the C2 disclaimer + the in-scope/out-of-scope fence for gitnexus-derived findings. |
| `CLAUDE.md` (project) | Update skill table: note x-research/x-do/x-review now gitnexus-aware (optional). |

No new dependencies. No changes to `bin/setup` (detectors already exist from v1.10.0).

---

## Prerequisites (mandatory before any task)

1. Re-read predecessor plan `2026-05-16-gitnexus-optional-integration.md` Tasks 6–7 — the mcp-toolbox row format and x-mindful gate wording are the canonical template; match them exactly.
2. Confirm the x-skills gitnexus index state with `gitnexus list` — it is currently stale (read the exact `commitsBehind` from that output; do NOT hardcode a count here, it drifts with every commit); the freshness gate (C3) MUST be exercised during verification against this real stale state, not a synthetic one.
3. Re-read the canonical envelope emitter `skills/x-mindful/steps/step-05-handoff.md:9-39` (schema-of-record; `skills/x-mindful/SKILL.md:87-112` shows an illustrative copy) before touching x-do Task 3 — the consume contract (C5) keys on the `<!-- x-mindful-envelope v1 -->` markers and the per-item `[<id>] <title>` lines, NOT on any blast-radius or in-envelope `Impact source:` field (neither exists inside the envelope).
4. Re-read `skills/x-review/SKILL.md:11-35` (Scope Contract) before Task 4 — gitnexus must sharpen in-scope findings only, never become a scope-creep vector.

---

## Task 1 — Foundation: extend `mcp-toolbox.md` (do FIRST)

All other tasks depend on the rows defined here (C4). In `skills/x-shared/mcp-toolbox.md` § `GitNexus (optional, when mcp.gitnexus pinned)`:

1. Replace the flat "when pinned" gate with the **three-part gate** and the **use-class asymmetry** from C3. Add a short subsection "Freshness gate" stating: correctness-sensitive consumers hard-degrade on stale; advisory consumers proceed with a staleness note.
2. Add rows (Primary | Fallback):
   - `Local structural / "how does X work" (advisory, indexed+any-freshness)` → `gitnexus query` (process-grouped) | `morph-mcp codebase_search`
   - `Symbol 360° (callers+callees+flows, advisory)` → `gitnexus context` | 2× `morph-mcp codebase_search`
   - `Ceremony/severity grounding (correctness-sensitive, indexed+fresh)` → `gitnexus impact` **counts only, never the risk label (C1)** | heuristic depth calibration / qualitative scan
   - `Pre-commit scope + flow check (correctness-sensitive, indexed+fresh)` → `gitnexus detect_changes` (changed symbols + affected processes) | `git diff` (no flow membership)
3. Add an explicit caveat line under the table: "`impact`/`context` reflect the static call graph and may miss dynamic dispatch / reflection / string-keyed handlers (C2). Never present a 0-result as a safety guarantee."
4. **(F2) Add a use-class index** as an explicit, greppable subsection immediately under the GitNexus table — a single place that classifies BOTH the 4 new rows AND the existing v1.10.0 rows (**including the v1.10.0 `rename` row — 8 tools total, not 7; the original plan under-enumerated, corrected in v4**), so every downstream task (esp. Task 4a) resolves a tool's class from ONE source, not by re-deriving it:
   - **correctness-sensitive** (stale → hard-degrade): `impact`, `detect_changes`, `route_map`, `api_impact`, `shape_check`, `rename`
   - **advisory** (stale → usable with staleness note): `query`, `context`
   This subsection is additive prose under the table; it does NOT mutate the v1.10.0 rows themselves (regression guard below still holds). It is the canonical answer to "is tool X correctness-sensitive?" referenced by Tasks 3a and 4a.

**Regression guard:** the existing v1.10.0 rows (impact-for-x-mindful, route_map/shape_check-for-x-api-pentest) MUST remain byte-identical except for the gate-wording refactor. `git diff` on this file must show only additions (new rows + the use-class index subsection) + the gate paragraph rewrite — no row deletions.

**Verify:** the GitNexus table has exactly **4 new Primary|Fallback rows** added under it in the canonical v1.10.0 format (count the added rows directly — do NOT use a `grep -c "Fallback"` delta as a row-count proxy: in the canonical format "Fallback" is a column-header/prose token, never a per-row cell, so 4 new rows add 0 "Fallback" lines; the only `Fallback`-string delta comes from the gate-paragraph rewrite); the use-class index subsection lists all 7 tools with exactly one class each (no tool unclassified, none in both buckets); `git diff` shows ZERO v1.10.0 row deletions (only additions + the single gate-paragraph rewrite); the x-mindful and x-api-pentest plans' referenced anchors still resolve.

---

## Task 2 — x-research: consume shared indexed+fresh probe + Detection rows

**2a. Shared bootstrap probe (once per session, cached) — F3.** Add the probe to `skills/x-shared/capability-loading.md` as a documented shared step: if `mcp.gitnexus` pinned, run a one-time `gitnexus list` parse to build the set of indexed repo paths + their per-repo freshness (`staleness.commitsBehind`), session-pinned. x-research, x-do (Task 3a), and x-review (Task 4a) ALL consume this single pinned result from their Bootstrap — none re-probes per dispatch, none runs its own independent `gitnexus list`. Mirror the parse shape of the x-api-pentest `gitnexus list reports SOURCE_REPO as indexed` pattern at `skills/x-api-pentest/steps/step-01-recon.md:104`. In `skills/x-research/SKILL.md` § Bootstrap, after the capability pin, add a one-line "consume the shared gitnexus indexed+fresh probe per `../x-shared/capability-loading.md`" reference (no per-skill probe logic — the derivation lives in one place).

**2b. Detection table.** Add gitnexus rows ABOVE the existing morph rows for:
- `Local code: "how does our X work" (target repo indexed)` → Primary `gitnexus query`; Escalation/fallback `morph-mcp codebase_search` → OMO `explore`
- `Symbol callers+callees+flows (target repo indexed)` → Primary `gitnexus context`; fallback 2× `morph codebase_search`

Both rows: if not pinned OR not indexed → row collapses to the existing morph behavior (zero behavior change for unindexed repos — this is the graceful-degradation property, state it inline). If indexed but stale → use it, append `(index N commits stale — results may lag HEAD)` to the synthesis (C3 advisory class).

**2c.** Add invocation templates + the staleness-note wording to `skills/x-research/references/prompt-templates.md`.

**Regression guard:** the morph rows are not deleted — they remain as the fallback column / unindexed path. A repo with no gitnexus index must produce the exact pre-change routing.

**Verify:** dry-run x-research on a structural question against (a) the indexed x-skills repo → routes to `gitnexus query` with staleness note; (b) a non-indexed sibling path → routes to morph unchanged.

---

## Task 3 — x-do: Depth Calibration grounding + commit scope + consume x-mindful

**3a. Depth Calibration discriminator (C1).** In `skills/x-do/SKILL.md` § Depth Calibration, add an OPTIONAL grounding step gated by ALL of:
- Mode ∈ {A, B, F} (never D; C delegates to x-bugfix)
- **the named-symbol set is non-empty**, where "named symbols" is resolved by ONE pinned mechanism (no guessing): (i) Mode A — symbols referenced in the plan file; (ii) Mode F — symbols named in the refactor prompt; (iii) Mode B — symbols carried in the inbound x-research / x-mindful handoff envelope, OR backtick-quoted identifiers in the user prompt that resolve to existing graph nodes. **Mode B with no resolvable existing symbol ⇒ gate OUT** (heuristic Depth Calibration) — do NOT speculatively call impact on a greenfield feature.
- gate from Task 1 satisfied — **(F3)** "pinned + indexed + **fresh**" is read from the shared session-pinned probe (Task 2a / `../x-shared/capability-loading.md`), NOT a per-skill `gitnexus list` call; correctness-sensitive class per the **Task 1 use-class index**.

When gated-in: call `gitnexus impact` on the named symbols, take **depth-1 caller count + affected-process count only**. Map to the existing Light/Standard/Heavy ladder via an explicit table in `references/delegation-and-scaling.md` (e.g. `≥1 affected process OR ≥N depth-1 callers → bump one ceremony level`). NEVER read gitnexus's `risk` field. When gated-out (incl. stale or empty symbol set): use the existing heuristic Depth Calibration unchanged. **(F1)** Surface one line carrying the explicit symbol set: `Depth grounding: gitnexus.impact (N callers, M processes) [direct] symbols=[<comma-separated names>]` or `Depth grounding: heuristic` (no `symbols=` field when heuristic — nothing was graph-grounded).

**3b. Consume x-mindful, don't re-run (C5).** In Mode A guidance, add: if an `<!-- x-mindful-envelope v1 -->` block is present in handoff context, x-do extracts the set of symbols named in its items (backtick-quoted identifiers in each `[<id>] <title>` line, plus Modified items' `Original plan` / `User direction` text, across the Confirmed/Modified/Rejected/Skipped/Pending sections); it MUST NOT re-invoke `gitnexus impact` on any symbol in that set. The envelope carries no blast-radius payload to reuse — C5 is a no-re-run dedup, not a numbers-reuse. Depth Calibration grounding (3a) applies only to symbols NOT in the envelope set; for symbols that ARE in the set x-do surfaces **(F1)** `Depth grounding: x-mindful envelope [covered] symbols=[<comma-separated names>]`, and for symbols it grounded itself `Depth grounding: gitnexus.impact (N callers, M processes) [direct] symbols=[<comma-separated names>]`. The `symbols=[…]` field is mandatory on every non-heuristic `Depth grounding:` line and is the grep-assertable signal for Task 6 step 4 — the `[covered]`/`[direct]` tag PLUS the explicit `symbols=` list together make the C5 no-double-run check measurable (a symbol name appearing in a `[direct]` line's `symbols=` list while also in an envelope item is the violation Task 6.4 detects).

**3c. Commit Recomposition scope check.** In `skills/x-do/steps/step-04-execute.md` § Commit Recomposition (referenced from `SKILL.md:230-232`), add: after recomposition, if gate satisfied (correctness-sensitive, fresh), run `gitnexus detect_changes` with **`scope: "compare"`, `base_ref: <BASE_SHA>`** — the `BASE_SHA` captured pre-recomposition. (The default `scope: "unstaged"` returns the empty-state stub on a clean post-recomposition tree — `local-backend.ts:2163-2173` — so `compare` is mandatory here, not optional.) Report changed symbols + affected processes as a scope sanity check ("recomposition touched flows: …"). Explicitly state the delta over `git diff`: flow membership. Stale or unindexed → skip silently, `git diff` already covers file scope. Advisory output, not a gate — never block the commit on it.

**Regression guard:** Mode D path is untouched (no impact call ever fires for D). With `mcp.gitnexus` unpinned, x-do behavior is byte-identical to pre-change (heuristic Depth Calibration, no detect_changes).

**Verify:** Mode B feature touching existing symbols on the (stale) x-skills index → grounding correctly gates OUT due to staleness, falls to heuristic, surfaces the `heuristic` line. Re-test against a freshly-indexed scratch repo → grounding gates IN, counts surface, ceremony maps correctly.

---

## Task 4 — x-review: gated blast-radius enrichment, scope-fenced

**4a.** In `skills/x-review/steps/step-01-prepare.md`, after target/diff collection, add an OPTIONAL step gated by the Task 1 correctness-sensitive class — **(F3)** "pinned + indexed + fresh" is read from the shared session-pinned probe (Task 2a / `../x-shared/capability-loading.md`); **(F2)** `impact` AND `route_map`/`api_impact` are resolved as correctness-sensitive via the **Task 1 use-class index** (which now classifies the v1.10.0 `route_map`/`api_impact`/`shape_check` row explicitly — no longer an unclassified dependency). x-review consumes the shared probe in its Bootstrap; it does not run its own `gitnexus list`.
- For changed **code symbols**: call `gitnexus impact` (direction upstream) → **summarized depth-1-only** line per symbol (`<symbol>: K depth-1 callers, flows: [...]`). Hard cap top-8 callers, **ordered by edge confidence descending, ties broken by depth ascending then name** (deterministic across runs — two reviewers must see the same 8).
- For changed **API route handlers**: additionally call `gitnexus route_map` / `api_impact` → consumer list. The canonical in-scope false-assumption finding ("PR says handler is internal-only; 3 external consumers exist") comes from `route_map` consumers, NOT `impact` depth-1 callers — both tools feed 4b.
- Stale/unindexed → skip entirely.

**4b.** Feed the summary into the **Scope Contract block** of `skills/x-review/SKILL.md:11-35`, NOT the reviewer prompt body. Add explicit fencing:
- ✅ In scope: gitnexus contradicts a stated claim → a real false-assumption / spec-deviation finding (e.g. "PR says handler is internal-only; `route_map` shows 3 external consumers").
- ❌ Out of scope: "high coupling / consider restructuring" — gitnexus must NEVER generate the refactor/architecture findings the contract already drops.
- Mandatory disclaimer on every gitnexus-derived line (C2): "static call graph — may miss dynamic dispatch; a 0-caller result is NOT a safety proof."

**Regression guard:** with gitnexus unavailable/stale, step-01 output is byte-identical to pre-change. The Scope Contract's existing out-of-scope list is unchanged — only an additional fence for gitnexus-derived material is appended.

**Verify:** review a diff on the stale x-skills index → enrichment correctly skips (stale gate), review proceeds unchanged. Review a diff on a fresh scratch repo with a known false "internal-only" claim → reviewer surfaces it as an in-scope false-assumption finding with the C2 disclaimer.

---

## Task 5 — Docs touch-up

- `CLAUDE.md` (project) skill table: append "(gitnexus-aware, optional)" to x-research / x-do / x-review purpose cells. No rule-block changes (the auto-managed GitNexus block + Fallback section already cover enforcement semantics).
- `skills/x-shared/capability-loading.md`: **(F3 — now mandatory, not conditional)** document the shared once-per-session indexed+fresh probe: its derivation (`gitnexus list` parse → indexed-path set + per-repo `staleness.commitsBehind`), that it is session-pinned and consumed identically by x-research/x-do/x-review, and that it is a derived session state — NOT a `bin/setup` capability key (does not appear in `~/.config/x-skills/capabilities.json`). This is the single source of the indexed+fresh signal Tasks 2a/3a/4a all read.

---

## Task 6 — End-to-end verification

1. **Unindexed-repo invariance:** run x-research / x-do / x-review in a repo with no gitnexus index → all three behave byte-identically to pre-change (capture before/after transcripts; diff must be empty).
2. **Stale-index correctness (the real x-skills state):** confirm correctness-sensitive consumers (x-do Depth grounding, x-do detect_changes, x-review enrichment) all degrade to fallback and surface the `heuristic`/skip line; confirm advisory consumer (x-research query) proceeds WITH the staleness note.
3. **Fresh-index happy path:** `gitnexus analyze` a small scratch repo, **then re-pin the shared indexed+fresh probe** — because F3 makes the probe once-per-session/session-pinned (Task 2a / Task 5), the pre-`analyze` snapshot would otherwise mask the now-fresh state; the verification MUST either start a fresh session OR explicitly re-run the shared `gitnexus list` probe and re-pin it before the rerun. Then re-run all three → counts surface, ceremony maps per the table, reviewer disclaimer present. (This re-pin is a verification-procedure step only; it does NOT relax the F3 "none re-probes per dispatch" rule for normal operation.)
4. **C5 no-double-run:** Mode A with an x-mindful envelope present → grep the x-do transcript for `Depth grounding:` lines, **restricted to non-heuristic lines (those bearing a `[covered]` or `[direct]` tag); `Depth grounding: heuristic` lines carry no `symbols=` field by design (Task 3a) and are skipped — they grounded nothing, so they are irrelevant to the no-double-run check**. **(F1)** Parse the `symbols=[…]` field on each remaining (tagged) line: assert every symbol named in an envelope item appears in a `[covered]` line's `symbols=` list and NEVER in a `[direct]` line's `symbols=` list; assert no `symbols=` list contains a duplicate across a `[covered]` and a `[direct]` line. (Now a real grep on the explicit `symbols=` field of tagged lines — the prior version asserted on a symbol name the log line did not emit; F1 added the field so the assertion is measurable from real transcript content, keyed on the emitted `symbols=` membership.)
5. **mcp-toolbox integrity:** predecessor-plan anchors (x-mindful, x-api-pentest) still resolve; no v1.10.0 row deleted; the use-class index subsection (F2) classifies all **8** tools (incl. the v1.10.0 `rename` row) with exactly one class each.

Done = all 5 pass; no skill loses a capability when gitnexus is absent; no correctness-sensitive consumer trusts a stale graph.

---

## Risks & Non-Goals

- **Non-goal:** making any skill *require* gitnexus. Every path degrades. If verification step 1 shows any behavior drift on an unindexed repo, the task is wrong, not the test.
- **Non-goal:** using gitnexus risk labels anywhere (C1). Counts only.
- **Risk:** scope creep in x-review (Task 4) — mitigated by 4b fencing; the reviewer agent must be unable to emit refactor findings via gitnexus that the Scope Contract already forbids directly.
- **Risk:** Depth Calibration latency regression — mitigated by the Mode-D exclusion + named-symbol discriminator (3a); impact never fires on the trivial-edit fast path.
- **Sequencing:** Task 1 is a hard prerequisite for 2–4 (it now also emits the F2 use-class index that 4a depends on). The F3 shared probe in `capability-loading.md` is a co-prerequisite landed with Task 1/2a. Tasks 2, 3, 4 are independent of each other and may be implemented/reviewed in parallel after Task 1 + the shared probe land.
