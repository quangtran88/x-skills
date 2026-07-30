---
title: "R6: v2 skill reuse audit — per-dir disposition check, duplication clusters, codex-plugin-cc"
slug: v2-skill-reuse-audit
type: research
status: done
created: 2026-07-30
updated: 2026-07-30
related: [x-skills-v3, x-skills-v3-decisions, v3-round4-audit, v3-qa-escalation]
---

# R6 — v2 skill reuse audit (2026-07-30, user-directed)

The user asked: review each existing skill for reuse / removal / refactor and duplicated content,
then double-check every finding. Method: a 13-agent workflow (12 auditor lanes covering all 19
`skills/` dirs — every `.md` read in full — plus one high-effort cross-checker that verified
overlap claims at their cited lines and killed thematic-resemblance claims), followed by a
**by-hand re-verification of every surviving claim** in the main session. Every claim below was
re-confirmed at its `file:line` on 2026-07-30; none of the cross-checker's findings failed
re-verification.

Two verification artifacts worth recording (both mine, both caught in-session): **zsh does not
word-split an unquoted `$VAR`**, so `git grep -- $KEPT_DIRS` silently greps one bogus pathspec and
returns 0; and **macOS `git grep -E` has no `\b`** (POSIX ERE), so boundary-anchored patterns
return 0 without error. Both produced false "0 hits" runs before the corrected sweeps below.
Consequence for this repo's release gates: assert with plain alternations and explicit pathspecs,
and treat a 0 from a boundary-anchored ERE as suspect until re-run without `\b`.

## §1 Headline verdict

**No disposition flips on the merits.** All 19 fates in the Disposition table were upheld; 17 of
19 carried amendments, all evidence-backed. The two flips that did happen are **user decisions**,
not audit findings: x-review is kept standalone (DEC-023) and OMO's job moves to
`openai/codex-plugin-cc` (DEC-024).

The plan's real defect was the S6 **scrub definition**: "strip `superpowers:`/`oh-my-claudecode:`
+ dead intra-repo paths", asserted by a framework-prefix grep only. Measured 2026-07-30 over the
new 9-dir kept set (x-review included, `review` removed from the dead-name alternation):

```
git grep -nE 'x-(do|bugfix|verify|research|backlog|mindful|omo|gemini|team)' -- <9 kept dirs> | wc -l
→ 95 hits across 33 files
```

None match either framework prefix, so Acceptance row 1 passes green while kept skills dispatch
deleted skills. Non-`.md` carriers confirmed: `x-guide/config.json:2-4`,
`x-skill-improve/config.json:3-8`, and 4 x-qa shell scripts (`scripts/init.sh:46`,
`scripts/kb-writeback.sh:259`, `scripts/launch-entry-point.sh:29`,
`scripts/explore/finding-to-case.sh:3`). The audit lanes' counts (90/8-dir set) differ from the
final numbers by pattern construction (boundary handling, x-review membership), not substance.

## §2 Verified per-dir findings (the ones that change the plan)

- **x-worktree** dispatches deleted x-do: `SKILL.md:152` (`Skill: x-skills:x-do`), `:149`, `:158-160`;
  `references/caller-integration.md:3` is written for `x-do --wt`/`x-bugfix --wt`, `:45` specs the
  x-do→x-bugfix handoff, `:99` names x-verify as the caller-side verifier. KEPT UNCHANGED is
  therefore impossible — this is a rewrite pass.
- **x-guide**: 31 dead refs across 7 files incl. `config.json`; `references/routing-matrix.md:9`
  routes every `vague` input to x-research unconditionally — a string-strip leaves an advertised
  input type with no route. `steps/step-02-ingest.md:45-82` are full dispatch procedures into
  x-research/x-gemini.
