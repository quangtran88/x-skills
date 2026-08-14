---
title: x-skills v3 — consult / record / implement
slug: x-skills-v3
type: refactor
status: ready
created: 2026-07-27
updated: 2026-08-14
related: [x-skills-v3-decisions, x-skills-v3-foundations, v3-round4-audit, v3-qa-escalation, v2-skill-reuse-audit, v3-memory-store-research]
---

# x-skills v3 — consult / record / implement

Collapse 18 plugin skills into **4 new + 9 kept**, with zero runtime dependency on
`obra/superpowers` or `yeachan-heo/oh-my-claudecode` — and **zero plugin dependencies**
(DEC-026). Two MCP dependencies are kept deliberately — basic-memory (re-verified against the
2026 field and builtin memory, `[MEM]`) and gitnexus — plus two
optional user-supplied CLI backends driven directly, `codex` and `opencode`:
**codex → opencode → same-model is v3's cross-model chain** (DEC-024/025/026), with a
user-configurable reviewer roster that x-review dispatches in parallel (DEC-027).

**This doc is the human review surface. Read it end to end.** It carries the problem statement, the
disposition of every v2 skill, the contracts, the build order and the acceptance list. The
twenty-seven decisions and their warrants live in
**[`x-skills-v3-decisions.md`](x-skills-v3-decisions.md)** — read a block before changing what it
decided. Facts and citations live in `../research/`: `[FOUND]` =
`2026-07-27-x-skills-v3-foundations.md`, `[OSS]` = `2026-07-28-oss-skill-framework-survey.md`,
`[R4]` = `2026-07-28-v3-round4-audit.md`, `[R5]` = `2026-07-29-v3-qa-escalation.md`,
`[R6]` = `2026-07-30-v2-skill-reuse-audit.md`, `[MEM]` = `2026-08-13-v3-memory-store-research.md`.

**Six audit/research rounds.** R1 established the design; **R2** falsified much of it and added DEC-014/015;
**R3** surveyed eight OSS skill frameworks, changed the dependency scope to keep basic-memory and
gitnexus (DEC-016/017), added DEC-018, and refuted all nine top transfer candidates as proposed —
adopting each only in narrowed form; **R4** re-verified every repo-checkable assumption
(**0 of 20 refuted, 7 carried wrong numbers**, corrected), validated the direction against
Anthropic's published guidance and four prior-art lineages, mapped all 19 v2 skills for reuse, and
fixed two build-order blockers plus ten internal contradictions. DEC-019 and DEC-020 are R4's;
so is the **Disposition** section, which is what S6 executes. Per-decision amendment history lives
in each block. **The direction is confirmed: the 3-skill thin-router shape is the *canonical*
documented Agent Skills pattern, not merely a permitted one** `[R4 §3.1]`. **R5** (2026-07-29,
user-directed) researched two improvements — post-implement live QA and the blocker decision
brief — and added DEC-021/DEC-022 plus slice S7; both verdicts were "the machinery exists,
the wiring doesn't" `[R5 §5]`. **R6** (2026-07-30, user-directed) audited all 19 v2 dirs for
reuse and duplication (13-agent fan-out, every finding re-verified by hand at its `file:line`):
every disposition held on the merits, but 9 duplication clusters, 12 unnamed harvests and a
95-hit dead-reference sweep forced the S6 scrub's redefinition; the user kept x-review standalone
(DEC-023) and swapped OMO for `codex-plugin-cc` (DEC-024) `[R6]`. The **2026-08-06 pre-build
review** discharged the codex probe early (DEC-024 as amended), re-confirmed DEC-011 autonomy and
the DEC-020 harness, and removed agy entirely on the user's direction (DEC-025); after a
plugin-field survey (no official OpenCode plugin; community 0–88★), the user then dropped the
plugin dependency for an in-repo thin wrapper over both CLIs (DEC-026) and made x-review's
reviewer roster user config, dispatched in parallel (DEC-027). The **2026-08-13 memory-store
research** (user-directed; 4 research lanes + judge + 3 adversarial verifiers) re-verified
DEC-016's keep from outside: builtin Claude Code memory refuted for cross-repo recall (per-git-repo
scope, no supported sharing), the 2026 OSS field refuted on shape (its growth pattern is
auto-capture into databases — DEC-016's named anti-pattern), and basic-memory confirmed healthy —
kept with pin-era query rules, a formalized flat-store fallback and a gated v0.23 upgrade
(DEC-016 as amended) `[MEM]`.

## Context & Problem

Three things are wrong with v2, in order of cost.

**1. Skills document each other's internals.** 18 plugin skills (19 dirs — `x-shared/` holds
assets and has no `SKILL.md`) means up to ~306 possible directed handoff edges, and v2 pays that in
prose: `x-backlog/SKILL.md:137-150` spends ~14 lines on git states inside x-worktree, inside a
22-line handoff block. Dropping the two frameworks is a **96-call-site** mechanical change (61
`superpowers:` + 35 `oh-my-claudecode:` across **30 tracked files** under `skills/`); the coupling
is the real cost. All four numbers corrected round 4 — the quadratic argument is unchanged
`[R4 §1]`.

**2. The output contract does not self-enforce.** `done-format.md:97` bans progress banners;
13 step files open with one (4 x-do + 4 x-review + 5 x-guide, confirmed exactly). **~2,200–2,400**
lines of x-shared and bridge skills are read at bootstrap and cannot be acted on — x-omo alone is
1,084, x-gemini 178, x-team 871 `[R4 §1]`.

**3. Nothing closes the human/agent context gap.** No skill asks the questions that would. The
agent's model of the system is never stated back for correction, so misunderstandings surface
at code review — the most expensive possible time to change your mind.

Success metric is **"my mental model matches the code,"** not "correct output" `[FOUND §2.3]`.
Why this is permanent rather than a stopgap: coding models are RL-trained on binary test-pass
rewards with no penalty for eroding maintainability, and bad architecture's cost arrives in weeks,
where no reward signal reaches `[FOUND §2.1]`.

## Key Decisions

