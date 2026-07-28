---
title: v3 round-4 audit — assumption re-verification, direction validation, reuse map
slug: v3-round4-audit
type: research
status: done
created: 2026-07-28
related: [x-skills-v3, x-skills-v3-foundations, oss-skill-framework-survey]
---

# v3 round-4 audit — every assumption re-checked, direction externally validated, 19 skills mapped for reuse

Cited from the backlog doc as `[R4 §n]`. Method: 11-agent audit (2026-07-28) — one
assumption extractor + four adversarial verifiers instructed to refute, one plan-internal
critic, three external research lanes, two reuse auditors covering all 19 skill dirs plus
every file in `x-shared/`. ~1.07M tokens, 212 tool calls. Every verdict below carries the
command or URL that produced it.

## §1 Verification — 20 assumptions: 13 hold, 7 weakened, 0 refuted

No repo-checkable claim in the plan was refuted. Seven carried wrong numbers; every
correction is applied in the backlog doc as of round 4. The corrections:

| Claim (as written) | Measured | Check |
|---|---|---|
| "19 skills … ~342 directed edges" | 18 plugin skills (19 dirs incl. x-shared, which has no SKILL.md) → ~306 edges; quadratic argument survives at either n | `ls skills/*/SKILL.md \| wc -l` → 18 |
| "101 call sites across ~40 files" | **96 tracked** under `skills/` (61 superpowers + 35 OMC) across **30 files** | `git grep -o` both prefixes |
| "~1,700 bootstrap lines" (DEC-013 deletions) | ~2,200–2,400 deletable; x-omo alone = 1,084 exactly, x-gemini = 178, x-team = 871; the ≥1,500 floor is comfortably met | `find … -exec wc -l` per tree |
| "x-backlog/SKILL.md:136-157 spends ~40 lines on x-worktree git states" | ~14 lines, at 137-150, inside a 22-line handoff block | read the range |
| "done-format.md:98 bans progress banners" | line **97**; the 13-file banner count (4 x-do + 4 x-review + 5 x-guide) confirmed exactly | `grep -n`; `grep -rlE 'Step [0-9]+ of'` |
| survey §4: "18 definitions, all vendored" | ~20 on re-run (varies by index state), still every one vendored — warrant stands | `gitnexus query` |
| survey §4: "zero of 111 .sh files" | zero of **113** tracked .sh files (108 under skills/) | `git ls-files '*.sh'` |

