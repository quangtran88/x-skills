# x-skills Overview

x-skills is a Claude Code plugin that provides **intelligent skill routers** — not direct executors, but classification and routing layers that detect user intent and dispatch to the optimal executor (Claude-native tools, OMC agents, OMO agents, or external tools).

## Philosophy

Every skill in x-skills follows the **router principle**: it classifies, it routes, it does not execute complex work directly. This separation of concerns allows:

- **Consistent behavior** across different capability tiers (full multi-model vs Claude-only)
- **Graceful degradation** when optional dependencies are missing
- **Composability** — skills chain together via handoff context
- **Observability** — every dispatch names the primitive (`handoff` vs `assign`) and the resolved slot

## Skill Inventory

| Skill | Declared Role | What It Does |
|-------|---------------|-------------|
| **x-do** | `router` | Universal execution router — classifies tasks into modes (new feature, bugfix, quick edit, refactor, plan execution) and dispatches to the right workflow |
| **x-research** | *(not declared)* | Universal research router — classifies questions by information-source signal and routes to optimal tools/agents |
| **x-review** | `reviewer` | Code/plan/PR review orchestrator — cross-model review with Claude + GPT perspectives, structured verdicts |
| **x-bugfix** | *(not declared)* | Structured debugging — routes through investigation, hypothesis testing, and verified fix with evidence collection |
| **x-design** | *(not declared)* | Visual design system integration — resolves brand references to curated DESIGN.md files |
| **x-api-pentest** | *(not declared)* | API security testing — OWASP API Top 10 testing with schemathesis, nuclei, sqlmap, spectral |
| **x-omo** | *(not declared)* | OpenCode multi-model bridge — dispatch to GPT-5.4, Gemini, Codex models via role agents or direct model routing |
| **x-gemini** | *(not declared)* | Direct Gemini CLI bridge — uses Google Ultra subscription, native Google Search grounding, gemini-3.x access |
| **x-skill-improve** | *(not declared)* | Session-based skill alignment analyzer — evaluates how well a skill was followed during a real session |
| **x-verify** | `verifier` | Completion cascade dispatcher — answers "am I done?" for long-running skills |
| **x-guide** | `progressive-tutor` | Comprehension-gated tutorial generator — turns docs/specs/code into a progressive, resumable walkthrough with per-project state |
| **x-worktree** | `worktree-provider` | Isolated git worktree provisioner — base branch + new branch resolution, `wt`/`git worktree` dual provider, machine-readable result envelope. Invoked directly or via `--wt` from `x-do`/`x-bugfix`. |
| **x-shared** | *(not a skill)* | Shared infrastructure consumed by other skills (not invokable) |

Skills that declare a `role` in their frontmatter have explicit behavioral constraints. The role taxonomy exists to prevent role leakage (e.g., a reviewer applying fixes during review phase). Not all skills declare a role — those without one follow general conventions documented in their SKILL.md body.

### Role Taxonomy (for skills that declare one)

| Role | Can Do | Cannot Do |
|------|--------|-----------|
| **router** | Classify, dispatch, coordinate | Apply code changes directly (in most modes) |
| **reviewer** | Evaluate, return verdicts, surface menus | Apply fixes during review phase |
| **verifier** | Report completion status, run checks | Apply fixes |

## Key Design Principles

1. **Statelessness**: Skills do not maintain state between invocations. All context is passed via handoff envelopes or inline in the conversation.

2. **Capability Pinning**: At bootstrap, skills read the capability manifest once and filter routing tables against it. They do not re-check per dispatch.

3. **Slot Resolution**: Pluggable dependencies (verifier, workspace strategy) are resolved via a 3-layer cascade: user override → skill frontmatter → canonical default.

4. **Primitive Discipline**: Every subagent dispatch is either `handoff` (sync, sequential dependency) or `assign` (async fan-out, independent tasks). No ad-hoc patterns.

5. **Cheapest-Viable-First**: Free/instant tools before token-billed before agent-billed. Morph search before OMO agents.

6. **Verification-Before-Completion**: Long-running skills must run the completion cascade before claiming done. The single biggest compliance-gap closer.

## Capability Tiers

| Tier | What You Have | Skill Capability |
|------|--------------|-----------------|
| **Full** | OpenCode + oh-my-openagent + OMC + superpowers + MCP servers | Multi-model routing, cross-model review, full agent catalog |
| **Claude+Plugins** | OMC + superpowers (no OpenCode) | Claude-only routing with OMC agents and workflow skills |
| **Bare** | Just x-skills | Claude-only fallback — skills still work using native Agent tool |

## Directory Structure

```
x-skills/
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest (version, hooks, metadata)
│   └── marketplace.json      # Marketplace registration
├── bin/
│   ├── omo-agent             # OpenCode multi-model wrapper script
│   ├── gemini-agent          # Gemini CLI wrapper script
│   ├── setup                 # Setup script (binding + detection + capability manifest)
│   └── find-plugin-dir       # Plugin path resolver
├── commands/
│   └── setup.md              # /x-skills:setup command definition
├── hooks/
│   ├── check-version.sh      # SessionStart: version drift detection
│   └── inject-capabilities.sh # SessionStart: capability snapshot injection
├── lib/
│   └── feature-gate.md       # Fallback routing reference
├── docs/
│   ├── DEPENDENCY_SYSTEM_DESIGN.md  # Lazy dependency system design
│   └── [generated docs]      # This documentation set
└── skills/
    ├── x-do/                 # Execution router
    ├── x-research/           # Research router
    ├── x-review/             # Review orchestrator
    ├── x-bugfix/             # Debugging workflow
    ├── x-design/             # Design system integration
    ├── x-api-pentest/        # API security testing
    ├── x-omo/                # OpenCode bridge
    ├── x-gemini/             # Gemini CLI bridge
    ├── x-skill-improve/      # Skill alignment analyzer
    ├── x-guide/              # Progressive comprehension-gated tutor
    ├── x-worktree/           # Isolated git worktree provisioner
    └── x-shared/             # Shared references (NOT a skill)
```

## How a Request Flows

```
User: "add auth to the API"
         │
    x-do classifies → Mode B (new feature)
         │
    ┌────┴────────────────────┐
    │ Research needed?          │
    ├─── yes ─→ x-research      │
    │          (Type F: pre-plan)│
    ├─── no ──→ continue        │
    └─────────────────────────┘
         │
    Depth calibration → Standard (3-5 files, 2 modules)
         │
    Brainstorm → Plan → Plan Review (3 reviewers, parallel)
         │
    Execute (ralph or direct)
         │
    Post-Implementation Review (3 reviewers, parallel)
         │
    x-verify completion cascade
         │
    Handoff menu → /x-review, commit, plan-next, done
```

## Next Steps

- Read [INTERNAL_ARCHITECTURE.md](INTERNAL_ARCHITECTURE.md) for the plugin's internal machinery
- Read [BOOTSTRAP_AND_CAPABILITY_SYSTEM.md](BOOTSTRAP_AND_CAPABILITY_SYSTEM.md) for how capabilities are detected and pinned
- Read [SKILL_ROUTING_AND_MODES.md](SKILL_ROUTING_AND_MODES.md) for how x-do and x-research classify tasks
- Read [OMO_BRIDGE_AND_AGENTS.md](OMO_BRIDGE_AND_AGENTS.md) for multi-model orchestration