- **x-qa**: fail edge routes to a deleted skill — `SKILL.md:213-214` offers `/x-skills:x-bugfix`
  for failed cases and confirmed exploratory findings; `:211` special-cases "invoked by x-team".
  28 dead-ref hits across 11 files incl. the 4 scripts. S7 wires the DONE edge and must also
  re-point the fail edge.
- **x-api-pentest**: `references/tool-invocations.md:33,:36` and `references/auth-recipes.md:60`
  still carry `--base-url` / `--report-format json`, which `steps/step-03-automated-sweep.md:40-49`
  fixed to `--url` / `--report ndjson` — `gotchas.md:73` records the fix (V2, 2026-04-09) that the
  references never received.
- **x-design**: "no known dirt" falsified — `SKILL.md:20,:128` route to x-review (now moot via
  DEC-023), `:21` routes to `multimodal-looker` (dies with x-omo), `:78,:80` link
  context-envelope's dying half, `gotchas.md:39` names a nonexistent `add-research` skill;
  `references/0{0-3}-*.md` = 412 lines with zero inbound references.
- **x-worktree-isolate**: scrub is a no-op (0 framework strings, 0 dead refs); the real defects:
  `gotchas.md:89-91` ("declarative, not a runtime lock") contradicts `SKILL.md:95-96`'s v0.3
  enforced claim/refuse/steal — and `SKILL.md:25` orders gotchas read at bootstrap;
  `references/detection-heuristics.md:27` says `disable_method=replicas-zero (default)` vs
  `SKILL.md:87` (profile-gate default, replicas-zero Swarm-only); `SKILL.md:24` hardcodes
  `/Users/randytran/Codes/x-skills/bin/setup` in a distributable plugin.
- **x-skill-improve**: 14 dead refs across 6 files; `config.json:3-8` `supported_skills` lists
  x-do/x-research/x-review/x-bugfix (x-review survives, DEC-023); `analysis-rubric.md:13-14`'s
  universal checks would misclassify correct v3 behavior as COMPLIANCE GAP.
- **bin/omo-agent is unowned by the plan**: byte-identical to `skills/x-omo/omo-agent`
  (`diff -q` clean); `bin/setup:505-515` is the binding and hard-fails at `:509` without it;
  `bin/setup:454-455` advertises it as enabling x-do/x-research/x-review/x-bugfix;
  `bin/find-plugin-dir:22-25` resolves the plugin dir through its symlink; `grep -c omo-agent`
  over both plan docs → 0. Resolved by DEC-024 (delete with x-omo, in one slice).

## §3 Duplication clusters (9, all verified at their lines)

