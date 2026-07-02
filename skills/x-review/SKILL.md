---
name: x-review
description: Use when the user asks to review code, a plan, a PR, or a directory — auto-detects target, runs cross-model review (Claude + GPT + Gemini-3-pro). Reports bugs, security issues, false assumptions, and plan deviations only; refactor/perf/restructure are opt-in passes
role: reviewer
---

## Role: reviewer

**x-review is a reviewer.** It evaluates existing work and returns verdicts. It does **not** apply fixes.

## Scope Contract (READ FIRST — overrides reviewer instincts)

x-review evaluates whether the target **does what it claims to do, safely**. Nothing more.

**In scope (report these):**
- **Bugs** — logic defects, off-by-one, null deref, race conditions, broken control flow, incorrect error handling that hides failure.
- **Security issues** — injection, auth/authz holes, secret leakage, unsafe deserialization, SSRF, path traversal, missing input validation at trust boundaries.
- **False assumptions** — claims in the spec/plan/code/comments that contradict the actual code, missing dependencies the plan presumes exist, success criteria that cannot be measured, fabricated APIs/files/symbols.
- **Spec/plan deviations** — implementation diverges from the stated intent of the plan or PR description.

**Out of scope (DO NOT report unless the user explicitly asks):**
- New features, alternative approaches, "you could also…" suggestions
- Performance optimizations that aren't user-visible bugs (no "this is O(n²), consider a map")
- Refactors, restructuring, extraction, layering changes
- Style, naming, formatting, comment quality
- Test coverage suggestions for code that already has tests, unless a missing test would have caught a real bug found in this review
- Architectural redesigns, library swaps, framework migrations
- "Future-proofing", extensibility, configurability that the spec did not ask for
- Documentation polish, README improvements

**Severity rule:** If a finding does not name a concrete bug, security flaw, or false assumption that affects correctness or safety, it is out of scope — drop it, do not downgrade it to LOW. Reviewers will surface noise; the synthesis step (step 3) is where it gets filtered.

**The test:** "If we shipped this as-is and a user hit it, would something break, leak, or behave wrong?" If no → out of scope.

This contract narrows what reviewers report. The user can request broader passes explicitly via the [P]/[C]/[D] menu in step 4 — those passes are opt-in scope-expanders, never default.

**gitnexus-derived material (fence — applies to the optional blast-radius enrichment from `steps/step-01-prepare.md`):**
The existing in-scope / out-of-scope lists above are UNCHANGED. This fence is an ADDITIONAL constraint on any finding that draws on gitnexus enrichment (depth-1 caller summaries, `route_map`/`api_impact` consumer lists):
- ✅ **In scope:** gitnexus structurally contradicts a stated claim → a real false-assumption / spec-deviation finding. Canonical example: the PR/plan says a handler is internal-only, but `route_map` shows N external consumers. This is the in-scope false-assumption finding — and it comes from `route_map` consumers, NOT from `impact` depth-1 callers.
- ❌ **Out of scope:** "high coupling / consider restructuring", "this symbol has many callers, consider decoupling", or any refactor/architecture observation. gitnexus MUST NEVER generate the refactor/restructuring findings the out-of-scope list above already drops — high caller counts are context for a correctness finding, never a finding on their own.
- **Mandatory C2 disclaimer:** EVERY gitnexus-derived reviewer-facing line MUST carry verbatim: *static call graph — may miss dynamic dispatch; a 0-caller result is NOT a safety proof.* A 0-caller / 0-consumer result is never phrased as "safe to change."

**x-review MUST NOT:**
- Call `Edit` or `Write` during the review phase (steps 1-3 up to verdict) — reviewers evaluate, they don't fix
- Propose "while I'm here, let me just fix this" inline fixes — that's role leakage
- Run `Bash` commands that mutate state (no `git commit`, no `npm install`, no `gh pr merge`) during the review phase

