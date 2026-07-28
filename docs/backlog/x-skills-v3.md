---
title: x-skills v3 — consult / record / implement
slug: x-skills-v3
type: refactor
status: ready
created: 2026-07-27
updated: 2026-07-29
related: [x-skills-v3-decisions, x-skills-v3-foundations, v3-round4-audit, v3-qa-escalation]
---

# x-skills v3 — consult / record / implement

Collapse 18 plugin skills into **3 new + 8 kept**, with zero runtime dependency on
`obra/superpowers` or `yeachan-heo/oh-my-claudecode`. Two MCP dependencies are kept deliberately:
basic-memory and gitnexus.

**This doc is the human review surface. Read it end to end.** It carries the problem statement, the
disposition of every v2 skill, the contracts, the build order and the acceptance list. The
twenty-two decisions and their warrants live in
**[`x-skills-v3-decisions.md`](x-skills-v3-decisions.md)** — read a block before changing what it
decided. Facts and citations live in `../research/`: `[FOUND]` =
`2026-07-27-x-skills-v3-foundations.md`, `[OSS]` = `2026-07-28-oss-skill-framework-survey.md`,
`[R4]` = `2026-07-28-v3-round4-audit.md`, `[R5]` = `2026-07-29-v3-qa-escalation.md`.

**Five audit/research rounds.** R1 established the design; **R2** falsified much of it and added DEC-014/015;
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
the wiring doesn't" `[R5 §5]`.

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

Twenty-two accepted decisions, each with its full Nygard warrant, live in
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

## Contracts

**This block is authoritative.** Where a DEC body and this block disagree, the block wins and the
DEC is amended (DEC-008).

```
TerminalEmit                        # first token, derived — never model-composed
  status   : DONE | BLOCKED | NEEDS-INPUT | FAILED-GATE
  payload  :                        # per-status, NOT a shared string (DEC-008)
    DONE        { filesWritten[], gateExitCodes[] }
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
  reviewer     : same-model | cross-model:<cli>    # DEC-015 — machine channel only
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
  crossModelCli : string | null     # DEC-015 two-role gate
```

Manifests are per situation, cheapest disqualifier first: **new-requirement** (user + trigger,
current behavior, desired behavior, boundary/contract, non-goals, acceptance examples) ·
**read-only-question** (the question asked, who is asking and what decision it feeds, claim +
probe) · **prod-bug** (expected behavior *first*, error evidence, repro, blast radius, when it
started).

## Disposition — all 19 dirs, and what S6 actually does