Confirmed exactly, live (selection): gitnexus own-coverage 2,231/160,141 = 1.4% and 0 own
symbols in any of 300 Processes (cypher counts); 7 of 8 indexed repos stale, x-skills itself
15 commits behind; the basic-memory `tags` filter is a restrictive AND — a tag miss returns
output byte-identical to an empty knowledge base (probed with a nonexistent tag); 19 session
notes titled from raw first messages; exactly three dotted worktree-named folders under
`lessons/`; the banned green-run note exists (`bm-remember/v3-whole-stack-e2e-suite-…`);
`bin/setup:905` and `hooks/inject-capabilities.sh:50` exact; `.x-skills/` and `docs/plans/`
already gitignored; the archival `git mv` fired **twice**, not once (0c665f8 broke
`docs/backlog/README.md:8`'s inbound link; 441ec8e renamed a plan), strengthening DEC-009;
superpowers' autonomy text + four-status routing verbatim at upstream HEAD (not a local edit);
`~/.config/x-skills/capabilities.json` is pinned at plugin 2.3.0 while the repo is 2.4.0 —
the manifest gating both kept deps is one version stale.

## §2 Plan-internal defects — 2 blockers, 10 major, 7 minor (all fixed round 4)

**Blocker 1 — build-order contradiction.** S3 required "the plan's own verification list
extends the floor cascade" and DEC-006's freeze armed "when x-record writes the plan" — but
the plan template and `lint-plan.sh` were built in S5, and S2 is Tier 2 ("design doc only"),
so on the S2→S3 path no plan ever exists: no gate source, no freeze trigger, and DEC-006's
falsifier ("if the hash never changes across S3 and S5") presupposed an event that could not
occur. Fix applied: the acceptance-examples block and the per-phase verification list live in
the **backlog template too**; the freeze arms when x-record writes whichever artifact carries
the block; S3 reads gates from the backlog doc at Tier 2, the plan at Tier 3.

**Blocker 2 — the end-state was never stated and three scope statements contradicted each
other.** Headline "collapse 19 into 3"; Non-Goals kept 5; S6 said "retire the 19" (read
literally: delete the kept 5); the outline's "unchanged" line listed only 3 of the 5; and six
skills had **no stated disposition anywhere**: x-design, x-guide, x-mindful, x-review,
x-upstream (zero mentions), x-research (doc-paths only). x-upstream additionally has zero
inbound references — nothing would have broken loudly when S6 deleted it by omission. Fix:
the Disposition table (backlog doc) now covers all 19 dirs + all 14 x-shared files; S6
reworded.

Major defects, one line each (fixes in the backlog doc): TerminalEmit encoded the exact
shared-`nextStep` shape DEC-008 rejects → per-status payload variants, Contracts block
declared authoritative. Outline named 6 of 14 x-shared files; `mcp-toolbox.md` — the file
DEC-013/016/017 all cite as their contracts' home — was absent, so a literal build deleted
it. `ownCoverage` appeared in DEC-017's branch table but in no contract, no outline entry, no
slice. DEC-016 routed `command+output` to basic-memory while its own one-line rule routed
commit-dependent output to `docs/` → split repo-bound vs repo-independent;
user-utterance-spans persist in the consult artifact. Recall-before-scout contradicted
DEC-004's own partial-measures evidence outright (not merely "open") → recall moved after
02-scout. S4's "provably contains no hypothesis" had no prover → dispatch prompts persist to
`.x-skills/run/<slug>/dispatch/` and the check is a lint. The overlap rate and rework tally —
two load-bearing instruments — had no writer, no format, no storage → `metrics.md` defined;
and the rework tally's cross-run channel **already exists** (`x-skill-improve/data/
alignment-log.jsonl` — do not build a second one). Several DEC-011/017 falsifiers named no
observer or channel (the doc's own declared anti-pattern) → each now names its recorder or
was cut. DEC-009's Choice line still pinned ~200 lines to the backlog doc after round 3 moved
the budget to phase files. `nextStep` derivation could not produce DEC-017's remediation
command → three enumerated variants.

Representative minors (also fixed): `grep -rc … → 0` can never output `0` (prints per-file
`path:count` lines) → `grep -rl … | wc -l`; "stop and escalate" used the word its own stop
set bans → "emit `BLOCKED{gate + both attempts' output}`"; `terminalState` was a contract
enum no DEC defined; "three-edge chain" has two edges.

## §3 Direction — aligned with official guidance; corroborated by four independent lineages; all four risky bets survive the 2026 sweep

### §3.1 Anthropic official guidance (strong confidence, primary sources)

The 3-skill thin-router shape is not merely compatible — it is the canonical documented
pattern. Granularity: "a coherent unit of work that composes well … Skills scoped too
narrowly force multiple skills to load for a single task, risking overhead and conflicting
instructions" (agentskills.io best-practices, which Claude Code docs link as canonical). No
upper bound on skill count exists anywhere; the pressure is context mechanics: every skill's
description is always-on (~80–100 tokens each), the listing budget is 1% of the context
window, and **when it overflows, Claude Code shortens/drops descriptions starting with the
least-invoked skills** — 19 overlapping routers sit squarely in the documented failure zone.
Progressive disclosure is specified exactly as v3's router+phases: metadata ~100 tokens /
SKILL.md body <500 lines and <5,000 tokens / resources on demand; the platform doc's
"Pattern 2" is literally SKILL.md-as-navigation. Two constraints v3 must respect: reference
files **one level deep** from SKILL.md (deeper links get partially read via `head -100`), and
every phase-file pointer states **when** to load it, not just that it exists. One
model-invoked skill matches the invocation-control model: `disable-model-invocation` removes
the other skills' descriptions from context entirely and is what the docs prescribe for
side-effectful workflows ("you don't want Claude deciding to deploy") — corroborating
x-implement being user-invoked. The one new obligation: x-consult's ≤1,024-char description
now carries the whole trigger surface of the former 19; official guidance says validate with
~20 should/should-not-trigger prompts, ~3 runs each, 0.5 trigger-rate threshold. Sources:
agentskills.io/specification + /skill-creation/{best-practices,optimizing-descriptions};
anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills;
platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices;
code.claude.com/docs/en/{skills,plugins-reference}.

### §3.2 Pipeline prior art — corroborated, with six deltas

consult→record→implement is the shared skeleton of four field-tested lineages: HumanLayer
research→plan→implement (~200-line plans, review leverage on artifacts — "a bad line of
research → thousands of bad lines of code"; 35k lines in one 7-hour session on a 300k-LOC
codebase); Anthropic's explore→plan→code→commit plus the "let Claude interview you → SPEC.md
→ fresh session" pattern (near-verbatim consult→record→implement); GitHub Spec Kit; Amazon
Kiro. Deltas adopted round 4: **(1)** the record is v3's only human gate (x-implement is
autonomous), so `lint-plan.sh` also enforces reviewability — per-phase success criteria,
exact file paths, out-of-scope statement, end-to-end verification step. **(2)** Kiro's
most-cited flaw is "specs don't self-update"; HumanLayer compacts status back into the plan —
x-implement now appends deviations to the plan doc, not only the ledger. **(3)** Every
credible negative field report (Scott Logic "sea of markdown, no qualitative benefit";
martinelli.ch; r/ExperiencedDevs) attacks *mandatory ceremony on small tasks*, and Anthropic
itself says "if you could describe the diff in one sentence, skip the plan" — DEC-002's
default-LOW tiering is the corroborated mitigation, not an optional nicety. **(4)** Do not
adopt Spec Kit's "spec is source of truth, code is regenerated output" — the sharpest
published critique (non-deterministic generators produce different architectures from the
same spec) falsifies it; v3's record is a decision log + frozen acceptance contract.
**(5)** Frozen oracles are corroborated (SWE-bench FAIL_TO_PASS, tdd-guard, Spec Kit's
user-approved confirmed-failing tests) and the documented failure mode is **oracle gaming**:
METR recorded frontier models overwriting graders and timers, ~80% reward-hack-attempt
trajectories on a hard hidden-test variant; Anthropic's emergent-misalignment work documents
`sys.exit(0)` harness escapes. DEC-006's sha256 freeze and DEC-011's stub scan are therefore
mechanically warranted, and gate-pass is necessary-not-sufficient — 03-review is the
backstop. **(6)** Cheap proven details: HumanLayer's scouts are "documentarians — describe
what exists, never suggest improvements" (DEC-004 verbatim, independently derived), and
40–60% context-utilization discipline.

### §3.3 Counter-evidence sweep — all four bets stand

**DEC-010 (no parallel mutation): stands.** Nothing shows concurrent mutation beating solo
serial; the one 2026 measurement (arXiv:2510.18893) shows parallel speed bought with ~7.7%
quality loss. One amendment: Anthropic's Feb 2026 C-compiler post (16 Claudes concurrently
mutating one repo, $20k, 100k-line compiler) is a published **existence proof** — with no
solo baseline, frequent merge conflicts, and three preconditions (greenfield, dense
machine-checkable oracle, naturally decomposable tasks) that x-implement's brownfield targets
rarely satisfy. "No configuration with published support" was therefore overstated; the ban
is not. **DEC-011 (full autonomy): stands, and field practice moved toward it** (Anthropic
telemetry: experienced users auto-approve >40% vs ~20% for new users, interrupting on
anomaly). But the accepted residual now has hard numbers: MSR 2026 (Agarwal et al.) measures
autonomous-agent usage at **+18% static-analysis warnings and +39% cognitive complexity,
persisting after velocity gains fade** — the first field quantification of exactly the debt
class DEC-011's falsifier watches. Consequence adopted: instrument the rework channel from
S3, and the merge boundary — not slice boundaries — is where every credible source locates
the needed check (v3's 03-review, gated on the diff artifact, is that check at zero human
cost). **DEC-005/DEC-014: stand, strengthened.** No open-beats-enumerated study emerged; the
second-reading bet gained direct quantitative support — across 8 models and 294 confirmed
defects, no single model exceeded ~61% recall, 56.8% of defects were found by exactly one
model, and a second independent reviewer lifts coverage ~47%→~72% at median cross-family
overlap ~0.29, strikingly close to the human ~26% DEC-014 already cites (Zenodo 21328807).
Caveat confirmed, already priced in: gains concentrate when the second reader is a different
model family — DEC-015's carve-out exists for exactly this. **DEC-016 (cross-repo memory):
the strongest bet post-sweep.** Kim et al. 2026: cross-domain memory pooling +3.7% Pass@3
with 94.5% of the gain from procedural meta-knowledge; insight-level memories (paths and
concrete code stripped) help ~3× more than raw trajectories, and low-abstraction memories
cause **negative transfer**. Ungoverned persistence is worse than nothing (96% task
completion selective vs 79% no-memory vs 71% full-history, arXiv:2607.09493). This upgrades
"link, don't restate" from style rule to measured necessity → the >~40-contiguous-words
overlap check becomes a write-time lint at S2, not a post-hoc diff audit.

