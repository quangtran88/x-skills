---
name: x-skill-improve
description: Use when the user wants to evaluate x-skill alignment and improve a skill based on real session usage — searches Claude Code session history automatically
---

# x-skill-improve — Session-Based Skill Alignment Analyzer

Evaluates how well an x-skill was followed during a real session, then improves the skill based on findings.

## Bootstrap

0. Pin capabilities for the session per `../x-shared/capability-loading.md`. The `plugin.omc` snapshot token (manifest key `plugins.oh_my_claudecode`) gates the `session_search` MCP tool used in step 1; degrade to JSONL-direct fallback if unavailable.

## Invocation

For how to invoke skills and agents, see `../x-shared/invocation-guide.md`.

**Usage:**
- `/x-skill-improve x-do` — search recent sessions for x-do usage
- `/x-skill-improve x-research --since 2d` — search last 2 days
- `/x-skill-improve x-do /path/to/project abc123 def456` — skill + project dir + multiple sessions
- `/x-skill-improve /path/to/project abc123 def456` — project dir + multiple sessions (auto-detect skill)
- `/x-skill-improve abc123-def456` — single session (auto-detect skill, use current project)
- `/x-skill-improve` (no args) — prompt for skill name, then search

## Detection

Trigger when the user:
- Asks to improve/evaluate a skill based on recent usage
- Wants to check if a skill was followed correctly
- Asks to evolve a skill based on real usage
- Says "improve skill from session", "skill alignment check", "did the skill work right"

## Workflow

### 1. Locate Session

Use `session_search` (MCP tool) to find sessions where the target skill was invoked.

**Parse arguments** — see `references/argument-parsing.md` for the full parsing table and resolution rules.

**Search and extract** — see `references/session-discovery.md` for discovery queries, fallback ladder, and deep extraction parameters.

- [ ] **Memory recall** (only when `mcp.basic_memory` pinned in bootstrap-active set): one `mcp__basic-memory__recent_activity({ timeframe: "30d" })` call plus one `mcp__basic-memory__search_notes({ query: "<skill name + improvement keyword>", page_size: 5 })` call. Treat results as supplementary leads — basic-memory holds curated notes, not session transcripts, so the ad-hoc JSONL scan above remains the primary session-discovery path. **Apply consumer rules from `../x-shared/mcp-toolbox.md § Consumer rules`.** When `mcp.basic_memory` is not pinned, **skip silently** — Claude's native auto-memory file still applies and the JSONL fallback above remains the path.

### 2. Load Skill Files

Read the full skill directory for the identified skill. Resolve location using this precedence:
- Skill name starts with `x-` → check **plugin source repo** first. Resolve dynamically:
  1. `${X_SKILLS_PLUGIN_ROOT:-}/skills/<name>/` if env var set
  2. The directory of an x-skills git checkout (try `git -C "$dir" config --get remote.origin.url | grep -q x-skills` for any candidate from `~/Codes`, `~/code`, `~/src`, `$HOME`)
  3. `~/.claude/plugins/cache/x-skills-marketplace/x-skills/*/skills/<name>/` (read-only — never edit here)
- Fallback for non-x skills → `~/.claude/skills/<name>/`
- Plugin cache → **read-only reference**, never edit here

```
<resolved-path>/<skill-name>/
├── SKILL.md          # Always read
├── steps/            # Read all if present
├── references/       # Read all if present
├── gotchas.md        # Read if present
└── config.json       # Read if present
```

Build an **instruction inventory** — a list of every rule, gate, checklist item, and workflow step in the skill.

### 3. Analyze Alignment

Walk through the instruction inventory. For each item, classify based on the session:

| Status | Meaning |
|--------|---------|
| **Followed** | Execution matched the instruction |
| **Deviated** | Execution did something different |
| **Skipped** | Instruction was ignored entirely |
| **Worked Around** | Execution hit a problem the skill didn't account for |
| **N/A** | Instruction doesn't apply to this session's mode/type |

Use the analysis rubric in `references/analysis-rubric.md` for skill-specific checks.