**End state: 3 new skills + 8 kept + `x-shared/` = 12 dirs** (seven kept unchanged; x-qa kept +
wired in S7, DEC-021 — the "6 kept / 10 dirs" this line carried until 2026-07-29 contradicted both
the headline and this section's own table). Round 3 never stated this
and three passages disagreed: the headline said "collapse 19 into 3", Non-Goals kept 5, and S6 said
"retire the 19" — which read literally deleted the kept ones. Six skills had no disposition anywhere
(x-design, x-guide, x-mindful, x-review, x-upstream, and x-research beyond its doc paths), and
**x-upstream has zero inbound references**, so nothing would have broken loudly when S6 deleted it
by omission `[R4 §2]`. Reuse verdicts and the assets behind them are in `[R4 §4]`.

| Dir | Fate | Goes where |
|---|---|---|
| x-do | absorbed | x-implement (`01-slice`); bounded-escalation branch → `02-gates` |
| x-bugfix | absorbed + harvest | intake → `manifests/prod-bug.md`; 3-Strike/Instrumentation Pivot → `02-gates`; `backward-tracing.md` near-verbatim |
| x-verify | absorbed | `gates.sh` + `validate-emit.sh` — its model-asserted verdicts are what DEC-007 inverts |
| x-review | absorbed + harvest | `03-review`: Scope Contract, `scope-guard.md`, verify-each-finding pass |
| x-research | absorbed + harvest | MCP detection rows → `02-scout`; `synthesis-rules.md` → `templates/research.md` |
| x-backlog | absorbed | x-record — `references/template.md` CORE skeleton is the backlog template |
| x-mindful | absorbed + harvest | `extraction-prompts.md` → `01-questions`/`03-debate`; reversibility + severity rubric → `00-triage`. **Do not port the per-item walkthrough** |
| x-omo · x-gemini · x-team | **deleted** | harvest first: `prompt-blocks.md` → dispatch prompts; agy exit-0 semantics → `capability-loading.md`; `blocker-escalation.md` sanitizer **+ options-with-implications render** → `emit-contract.md` (DEC-018, DEC-022); worker preamble's QA loop → the DEC-021 chain |
| x-worktree · x-worktree-isolate · x-api-pentest · x-skill-improve · x-design · x-guide · x-upstream | **kept unchanged** | plus a mandatory scrub pass, below. x-design/x-guide/x-upstream added round 4 — orthogonal jobs with no successor in v3 |
| x-qa | **kept + wired** | S7 (DEC-021): x-implement DONE chains in; scout armed on the branch/pr path; `references/change-derivation.md` added; TEST_PLAN persisted; real-QA contract untouched; the scrub pass still applies |
| x-shared | rebuilt | see the outline; 14 files today, 8 survive |

**S6 is not only deletion — the kept skills are not clean, and Acceptance row 1 fails on day one
without this `[R4 §4]`.** x-qa carries 8 framework strings and routes to x-omo/x-gemini/x-team in
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
  x-shared/                         # 14 files today -> 8; every one has a verdict (DEC-013)
    emit-contract.md                # NEW — DEC-007/008/018/022 (x-team sanitizer + escalation
                                    #   render, altitude + implication rules), one place
    validate-emit.sh                # NEW — schema-conditional required fields; pre-judging +
                                    #   hypothesis-marker lint over dispatch/; ledger line format
    lint-chain.sh                   # NEW — reachability, enumerated chain edges, live-ref budget,
                                    #   phase-file wc -l, bootstrap line total, one-level-deep refs
    capability-loading.md           # MODIFIED — drop plugin.omc/superpowers + dead consumer list;
                                    #   add ownCoverage + crossModelCli + agy exit-0 semantics
    mcp-toolbox.md                  # MODIFIED — home of DEC-013/016/017 contracts; rewrite every
                                    #   OMO/agy fallback cell (was absent from this outline)
    completion-cascade.md           # MODIFIED -> harvested into gates.sh, then DELETED
    done-format.md                  # MODIFIED — 3 rules survive, not 3 shapes: banner ban (:97),
                                    #   first-token discipline, safety-axis option rule
    invocation-guide.md             # MODIFIED — handoff/assign + collect-all-background only
                                    #   (~45 of 235 lines); ladder deleted -> CLAUDE.md needs a fix
    instrument-and-verify.md        # MODIFIED (not "unchanged") — 3 rules keep; strip the
                                    #   superpowers: string at :77 and 2 dead intra-repo paths
    severity-guide.md               # unchanged — reuse verbatim; 2 KEPT skills consume it
    README.md                       # MODIFIED — rewrite the index, keep the "why no SKILL.md" rule
    context-envelope.md             # SPLIT — DOCKER CONTEXT half -> x-worktree/references/; rest dies
    slot-schema.md  reactions-vocabulary.md   # DELETED -> lint-chain.sh bad-case fixtures
    common-gotchas.md  omo-routing.md  workflow-chains.md   # DELETED (carry 1 line to x-worktree)
  bin/setup  hooks/inject-capabilities.sh     # MODIFIED — ownCoverage + crossModelCli probe (S3)
  x-omo/ x-gemini/ x-team/          # DELETED as bootstrap deps (DEC-013), after harvest
  x-worktree/ x-worktree-isolate/ x-qa/ x-api-pentest/ x-skill-improve/ x-design/ x-guide/
  x-upstream/                       # KEPT — jobs v3 does not absorb; S6 scrub pass required;
                                    #   x-qa additionally wired in S7 (DEC-021)
```

Slices in order. **No slice starts before its predecessor's checkpoint passes.**

| # | Slice | Verification checkpoint |
|---|---|---|
| S0 | `emit-contract.md` + `validate-emit.sh` | 3 good / 5 bad emits (missing status token, composed status, OBSERVED claim with no pointer, BLOCKED without a Question, code-level identifier in a question/option — DEC-022) → correct verdict on all 8; `--selftest` hard-fails; wired to `npm run check` and a deliberately-broken run goes red (DEC-019) |
| S1 | x-consult Tier 0 ANSWER, end to end | Real read-only question about this repo → derived status, every claim pointered, terminates without offering implementation |
| S2 | x-consult Tier 2 + x-record backlog doc + DEC-014 review | Doc lands at immutable path with `DEC-`/`AC-` IDs, a Structure Outline section, an acceptance-examples block and a per-phase verification list; **overlap rate written to `metrics.md`** with `reviewer:` recorded; basic-memory write-time overlap lint rejects a >40-word restatement; validator passes |
| S3 | x-implement on that doc, serial slices + gitnexus lane | Every gate prints command + exit code; status derived; the **backlog doc's** verification list extends the floor cascade; sha256 freeze fires; N/A rows print their reason; stub scan labelled over 10 real diffs; gitnexus prints `commitsBehind` when stale and prints the skip when it withholds |
| S4 | prod-bug manifest + intent-blind scout | Every dispatch prompt lands in `dispatch/` **before** dispatch; the lint finds no pre-judging phrase and no hypothesis marker in the `02-scout` prompt; research doc is fact-only |
| S5 | Tier 3 full chain + plan doc + `lint-plan.sh` | A plan with a phase naming no end-to-end validation is rejected; one missing a per-phase success criterion, exact file paths or an out-of-scope statement is rejected; a fully-validated plan passes |
| S6 | Cutover — delete + harvest per the Disposition table, **scrub the 8 kept skills** | `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ \| wc -l` → 0 **including x-qa and x-api-pentest**; `lint-chain.sh` green on the whole tree; bootstrap line count down ≥1,500; DEC-020 trigger eval passes at ≥0.5 |
| S7 | Wire the QA chain into kept x-qa (DEC-021) + mid-run decision recording (DEC-022) | One real chained run: x-implement DONE derives `chain{x-qa}`; acceptance examples arrive as `severity: required` obligations and the coverage gate **arms on the branch/pr path**; `QA_VERDICT=fail` re-enters as `FAILED-GATE{gate: qa}`; a pass appends verdict + coverage counters to the backlog doc; one reversible decision self-decided with a `Decision:` line, one costly decision emitting NEEDS-INPUT whose options carry implications at human altitude |

## Scope & Non-Goals

**In scope:** the three skills, the shared emit contract + validator, the three doc templates, the
DEC-014 review dispatch, the DEC-015 capability-gated two-role cross-model path, the DEC-013
deletions, the DEC-021 QA chain (S7), the DEC-022 blocker decision brief, and retiring the 19 v2
skills.

**Non-goals:** `x-worktree`, `x-api-pentest`, `x-worktree-isolate`, `x-skill-improve`,
and — added round 4, previously unstated anywhere — `x-design`, `x-guide`, `x-upstream`
(orthogonal, invoked by name; see the Disposition table). `x-qa` left this list on 2026-07-29:
S7 wires it without touching its internals or its real-QA contract (DEC-021). Cross-model as a
**general** dispatch layer (DEC-015 permits exactly
two roles). Hook-based enforcement of consult-first. Parallel code mutation. Human stops at slice
boundaries (DEC-011, decided against — DEC-022's reversibility gate governs mid-run *decision*
interrupts, not slice boundaries). Notification/delivery infrastructure for blocked envelopes
(terminal + run-dir file only, DEC-022). Change-scoped test selection in place of the per-task
full suite (deferred, DEC-021). Any ML on the rework tally.

## Acceptance

- [ ] `git grep -l 'superpowers:\|oh-my-claudecode:' -- skills/ | wc -l` returns 0 across all
      shipped skills — **including the kept ones**: x-qa (`SKILL.md`, `explorer-prompts.md`,
      `case-runner-prompts.md`), x-api-pentest (`SKILL.md`, `step-06-report.md`) and
      `x-shared/instrument-and-verify.md` all carry strings today. Two round-4 corrections:
      `grep -rc` prints a `path:count` line per file and can never output a bare `0`, and a
      plain `grep -r` also matches untracked gitignored `.omc/state/*.jsonl` debris — so the
      assertion must be tracking-aware.
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
- [ ] The cross-model lane re-derives a real exit code (empty stdout + log tail) instead of trusting
      `agy`'s exit 0, and serializes its calls — otherwise an auth failure logs as 0% overlap.
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
  upstream artifacts. Falsifier: rework attributable to code the human never read.
- **Open:** DEC-003 gates artifact-internal completeness only. Nothing in this design closes
  "the requirement nobody thought of" when it lives outside both your words and the codebase —
  and three inspection studies say a topic checklist does not close it either. Stated, not solved.
- **Gotcha:** nothing stops a user who never invokes x-consult. Accepted, not solved.
- **Resolved 2026-07-28 — the doc-length gotcha.** The question was "is the cap wrong or has this
  stopped being a review surface"; the corpus answered a better one: an unenforced cap holds when it
  is generous *and names a destination*, fails when it is tight and names none `[OSS §5]`. Both
  halves are now fixed in DEC-009 — the budget is **per phase file**, this doc's destination is
  `docs/research/`, and the number is asserted by `wc -l` or deleted. This doc stays long because it
  is a decision record with 18 blocks; the phase files are what must stay small.
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
- **Open — DEC-015 has no read-only flag.** Neither `agy` nor `bin/agy-agent` documents one, so the
  DEC-018 requirement that the cross-model CLI run read-only currently has no implementation. Verify
  before S2 or weaken it to a tool-allowlist constraint `[R4 §4]`.
- **Assumed — exploratory testing transfers from human testers to agent-run charters.** Every ET
  measurement is human-subject; the agent-native mitigation is x-qa's existing bounded-probe +
  independent-triage hunt. Falsifier: `EXPLORE_CONFIRMED` per probe budget across 5 chained runs
  (DEC-021) `[R5 §6]`.
- **Open — the DEC-022 altitude lint is heuristic.** "No code-level identifiers" is enforced by
  pattern (path-like tokens, `()`, snake_case in narrative fields) and will misfire both ways;
  tune on S0's fixtures, revisit at the S3 checkpoint.
- **Open — DEC-020's trigger eval has no harness.** Official guidance supplies the protocol
  (~20 prompts per side, ~3 runs, 0.5 threshold) and `skill-creator` automates it, but v3 ships no
  implementation. It is the one instrument round 4 added that is unbuilt `[R4 §6]`.
- **Not verifiable, stated so it is not mistaken for evidence `[R4 §6]`.** No controlled study
  isolates spec-driven from plan-free agent workflows (the critique corpus is retrospectives plus
  one adjacent RCT); no end-to-end A/B exists for a coding agent with vs without a cross-session
  memory store, so DEC-016's magnitude is extrapolated; and the checkpointed-vs-autonomous question
  (DEC-011) has no RCT — it rests on field telemetry and split prior art.
