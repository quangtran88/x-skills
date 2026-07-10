# x-skills — Intelligent Skill Routers for Claude Code

18 plugin skills that classify user intent and route to the optimal executor, plus an external companion skill (`x-skill-review`, installed at `~/.claude/skills/`). Ships with optional multi-model orchestration via OpenCode.

See `README.md` for the per-skill table, install steps, and dependency list. This file holds only runtime / behavior-shaping rules that Claude needs at every turn.

## Feature Gates

Skills auto-detect available dependencies at bootstrap and route accordingly. No dependency is strictly required — skills degrade gracefully.

**Full capability** = opencode + oh-my-claudecode + superpowers + MCP servers (perplexity, deepwiki, exa, context7) + optional gitnexus (impact / context / rename / route_map; PolyForm Noncommercial license)
**Claude-only mode** = works with zero external deps, uses native Claude Code agents and tools

### Bootstrap Protocol

Every skill that dispatches to external agents MUST follow the contract in `skills/x-shared/capability-loading.md`:

1. Look for the `[x-skills/capabilities]` line injected by the SessionStart hook (parsed once per session — do NOT re-check per dispatch)
2. If absent, read `~/.config/x-skills/capabilities.json` (written by `bin/setup`)
3. Merge `.x-skills/capabilities.json` from the project if present (project override > user manifest)
4. Filter routing tables against the pinned set; pick fallback rows when primary unavailable
5. If the manifest is missing entirely, assume Claude-only mode

Quick fallback reference for OMO/OMC agents lives in this file (tables below). Detailed schema, drift handling, and opt-out mechanics live in `skills/x-shared/capability-loading.md`.

### Claude-Only Fallback Routing

When opencode is unavailable, skills substitute:

| OMO Agent | Claude-Only Replacement |
|-----------|------------------------|
| `oracle` | `Agent` tool with `model=opus` |
| `explore` (Gemini Flash) | `Agent` tool with `subagent_type=Explore` |
| `librarian` (Gemini Flash) | `Agent` tool with web search |
| `multimodal-looker` (Gemini Pro) | `Read` tool (Claude is multimodal) |
| `--model codex` | `Agent` tool with `model=opus` |

When OMC plugin is unavailable:
| OMC Agent | Claude-Only Replacement |
|-----------|------------------------|
| `executor` | `Agent` tool with `mode=auto` |
| `code-reviewer` | `Agent` tool with review prompt |
| `debugger` | `Agent` tool with debug prompt |

## Release Workflow

When releasing a new version (after feature/fix commits are on `main`):

1. **Commit the fixes** — standard `fix()`/`feat()` commits.
2. **Bump the three version manifests** — all must be updated together:
   - `.claude-plugin/plugin.json` → `"version"`
   - `.claude-plugin/marketplace.json` → `"version"` (inside the `skills` array entry)
   - `package.json` → `"version"`
3. **Commit the manifest bump** as `chore(release): vX.Y.Z — <one-line summary>`.
4. **Create + push the git tag**: `git tag vX.Y.Z && git push origin vX.Y.Z`
5. **Publish the GitHub release**: `gh release create vX.Y.Z --title vX.Y.Z --notes "..."` (use the `/release` skill to automate steps 4–5).
6. **Push main**: `git push origin main`

**Semver rules:** BREAKING → MAJOR (or MINOR if major=0), FEATURE → MINOR, FIX/CHORE → PATCH.

> If you skip step 2, the plugin cache will report the old version and `/plugin` will not upgrade consumers.

## Instruction Precedence

The skills in this repo resolve conflicting instructions via the precedence ladder in `skills/x-shared/invocation-guide.md` § "Prompt Assembly — Precedence Ladder".

TL;DR: inviolable principles > user in-prompt > project `CLAUDE.md` > **this file** > advisory memory > `~/.claude/CLAUDE.md` > skill frontmatter > skill body > harness.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **x-skills** (87923 symbols, 119194 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/x-skills/context` | Codebase overview, check index freshness |
| `gitnexus://repo/x-skills/clusters` | All functional areas |
| `gitnexus://repo/x-skills/processes` | All execution flows |
| `gitnexus://repo/x-skills/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->

### GitNexus Fallback

When `mcp.gitnexus` is NOT pinned in the active capability set, the "Always Do" / "Never Do" rules above are best-effort guidance, not enforced gates. The impact-gating in `skills/x-mindful` and the route-map preflight in `skills/x-api-pentest` fall back per the documented Fallback column in `skills/x-shared/mcp-toolbox.md § GitNexus (optional)` (typically native `Grep` or `git diff` + manual analysis). No skill becomes unavailable; gitnexus-grounded checks become best-effort. The MANDATORY language in the auto-managed block above applies only when `mcp.gitnexus` is pinned AND the current repo has a fresh GitNexus index.
