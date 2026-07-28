---
title: OSS skill-framework survey — what transfers to v3
slug: oss-skill-framework-survey
type: research
status: done
created: 2026-07-28
related: [x-skills-v3, x-skills-v3-foundations]
---

# OSS skill-framework survey — what transfers to v3

Eight repos read in full by independent agents, 94 mechanisms extracted, 9 top candidates put
through adversarial verification. **Every one of the 9 was refuted as proposed; every one left a
narrowed residual.** That ratio is the finding: the patterns are real, the transfers are not.

Facts only — decisions live in `../backlog/x-skills-v3.md`. Cited as `[OSS §n]` from there.

## §1 Method, and one error it caught in itself

Each repo got one reader with the v3 design docs in hand, instructed that a finding restating an
existing DEC is worthless. Convergence across repos was then clustered, and the top 9 sent to three
adversarial lenses (correctness / cost-and-coupling / does-it-actually-exist) with instructions to
open the cited files rather than reason from the description.

**The verify pass earned its cost twice over.** It caught the synthesis citing ECC under "a control
arm is mandatory" when ECC ships no control arm at all (`grep -rni "baseline|control arm" ECC/skills/skill-comply/`
→ zero hits, all three strictness rungs load the target skill). It caught superpowers' one
pre-registered stop gate being cited as "it fired and stopped the change" when the record shows it
fired and the change **shipped**, with the claim narrowed instead.

**One error survived the verify pass and I caught it by hand.** The anti-pattern summary asserts a
within-repo A/B proving "an unenforced budget is decoration": *"the mechanized 1024-char description
budget holds across 24 skills, the prose 500-line budget is violated by 23."* Measured:

| Repo | Budget | Enforced? | Result |
|---|---|---|---|
| addyosmani | `SKILL.md` < **500 lines** (`docs/skill-anatomy.md:125`) | no linter rule | **held 24/24** — max 467, mean 293 |
| addyosmani | description ≤ **1024 chars** (`skill-lint.js:28`) | mechanized | held 24/24 |
| superpowers | other skills < **500 words** (`writing-skills/SKILL.md:213-221`) | no check | **violated 11/14** — max 4,074 |

The "violated by 23" is an inversion of the repo's own data; the convergence row itself reported
"mean 293, max 467" correctly and the summary then stated the opposite conclusion. The rule survives
on superpowers' data alone, and it comes out **weaker and more useful**: addyosmani's unenforced cap
held because it is *generous* and paired with a named destination ("move detailed reference material
into supporting files"); superpowers' failed because it is *tight* and names no destination — its own
authoring guide is 7.6× over its own rule. See §5.

## §2 The dominant failure across all eight repos

**The instrument exists and nothing consumes it.** Every repo wrote a validator, schema, benchmark or
eval; in six, it warns, exits 0, is absent from CI, writes to a gitignored path, or has zero
production callers.

- ECC: `skill-evolution/tracker.js:105` `recordSkillExecution` — every caller outside the file is a test.
- claudekit: claim-resolution linter ends in unconditional `process.exit(0)`.
- caveman: 18 test files, a three-arm eval harness, one CI workflow that does `cp` + `zip`.
- OMC: a SWE-bench runner with every results cell `-`, and 40–60% savings quoted from it anyway.
- superpowers: **no `.github/workflows` at all** — `run-all.sh` is never executed; `docs/testing.md:20`
  files `tests/explicit-skill-requests/` as residue; `run-all.sh` hardcodes 4 tests against 9 prompt
  fixtures, leaving 5 orphans.

**This repo has already produced the artifact twice.** `docs/research/agy-eval-harness/run.sh` +
`score.sh` — "Pure grep — deterministic, auditable", prompt fixture, per-lane meta, grep verdicts.
One commit (`5e7f0a3`, 2026-06-08), referenced from one line of one plan, never re-run, never a gate.
Same for `bin/tests/agy-agent.test.sh`. x-skills has no `.github/workflows`, no `tests/`, and
`package.json` exposes only `setup` and `check`.

Derived rules: name the consumer before writing the gate · no warn tier, no env escape, no `exit 0` ·
a budget not machine-checked is decoration · single-source every contract · bind every measurement to
the bytes it measured · never assert on a model's self-description (superpowers has a passing test
asserting the opposite of its current skill, `test-subagent-driven-development.sh:139-149`).

