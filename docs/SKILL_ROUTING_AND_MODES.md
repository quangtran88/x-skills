# Skill Routing and Modes

This document describes how x-skills classify user requests and route them through the optimal workflow.

## x-do — Universal Work Command

x-do is the primary execution router. It classifies tasks into six modes and dispatches accordingly.

### Detection Matrix

| Mode | Detect When | Key Signals |
|------|------------|-------------|
| **A: Existing Plan** | User references a plan/spec/doc file | File path, "implement the plan", "execute the spec" |
| **B: New Feature** | Something to build/add/create, no existing plan | Creative/new work, no plan referenced |
| **C: Bug Fix** | Error, stack trace, failure description | "fix", "bug", "error", "broken", "crash", "failing" |
| **D: Quick Task** | Trivial change, clearly < 5 min, no ambiguity | Rename, small edit, config change, single-file |
| **E: Visual Input** | PDF, image, screenshot, diagram provided | Binary file attachment, visual reference |
| **F: Refactor** | Structural code change, not a bug or new feature | "refactor", "restructure", "reorganize", "extract", "inline", "move to", "clean up" (multi-file) |

### Special Cases

- **Review feedback → Mode A**: When the user provides numbered/enumerated feedback on an existing commit, route to Mode A — the feedback list IS the plan.
- **Mode D vs F boundary**: Single-file rename → Mode D. Multi-file structural changes → Mode F.

### Depth Calibration

Before entering mode guidance, x-do assesses complexity along four dimensions:

| Dimension | Light | Standard | Heavy |
|-----------|-------|----------|-------|
| **Scope** | 1-2 files, single module | 3-5 files, 2 modules | 5+ files, 3+ modules |
| **Risk** | No shared state, reversible | Touches shared interfaces | Auth, data, payments, migrations |
| **Novelty** | Known patterns, clear path | Some unknowns | Unfamiliar stack, no precedent |
| **Dependencies** | Independent changes | Some ordering needed | Cross-task dependencies, integration points |

**Scoring**: Majority determines ceremony level:
- **Light** → Skip brainstorming, skip plan review, 1 reviewer post-impl
- **Standard** → Brief brainstorm, plan if 3+ tasks, full 3-reviewer post-impl
- **Heavy** → Full pipeline: brainstorm → plan → plan review → execute → post-impl review

### Mode A: Existing Plan

1. Read the plan fully
2. **Plan Review (cross-model, parallel) — NON-NEGOTIABLE** for 3+ tasks or multi-module. Launch all 3 reviewers in ONE message.
   - Exception: trivial plans (< 3 tasks AND single module) skip review
   - Exception: mechanical batches (same structural change across N files) skip review
   - Exception: research-produced plans may use reduced review (1 reviewer)
3. Execute: `ralph` for 3+ tasks, direct execution for simpler plans
   - Exception: mechanical batches → direct execution regardless of count
   - Exception: surgical edits (single-location, no deps, < 30 lines) → direct execution
4. **Post-Implementation Review** (cross-model, parallel)
   - Trivial implementations: reduce to 1 reviewer
   - Parent workflow deference: when inside x-skill-improve, defer to parent's validation
5. Verify and finish branch

### Mode B: New Feature

1. If requirements clear: brainstorm approaches, then plan
2. If requirements vague or cross 3+ modules: follow step files (`step-01-gather.md` through `step-04-execute.md`)
3. **Plan Review** (same rules as Mode A)
4. Execute based on scope:
   - 3+ tasks → `ralph`
   - 1-2 tasks → OMO `--model codex` or direct execution
   - Mechanical batch or surgical edits → direct execution
5. **Post-Implementation Review** (same rules as Mode A)
6. Verify and finish branch

### Mode C: Bug Fix

**Delegate to `/x-bugfix`** — it has structured investigation phases, evidence hierarchy, and verified fixes.

After x-bugfix completes:
1. Post-Fix Review (cross-model, parallel)
2. Verify and finish branch

### Mode D: Quick Task

1. Execute directly — no agent spawn for trivial changes
   - Use `morph-mcp edit_file` as default edit tool
   - Use `morph-mcp codebase_search` to locate target code
   - Spawn OMC `executor` only if task benefits from isolation
2. Still verify — even quick tasks need evidence (tsc + eslint)

### Mode E: Visual Input