**Exception — Fix Mode:** When the user explicitly requests fixes (e.g., "fix all", "apply fixes") after a REQUEST_CHANGES verdict, x-review enters Fix Mode (step 3). In Fix Mode, `Edit`/`Write`/mutating `Bash` are permitted via the `receiving-code-review` workflow. The role boundary shifts from "report only" to "report then fix on request."

**Allowed:**
- `Read` to inspect diff, source files, tests
- `Bash` for **read-only** verification (running tests, reading git log, checking lint output)
- `Agent` tool to dispatch `code-reviewer` for cross-model passes
- `Skill` tool for dispatching additional review passes

**Self-check before every tool call:**
If you're about to call `Edit`/`Write` or a mutating `Bash` and you are NOT in Fix Mode, STOP.
Reviewers report; they don't fix — until the user says otherwise.
Return your findings and surface the menu — only enter Fix Mode after explicit user request.

# x-review — Universal Review Command

Smart review that detects what to review and how deep to go.

## Bootstrap

**MANDATORY first step — do this BEFORE anything else:**
0. Pin capabilities for the session per `../x-shared/capability-loading.md`. Filter routing tables against the pinned set; do NOT re-check per dispatch. **If `mcp.gitnexus` is pinned, also consume the shared session-pinned indexed+fresh probe per `../x-shared/capability-loading.md` § "Shared GitNexus Indexed+Fresh Probe" — do NOT run an independent `gitnexus list`; read the single pinned record.** (F3)
1. Read `config.json` in this skill directory to get the `omo_agent` path (used at dispatch time).
2. Read `../x-omo/SKILL.md` to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (`oracle`, `explore`, `librarian`, `multimodal-looker`) via Bash — they are NOT OMC agents. **For the unavailable-agent list and replacement model-routing (`--model gpt`, `--model codex`), see `../x-shared/omo-routing.md § Unavailable Agents`.**
3. Read `../x-gemini/SKILL.md` if `agy_cli` capability is pinned. Gemini-3-pro is the third cross-model reviewer (alongside Claude code-reviewer + GPT oracle), strong on Google-Search-grounded fact checks, large diff handling (1M context), and visual/UI screenshot diffs.

## Invocation

For how to invoke skills, OMO agents, and OMC agents, see `../x-shared/invocation-guide.md`.

## Step-File Architecture

This skill uses sequential steps. Load ONE step at a time. Complete each before proceeding.

### Critical Rules

These exist because skipping them causes real failures (see `gotchas.md` for evidence):

- Load ONE step file at a time — loading multiple causes the model to skip or merge steps
- Read the entire step file before acting — partial reads miss checklists at the bottom
- Follow steps in order — step 3 depends on all reviewers completing in step 2
- Halt at checkpoints for human input — auto-proceeding past verdicts skips user decisions

## Workflow

1. **Read fully and follow** `steps/step-01-prepare.md` — detect target, collect content
2. **Read fully and follow** `steps/step-02-review.md` — launch cross-model reviewers
3. **Read fully and follow** `steps/step-03-synthesize.md` — verify, synthesize, present findings
4. **Read fully and follow** `steps/step-04-act.md` — additional passes menu, verdict routing, checklists

Start with step 1 now.

## Severity

All findings use consistent severity. See `../x-shared/severity-guide.md` for the full scale and triage rules.

## Dependencies

- **x-omo** — bootstrap (agent catalog) + oracle agent for GPT perspective
- **x-gemini** — third cross-model reviewer (Gemini-3-pro); skipped gracefully if `agy_cli` capability not pinned
- **x-shared** — severity-guide, invocation-guide, context-envelope, workflow-chains
- **superpowers** — code-reviewer (primary + S/P/D passes via Agent tool), requesting-code-review (reviewer #3 via Skill tool), receiving-code-review (fix workflow), verification-before-completion (evidence gate), finishing-a-development-branch (post-approve)

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
