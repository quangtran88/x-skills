---
title: Memory Reflex Contract
slug: memory-reflex-contract
type: feat
status: done
created: 2026-07-14
updated: 2026-07-14
related: []
---

# Memory Reflex Contract

## Context & Problem

A capability audit of all 18 x-skills found that the plugin **detects and pins** its
optional dependencies correctly (`bin/setup` probes basic-memory + gitnexus; the
SessionStart hook `inject-capabilities.sh` injects an `active=…,mcp.basic_memory,…`
snapshot), but the snapshot is **availability-only** — it carries no instruction to
actually *use* those dependencies. The "recall from basic-memory before you research /
fix / plan, and persist durable knowledge afterward" behavior is re-implemented by hand
inside each skill, and `workflow-chains.md` does not mandate it.

The result is inconsistent coverage. The recall→persist pattern is correct in 5 skills
(x-research, x-review, x-qa, x-design, x-skill-improve), half-wired in 2 (x-do, x-mindful),
and entirely absent in 4 skills that produce exactly the durable knowledge basic-memory
exists to hold (x-guide, x-team, x-backlog, x-api-pentest). Because every skill copies the
step, the copies have already drifted, and new skills inherit no default.

One reassuring finding scopes this work: **gating discipline is uniform and correct**
everywhere the pattern exists — every call already checks the `mcp.basic_memory` pin and
skips silently when unpinned; there are zero unconditional calls. So this is a *coverage
and placement* problem, not a correctness problem. Nothing here changes the gate.

## Solution Overview

Define **one** canonical "Memory Reflex" — a named recall-before-work step and a named
persist-after-completion step — in the shared layer, and have every work-producing skill
reference it from an **always-run** location (Bootstrap / Pre-Flight), never from an
opt-in branch. The consumer rules (which directory by note kind, tagging, project
targeting) already live in `x-shared/mcp-toolbox.md § basic-memory`; what's missing is the
named *step* that skills point to instead of restating.

Concretely, the change is:
1. Add a **§ Memory Reflex** subsection to `x-shared/mcp-toolbox.md`, co-located with the
   existing basic-memory consumer rules, defining the two steps + the always-run placement
   rule + the per-note-kind routing already documented there.
2. **Wire the 4 missing skills** — x-guide, x-team, x-backlog, x-api-pentest — each with a
   gated `search_notes` before core work and a gated `write_note` at completion, pointing
   at the shared section rather than duplicating it.
3. **Fix placement in the 2 half-wired skills** — move x-do's recall to the always-run
   Pre-Flight (so Mode A/D reach it, not just the vague-requirements path), and lift
   x-mindful's persist out of the opt-in "Save envelope" branch to an unconditional gated
   completion step.

The 5 already-correct skills are left alone except for an optional later pass to collapse
their inline copy to a pointer (tracked under the separate reorg/dedup backlog, not here).
Skills that are N-A-by-design (x-worktree, x-worktree-isolate, x-upstream, x-verify,
x-omo, x-gemini) are untouched.

## Key Decisions

### Decision: Central contract in x-shared, not per-skill duplication
- **Choice:** Define the reflex once in `x-shared/mcp-toolbox.md` and have skills reference it.
- **Why:** The per-skill copies have already drifted and produced coverage gaps; a single
  definition is the only thing that keeps new and existing skills consistent.
- **Alternatives:** Keep the per-skill pattern and just add the 4 missing copies — rejected
  because it adds 4 more drift surfaces and does nothing for the next skill.
- **Consequences:** One place to update the recipe; skills get shorter. Slight indirection
  (a reader must follow the pointer to see the exact call), accepted because the consumer
  rules already live there anyway.

### Decision: Extend mcp-toolbox.md rather than add a new x-shared file
- **Choice:** Add a "§ Memory Reflex" subsection to the existing `mcp-toolbox.md`, directly
  after `§ basic-memory — Consumer rules`.
- **Why:** The consumer rules (placement, tagging, project targeting) already live in that
  file; co-locating the step definition keeps references one level deep and avoids yet
  another shared file to load.
- **Alternatives:** New `x-shared/memory-reflex.md` — rejected as unnecessary file
  proliferation for ~30 lines of content that belongs next to its consumer rules.
- **Consequences:** `mcp-toolbox.md` grows modestly; skills that already load it for the
  consumer rules get the reflex step for free.

### Decision: Reflex lives in an always-run location, never an opt-in branch
- **Choice:** Recall goes in Bootstrap/Pre-Flight; persist goes in an unconditional
  completion step. Both gated only on the `mcp.basic_memory` pin.
- **Why:** The two half-wired skills fail precisely because the step is reachable only on
  some paths — x-do's recall sits in step-01 (skipped by Mode A/D), x-mindful's persist
  sits under "Persistence (only on explicit request)". Placement, not gating, is the bug.
- **Alternatives:** Leave placement as-is and document the gaps — rejected; the whole point
  is that the reflex fires reliably.
- **Consequences:** Recall/persist fire on every path where the skill does real work; the
  only skip is the capability gate.

### Decision: Gating is unchanged
- **Choice:** Every new or moved call keeps the existing `mcp.basic_memory`-pinned +
  skip-silently gate. No gate logic is added, removed, or loosened.
- **Why:** The audit found gating already uniform and correct (zero unconditional calls);
  Claude-only mode must stay byte-identical.
- **Alternatives:** none seriously considered.
- **Consequences:** Sessions without basic-memory see zero behavior change.

## Scope & Non-Goals