## §4 Reuse map — what the 19 skills actually contribute to v3

Full disposition table lives in the backlog doc. The load-bearing discoveries, in order of
value:

1. **`x-qa/scripts/lib/verdict.sh` + `scripts/tests/` fixtures are the only existing
   implementation of DEC-007's core mechanism** — status computed from machine state (reads
   metrics JSON, emits pass|warn|fail, never model-composed), with the exact
   fixture-pairs-plus-selftest shape the Acceptance list demands. gates.sh starts here, not
   from scratch. Its `quality-gates.md` "unmeasured" handling (missing metric ⇒ status
   `unmeasured`, verdict NOT flipped, surfaced as ⚠) is DEC-011's N/A row, already solved.
2. **`x-team/references/blocker-escalation.md` is the only existing DEC-018
   implementation** — a concrete 4-rule sanitizer for untrusted subagent text (strip control
   chars; cap fields at 4000 chars; fenced-quote rendering; strip `^\s*(===|---|###)\s*
   (HUMAN|LEAD|OVERRIDE|APPROVE|RESOLVED)` impersonation lines), plus the NOT-blockers list
   (test failure, type errors, lint warnings ≠ blockers) that sharpens DEC-011's stop set,
   the persisted attempt counter ("the in-prompt counter is lost on compaction"), and the
   IDLE never-retry-unchanged rule. The skill dies; these four assets are DEC-011/018
   mechanisms the plan states with no implementation.