## §3 The nine falsified proposals and what survived

Each row: the proposal as clustered → the kill → the residual that survives. Full reasoning in the
run journal (`wf_a0346314-197`).

| # | Proposed | Killed because | Residual (adopted) |
|---|---|---|---|
| 1 | Control arm in S2; a non-failing baseline is stop-ship | Its own best prior art narrowed the claim and shipped; ECC has no control arm; the arm isolates ≥4 variables at n=1; acceptance box 8 **is** already comparative | Pre-register what DEC-014's claim narrows *to*; define the overlap predicate mechanically via `Question.eliminates` |
| 2 | Lint the shipped source, fenced blocks stripped | 3 of 4 rules already accepted; the `done-format.md:98` ban is in a **table cell**, not a fence, so stripping buys nothing; the 13 violating files are all deleted by S6; exemption governance has no population at 1 author | One grep for `Step N of M` over the fresh surface, wired into `npm run check` |
| 3 | `notRun[]`, empty-diff check, stub scan | Fail-fast makes `notRun` unreachable (an unrun gate implies an upstream non-zero exit); `filesWritten[]` already carries the empty-diff signal; `unverifiable[]` invites the inference DEC-014 bans | Stub scan as one `gates.sh` row — but only with its three preconditions: added lines only, extension allowlist, string/regex-literal stripping |
| 4 | A durable falsifier ledger with frozen line formats | `.gitignore` already ignores `docs/plans/`; ponytail's own ledger is gitignored-by-default and works; 3 of 4 named falsifiers are cross-run and unobservable from within a run; superpowers needed ~40 lines of tooling + a separate evals repo | **Resume predicate** for x-implement, justified on MAST FM-1.3 (15.7% step repetitions) — not on falsifiability |
| 5 | Read-back, rollback-to-base, scoped repair | superpowers does the **opposite** at its cap — parks the finding, lets the code stand; the only real `git reset --hard` is OMC's, in a dedicated worktree behind `assertResetSafeWorktree`; v3 has no per-slice commit and x-worktree is a non-goal | The **constrained repair dispatch**: verbatim gate output, scoped to files the gate named, do not regenerate the slice |
| 6 | Assert behaviour on the transcript | The cited exit code carries invocation only — ordering is printed and discarded; the form is *declining* in its home repo; absence-assertion has no prior art and trips on the skill's own body in the log | ~12 lines asserting invocation only, feeding the **last assistant message** to `validate-emit.sh` |
| 7 | Withhold the oracle structurally | Inverts M7 — contamination runs oracle-by-code, and DEC-006 authors examples before code exists, so ordering already satisfies it; withholding reintroduces the prose ambiguity DEC-006 exists to remove; caveman's guarantee needs the script to own stdin, which no x-implement phase does | **sha256-freeze** the acceptance block in `gates.sh`; downgrade S4's "provably" to "lint-clean" |
| 8 | `disallowedTools` frontmatter + model routing | The parsed path is the SDK path; x-skills ships zero TypeScript; an `agents/` dir pollutes every session's agent list; `disallowedTools` is **silently ignored if `tools:` is set** | `subagent_type: "Explore"` + per-call `model` at three dispatch sites — same harness guarantee, zero new files |
| 9 | No-op sentence test + leading word | No-Op is model-relative and settled by *running the skill*; a human decision record has no model-default to differ from — the right terms are Duplication/Sprawl; v3 already repeats its three leading tokens (derived ×9, slice ×13, intent-blind ×4); DEC-008's "prose deleted where a pointer exists" is already a machine-checked deletion rule | A **pretrained-token audit** scoped to phase files only; `intent-blind` and `derived` are coined and pay the definition-token tax |

## §4 The two kept dependencies — measured

### basic-memory
The one job `docs/` structurally cannot do is **cross-repo recall**: x-skills runs inside *other*
checkouts, so a transferable gotcha learned while implementing in `oneclaw` has no home in either
repo's `docs/`. Already OBSERVED in the store: `lessons/x-skills/bsd-grep-alternation-silently-fails-without-e-flag`.