**In scope**
- New **§ Memory Reflex** subsection in `x-shared/mcp-toolbox.md` (recall step, persist
  step, always-run placement rule, per-note-kind routing pointer).
- Wire **x-guide** — gated recall in Bootstrap before Phase-2 ingest; gated persist of
  key-takeaways to `notes/<slug>/` at Phase-5 wrap.
- Wire **x-team** — gated recall before Phase-1 decomposition; gated persist of
  failed-feature root causes / blocker verdicts to `lessons/` + `decisions/<slug>/` at Phase-8.
- Wire **x-backlog** — gated recall over `decisions/<slug>/` in step-2 harvest (surfaces
  cross-session contradictions for blocker #1); gated persist of drafted Key Decisions to
  `decisions/<slug>/` at step-5/6.
- Wire **x-api-pentest** — gated recall of prior findings / target gotchas in bootstrap;
  gated persist of confirmed vuln classes + noise-filter lessons to `lessons/<slug>/` at step-06.
- Fix **x-do** — move the gated `search_notes` from `steps/step-01-gather.md` to the
  always-run Pre-Flight checklist in `SKILL.md` so Mode A/D recall too.
- Fix **x-mindful** — move the gated `write_note` out of the opt-in "Save envelope" branch
  in `steps/step-05-handoff.md` to an unconditional gated completion step.
- Each wired/fixed skill references the shared § Memory Reflex instead of restating it.
- Version bump + release per `CLAUDE.md § Release Workflow`.

**Non-goals** (explicitly out, so nobody assumes otherwise)
- The gitnexus **impact-before-edit** contract reconciliation for x-do / x-bugfix /
  x-mindful (x-do removed it vs CLAUDE.md MANDATORY; x-bugfix never had it; x-mindful
  under-gates it). Separate backlog.
- The broad **reorg / dedup pass** (collapsing the ≤1-agy rule, serial-agy rule, taxonomy
  duplications; deleting x-design's 412 orphaned reference lines; removing committed
  `.omc/state` junk; x-qa report-schema `warn` drift; x-team un-namespaced `executor`;
  x-omo missing bootstrap). Separate backlog(s).
- Any change to the gate logic or to Claude-only fallback behavior.
- Collapsing the 5 already-correct skills' inline copies to pointers (nice-to-have; folds
  into the reorg pass).
- Touching N-A-by-design skills.

## Acceptance / Ready-check
- [ ] `x-shared/mcp-toolbox.md` contains a named **§ Memory Reflex** defining a recall-before-work step and a persist-after-completion step, plus the always-run placement rule.
- [ ] x-guide, x-team, x-backlog, x-api-pentest each invoke a gated `search_notes` before their core work and a gated `write_note` at completion, each pointing at § Memory Reflex.
- [ ] x-do's recall fires on all mode paths — verified by tracing Mode A and Mode D to a Pre-Flight recall (not just `step-01-gather.md`).
- [ ] x-mindful's persist fires on the common handoff path (menu option 1), not only the "Save envelope" branch.
- [ ] Every new or moved call is gated on `mcp.basic_memory` with an explicit silent-skip fallback; a grep confirms no unconditional `search_notes` / `write_note` was introduced.
- [ ] Placement + tagging follow `mcp-toolbox.md § Consumer rules` (correct `lessons/` / `decisions/` / `notes/` by note kind; tags include project-slug + emitting skill).
- [ ] A Claude-only-mode dry read of each edited skill shows no behavior change when `mcp.basic_memory` is unpinned.
- [ ] Three version manifests bumped together + tag + GitHub release per the release workflow.

## Feature Breakdown
| Feature | What it does | Priority |
|---|---|---|
| § Memory Reflex in mcp-toolbox.md | Canonical recall + persist step definitions skills point to | must |
| Wire x-guide | Recall before ingest; persist takeaways to `notes/` | must |
| Wire x-team | Recall before decomposition; persist root-causes/blocker verdicts | must |
| Wire x-backlog | Recall over `decisions/`; persist drafted Key Decisions | must |
| Wire x-api-pentest | Recall prior findings; persist vuln classes + noise-filters | must |
| Fix x-do placement | Move recall to always-run Pre-Flight | must |
| Fix x-mindful placement | Lift persist out of opt-in branch | must |
| Collapse 5 correct skills to pointer | Dedup inline copies (defer to reorg pass) | could |

## Handoff Notes / Open Questions
- **Per-skill query/directory recipe:** the recall query and target directory differ by
  skill — x-backlog recalls/persists `decisions/<slug>/`; x-api-pentest recalls prior
  findings and persists `lessons/<slug>/`; x-guide persists takeaways to `notes/<slug>/`;
  x-team persists to both `lessons/` and `decisions/`. The § Memory Reflex step should
  define the *shape* and let each skill supply its own query hint + note kind.
- **Self-reference:** x-backlog is both a skill being wired and the tool that drafted this
  doc — no conflict, but worth noting the edit lands in the same skill.
- **Recall framing:** keep the established "leads, not verdicts" framing so recalled notes
  inform but never auto-drive the workflow (already the convention in x-research/x-bugfix).
- **Persist chaff risk:** persist *durable* output only (decisions with rationale, root
  causes, confirmed findings) — not routine run summaries. x-do's current persist writes
  build logs to `lessons/` unconditionally; the placement fix should also narrow *what* it
  writes (or the reorg pass should). Flag if the implementer wants to fold that in here.
- **Verification:** the acceptance "no unconditional call introduced" check is a simple
  grep gate — include it in the x-do implementation's instrument-and-verify step.
