---
name: x-review
description: Use when the user asks to review code, a plan, a PR, or a directory — auto-detects target and runs cross-model review by default (Claude + GPT perspectives)
role: reviewer
---

## Role: reviewer

**x-review is a reviewer.** It evaluates existing work and returns verdicts. It does **not** apply fixes.

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
1. Read `config.json` in this skill directory to get the `omo_agent` path.
2. Read the x-omo SKILL.md (at the parent directory of `omo_agent`) to load the OMO agent catalog, invocation commands, and model routing. This ensures you know how to invoke OMO agents (`oracle`, `explore`, `librarian`, `multimodal-looker`) via Bash — they are NOT OMC agents. **Do NOT dispatch to `hephaestus`, `atlas`, `prometheus`, `metis`, or `momus` — they are UNAVAILABLE due to a plugin compat bug. Use `--model gpt` (plan review / blocker-finder) or `--model codex` (autonomous implementation) instead. See `../x-omo/gotchas.md`.**

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
- **x-shared** — severity-guide, invocation-guide, context-envelope, workflow-chains
- **superpowers** — code-reviewer (primary + S/P/D passes via Agent tool), requesting-code-review (reviewer #3 via Skill tool), receiving-code-review (fix workflow), verification-before-completion (evidence gate), finishing-a-development-branch (post-approve)

## Gotchas

See `gotchas.md` for known failure patterns — update it when you encounter new ones.

Task: {{ARGUMENTS}}