Twenty-seven accepted decisions, each with its full Nygard warrant, live in
**[`x-skills-v3-decisions.md`](x-skills-v3-decisions.md)**. **Cite them by bare ID** (`DEC-011`) and
let the reader grep — never by a generated heading anchor, which is derived from heading prose and
breaks the moment a title is reworded (DEC-009's rule, applied to itself). This index is the map;
it is not a substitute for reading a block before changing what it decided.

| ID | Decision | Load-bearing because |
|---|---|---|
| DEC-001 | Three skills; basic-memory + gitnexus kept, wired and warranted | Coupling, not dependency count, is the cost driver |
| DEC-002 | Entry mandatory, depth triaged, **default LOW**, escalation floor | Proportionality is the #1 credible failure of every comparable tool |
| DEC-003 | Hand-authored slot manifest; RESOLVED/ASSUMED/DEFERRED | Forces the classification to happen; the pointer is the checkable half |
| DEC-004 | Research questions first; the scout is **intent-blind** | Best-grounded decision in the set; partial withholding is measured to fail |
| DEC-005 | Fixed question recipe, options + recommendation, budget 3–5 cap 7 | Enumerated options are an information-budget requirement, not taste |
| DEC-006 | Close with acceptance examples; they become the **frozen oracle** | The only intervention measured against the missing-requirement class |
| DEC-007 | Status enum **derived from machine state**, validated mechanically | MAST measures the hole; the closest prior art has no failure branch at all |
| DEC-008 | Pointer-or-delete; three evidence grades; no numeric confidence | Explanations raise acceptance regardless of correctness |
| DEC-009 | Three docs, immutable paths, stable IDs, document precedence | The archival `git mv` has already broken inbound links twice |
| DEC-010 | Serial vertical slices; subagents never mutate concurrently | Every 2026 measurement still puts concurrent mutation below solo serial |
| DEC-011 | Per-task gate cascade, **fully autonomous**, enumerated stop set | Split evidence, chosen knowingly; the debt channel is now quantified |
| DEC-012 | Thin router + phase files; one model-invoked skill; derived `nextStep` | Coupling has no instrument, and that is the regression v3 exists to prevent |
| DEC-013 | Delete, don't port (~2,200–2,400 bootstrap lines) | Lines the model reads at bootstrap and cannot act on |
| DEC-014 | Interview-review dispatch, **unioned** not reconciled | A second independent reader roughly doubles yield at ~26–29% overlap |
| DEC-015 | Cross-model for exactly two roles, capability-gated | Critic *strength* is the active ingredient; also the monomethod fix |
| DEC-016 | basic-memory for **cross-repo transferables only** | The one job `docs/` structurally cannot do; ungoverned stores measure worse than none |
| DEC-017 | gitnexus is **advisory, never a gate**; three deterministic states | 1.4% own-coverage and 7/8 repos stale make a freshness gate decorative |
| DEC-018 | Every ingested payload is fenced as untrusted data | DEC-011 removed the human who would have noticed a poisoned instruction |
| DEC-019 | Every enforcement script is wired and self-tested, or it does not ship | The corpus's dominant failure; this repo has already built two nobody runs |
| DEC-020 | One description now carries the trigger surface of eighteen | Consolidation moves a real risk; guidance names it and prescribes the test |
| DEC-021 | x-implement DONE chains into x-qa; live tests derive from oracle + diff | The QA engine exists and is unreachable — every gap is wiring, and the only implement→QA loop dies with x-team |
| DEC-022 | BLOCKED is a decision brief; reversibility gates ask-vs-decide; answers become scoped rules | The state the user's ask targets hands the human raw gate output while every missing ingredient sits unwired in the repo |
| DEC-023 | x-review kept standalone; `03-review` harvests it inline | User-directed; it is also the *original* of the DEC-022 options render |
| DEC-024 | The codex lane replaces OMO as the cross-model backend | User-directed; probed live 2026-08-06, and it closes the `bin/omo-agent` orphan; plugin half dropped by DEC-026 |
| DEC-025 | agy removed entirely; **codex → same-model** is the only chain | User-directed; deletes the second bespoke binary and cancels the envelope harvest |
| DEC-026 | Zero plugin dependencies; thin `x-delegate` drives both CLIs | One envelope for both channels; the plugin field is unofficial, tiny or stale |
| DEC-027 | Reviewer roster is user config; x-review runs all lanes in parallel | Third-family coverage at config cost; kills the hardcoded-roster churn class |

## Contracts

**This block is authoritative.** Where a DEC body and this block disagree, the block wins and the
DEC is amended (DEC-008).

```
TerminalEmit                        # first token, derived — never model-composed
  status   : DONE | BLOCKED | NEEDS-INPUT | FAILED-GATE
  payload  :                        # per-status, NOT a shared string (DEC-008)
    DONE        { filesWritten[], gateExitCodes[] }
                                    # an all-N/A gate list never derives DONE — the SCOPE-GATE
                                    #   discriminator (only-reads | docs-only | no-code-tree |
                                    #   placeholder-test-script) is the sole exemption, printed
                                    #   as the reason; else the emit is NEEDS-INPUT [R6 §4.2]
    BLOCKED     { blockerType, blocker, attempts[], feasibility, question: Question }
                                    # a decision brief, not a report (DEC-022); blockerType ∈
                                    #   missing-dependency | plan-gap | unclear-instruction |
                                    #   repeated-failure | test-modification | infeasible
    NEEDS-INPUT { question: Question }           # the one admissible question
    FAILED-GATE { gate, exitCode, output }
  nextStep : chain{skill, artifactPath}          # derived from `next-skill:` frontmatter
           | remediate{command}                  # fixed table keyed on machine state (DEC-017)
           | end                                 # chain terminus
           # x-implement DONE -> chain{x-qa} iff .x-skills/x-qa/profile.json exists, else end;
           #   a chained QA_VERDICT=fail re-enters as FAILED-GATE{gate: qa} (DEC-021)
  # subagents never ask: a blocker inside a dispatched agent returns as fenced data (DEC-018);
  #   only the top-level router emits NEEDS-INPUT/BLOCKED (DEC-022)

Claim
  grade   : OBSERVED | INFERRED | ASSUMED
  pointer : file:line | command+output | commit-sha | doc-anchor | user-utterance-span
          | memory://<permalink>     # DEC-016 — never OBSERVED; INFERRED only once scouted
  # pointer form routes the store (DEC-016):
  #   file:line | commit-sha | doc-anchor | repo-bound command+output   -> docs/
  #   repo-INDEPENDENT invariant (incl. command+output that survives a checkout) -> basic-memory
  #   user-utterance-span -> the consult artifact itself; MEMORY.md is never written by x-skills
  #   mcp.basic_memory absent -> rg/Read/Write over ~/basic-memory, file-path citations
  #     (DEC-016 as amended [MEM §7] — possible because the store is file-first markdown)

SlotRow
  name     : string
  required : bool
  verdict  : RESOLVED{pointer}      # pointer is the CHECKABLE half — mandatory
           | ASSUMED{falsifier}     # narrative — never evidence of resolution
           | DEFERRED{breaksIf}     # narrative

Question                            # exactly one decision each
  evidence     : pointer            # what was checked and failed to resolve; mid-run this is the
                                    #   consistency ladder walked before asking (DEC-022)
  decision     : infinitive         # "To choose <x>" — the decision required, stated first
  question     : string + options[A|B|C] + D:"none of these — what am I missing?"
                                    # each option carries a one-line user-visible implication;
                                    #   no code-level identifiers in question or options (DEC-022)
  reversibility: reversible | costly | one-way   # reversible + myAnswer => agent decides and
                                    #   logs, never interrupts; costly/one-way => ask (DEC-022)
  scope        : alternative-space  # a recorded rule never extends past it (DEC-022)
  eliminates   : reading            # which competing reading this rules out; none => inadmissible
  myAnswer     : recommendation + costOfBeingWrong
  # ordered stakes-descending; no yes/no confirmations; an unanswered NEEDS-INPUT degrades to
  #   BLOCKED — no self-answer path exists (DEC-022)

ReviewFindings → union              # DEC-014, agent-side, zero human cost
  cues[]       : user-utterance-span
  questions[]  : Question           # unioned + deduped with primary's, never reconciled
  downgraded[] : OBSERVED → INFERRED
  reviewer     : same-model | <backend>/<model>    # DEC-015/027 — recorded per lane
  overlap      : |same| / |union|   # same iff eliminates: strings match; >=0.80 narrows DEC-014

ConsultArtifact → x-record          # the gate x-record checks on disk
  tier         : 0 | 1 | 2 | 3
  slots        : SlotRow[]          # zero open REQUIRED rows to pass
  examples     : (input → expectedOutput)[]        # becomes the frozen oracle; rows carry x-qa
                                                   #   obligation ids so the chained run's
                                                   #   coverage gate arms (DEC-021)
  terminalState: answered | research | backlog | plan   # derived from tier, DEC-002 phase-mask
                                    # 0,1 -> answered | 2 -> research|backlog | 3 -> plan
                                    # `handoff` deleted — no DEC defined it
  nextStep     : TerminalEmit.nextStep

RunArtifacts   .x-skills/run/<slug>/               # gitignored; one dir per consult/plan slug
  metrics.md   : one row per instrument            # DEC-014 overlap, DEC-017 gitnexus-vs-Grep,
                                                   #   DEC-003 rework pointer — written from S2
  progress.md  : `Slice <N>: complete (<sha>)`     # resume predicate (DEC-011); line 1 names the plan
               | `Decision: <id> -> <choice> (<span>)`  # self-decided or answered (DEC-022)
  dispatch/    : <phase>-<n>.txt, written pre-dispatch  # what S4's lint reads (DEC-012)
  attempt-1/   : stashed tree before a constrained retry  # DEC-011 falsifier's only channel
  envelope.md  : serialized BLOCKED/NEEDS-INPUT + its answer when given — resume reads it before
                 the ledger; the run exits cleanly on emit (DEC-022)

CapabilityManifest                  # additions only; schema lives in capability-loading.md
  mcp.gitnexus  : { pinned, indexed, fresh, commitsBehind, ownCoverage }   # DEC-017
  tool.codex    : bool              # DEC-024/026 — binary-only pins; no plugin pin exists
  tool.opencode : bool              # DEC-026
  roster        : models.json       # user file, project override wins (DEC-027)
```

Manifests are per situation, cheapest disqualifier first: **new-requirement** (user + trigger,
current behavior, desired behavior, boundary/contract, non-goals, acceptance examples) ·
**read-only-question** (the question asked, who is asking and what decision it feeds, claim +
probe) · **prod-bug** (expected behavior *first*, error evidence, repro, blast radius, when it
started).

## Disposition — all 19 dirs, and what S6 actually does

**End state: 3 chain skills + `x-delegate` + 9 kept + `x-shared/` = 14 dirs** (x-delegate added
2026-08-06 — DEC-026; x-review joined the kept set
2026-07-30, user-directed — DEC-023; x-qa kept + wired in S7, DEC-021; three kept rows are
**rewrite passes**, not string-strips — see the table. The "6 kept / 10 dirs" this line carried
until 2026-07-29 contradicted both the headline and this section's own table). Round 3 never stated this
and three passages disagreed: the headline said "collapse 19 into 3", Non-Goals kept 5, and S6 said
"retire the 19" — which read literally deleted the kept ones. Six skills had no disposition anywhere
(x-design, x-guide, x-mindful, x-review, x-upstream, and x-research beyond its doc paths), and
**x-upstream has zero inbound references**, so nothing would have broken loudly when S6 deleted it
by omission `[R4 §2]`. Reuse verdicts and the assets behind them are in `[R4 §4]`.

| Dir | Fate | Goes where |
|---|---|---|
| x-do | absorbed + harvest | x-implement (`01-slice`); bounded-escalation branch → `02-gates`; `iteration-patterns.md:17-29`'s progress-signal counter is 02-gates' stagnation base — **one merged ladder** with x-bugfix's, thresholds bound to the countable definition `[R6 §3.5]`; status-flip + never-revert-on-abort invariant (`SKILL.md:216-224`) → x-implement close-out; archival `git mv` NOT ported (DEC-009) |
| x-bugfix | absorbed + harvest | intake → `manifests/prod-bug.md`; 3-Strike/Instrumentation Pivot → `02-gates` — **merged into x-do's ladder, one threshold set survives** `[R6 §3.5]`; regression-gate proof (test FAILS pre-fix / PASSES post-fix, `prevention-gate.md:9-11`) → `02-gates` prod-bug path; `backward-tracing.md` near-verbatim (strip its `prevention-gate.md:55` pointer) |
| x-verify | absorbed | `gates.sh` + `validate-emit.sh` — its model-asserted verdicts are what DEC-007 inverts |
| x-review | **kept + harvest** (DEC-023) | standalone multi-model review stays; `03-review` harvests inline: Scope Contract, `scope-guard.md` SCOPE body, verify-each-finding, the synthesis-side scope **filter** (`step-03:11-36`) + >30% unreliability threshold (`:49`); Impact-line fixtures (`:120-132`) → `emit-contract.md` altitude calibration; reviewer roster externalized to `models.json` and every lane dispatched in parallel (DEC-027) |
| x-research | absorbed + harvest | MCP rows: **dedupe against `mcp-toolbox.md`** — 02-scout carries only rows it lacks, plus cheapest-first ordering and the primary-first HARD GATE (`SKILL.md:71,:83`) `[R6 §3.6]`; `synthesis-rules.md` → `templates/research.md` |
| x-backlog | absorbed | x-record — `references/template.md` CORE skeleton is the backlog template; `slug:`/`type:` frontmatter survives **verbatim** — kept x-worktree derives `<type>/<slug>` branches from it (`doc-naming.md:19`) `[R6 §4.6]`; the batch-once blocker checkpoint (`SKILL.md:78-91`) → `01-questions` + the DEC-022 trigger |
| x-mindful | absorbed + harvest | `extraction-prompts.md` → `01-questions`/`03-debate` **carrying `item-schema.md:65-83` and `step-02-extract.md:58-64`'s cross-cutting heuristics — the prompts are non-functional without them** `[R6 §4.10]`; reversibility + severity rubric → `00-triage` (scale sourced from kept `severity-guide.md`, never restated). **Do not port the per-item walkthrough** |
| x-omo · x-gemini · x-team | **deleted** | harvest first: `prompt-blocks.md` → dispatch prompts; the agy envelope harvest is **cancelled** — agy leaves v3 entirely, and `bin/agy-agent` + `bin/setup` §1h die with `bin/omo-agent` (DEC-025); `blocker-escalation.md` sanitizer + `monitor-loop.md:7-24`'s validate-before-act schema + `worker-preamble.md:42-46,:73-75` two-phase-write rules → `emit-contract.md`/`validate-emit.sh` (DEC-018, DEC-022, `[R6 §4.3, §4.5]`); worker preamble's QA loop → the DEC-021 chain; the options render sources from **x-review** (DEC-023), not x-team's thin copy. x-omo's deletion includes `bin/omo-agent` + `bin/setup` §1 + the `find-plugin-dir` branch — the codex lane takes the job (DEC-024/026) |
| x-worktree · x-guide · x-api-pentest | **kept + rewrite pass** (R6) | not string-strips: x-worktree dispatches deleted x-do (`SKILL.md:152`) and `caller-integration.md:3,:45,:99` names three dead callers — retarget to x-implement or rewrite for direct invocation; x-guide's `step-02-ingest.md:45-82` are dispatch procedures into deleted skills and `routing-matrix.md:9` leaves the advertised `vague` input route-less (plus `config.json:2-4`, invisible to a `.md` scrub); x-api-pentest's references contradict its already-fixed steps (`--base-url`/`--report-format json` vs `--url`/`--report ndjson` — gotchas V2) and the `[F]` menu bullet at `step-06-report.md:99` loses its target |
| x-worktree-isolate · x-skill-improve · x-design · x-upstream | **kept** + scrub/fix | x-worktree-isolate: the prefix scrub is a provable no-op — instead fix two doc contradictions (`gotchas.md:89-91` vs `SKILL.md:95-96`; `detection-heuristics.md:27` vs `:87`) + the hardcoded `/Users/randytran` path (`SKILL.md:24`); x-skill-improve: re-key 14 dead refs incl. `config.json:3-8` and `analysis-rubric.md:13-14` (its checks would flag correct v3 behavior); x-design: 6 dead refs (`SKILL.md:20,:21,:78,:80,:128`, `gotchas.md:39`) — round-4's "no known dirt" was false; x-upstream: clean `[R6 §2]` |
| x-qa | **kept + wired** | S7 (DEC-021): x-implement DONE chains in; scout armed on the branch/pr path; `references/change-derivation.md` added; TEST_PLAN persisted; real-QA contract untouched; the scrub pass still applies; runner dispatch re-pointed from agy to the codex lane, same-model fallback (DEC-025) |
| x-shared | rebuilt | see the outline; 14 files today, 8 survive |

**S6 is not only deletion — the kept skills are not clean, and Acceptance row 1 fails on day one
without this `[R4 §4]`.** The scrub is also **wider than two prefixes** `[R6 §1]`: the dead-skill
name sweep over the 9 kept dirs returns **95 hits across 33 files**, none matching either
framework prefix — including two `config.json` files and four x-qa shell scripts — so S6 carries
a second, tracking-aware assertion over dead names covering `.json`/`.sh`, and x-review joins the
scrub with 20 framework strings across 4 files plus its roster externalization to `models.json`
(DEC-023/027).
DEC-025 adds a third sweep: `agy` strings over the kept dirs + surviving x-shared files —
baseline **61 case-insensitive hits across 21 files**, x-qa's two eval `.sh` scripts included
— → 0.
x-qa carries 8 framework strings and routes to x-omo/x-gemini/x-team in
three places (Bootstrap step 2, two Capability Routing rows, Dependencies); x-api-pentest carries 2;
`instrument-and-verify.md`, which the outline marked *unchanged*, carries
`superpowers:test-driven-development` at line 77 plus two dead intra-repo paths — one 83-line file
failing both the dependency grep and `lint-chain.sh` simultaneously. x-guide routes to x-gemini and
x-research; x-skill-improve's `analysis-rubric.md` is keyed to the 19 v2 skill names. Three
carry-overs must survive the x-shared pruning or a kept skill breaks silently:
`severity-guide.md` (17 lines, consumed by x-api-pentest and x-skill-improve), the DOCKER CONTEXT
half of `context-envelope.md` (x-worktree), and `workflow-chains.md`'s Backlog Lifecycle line — the
**only** documented entry into x-worktree's doc-driven mode, which must move into x-worktree's own
`SKILL.md` before the file dies.

## Structure Outline

```
skills/
  x-consult/                        # NEW — only model-invoked skill
    SKILL.md                        # thin router: triage → questions → scout → debate → review → close
    phases/00-triage.md             # tier printed first, one-word override (DEC-002)
    phases/01-questions.md          # research questions: agent-authored, agent-answered (DEC-004)
    phases/02-scout.md              # intent-blind subagent; file:line facts only
    phases/03-debate.md             # question recipe (DEC-005) + slot sweep (DEC-003)
    phases/03b-review.md            # NEW — interview-review dispatch, union + dedupe (DEC-014)
    phases/04-close.md              # acceptance examples + exception sweep (DEC-006)
    manifests/{new-requirement,read-only-question,prod-bug}.md
  x-record/                         # NEW  (was x-backlog + x-research doc paths)
    SKILL.md
    templates/{research,backlog,plan}.md          # backlog carries Structure Outline section;
                                    #   acceptance examples carry obligation ids (DEC-021);
                                    #   plan carries a decision-authority section (DEC-022)
    lint-plan.sh                    # rejects any phase naming no end-to-end validation (DEC-010)
  x-implement/                      # NEW  (was x-do + x-bugfix + x-verify)
    SKILL.md
    phases/{01-slice,02-gates,03-review,04-report}.md
    gates.sh                        # floor cascade + plan's verification list; cmd+exit; sha256
                                    #   acceptance freeze (DEC-006); stub scan (DEC-011); N/A rows;
                                    #   from x-qa/scripts/lib/verdict.sh (DEC-019)
    # run dir: .x-skills/run/<slug>/ — progress.md, metrics.md, dispatch/, attempt-1/ (Contracts)
  x-delegate/                       # NEW (DEC-026) — thin human channel for the cross-model lane:
    SKILL.md                        #   review | ask | delegate, --backend codex|opencode, wrapping
                                    #   capability-loading.md's canonical invocations; roster from
                                    #   models.json (DEC-027); disable-model-invocation: true
  x-shared/                         # 14 files today -> 8; every one has a verdict (DEC-013)
    emit-contract.md                # NEW — DEC-007/008/018/022 one place: x-team sanitizer +
                                    #   monitor-loop validate-before-act schema + two-phase-write
                                    #   rules [R6 §4.3, §4.5]; options render from x-review
                                    #   step-03 (the original, DEC-023); Handoff Context format
                                    #   lands here and its 6 refs repoint [R6 §4.1]
    validate-emit.sh                # NEW — schema-conditional required fields; pre-judging +
                                    #   hypothesis-marker lint over dispatch/; ledger line format
    lint-chain.sh                   # NEW — reachability, enumerated chain edges, live-ref budget,
                                    #   phase-file wc -l, bootstrap line total, one-level-deep refs
    capability-loading.md           # MODIFIED — drop plugin.omc/superpowers + agy_cli + dead
                                    #   consumer list; add ownCoverage + tool.codex/tool.opencode
                                    #   + both canonical invocations + the models.json roster
                                    #   schema (DEC-024/026/027); plugin.codex never ships;
                                    #   agy envelope harvest cancelled (DEC-025)
    mcp-toolbox.md                  # MODIFIED — home of DEC-013/016/017 contracts; rewrite every
                                    #   OMO/agy fallback cell to codex → same-model, DEC-025 (was absent from this outline)
    completion-cascade.md           # MODIFIED -> harvested into gates.sh, then DELETED
    done-format.md                  # MODIFIED — 3 rules survive, not 3 shapes: banner ban (:97),
                                    #   first-token discipline, safety-axis option rule
    invocation-guide.md             # MODIFIED — handoff/assign + collect-all-background only
                                    #   (~45 of 235 lines); ladder deleted -> CLAUDE.md needs a fix
    instrument-and-verify.md        # MODIFIED (not "unchanged") — 3 rules keep; strip the
                                    #   superpowers: string at :77 and 2 dead intra-repo paths
    severity-guide.md               # unchanged — reuse verbatim; 2 KEPT skills consume it
    README.md                       # MODIFIED — rewrite the index, keep the "why no SKILL.md" rule
    context-envelope.md             # MERGED-AND-DELETED — DOCKER half folds into x-worktree's
                                    #   caller-integration.md:81-95 (already verbatim there, no
                                    #   new file); Handoff Context half -> emit-contract.md [R6 §3.2-3.3]
    slot-schema.md  reactions-vocabulary.md   # DELETED -> lint-chain.sh bad-case fixtures
    common-gotchas.md  omo-routing.md  workflow-chains.md   # DELETED (carry 1 line to x-worktree)
  bin/setup  hooks/inject-capabilities.sh     # MODIFIED — ownCoverage + codex probe (S3); DELETE
                                    #   setup §1 omo-agent binding + find-plugin-dir branch +
                                    #   bin/omo-agent itself (DEC-024) + the §1h agy binding +
                                    #   bin/agy-agent (DEC-025); no marketplace-install print —
                                    #   no plugin dependency remains (DEC-026); probe tool.opencode;
                                    #   per-backend model discovery + models.json seeding — opencode
                                    #   via `opencode models` captured-to-var (64KB pipe truncation)
                                    #   with opencode.json fallback, codex via config.toml default
                                    #   (no enumeration exists), claude static (DEC-027 as amended)
  x-omo/ x-gemini/ x-team/          # DELETED as bootstrap deps (DEC-013), after harvest —
                                    #   including bin/omo-agent (DEC-024) + bin/agy-agent (DEC-025)
  x-worktree/ x-worktree-isolate/ x-qa/ x-api-pentest/ x-skill-improve/ x-design/ x-guide/
  x-upstream/ x-review/             # KEPT — jobs v3 does not absorb; S6 scrub/rewrite per the
                                    #   Disposition table; x-qa wired in S7 (DEC-021); x-review
                                    #   kept standalone (DEC-023)
```

Slices in order. **No slice starts before its predecessor's checkpoint passes.**

| # | Slice | Verification checkpoint |
|---|---|---|
| S0 | `emit-contract.md` + `validate-emit.sh` | 3 good / 5 bad emits (missing status token, composed status, OBSERVED claim with no pointer, BLOCKED without a Question, code-level identifier in a question/option — DEC-022) → correct verdict on all 8; `--selftest` hard-fails; wired to `npm run check` and a deliberately-broken run goes red (DEC-019) |
| S1 | x-consult Tier 0 ANSWER, end to end | Real read-only question about this repo → derived status, every claim pointered, terminates without offering implementation |
| S2 | x-consult Tier 2 + x-record backlog doc + DEC-014 review | Doc lands at immutable path with `DEC-`/`AC-` IDs, a Structure Outline section, an acceptance-examples block and a per-phase verification list; **overlap rate written to `metrics.md`** with `reviewer:` recorded; basic-memory write-time overlap lint rejects a >40-word restatement; validator passes |
| S3 | x-implement on that doc, serial slices + gitnexus lane | Every gate prints command + exit code; status derived; the **backlog doc's** verification list extends the floor cascade; sha256 freeze fires; N/A rows print their reason; a code-touching slice with zero runnable gates derives NEEDS-INPUT, never DONE (SCOPE-GATE discriminator exempts docs-only/only-reads, printed) `[R6 §4.2]`; stub scan labelled over 10 real diffs; gitnexus prints `commitsBehind` when stale and prints the skip when it withholds |
| S4 | prod-bug manifest + intent-blind scout | Every dispatch prompt lands in `dispatch/` **before** dispatch; the lint finds no pre-judging phrase and no hypothesis marker in the `02-scout` prompt; research doc is fact-only |
| S5 | Tier 3 full chain + plan doc + `lint-plan.sh` | A plan with a phase naming no end-to-end validation is rejected; one missing a per-phase success criterion, exact file paths or an out-of-scope statement is rejected; a fully-validated plan passes |
| S6 | Cutover — delete + harvest per the Disposition table, **scrub/rewrite the 9 kept skills** | `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ \| wc -l` → 0 **including x-qa, x-api-pentest and x-review**; the dead-name sweep (`git grep -nE 'x-(do\|bugfix\|verify\|research\|backlog\|mindful\|omo\|gemini\|team)'` over the 9 kept dirs, `.json`/`.sh` included) → 0, from a 95-hit/33-file baseline `[R6 §1]`; `lint-chain.sh` green on the whole tree; bootstrap line count down ≥1,500; DEC-020 trigger eval passes at ≥0.5; the agy sweep → 0 from a 61-hit/21-file baseline (DEC-025); a fresh `bin/setup` run succeeds with neither omo-agent nor agy-agent present (DEC-024/025); x-delegate ships thin (`disable-model-invocation: true`, `lint-chain.sh` green) and one x-review run on a 3-entry roster launches every lane in parallel with per-lane `reviewer:` recorded (DEC-026/027) |
| S7 | Wire the QA chain into kept x-qa (DEC-021) + mid-run decision recording (DEC-022) | One real chained run: x-implement DONE derives `chain{x-qa}`; acceptance examples arrive as `severity: required` obligations and the coverage gate **arms on the branch/pr path**; `QA_VERDICT=fail` re-enters as `FAILED-GATE{gate: qa}`; a pass appends verdict + coverage counters to the backlog doc; one reversible decision self-decided with a `Decision:` line, one costly decision emitting NEEDS-INPUT whose options carry implications at human altitude; the fail edge re-points x-qa's `/x-skills:x-bugfix` offers to x-implement's prod-bug intake and the machine-caller identity to the chain (DEC-021 as amended); the runner lane dispatches via DEC-024's canonical invocation, same-model when codex is absent (DEC-025) |

## Scope & Non-Goals

**In scope:** the three chain skills + the `x-delegate` thin wrapper (DEC-026), the shared emit
contract + validator, the three doc templates, the
DEC-014 review dispatch, the DEC-015 capability-gated two-role cross-model path (now backed by
the plugin-free codex + opencode lanes, DEC-024/026, with the DEC-027 roster), the DEC-013 deletions (including `bin/omo-agent` and `bin/agy-agent` — DEC-024/025), the DEC-021 QA chain (S7),
the DEC-022 blocker decision brief, the DEC-023 x-review scrub + DEC-027 roster externalization,
and retiring the
v2 skills the Disposition deletes.

**Non-goals:** `x-worktree`, `x-api-pentest`, `x-worktree-isolate`, `x-skill-improve`,
and — added round 4, previously unstated anywhere — `x-design`, `x-guide`, `x-upstream`
(orthogonal, invoked by name; see the Disposition table), plus — added 2026-07-30 — `x-review`
internals beyond the S6 scrub + roster re-point (DEC-023). `x-qa` left this list on 2026-07-29:
S7 wires it without touching its internals or its real-QA contract (DEC-021). Cross-model as a
**general** dispatch layer (DEC-015 permits exactly two *machine* roles; human-invoked
x-review/x-delegate sit outside that limit — DEC-026/027). Hook-based enforcement of consult-first. Parallel code mutation. Human stops at slice
boundaries (DEC-011, decided against — DEC-022's reversibility gate governs mid-run *decision*
interrupts, not slice boundaries). Notification/delivery infrastructure for blocked envelopes
(terminal + run-dir file only, DEC-022). Change-scoped test selection in place of the per-task
full suite (deferred, DEC-021). Any ML on the rework tally.

## Acceptance

- [ ] `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ | wc -l` returns 0 across all
      shipped skills — **including the kept ones**: x-qa (`SKILL.md`, `explorer-prompts.md`,
      `case-runner-prompts.md`), x-api-pentest (`SKILL.md`, `step-06-report.md`), x-review
      (20 strings across `gotchas.md`, `review-passes.md`, `step-02-review.md`, `step-04-act.md`
      — DEC-023) and
      `x-shared/instrument-and-verify.md` all carry strings today. Two round-4 corrections:
      `grep -rc` prints a `path:count` line per file and can never output a bare `0`, and a
      plain `grep -r` also matches untracked gitignored `.omc/state/*.jsonl` debris — so the
      assertion must be tracking-aware.
- [ ] The dead-skill-name sweep returns 0 over the 9 kept dirs **including `.json` and `.sh`
      files** (tracking-aware; allowlist = surviving skill names). Baseline 2026-07-30: 95 hits
      across 33 files, incl. `x-guide/config.json`, `x-skill-improve/config.json` and four x-qa
      scripts `[R6 §1]`.
- [ ] The agy sweep returns 0 over the 9 kept dirs + surviving x-shared files (tracking-aware,
      case-insensitive). Baseline 2026-08-06: 61 hits across 21 files, incl. two x-qa eval `.sh`
      scripts; `bin/agy-agent` is deleted and `bin/setup` carries no §1h (DEC-025).
- [ ] x-review reads the roster (project override > user file > per-available-backend default),
      launches every entry in parallel, records `reviewer: <backend>/<model>` per lane, and
      prints the skip for any absent backend; an all-absent roster degrades to same-model,
      recorded (DEC-026/027).
- [ ] `bin/setup` discovers the model inventory per backend and offers the pick that seeds
      `models.json`: opencode via `opencode models` captured to a variable — never piped — with
      `opencode.json` as fallback; codex from `~/.codex/config.toml`'s default (no enumeration
      command exists); claude static. The menu caps at **5 per backend** (roster entries first,
      then the configured default, then the per-backend heuristic) with the total printed and a
      manual free-form option last; re-running setup rescans and re-seeds `models.json` after a
      timestamped `.bak`. A roster entry absent from the last discovery warns and
      still runs; the inventory is never persisted into `capabilities.json` (DEC-027 as amended).
- [ ] Recall follows DEC-016's pin-era query rules: `search_notes` queries carry ≥3 plain
      distinctive terms or explicit `OR` (a 2-word query is pure AND with no fallback at the
      0.22.1 pin); tag filters are never used; an empty result is treated as inconclusive and
      retried as `rg` over `~/basic-memory` before the chain concludes "no prior knowledge".
      When `mcp.basic_memory` is absent, recall/write degrade to native `rg`/Read/Write over the
      store with file-path citations (DEC-016 as amended, `[MEM §5–7]`).
- [ ] `validate-emit.sh` rejects a DONE whose gate list is entirely N/A unless the run is
      SCOPE-GATE-exempt (only-reads / docs-only / no-code-tree / placeholder-test-script);
      `gates.sh` short-circuits those cases to a legitimate DONE with the printed reason
      `[R6 §4.2]`.
- [ ] `02-gates` ships exactly **one** stagnation ladder, expressed over iteration-patterns'
      countable definition (mutate+verify pairs) — the 3/5/7 and 3-Strike/Instrumentation-Pivot
      sets merged; no model-judged threshold survives `[R6 §3.5]`.
- [ ] x-consult works from a bare invocation with **no magic phrase**, and prints its tier first.
- [ ] Tier 0 terminates without offering x-record or x-implement.
- [ ] x-record refuses to write when the consult artifact is absent or has an open REQUIRED slot.
- [ ] `validate-emit.sh` rejects: missing status token, model-composed status, an OBSERVED claim
      with no pointer, numeric confidence, a banned label heading, a progress banner, and a
      question that names no reading it eliminates.
- [ ] `lint-plan.sh` rejects a plan containing a phase that names no validation exercising the
      slice end to end.
- [ ] Every gate in x-implement prints command + exit code; status is derived, never asserted; the
      plan's own verification entries run alongside the floor cascade.
- [ ] The DEC-014 review dispatch's **overlap rate** with the primary agent's questions is logged
      from S2 — the falsifier for the monomethod risk.
- [ ] DEC-015's two roles degrade to same-model with `reviewer: same-model` recorded on the overlap
      row — silent in the human channel only, never in the machine channel (DEC-015, round 4).
- [ ] The cross-model lane re-derives a real exit code (empty output + log tail) rather than
      trusting the CLI's exit status — a discipline born from agy's exit-0 masking, kept for the
      codex lane until S2 exercises a real failure (DEC-024/025) — and serializes its calls;
      otherwise an auth failure logs as 0% overlap.
- [ ] DEC-020: x-consult's description passes a should/should-not-trigger eval at ≥0.5, and every
      other shipped skill declares `disable-model-invocation: true`.
- [ ] Reference files are one level deep from each `SKILL.md`, and every phase-file pointer states
      **when** to load it (`lint-chain.sh`).
- [ ] No doc path changes on completion; no inbound link breaks at `status: done`.
- [ ] Bootstrap-path line count drops by ≥1,500 vs v2, **measured on every release, not once**.
- [ ] `lint-chain.sh` rejects: a router naming a missing file, a `phases/` file no router names, and
      a phase file naming a skill more than one hop downstream.
- [ ] DEC-019: every gate script is **wired to `npm run check`** in the slice that creates it, ships
      good/bad fixture pairs and a `--selftest` that hard-fails, and each slice's checkpoint
      includes one deliberately-broken run that must go red.
- [ ] `.x-skills/run/<slug>/metrics.md` exists from S2 and carries the overlap row, the
      gitnexus-vs-`Grep` row, and the rework pointer — the three instruments that had no writer.
- [ ] x-record prints the derived project slug and hard-fails on a slug containing a dot (DEC-016).
- [ ] gitnexus lane prints `commitsBehind` when stale and prints the skip when it withholds the
      correctness-sensitive class; never silent either way (DEC-017).
- [ ] `validate-emit.sh` additionally rejects: a BLOCKED without a Question, a question or option
      containing a code-level identifier, an option missing its implication line, and a missing
      reversibility class (DEC-022; fixtures per DEC-019).
- [ ] A reversible-classed decision never emits NEEDS-INPUT — it is self-decided and appears as a
      `Decision:` line in `progress.md`; an unanswered NEEDS-INPUT resumes as BLOCKED, never
      self-answers (DEC-022).
- [ ] The chained x-qa run arms the coverage gate on the branch/pr path with acceptance-derived
      `severity: required` obligations, and `QA_VERDICT=fail` surfaces as `FAILED-GATE{gate: qa}`
      with constrained-retry semantics (DEC-021, S7).
- [ ] 03-review runs the tamper checklist and the reviewer-authored mutant probe on changed hunks;
      an edit to a pre-existing test or the frozen oracle emits
      `BLOCKED{blockerType: test-modification}` (DEC-011 as amended, DEC-021).
- [ ] One full Tier 3 cycle completes on a real feature — **which has never happened in v2**.
      Human-observed; no instrument in the surveyed corpus can automate this row.

## Handoff Notes / Open Questions

- **Assumed — the manifest buys robustness, not accuracy.** The one A/B says a scaffold beats an
  *unscaffolded* agent (69.40% vs 61.20%) but **ties a well-prompted one (70.40%)** at double the
  cost; its clear win is on instruction-fragile backbones `[FOUND §5]`. Falsifier: the rework tally.
- **Assumed — DEC-014's port from humans to one base model holds.** The measured effect came from
  perception differences between *people*. Falsifier: overlap rate persistently above ~26%.
- **Assumed — the exception sweep works on a just-scouted codebase.** Alexander's 3.17× came from
  experienced engineers with operational intuition. Falsifier: ratio of exception probes ruled in
  scope vs dismissed. Also: DEC-006's sweep and DEC-014 hunt the same omission class and may
  overlap more than their individual effect sizes suggest.
- **Accepted risk — no human reads the diff (DEC-011).** Success metric now rests entirely on the
  upstream artifacts. Falsifier: rework attributable to code the human never read. Re-confirmed by
  the user 2026-08-06 at the pre-build review (offered slice-boundary and Tier-3-only pauses;
  declined both).
- **Open:** DEC-003 gates artifact-internal completeness only. Nothing in this design closes
  "the requirement nobody thought of" when it lives outside both your words and the codebase —
  and three inspection studies say a topic checklist does not close it either. Stated, not solved.
- **Gotcha:** nothing stops a user who never invokes x-consult. Accepted, not solved.
- **Resolved 2026-07-28 — the doc-length gotcha.** The question was "is the cap wrong or has this
  stopped being a review surface"; the corpus answered a better one: an unenforced cap holds when it
  is generous *and names a destination*, fails when it is tight and names none `[OSS §5]`. Both
  halves are now fixed in DEC-009 — the budget is **per phase file**, this doc's destination is
  `docs/research/`, and the number is asserted by `wc -l` or deleted. This doc stays long because it
  is the review surface for a 27-decision design; the phase files are what must stay small.
- **Read before S3:** HumanLayer's `rpi` plugin v0.18.1 (16 skills) — **not** the pre-QRSPI
  `create_plan.md` set, which prescribes the exact horizontal ordering DEC-010 bans `[FOUND §6]`.
  Cite behaviour; do not vendor text (All Rights Reserved). The `implementer-agent` prompt — the
  closest prior art to x-implement's slice executor — is unpublished and remains unavailable.
  **Now partly superseded:** `[OSS §7]` names six readable files covering the same ground, including
  the constrained-repair and instrument-selftest prior art, with no licensing constraint.
- **Assumed — gitnexus earns its place.** Measured own-coverage is 1.4% and 7 of 8 repos are stale,
  so both lanes are near-dead exactly where DEC-017 gates them in. Falsifier: 10 x-implement slices
  in a real code repo with zero `impact` calls that beat `Grep` → cut it to a human-invoked tool.
- **Assumed — the basic-memory durability gate binds.** It is already being ignored in the live
  store (a green-run note the contract bans; ~18 session notes). DEC-016 replaces model discretion
  with a derived precondition. Falsifier: >1 non-durable note in 6 across S1–S6.
- **Resolved 2026-07-28 — recall placement.** Round 3 logged this as open pending a falsifier;
  round 4 found DEC-004's evidence contradicts the old placement outright, so recall **moved to
  `03-debate`, after the scout**. No experiment was needed to decide a question the cited evidence
  already answered `[R4 §2]`.
- **Resolved 2026-07-28 — the `CLAUDE.md` / DEC-017 contradiction, and it was narrower than
  reported.** `CLAUDE.md § GitNexus Fallback` already exempted the *stale-index* case, and this
  repo's index is 15 commits behind, so the MUSTs were already inapplicable by the existing clause.
  The real gap was **own-coverage**, which no clause covered: at 1.4% coverage with 0 own symbols in
  any execution flow and 0 of 113 `.sh` files indexed, `impact` returns "symbol not found" on
  anything you would edit here even with a perfectly fresh index. A `§ Own-coverage carve-out`
  section now scopes the MUSTs out of x-skills' own `skills/`/`bin/`/`hooks/`/`docs/` trees while
  leaving them intact for target repos. S0 is unblocked.
- **Gotcha — the installed capability manifest is one version stale.** `~/.config/x-skills/
  capabilities.json` reports `plugin_version 2.3.0` against the repo's 2.4.0, and it is what gates
  both kept dependencies. Re-run `/x-skills:setup` before trusting a capability-gated path `[R4 §1]`.
- **Resolved 2026-08-06 — the read-only question, open since R4 and inherited by the codex lane.**
  Neither `agy` nor `bin/agy-agent` ever documented a read-only flag `[R4 §4]`; the installed
  `codex-cli 0.145.0` does, and a live probe proved it **enforced** (write attempt → `DENIED`,
  no file created), non-interactive (`approval: never`), and stdin-fed (`-` argument, DEC-018).
  DEC-024's machine channel is capability, not spec; the canonical invocation and measured
  `--ignore-user-config` overhead saving live in DEC-024's 2026-08-06 amendment. What remains for
  S2 is only exercising a *failure* case before trusting the exit code (DEC-015's agy lesson).
- **Assumed — exploratory testing transfers from human testers to agent-run charters.** Every ET
  measurement is human-subject; the agent-native mitigation is x-qa's existing bounded-probe +
  independent-triage hunt. Falsifier: `EXPLORE_CONFIRMED` per probe budget across 5 chained runs
  (DEC-021) `[R5 §6]`.
- **Open — the DEC-022 altitude lint is heuristic.** "No code-level identifiers" is enforced by
  pattern (path-like tokens, `()`, snake_case in narrative fields) and will misfire both ways;
  tune on S0's fixtures, revisit at the S3 checkpoint.
- **Open — DEC-020's trigger eval has no harness.** Official guidance supplies the protocol
  (~20 prompts per side, ~3 runs, 0.5 threshold) and `skill-creator` automates it, but v3 ships no
  implementation. It is the one instrument round 4 added that is unbuilt `[R4 §6]`. 2026-08-06:
  user-confirmed at the pre-build review — the harness is a **committed S6 deliverable** (the
  manual-spot-check and defer options were declined); the ≥0.5 acceptance row stands unchanged.
- **Not verifiable, stated so it is not mistaken for evidence `[R4 §6]`.** No controlled study
  isolates spec-driven from plan-free agent workflows (the critique corpus is retrospectives plus
  one adjacent RCT); no end-to-end A/B exists for a coding agent with vs without a cross-session
  memory store, so DEC-016's magnitude is extrapolated; and the checkpointed-vs-autonomous question
  (DEC-011) has no RCT — it rests on field telemetry and split prior art.