It is also the only one of the three stores that is **droppable** — `MEMORY.md` is harness-injected
unconditionally and `docs/` is settled by DEC-009. So it must earn its keep on cross-repo
transferables alone.

Observed failure modes already in the live store:
- **Slug misderivation, silent** — three worktree-named folders exist:
  `lessons/oneclaw.feat-2026-07-14-dashboard-rbac-turso-monolith`, `…feat-2026-07-15-slack-channel-history-hardin`,
  `…shannon-e2e`. With 9+ parallel worktrees in routine use, this is the highest-probability failure.
- **Durability gate already ignored** — `bm-remember/v3-whole-stack-e2e-suite-complete-all-green-committed-2026-07-12.md`
  is a green-run note the contract explicitly bans; ~18 `sessions/` notes are titled from raw first
  user messages.
- Permalinks are title-derived and truncated mid-word
  (`…x-qa-eval-extension-plan-score-case.sh-the-default-curl-sut-path-is-broken-be`), so they are
  lossy identifiers — the opposite of DEC-009's stable-ID requirement. `edit_note` can neither move
  nor retag.

### gitnexus — the measurements that reframe it
All OBSERVED via `mcp__gitnexus__cypher` against repo `x-skills`, re-run by hand 2026-07-28:

| Query | Result |
|---|---|
| nodes under `skills/` | **2,231** |
| nodes under `research/` | **153,719** |
| own-code share of the 160,141-symbol index | **1.4%** |
| own symbols in any of 300 indexed Processes | **0 processes, 0 steps** |
| `context({name:'validate_emit'})` | not found |
| `query({query:'capability loading bootstrap manifest'})` | 0 processes, 18 definitions — **every one vendored** |

Of the 2,231 own nodes: 1,751 are markdown Sections, 305 File, 77 Variable, 24 Property, **18
Function, 1 Class**. All 18 Functions are in four Python files under `skills/x-worktree-isolate/scripts/`
— an explicit v3 non-goal. **Zero of the 111 tracked `.sh` files produce a Function node.**

Staleness, via `list_repos`: **7 of 8 indexed repos carry `commitsBehind > 0`** (8, 14, 16, 24, 443,
533, 16779). x-skills itself is 14 behind. Root cause already recorded in
`2026-06-20-gitnexus-stale-index-code-aware-gate.md`: pure SHA comparison with no file-type awareness,
index shared across worktrees via `--git-common-dir`, and **no incremental analyze** (full re-scan
2–10 min).

**Consequence:** a v3 that gates on freshness is a v3 whose gitnexus path is decorative. Design as if
gitnexus provides `query` + `context` only; `impact`/`detect_changes` are a bonus on the rare fresh index.

**Contradiction with a live project rule, flagged as such:** this repo's `CLAUDE.md` states *"MUST run
impact analysis before editing any symbol"* and *"NEVER edit a function without first running impact."*
Against 1.4% own coverage and zero own processes, that rule **cannot be satisfied while building v3
itself**, and a mandatory gate that is routinely unsatisfiable trains itself as ignorable — the
Urbach checklist result, self-inflicted.

## §5 The doc-length question, settled by evidence

v3's open gotcha asks whether DEC-009's ~200-line target is wrong or whether the doc stopped being a
review surface. The corpus answers a **different and better question**: what makes an unenforced
budget hold.

- **A generous cap with a named destination holds unenforced** — addyosmani, 24/24, at 500 lines with
  "move detailed reference material into supporting files."
- **A tight cap with no destination fails unenforced** — superpowers, 11/14, at 500 words, its own
  guide 7.6× over.
- **The unit that predicts rot is lines per file, not files** — ECC mean 261 healthy; its 36 outliers
  over 500 are where content became unmaintainable (`WORKING-CONTEXT.md:88-90` states a
  summarise-and-archive rule, then violates it for 88 consecutive entries at `:92-179`).

v3's ~200 target is the superpowers shape: tight, and with no destination named. This survey doc is
the destination.

## §6 Corrections to the record