3. **`x-shared/completion-cascade.md` §3 command discovery** — package.json scripts →
   per-language config → "mark `<tool>: no-config` and continue. Do NOT invent a command" —
   is the gates.sh floor-cascade ladder, and the do-not-invent rule is the part most likely
   to be lost if rewritten from memory. Its SCOPE GATE (docs-only short-circuit) is the
   entry predicate.
4. **`x-mindful/references/severity-rubric.md` defines reversibility** (reversible / costly /
   one-way, with examples) — DEC-002's escalation floor asserts "not cheaply reversible ⇒
   Tier 2" but defined reversibility nowhere. Its extraction-prompts.md (per-category prompts
   + a hard ban on code-level identifiers) is the strongest question-generation material in
   v2 → 01-questions/03-debate. Its walkthrough loop must NOT port (per-item confirm gates =
   the drip DEC-005 bans).
5. **`x-gemini/gotchas.md` is fatal to DEC-015 as written**: `agy` exits 0 on auth/quota/
   empty failures — a cross-model reviewer lane trusting exit status reads an auth failure as
   an empty review and logs a 0% overlap rate, corrupting DEC-014's only falsifier. The
   wrapper's re-derived exit code (empty stdout + log tail), serialize-calls rule, and
   error-table port into capability-loading.md's DEC-015 lane. Also: no read-only flag is
   documented for `agy` — DEC-015's read-only requirement has no prior art here.