1. If image is already in conversation: Claude analyzes directly first
2. For complex visual analysis: dispatch OMO `multimodal-looker` + OMC Explore in parallel
3. Synthesize, then route to A/B/C based on what the visual reveals

### Mode F: Refactor

1. Detect if `/refactor` skill is available (check `~/.claude/skills/refactor/`)
2. If available → delegate with handoff context
3. If absent → fall back to Mode A (treat as multi-task plan)
4. Post-Refactor Review (cross-model, parallel)
   - Small scope (< 3 files): reduce to 1 reviewer

## x-research — Universal Research Orchestrator

x-research classifies questions by **information-source signal** and picks the best tool/agent.

### Depth Calibration (Standard Mode)

| Depth | Signal | Action |
|-------|--------|--------|
| **Light** | Single concept, known area | Direct file reads or one MCP call |
| **Targeted** | Specific investigation, one knowledge domain | Single tool/agent with focused prompt |
| **Deep** | Multi-faceted, cross-domain, ambiguous | Parallel dispatch (escalate to Max Mode) |

### Detection — Signal → Primary Tool

| Signal | Primary | Escalation |
|--------|---------|------------|
| Local code: "how does our X work" | `morph-mcp` → `codebase_search` | OMO `explore` |
| Local cross-repo (3+ modules) | `morph` + OMO `explore` parallel | — |
| Public repo internals | `deepwiki` → `ask_question` | `morph` → `github_codebase_search` → OMO `librarian` |
| Library API usage | `context7` → `query-docs` | `exa` → `get_code_context_exa` |
| Library current state | `gemini-agent` (Google Search) | `perplexity_ask` |
| Quick factual lookup | `perplexity_ask` | `gemini-agent` |
| Fresh news / current events | `gemini-agent` | `perplexity_ask` w/ recency filter |
| X vs Y tradeoff | `perplexity_reason` | OMO `oracle` |
| Architecture decision | OMO `oracle` | + `perplexity_reason` |
| Pre-planning | OMO `oracle` ∥ `morph` ∥ `perplexity_ask` | — |
| Visual single file | Claude `Read` or `gemini-agent --file` | OMO `multimodal-looker` |
| Visual cross-file | OMO `multimodal-looker` | — |
| Exhaustive audit | `perplexity_research` | + OMO `oracle` |
| Dense code examples | `exa` → `get_code_context_exa` | OMO `librarian` |

### Hard Gate — Sequencing Matters

For any signal whose primary is `morph` or `deepwiki`:
- **MUST** call the primary AND read its output BEFORE dispatching any agent
- Firing agents "in parallel with the primary, just in case" is a violation
- "Insufficient" means you READ the output and judged it inadequate

**Max Mode is exempt** — its whole purpose is parallel multi-lane fan-out where the user has accepted the cost.

### Max Mode

Trigger: `/x-research max <question>`, `/x-research prism <question>`, or `--max` flag.

