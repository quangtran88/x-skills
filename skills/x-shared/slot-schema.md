# x-skill Plugin Slots (v1)

Skills declare their pluggable dependencies via frontmatter `slots:` block. v1 honors user-in-prompt overrides and skill-frontmatter defaults only. Project-level overrides are deferred to v2.

## Canonical slots (vocabulary)

| Slot | Type | Default | Purpose | Emitted in v1? |
|---|---|---|---|---|
| `model` | model-id | (agent-managed) | LLM for the skill's primary reasoning | No |
| `workspace` | workspace-strategy | `current-dir` | Code isolation strategy | **Yes** |
| `verifier` | **skill-or-agent** | `verification-before-completion` | Post-implementation verification. Type is `skill-or-agent` because valid values include both skills (e.g., `verification-before-completion`) and OMC subagents (e.g., `code-reviewer`). Callers must check which kind resolved and dispatch via `Skill` tool or `Agent` tool accordingly. | **Yes** |
| `reviewer` | **skill-or-agent** | `code-reviewer` | Code review pass. Same `skill-or-agent` rationale as `verifier`. | No |
| `executor` | skill-or-agent | `executor` (OMC agent) | Applies code changes | No |
| `researcher` | skill-name | `x-research` | Researches dependencies/context | No |
| `planner` | skill-name | `superpowers:writing-plans` | Produces structured plans | No |

"Emitted in v1" means a skill's frontmatter in this repo declares it. Non-emitted slots stay in the vocabulary for future use; no skill should add them until a follow-up proposal pilots them.

## Valid values

### `model` slot (vocabulary only — not emitted in v1)
- `claude-opus-4-6` — deep reasoning, architecture, complex debugging
- `claude-sonnet-4-6` — standard work (default)
- `claude-haiku-4-5` — quick lookups, trivial classification
- `gpt-5` — cross-model perspective (routes via x-omo Bash)
- `gemini` — cross-model perspective, multimodal (routes via x-omo Bash)
- `auto` — let the skill pick based on task complexity (default behavior)

### `workspace` slot (v1)
- `current-dir` — operate in the current working directory (default)
- `worktree` — create a git worktree via `superpowers:using-git-worktrees`, operate there
- `temp` — create a temporary directory, operate there, discard after

### `verifier` slot (v1)
**Type:** `skill-or-agent`. A verifier can be either a Skill-tool target or an Agent-tool subagent target — dispatch differs between the two, callers must check which kind of identifier resolved.
- `verification-before-completion` — superpowers default cascade (skill — dispatch via `Skill` tool)
- `x-verify` — local completion-cascade dispatcher (skill — dispatch via `Skill` tool; x-verify internally runs the cascade from 06)
- `x-skill-review` — when verifying a skill modification (skill, external — dispatch via `Skill` tool)
- `code-reviewer` — OMC agent (dispatch via `Agent` tool with `subagent_type: "oh-my-claudecode:code-reviewer"`)
- `custom:<skill-name>` — project-specific verifier (skill — dispatch via `Skill` tool)
- `none` — skip verification (DANGEROUS; requires explicit user approval inline before proceeding)

### `reviewer` slot (vocabulary only — not emitted in v1)
- `code-reviewer` — OMC code-reviewer subagent (default for code)
- `x-review` — full x-review skill with cross-model
- `cross-model-review` — shorthand for x-review with cross-model mandatory
- `none` — skip review (only for read-only research tasks)

### `executor` slot (vocabulary only — not emitted in v1)
- `executor` — dispatch to OMC executor subagent (**default**; routers cannot apply edits inline per proposal 04's role forbids)
- `inline` — current session applies edits. **⚠ Currently not usable by any x-skill.** Proposal 04 declares "No x-skill should declare `role: executor`" — therefore no x-skill can legally carry a role that permits `inline`. This value is retained in the vocabulary for future executor-role skills (if any are ever introduced). Setting `executor: inline` on a router, reviewer, or any other current x-skill is a **hard contradiction**: the skill must surface the conflict inline and refuse to dispatch. `x-skill-review` (external) should flag any `executor: inline` declaration as a role/slot conflict.
- `x-omo:<model>` — route edits through a non-Claude CLI (rare)

## Slot precedence (v1 — 3-layer cascade)

When resolving a slot value, check in order (first match wins):

1. **User's explicit request in the current prompt** — "use x-review this time" / "skip verification" → wins.
2. **Skill frontmatter `slots:` block** — the skill's declared default.
3. **Canonical default from this schema** — ultimate fallback.

If no layer specifies a slot, use the default.

**Why only 3 layers in v1:**
- v1 does **not** read project `CLAUDE.md` for a `## Slots` block. That mechanism is v2.
- `.agent-rules.md` is reserved per proposal 07 but not active — no file by that name exists and skills do not read it. Until a separate proposal introduces the convention (file format, discovery mechanism from arbitrary cwd, parse-failure handling), slot resolution uses the 3-layer cascade above. Do not cite `.agent-rules.md` in code paths that expect it to be a working override.

Proposal 07's full 9-layer precedence ladder governs how *instructions* resolve. The 3-layer slot cascade plugs into that ladder at two points: user-in-prompt = ladder priority 1, skill frontmatter = ladder priority 6. Canonical default is the implicit fallback (not a ladder layer).

## Slot resolution example (v1)

User prompt: "refactor this module"
Skill: `x-do` with `slots: { workspace: current-dir, verifier: verification-before-completion }`
Resolution:
- workspace: `current-dir` (from skill frontmatter; no user override)
- verifier: `verification-before-completion` (from skill frontmatter; no user override)

User prompt: "refactor this module, but skip the verifier this time"
Resolution:
- workspace: `current-dir` (from skill frontmatter)
- verifier: `none` (user-in-prompt override — requires x-do to surface the "DANGEROUS; explicit approval needed" prompt before proceeding)

## v2 reference — project CLAUDE.md mechanism

**⚠ Not shipped in v1. Reference only.** v2 will add a layer between 1 and 2:

1. User's explicit request in current prompt
2. **(v2) Project `CLAUDE.md` `## Slots` block** — per-project slot overrides
3. Skill frontmatter `slots:` block
4. Canonical default

The planned v2 mechanism: at skill bootstrap, call `Read` on `<cwd>/CLAUDE.md`. Look for a fenced code block or top-level heading `## Slots` followed by a YAML-shaped block. Parse it as a flat map of `slot-name: value`. Merge parsed values over skill-frontmatter defaults. On parse failure, surface the error inline and ask the user whether to use skill defaults or abort. One file per invocation; no directory walk.

v2 will need its own proposal covering: exact discovery contract (cwd only? repo root? ancestor walk?), parse-failure handling, interaction with monorepos (sub-projects each needing their own CLAUDE.md or one at root winning), and a dry-run audit pattern. Do not act on this section in v1.