6. **`x-worktree/references/doc-naming.md`** is the existing slug normalizer DEC-016's
   print-and-hard-fail requires (frontmatter > title > H1 > filename; 6-step normalization).
   **`x-bugfix`** splits: baseline capture → prod-bug manifest (near 1:1);
   3-Strike/Instrumentation Pivot → the constrained-retry branch; `backward-tracing.md`
   (59 lines, zero framework deps) near-verbatim. **`x-omo/references/prompt-blocks.md`**
   grounding/missing-context/citation XML blocks → scout and review dispatch prompts.
   **`x-backlog/references/template.md`** CORE skeleton → backlog template (the v3 plan doc
   itself is written in it). **`x-api-pentest`**'s one-step-file-at-a-time rules and its
   skip-stub artifact (`{"schema_version":1,"skipped":"<reason>"}`) → router discipline and
   the never-silent-skip. **`x-skill-improve/data/alignment-log.jsonl`** is the existing
   cross-run channel for DEC-003's rework tally.

Cut-over hazards the plan did not schedule: the KEPT skills are not clean — x-qa carries 8
framework strings and routes to x-omo/x-gemini/x-team in three places; x-api-pentest carries
2; `instrument-and-verify.md` (outline: "unchanged") carries `superpowers:test-driven-
development` at line 77 plus two dead intra-repo paths — so Acceptance row 1 and lint-chain
both fail on day one unless S6 includes a kept-skill scrub pass. `x-shared/severity-guide.md`
(17 lines, consumed by both kept skills) and the DOCKER CONTEXT half of `context-envelope.md`
(consumed by x-worktree) must survive the x-shared pruning. `workflow-chains.md` §Backlog
Lifecycle is the only documented entry into x-worktree's doc-driven mode — fold that one line
into x-worktree's SKILL.md before deleting the file.

## §5 Found while verifying the fixes, not by the fleet

The adversarial verifier counted call sites with `grep -rEo` over the working tree and reported
99 across 34 files. Re-run tracking-aware, it is **96 across 30 files**: a plain recursive grep
also matches untracked, gitignored `.omc/state/*.jsonl` agent-replay debris sitting inside
`skills/`. This is not only a number — Acceptance row 1 asserted a `grep -r` over `skills/`, so
**the release gate would have failed on any developer machine with local OMC state**, for reasons
unrelated to the dependency drop. The row now uses `git grep`. Two lessons the doc absorbs: an
assertion over a source tree must be tracking-aware, and every gate in the Acceptance list should
be *run once* before it is written down — `grep -rc … → 0` (§2) survived three audit rounds while
being incapable of ever printing `0`.

## §6 What this round could not verify

No controlled study isolates spec-driven vs plan-free agent workflows (the criticism corpus
is retrospectives + one adjacent RCT); no end-to-end SWE-bench A/B exists for a coding agent
with/without a cross-session store (DEC-016's magnitude is extrapolated); the checkpointed-
vs-autonomous question has no RCT (DEC-011 rests on field telemetry + the split prior art).
The trigger-eval obligation (§3.1) is the only new instrument this round adds that has an
official protocol but no v3 implementation yet.