Max Mode fans out across all relevant lanes for the question class, then reconciles findings (similar to x-review's multi-reviewer synthesis).

**Cost guard (MANDATORY before dispatch):**
```
Max Mode: <N> lanes — <lane list with rough cost/latency>.
Proceed? [Y/n/standard]
```

User may downgrade to Standard. Skip the prompt only when the user explicitly types `prism!` or `--max-yes`.

## x-bugfix — Universal Bugfix Command

x-bugfix classifies bugs into four modes:

| Mode | Detect When | Route |
|------|------------|-------|
| **Q: Quick Fix** | Trivial: lint error, type error, syntax fix, single obvious typo | Read error → locate file → fix → typecheck/lint |
| **A: Quick Bug** | Clear error, single component, obvious root cause path | Streamlined investigate → fix |
| **B: Deep Investigation** | Ambiguous, causal, multi-component, intermittent | Read `references/mode-b-deep.md` |
| **C: System/Infra** | CI/CD, deployment, performance, server/DB issues | Read `references/mode-c-system.md` |

### Iron Law

> **NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.** If you can't state the root cause in one sentence, you haven't investigated enough.

### Mode A: Quick Bug — Workflow

1. **Investigate**: Gather evidence before forming hypotheses
   - Reproduce the bug
   - Check recent changes (`git log --oneline -10 -- <affected-files>`)
   - Trace data flow backward from symptom to source
   - Use `morph-mcp codebase_search` as first search tool
   - Consult `references/pattern-catalog.md` to narrow search space
   - Output: a **root cause hypothesis** — specific and testable

2. **Hypothesize & Test**: Scientific method — one variable at a time
   - Form a single hypothesis, test minimally, verify
   - If wrong, form a NEW hypothesis — don't stack fixes

3. **Instrumentation Pivot** (after 2 failed iterations — MANDATORY)
   - STOP speculating and instrument the system
   - Add targeted debug logs along suspected call chain
   - Run live system to reproduce
   - Read logs in chronological order
   - Form next hypothesis from observed state, not assumptions

4. **3-Strike Rule**: 3 hypothesis iterations without progress → STOP
   - If instrumentation has happened and still no confident root cause → delegate to OMO `oracle`
   - If oracle confirms architectural issue → escalate to user

5. **Fix & Verify**:
   - Write regression test that fails without the fix
   - Implement single fix addressing root cause — minimal diff
   - Run test suite — no regressions
   - Fresh verification — reproduce original scenario, confirm fixed
   - **Prevention gate** — apply defense-in-depth, prevent the bug *class*

## x-review — Universal Review Command

x-review uses a **step-file architecture** — load ONE step at a time, complete each before proceeding.

| Step | File | Purpose |
|------|------|---------|
| 1 | `steps/step-01-prepare.md` | Detect target, collect content |
| 2 | `steps/step-02-review.md` | Launch cross-model reviewers |
| 3 | `steps/step-03-synthesize.md` | Verify, synthesize, present findings |
| 4 | `steps/step-04-act.md` | Additional passes menu, verdict routing, checklists |

### Role: Reviewer

- **MUST NOT** call `Edit` or `Write` during review phase (steps 1-3)
- **MUST NOT** propose inline fixes during review phase
- **MUST NOT** run mutating `Bash` during review phase
- **Exception — Fix Mode**: When user explicitly requests fixes after REQUEST_CHANGES verdict, x-review enters Fix Mode (step 4). Role boundary shifts from "report only" to "report then fix on request."

### Cross-Model Review

By default, x-review runs cross-model review (Claude + GPT perspectives):

**Target A (Plan/Spec review):**
1. **OMC `code-reviewer`** (Claude perspective) via `Agent` tool
2. **`--model gpt`** (GPT-5.5 blocker-finder perspective) via `omo-agent` Bash — OKAY/REJECT verdict. Replaces UNAVAILABLE `momus` role agent.
3. **`superpowers:requesting-code-review`** (third perspective) via `Skill` tool
(Optional 4th: OMO `oracle` for architecture-sensitive plans)

**Targets B/C/D (Code/Files/Diff review):**
1. **OMC `code-reviewer`** (Claude perspective) via `Agent` tool
2. **OMO `oracle`** (oracle perspective) via `omo-agent` Bash
3. **`superpowers:requesting-code-review`** (third perspective) via `Skill` tool

All three are launched in **ONE message** (`assign` primitive). Wait for ALL results before synthesizing.

By default, x-review runs cross-model review (Claude + GPT perspectives):

1. **OMC `code-reviewer`** (Claude perspective) via `Agent` tool
2. **`--model gpt`** (GPT-5.5 perspective) via `omo-agent` Bash
3. **`superpowers:requesting-code-review`** (third perspective) via `Skill` tool

All three are launched in **ONE message** (`assign` primitive). Wait for ALL results before synthesizing.

## x-design — Visual Design System Router

x-design resolves user design intent to a curated `DESIGN.md` file.

### Detection

| Signal | Route |
|--------|-------|
| Named brand ("Linear", "Stripe", "Claude") | Direct slug lookup in catalog |
| Descriptive intent ("warm editorial", "dark minimal") | Match against intent tags → propose 2-3 candidates |
| "What's available?" / "list styles" | Show catalog section(s) |
| "Something like X but Y" | Look up X's tags, filter by Y, propose candidates |

### Three-Stage Pipeline

1. **x-design** fetches `DESIGN.md` — brand vision (the *what*)
2. **ui-ux-pro-max** generates `design-system/MASTER.md` — enforceable rules (the *constraints*)
3. **shadcn** MCP finds and installs matching components — execution (the *how*)

Each stage is opt-in. Stages 2 and 3 are skipped if user declines or project can't support them.

## x-api-pentest — API Security Testing

Uses **step-file architecture** with security gates:

| Step | File | Purpose |
|------|------|---------|
| 1 | `steps/step-01-recon.md` | Spec lint, attack surface, role mapping, **consent gate** |
| 2 | `steps/step-02-auth-baseline.md` | Validate 2 user tokens + admin token |
| 3 | `steps/step-03-automated-sweep.md` | Parallel Schemathesis + RESTler + Nuclei |
| 4 | `steps/step-04-targeted-tests.md` | BOLA/BFLA, mass assignment, SSRF, velocity, business logic |
| 5 | `steps/step-05-synthesize.md` | Dedupe, severity, chain-impact reasoning |
| 6 | `steps/step-06-report.md` | Markdown + SARIF, handoff |

### Safe Execution

- Target must match `safety.allowed_target_patterns` (localhost, RFC1918, `*.staging.*`, etc.)
- Prefer egress-isolated container
- Credentials only via environment variables
- **No active scans without explicit target confirmation**

## x-skill-improve — Session-Based Skill Alignment Analyzer

### Workflow

1. **Locate Session**: Use `session_search` MCP tool to find sessions where target skill was invoked
2. **Load Skill Files**: Read full skill directory, build instruction inventory
3. **Analyze Alignment**: Walk through instruction inventory, classify each item:
   - **Followed** — execution matched instruction
   - **Deviated** — execution did something different
   - **Skipped** — instruction was ignored entirely
   - **Worked Around** — execution hit problem skill didn't account for
   - **N/A** — instruction doesn't apply to this session
4. **Dual-Perspective Findings**: For each misalignment, present:
   - What the skill says
   - What the session did
   - Verdict: `UPDATE SKILL` or `COMPLIANCE GAP`
   - Recommendation

### Persistence

Append summary to `data/alignment-log.jsonl` for cross-session pattern tracking.

### x-do: Research Gate (Before Detection)

Before classifying mode, x-do checks whether the task needs research first:

| Signal | Action |
|--------|--------|
| Unfamiliar library/API/framework | → `/x-research` (Type B or D) first, then return here |
| Vague requirements spanning 3+ modules | → `/x-research` (Type F) first, then return here |
| "How does X work in our codebase?" before fixing/building | → `/x-research` (Type A) first, then return here |
| Clear requirements, known codebase area | → Skip, proceed to Detection |

**Return path:** If x-research just completed in the same session and provided findings, skip this gate entirely and proceed directly to Detection. This includes cases where x-research's quick-action exception applied a fix inline.

### x-do: Pre-Flight Checklist (MANDATORY)

Before starting any mode, x-do completes ALL of these checks:

1. **Resume detection:** Check for in-progress state (paths in `config.json`):
   - `ralph_state` — incomplete stories → offer to resume
   - `specs_dir` — uncommitted design docs → offer to continue
   - Draft plan files (`spec-wip.md`) → offer to continue
2. **Gotchas:** Read `gotchas.md` for known failure patterns before starting
3. **Depth check:** Assess complexity to calibrate ceremony (see Depth Calibration above)

---

## x-design: Detailed Branching Behavior

### Step 6: ui-ux-pro-max Handoff

`DESIGN.md` captures aesthetic intent; `ui-ux-pro-max` captures enforceable rules (a11y, palettes, stack guidelines, anti-patterns). This is an **external user-level skill** (not shipped in this plugin).

**Behavior:**
- **Detect first** by checking the available skills list
- **Installed** → ask once: "Want me to also generate a `design-system/MASTER.md` with implementation rules via `ui-ux-pro-max`?"
- **Not installed** → surface the install pointer once, then skip step 6 (do NOT silently no-op):
  > "Optional next step: `ui-ux-pro-max` would generate enforceable rules (`design-system/MASTER.md`) to complement `DESIGN.md`. Not installed. Source: <https://github.com/nextlevelbuilder/ui-ux-pro-max-skill>. Skipping for now."
- If user accepts, invoke via `handoff` (sync) with a handoff context block
- If user declines, skip silently — never push twice

### Step 7: shadcn MCP Handoff

`DESIGN.md` + `MASTER.md` describe *what* the UI looks like; `shadcn` MCP is *how* to install matching components.

**Conditional gate:** Call `mcp__shadcn__get_project_registries` first:
- **Empty/error result** → trigger the **non-shadcn framework advisory** (see below), then proceed to step 8. Never push shadcn onto non-shadcn projects.
- **Registries exist** → follow `references/shadcn-handoff.md` workflow: detect → ask once → seed primitives with `search_items_in_registries` + `get_add_command_for_items` → optional `get_audit_checklist`

**Primitive:** sequential `handoff` after step 6 — `shadcn` consumes MASTER.md tokens, so it must follow the ui-ux-pro-max handoff (do NOT fan out steps 6 + 7 in parallel).

**Rule:** Print install commands; never auto-run.

**Non-shadcn framework advisory:** When `get_project_registries` returns empty, check for detectable framework and offer a one-line hint (never push, just inform):
- `nuxt.config.*` or `vue` in deps → "Apply DESIGN.md tokens via CSS custom properties or scoped `<style>` in Vue SFCs."
- `svelte.config.*` → "Apply tokens via Svelte's `style:` directives or a shared `tokens.css`."
- `pubspec.yaml` (Flutter) → "Map DESIGN.md hex values to `Color(0xFF...)` constants in a theme file."
- `index.html` only (vanilla) → "Apply tokens as CSS custom properties in a `<style>` block or linked stylesheet."
- No framework detected → skip silently.

### Step 8: Project CLAUDE.md Hint (Opt-in)

Default (`auto_update_claude_md: false`) is to **ASK first**. If user consents, append one line matched to what was installed:

| Files present | Line to append |
|---------------|----------------|
| Only `DESIGN.md` | `When generating or modifying UI, read DESIGN.md in the project root for visual styling rules.` |
| `DESIGN.md` + `design-system/MASTER.md` | `When generating UI: read DESIGN.md (brand vision) and design-system/MASTER.md (rules).` |
| Above + shadcn registries detected | `When generating UI: read DESIGN.md (vision) and design-system/MASTER.md (rules); use the shadcn MCP (search_items_in_registries, get_add_command_for_items) to install matching components.` |

Never modify any other content in `CLAUDE.md`.

---

## x-api-pentest: Safety Configuration and Operational Details

### config.json Safety Settings

```json
{
  "safety": {
    "require_target_confirmation": true,
    "allowed_target_patterns": ["localhost", "127.0.0.1", "10.*", "172.16.*", ..., "*.staging.*", "*.test.*", "*.local"],
    "denied_target_patterns": ["*.gov", "*.mil"],
    "require_allow_unsafe_target_flag": true,
    "max_requests_per_second": 50,
    "max_total_requests": 5000
  }
}
```

**Key rules:**
- `require_target_confirmation`: Must be explicitly confirmed before active scans
- `allowed_target_patterns`: Default covers localhost, RFC1918, `*.staging.*`, `*.test.*`, `*.local`
- `denied_target_patterns`: `*.gov` and `*.mil` are permanently denied (no override)
- Override outside allowlist requires `allow_unsafe_target=true` + explicit env var confirmation (`CONFIRMED_TARGET_URL`)
- Rate caps: 50 req/s, 5000 total requests max

### Target Allowlist Check Algorithm

Step 01 enforces the allowlist via a **Python script** (not bash glob — a prior bash-glob implementation failed open on `10.evil.com`):

- Parse URL with Python `urllib.parse`
- Denylist check first (`*.gov`, `*.mil`) — fnmatch, no override
- IP path: use `ipaddress` module for CIDR membership (127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Hostname path: fnmatch against `localhost`, `*.staging.*`, `*.test.*`, `*.local`
- Override: if `allow_unsafe_target=true` set, HALT and require `CONFIRMED_TARGET_URL='$url'` env var to proceed

### Oracles and Integrations

```json
{
  "oracles": {
    "bola": true,
    "bfla": true,
    "mass_assignment": true,
    "ssrf": true,
    "velocity": true,
    "business_logic": true,
    "llm_endpoints": "auto"
  },
  "integrations": {
    "prefer_hexstrike": false,
    "blind_verification": true,
    "blind_verification_min_severity": "High"
  }
}
```

- `prefer_hexstrike`: STUB ONLY — not implemented. When false (default), all tools invoked via direct CLI.
- `blind_verification`: Every Critical/High finding is re-verified with a fresh curl request
- `blind_verification_min_severity`: Only findings at High or above trigger blind re-verification

### Noise Filters (from gotchas.md)

These patterns must **NOT** be emitted as findings:

- Missing security headers alone (without exploit impact) → Info only, never Medium+
- Generic rate-limiting complaints without demonstrated brute-force/enumeration payoff
- Self-XSS requiring victim to paste into own console
- Verbose error messages disclosing non-sensitive internals (framework name, route handler) → Info only
- Test/demo/fixture endpoints under `/test`, `/demo`, `/sample`, `/_internal/debug`
- CORS misconfigurations without demonstrated credential-bearing exploit
- Local-only code paths where scanner cannot prove network reachability
- CI/CD injection vectors — out of scope
- TLS 1.1 warnings — infrastructure scope, not API scope

**Rule of thumb:** "Can I write a one-line curl that demonstrates impact?" If no, it's noise.

### sqlmap Risk Guardrails

- Default: `--level 2 --risk 1` (configured in `config.json`)
- **Never** raise to `--level 5 --risk 3` against unknown targets — destructive
- Must obtain explicit approval before raising sqlmap risk above default

---

## x-skill-improve: Internal Resolution and Analysis Details

### Source-Repo Resolution Precedence

When loading skill files for analysis, resolve location using this precedence:

1. **Skill name starts with `x-`** → check **plugin source repo** first:
   - `${X_SKILLS_PLUGIN_ROOT:-}/skills/<name>/` if env var set
   - Directory of an x-skills git checkout (detect via `git -C "$dir" config --get remote.origin.url | grep -q x-skills` for candidates from `~/Codes`, `~/code`, `~/src`, `$HOME`)
   - `~/.claude/plugins/cache/x-skills-marketplace/x-skills/*/skills/<name>/` (read-only — never edit here)
2. **Fallback for non-x skills** → `~/.claude/skills/<name>/`
3. **Plugin cache** → read-only reference, never edit

### Skill Directory Read Order

```
<resolved-path>/<skill-name>/
├── SKILL.md          # Always read
├── steps/            # Read all if present
├── references/       # Read all if present
├── gotchas.md        # Read if present
└── config.json       # Read if present
```

Build an **instruction inventory** — a list of every rule, gate, checklist item, and workflow step in the skill.

### Analysis Rubric (from references/analysis-rubric.md)

**Universal checks** (apply regardless of skill):
- Skill detection — was correct mode/type/target identified?
- Pre-flight checklist — were mandatory items completed?
- Invocation correctness — OMO agents via Bash (not Agent tool)? OMC agents via Agent tool?
- Background result collection — were all results collected before synthesis?
- Verification gate — was verification run before claiming completion?
- Gotchas awareness — were known gotchas avoided?
- Workflow chain — was recommended next skill suggested?

**Per-skill checks** (examples):
- x-do: mode classification, research gate, plan review gate (3+ tasks), post-impl review (3 reviewers in one message), ralph for 3+ tasks
- x-research: type classification, agent selection, parallel execution, synthesis quality, handoff offered
- x-review: target detection, cross-model review, all results collected, findings with severity, fix offering
- x-skill-improve: argument parsing, workingDirectory consistency, search parallelism, fallback ladder, full skill directory read, instruction inventory completeness, dual-perspective format, output template compliance, fix application restraint

**Weighting:**
- Mandatory gates skipped → CRITICAL or HIGH
- Wrong agent invocation → HIGH
- Missing verification → HIGH
- Workflow deviations → MEDIUM
- Missing suggestions → LOW

### Search Patterns (from references/search-patterns.md)

**Discovery queries per skill** (run all variants in parallel):
- x-do: `"/x-do"`, `"Mode A"`, `"x-do skill"`
- x-research: `"/x-research"`, `"Type A"`, `"x-research skill"`
- x-review: `"/x-review"`, `"x-review skill"`, `"Target A"`
- x-bugfix: `"/x-bugfix"`, `"x-bugfix skill"`, `"Mode B"`
- x-skill-improve: `"/x-skill-improve"`, `"skill alignment"`, `"UPDATE SKILL"`

**Auto-detection:** When no skill name is provided, run discovery queries for ALL supported skills in parallel. The skill that returns matches is the one to analyze.

**Discovery parameters:** `contextChars: 500`, `limit: 10`
**Deep extraction parameters:** `contextChars: 1000`, `limit: 20`