Focus on **high-signal misalignments** — not every trivial deviation matters. Prioritize:
- Mandatory gates that were skipped (e.g., plan review, verification)
- Steps that were worked around (signals missing guidance)
- Patterns that repeated (signals systemic issue)

### 4. Dual-Perspective Findings

For each misalignment, present both perspectives:

- **What the skill says** — quote the specific instruction
- **What the session did** — describe what actually happened
- **Verdict:**
  - `UPDATE SKILL` — The skill is wrong, incomplete, or too rigid. The execution was reasonable.
  - `COMPLIANCE GAP` — The skill is right. The execution should have followed it.
- **Recommendation** — Specific proposed change (file, location, content) or note for compliance

### 5. Present Report

Use the output format below. Then offer to apply fixes.

## Output Format

Use the template in `references/output-template.md`.

## Severity

All findings use the [shared severity scale](../x-shared/severity-guide.md):

| Severity | In This Context |
|----------|----------------|
| **CRITICAL** | Mandatory gate skipped AND skill has no exception for it |
| **HIGH** | Significant gap — skill missing guidance for a common scenario |
| **MEDIUM** | Instruction could be clearer or more flexible |
| **LOW** | Minor wording improvement, edge case documentation |

## Applying Fixes

When the user chooses to apply:

- **Resolve edit target:** For `x-*` skills, always edit the **source repo** (resolved per the precedence in step 2: `$X_SKILLS_PLUGIN_ROOT`, then a local x-skills git checkout). Never edit the plugin cache (`~/.claude/plugins/cache/`) or installed copy. For standalone skills, edit `~/.claude/skills/<name>/`.
- **Default edit tool:** native `Edit` / `Write` for all skill edits — surgical partial edits.
- **UPDATE SKILL findings:** Make targeted edits to the skill files. Prefer:
  - Adding exceptions to existing rules (not rewriting them)
  - Adding items to gotchas.md for newly discovered pitfalls
  - Adding missing guidance as short sections (not bloating SKILL.md)
- **COMPLIANCE GAP findings:** No skill change. Optionally add to gotchas.md as a reminder.
- After applying, show a summary of what changed and offer validation:
  > Updates applied. Validate with `/x-skill-review`? **[Y]** Run review **[N]** Done
- **For x-skills plugin edits:** Remind user to bump version and release after fixes.

## Dependencies

This skill references shared infrastructure in `../x-shared/`:
- `invocation-guide.md` — tool invocation patterns
- `severity-guide.md` — finding severity scale
- `workflow-chains.md` — cross-skill chaining

**Runtime:** Requires `session_search` MCP tool from the oh-my-claudecode plugin. Falls back to JSONL-direct read of `~/.claude/projects/*/sessions/*.jsonl` if unavailable.

## Persistence

After presenting the report, append a summary line to `data/alignment-log.jsonl`:

```json
{"skill":"x-bugfix","sessionId":"f7035623","date":"2026-04-01","findings":8,"updateSkill":3,"complianceGap":5,"applied":true}
```

This enables cross-session pattern tracking — recurring compliance gaps signal systemic issues.

- [ ] **Persist lesson** (only when `mcp.basic_memory` pinned): one `mcp__basic-memory__write_note({ title: "<skill-name>: <improvement-class>", directory: "lessons/<project-slug>", content: "<improvement applied to skill X>", tags: ["<project-slug>", "x-skill-improve", "<skill-name>", "<improvement-class>"] })` call (project-slug = basename of cwd — see `../x-shared/mcp-toolbox.md § Consumer rules`). Skip silently when not pinned.

## After This Skill

Updates applied? → Offer `/x-skill-review` on the modified skill (external user-level skill at `~/.claude/skills/x-skill-review/`; if the user has not installed it, surface that fact and stop — do NOT silently no-op the slash command). **Primitive: `handoff` (sync, depends on result).** Include a [handoff context](../x-shared/context-envelope.md) block: from x-skill-improve, name of the modified skill, list of applied edits with severities, alignment-log entry written. See `../x-shared/workflow-chains.md`.

## Gotchas

See `gotchas.md` for known pitfalls — update when you encounter new ones.

Task: {{ARGUMENTS}}