1. **`--wt`/ISOLATE_APPLIED pre-flight**: x-do `SKILL.md:129-139` ≈ x-bugfix `SKILL.md:52-62`
   near-verbatim; canonical spec already in kept `x-worktree/references/caller-integration.md`.
   `ISOLATE_APPLIED` counts: x-do 6, x-bugfix 5, x-team 1 (passing mention — the lane's "third
   copy" claim was correctly downgraded by the cross-checker). Survivor: caller-integration.md;
   v3 must either name x-implement the caller or rewrite the file for direct invocation.
2. **DOCKER CONTEXT block**: `x-shared/context-envelope.md:55-64` = 
   `caller-integration.md:81-95` byte-for-byte (the latter headed "verbatim — this is the
   contract"); third read-pattern copy in `auto-isolation.md:50-61`. The planned SPLIT must be a
   MERGE-AND-DELETE into caller-integration.md, not a new file.
3. **Handoff Context block**: defined at `context-envelope.md:5-14`; **mandated** by
   `invocation-guide.md:135` (inside the ~45 surviving lines: "Every `handoff` dispatch MUST
   include…") and `:192`; consumed by `caller-integration.md:45`, `x-design/SKILL.md:78,:80`,
   `x-qa/SKILL.md:220`, `x-skill-improve/SKILL.md:154`. The plan kept the mandate and deleted the
   format — self-contradiction. Survivor: emit-contract.md; repoint all six during S6.
4. **Options-with-implications render**: `x-review/steps/step-03-synthesize.md:105-151` is the
   developed original (axis table + decider, Impact-line accept/reject fixtures at `:120-132`,
   escape options D/E, deferral-requires-tracker); `x-shared/done-format.md:49-58` is a distilled
   copy citing the original at `:53`; `x-team/references/blocker-escalation.md:35` is a bare
   `"option A — implication"` array. DEC-022 credited the two copies and missed the original.
   x-team's unique contribution is only the untrusted-text sanitizer (`:45-50`).
5. **Two stagnation ladders**: `x-do/references/iteration-patterns.md:33-37` (pause@3 / oracle@5 /
   STOP@7) vs `x-bugfix/SKILL.md:111` (3-Strike → STOP + oracle) + `:103` (Instrumentation Pivot
   after 2). Both routed into 02-gates. Survivor: the countable base (`iteration-patterns.md:17-29`
   — progress-signal table + "one iteration = one mutating call + one verification call") with
   exactly one merged threshold set.
6. **MCP decision matrix**: `x-research/SKILL.md:55-69` restates `x-shared/mcp-toolbox.md:10-16`;
   staleness note duplicated to the character. Survivor: mcp-toolbox.md; 02-scout carries only the
   rows it lacks + the sequencing rules (`SKILL.md:71` cheapest-first, `:83` primary-first HARD GATE).
7. **Severity scale**: `x-mindful/references/severity-rubric.md:3` self-describes as a re-tune of
   kept `severity-guide.md`. Survivor: severity-guide.md; 00-triage carries only the reversibility
   axis + score formula.
8. **agy operational rules**: exit-0-lies + serialize-lanes stated in x-gemini
   (`gotchas.md:6,:10`), x-research (`gotchas.md:29`), x-qa (`SKILL.md:71`,
   `case-runner-prompts.md:13`). Survivor: capability-loading.md's agy section (full envelope, §5
   of DEC-015 amendment); kept x-qa keeps its skill-local Serial-agy rule but sources aliases /
   timeout / exit semantics there.
9. **state.local.json schema table**: `x-worktree/references/auto-isolation.md:63-76` vs
   `x-worktree-isolate/SKILL.md:144-159`, both kept. Lowest priority; make the isolate SKILL.md
   canonical, reduce the other to a pointer.

## §4 Missed harvests (12, verified; ranked)

1. **Handoff Context format** (cluster 3) → emit-contract.md.
2. **Empty-gate-set discriminator**: `completion-cascade.md:5-15` SCOPE GATE (only-reads /
   docs-only / no-code-tree / placeholder-test-script short-circuits) + `x-verify/SKILL.md:71-81`
   (`needs-user-review, reason: all-verification-inconclusive`). Without it, a repo with no
   test/lint/typecheck config yields zero gates all vacuously green and pure command-gating
   derives DONE — the regression x-verify existed to prevent. Both plan docs: 0 mentions of
   vacuous/zero-gate/docs-only (grep-verified). → gates.sh entry + validate-emit.sh reject rule.
3. **Machine-parseable emit envelope**: `x-team/references/monitor-loop.md:7-24` — kind = summary
   prefix, payload = first fenced json block, per-kind required fields validated **before**
   acting, unknown kinds logged not crashed. The repo's only battle-tested validate-before-act
   schema; S0 builds exactly this. → emit-contract.md + validate-emit.sh.
4. **Altitude-lint calibration fixtures**: `x-review/steps/step-03-synthesize.md:120-132` — three
   labelled-accept + three labelled-reject Impact lines, written for exactly the code-identifier
   distinction DEC-022's heuristic lint needs. → validate-emit.sh fixtures.
5. **Two-phase-write rules**: `x-team/references/worker-preamble.md:42-46` (emit before status —
   reverse order orphans the signal) and `:73-75` (awaiting-input excluded from stuck detection);
   `monitor-loop.md:68-80` orphan sweep. v3 has the same hazard between envelope.md and
   progress.md. → emit-contract.md status semantics.
6. **Backlog frontmatter contract**: `x-backlog/references/template.md:16-17` `slug:`/`type:` —
   consumed by kept `x-worktree/references/doc-naming.md:19` to derive `<type>/<slug>` branches.
   Must survive verbatim in templates/backlog.md.
7. **TOFU consent for repo-committed commands**: `x-qa/references/service-launch.md:12-21` —
   sha256(profile) + (repo_root, entry_point) trust key, refuse with distinct exit code until
   trusted, re-confirm on hash change. gates.sh runs commands read from a git-tracked doc — same
   supply-chain surface. → gates.sh.
8. **Caller-side worktree verification**: `caller-integration.md:101-113` — changes-landed +
   isolate-marker-survived as concrete commands; its named owner (x-verify) dies. → gates.sh.
9. **Blocker batching rule**: `x-backlog/SKILL.md:78-91` — ask only on contradiction /
   load-bearing-decision-with-no-default / target-ambiguity, batch into ONE checkpoint, everything
   else becomes an Open Question. → x-consult 01-questions + DEC-022 trigger.
10. **Cross-cutting extraction heuristics**: `x-mindful/steps/step-02-extract.md:58-64` (five
    framework-free trigger rules) + `references/item-schema.md:65-83` (Hard Rule + code-level →
    architect-level re-casts) — extraction-prompts.md names both at `:3` and is non-functional
    without them.
11. **Regression-gate proof**: `x-bugfix/references/prevention-gate.md:9-11` (test FAILS without
    fix, PASSES with), enforced at `SKILL.md:115,:122`. → 02-gates prod-bug path.
12. **Status-writeback invariant**: `x-do/SKILL.md:216-224` — flip `status: in-progress` + mirror
    the README row; **never revert on abort** (an abandoned run must stay distinguishable from one
    never started). Archival `git mv` correctly NOT ported (DEC-009). → x-record template note +
    x-implement close-out.

## §5 codex-plugin-cc facts (fetched 2026-07-30)

`github.com/openai/codex-plugin-cc` — official OpenAI. **Apache-2.0.** ~30.4k stars / 2.0k forks.
"Use Codex from inside Claude Code for code reviews or to delegate tasks to Codex." Install via
Claude Code marketplace: `/plugin marketplace add openai/codex-plugin-cc` →
`/plugin install codex@openai-codex` → `/reload-plugins`. Exposes `/codex:review`,
`/codex:adversarial-review`, `/codex:rescue`, `/codex:transfer`, `/codex:status`, `/codex:result`,
`/codex:cancel`, `/codex:setup`, plus a `codex-rescue` subagent. Wraps the Codex app server via
the **global `codex` binary**; requires Node ≥18.18 and a ChatGPT subscription (incl. Free) or an
OpenAI API key — therefore **capability-gated, never assumed present** (same posture as
basic-memory/gitnexus). License is permissive — no PolyForm/AGPL-style constraint. Unverified as
of this doc: the machine-channel invocation (`codex exec` with stdin prompt) and a read-only /
sandbox flag on the installed binary — probe before S2 (inherits DEC-015's open item).

## §6 User directions this round

1. **Keep x-review standalone** — "it's a standalone skill that uses multi-model for code review
   which our flow can use independently." → DEC-023. The audit independently supports it: x-review
   is the *original* of the options render (§3.4), and 03-review's harvest still happens — kept ≠
   unharvested.
2. **Replace OMO with codex-plugin-cc** — "the original intention [of x-omo] was to allow Claude
   to use multi-model within a Claude session." → DEC-024. Resolves §2's bin/omo-agent orphan by
   deletion, swaps a 1,084-line bootstrap dir + bespoke binary for a marketplace plugin, and gives
   DEC-015's two roles an official backend. agy remains the Gemini lane for kept x-qa.