- `research/affaan-m/ECC/scripts/lib/skill-evolution/tracker.js` is **146** lines, not 1,254 — the
  latter is the whole 6-file directory. The substantive claim (zero production callers) holds.
- OMC's `src/features/model-routing` is **2,249** lines and is **not** dead — re-exported at
  `src/features/index.ts:195`, its `ComplexityTier` consumed by `delegation-categories`. The advice
  ("write the table, not the scorer") stands; the "nothing calls it" evidence does not.
- superpowers `task-reviewer-prompt.md:145` reports ⚠️ *alongside* ✅/❌; the Assessment field at
  `:141` stays binary. It is a third reporting channel, not a third routed verdict.
- The live capability manifest (`~/.config/x-skills/capabilities.json`) reports `plugin_version 2.3.0`,
  generated 2026-07-14, while the repo is at v2.4.0 — the manifest gating both kept dependencies is
  itself stale.

## §7 Read in full before authoring

1. `research/addyosmani/agent-skills/scripts/run-evals.js` — the eval harness, and the `git init` +
   baseline-commit + `git apply working-tree.patch` fixture trick (S4/S5 scenario setup).
2. `research/obra/superpowers/skills/writing-skills/SKILL.md` — §"Match the Form to the Failure"
   (`:459-470`) is M16's actual source, plus the two carry-forward rules at `:473-474`.
3. `research/mattpocock/skills/skills/productivity/writing-great-skills/GLOSSARY.md` — Duplication
   (`:177-181`), Sprawl (`:113-117`), Leading Word (`:129-135`), Negation (`:161-165`).
4. `research/JuliusBrussee/caveman/skills/caveman-compress/scripts/compress.py` — `build_fix_prompt`
   (`:190-216`) is the constrained-repair prior art.
5. `research/affaan-m/ECC/workflows/orch-review.workflow.js` — schema-conditional required fields
   (`:62-94`).
6. `research/DietrichGebert/ponytail/benchmarks/agentic/run.py` — instrument selftest that refuses to
   spend (`:183-203`), arm isolation after a contaminated-baseline retraction (`:44-61`), and
   `judge.py:113-137` refusing to judge until it can rank a bad reference above a good one.

## §8 Contradictions against settled DECs

| DEC | Contradiction | Verified | Recommendation |
|---|---|---|---|
| DEC-011 "against the evidence" | superpowers `subagent-driven-development/SKILL.md:17` ships **deliberate full autonomy**: *"Do not pause to check in… 'Should I continue?' prompts and progress summaries waste their time."* | ✅ verbatim | **Hold the decision, amend the warrant** — the evidence is split, not unanimous. Import the enumerated stop set + per-status branch (`:236-250`) |
| DEC-002 "M16's ban narrowed to DISCIPLINE gates" | M16's own table row 4 already prescribes DEC-002's remedy as the *right* form. No narrowing was needed | ✅ `:459-470` | Delete the narrowing clause, cite row 4 |
| DEC-003 warrant | M16 row 3: an omitted element wants a **REQUIRED template slot**; "prose reminders near the template" is the wrong form. A required slot ≠ a tick-box checklist | ✅ | Re-warrant on row 3 — stronger than arguing against Urbach |
| DEC-005 "hard cap 7" | mattpocock ships a reasoned refusal to cap, from field report #44 ("Codex just asked me 200 questions"): a cap conflates under-specification with prompt quality | ✅ `.out-of-scope/question-limits.md` | Hold the cap, add the falsifier: a run terminating **at** the cap with all questions admissible is evidence the cap is wrong |
| DEC-015 "the absent path is silent" | addyosmani states the opposite three times: *"Skipping is fine; silent skipping is not."* Internal tension too — the overlap-rate log is uninterpretable without knowing which mode produced it | ✅ `doubt-driven-development/SKILL.md:153-166` | Amend: silent in the **human** channel, announced in the **machine** channel |
| M16 itself | mattpocock GLOSSARY `:161-165` (Negation): prohibition "drags the forbidden behaviour into context and makes it *more* available" — direct conflict with M16's prohibition-set finding | ✅ | Land on M16 (IEEE RE 2025, p=4.23e-8) over an ungraded practitioner claim; record the conflict |
