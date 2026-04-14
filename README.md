# x-skills

Intelligent skill routers for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Each skill classifies user intent and routes to the optimal executor — with optional multi-model orchestration via [OpenCode](https://github.com/opencode-ai/opencode).

All dependencies are optional. Skills degrade gracefully to Claude-only mode when external tools aren't available.

## Install

```bash
/plugin marketplace add quangtran88/x-skills
/plugin install x-skills@x-skills-marketplace
/reload-plugins
```

Then run setup to configure the omo-agent binding and detect available dependencies:

```
/x-skills:setup
```

## Skills

| Skill | Invoke | What it does |
|-------|--------|-------------|
| **x-do** | `/x-skills:x-do` | Universal execution router — classifies tasks into modes (new feature, bugfix, quick edit, refactor, plan execution) and dispatches to the right workflow |
| **x-research** | `/x-skills:x-research` | Universal research router — classifies questions and routes to optimal agents (codebase search, external docs, architecture review, OSS internals, pre-planning) |
| **x-review** | `/x-skills:x-review` | Code/plan/PR review orchestrator — cross-model review with Claude + GPT perspectives, structured verdicts |
| **x-bugfix** | `/x-skills:x-bugfix` | Structured debugging — routes through investigation, hypothesis testing, and verified fix with evidence collection |
| **x-design** | `/x-skills:x-design` | Visual design system integration — resolves brand references (Linear-like, Stripe-like) to curated DESIGN.md files from 58 indexed sites |
| **x-api-pentest** | `/x-skills:x-api-pentest` | API security testing — OWASP API Top 10 testing with schemathesis, nuclei, sqlmap, spectral |
| **x-omo** | `/x-skills:x-omo` | OpenCode multi-model bridge — dispatch to GPT-5.4, Gemini, Codex models via role agents or direct model routing |

`x-shared` is a reference library used by other skills (not invokable directly).

## How It Works

Each skill is a **router**, not an executor. It:

1. **Reads** `~/.config/x-skills/capabilities.json` to detect available tools
2. **Classifies** the user's request into a type/mode
3. **Dispatches** to the best available executor (OMO agent, OMC agent, native Claude agent, or direct tool)

```
User: "add auth to the API"
         │
    x-do classifies → Mode A (new feature)
         │
    ┌────┴────────────────────┐
    │ opencode available?     │
    ├─── yes ─→ OMO oracle    │  (GPT-5.4 review)
    │          + OMC executor  │  (Claude implementation)
    ├─── no ──→ Agent(opus)   │  (Claude-only fallback)
    └─────────────────────────┘
```

## Dependencies

Everything is optional. Setup detects what's available and skills adapt.

| Dependency | What it enables | Install |
|-----------|----------------|---------|
| [OpenCode](https://github.com/opencode-ai/opencode) | Multi-model dispatch (GPT, Gemini, Codex) | `curl -fsSL https://opencode.ai/install \| bash` |
| [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | Role agents (oracle, explore, librarian) | `opencode plugin oh-my-openagent` |
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | OMC agents (executor, code-reviewer, debugger) | `/plugin marketplace add Yeachan-Heo/oh-my-claudecode` |
| [superpowers](https://github.com/obra/superpowers) | Workflow skills (brainstorming, TDD, writing-plans) | `/plugin marketplace add obra/superpowers-marketplace` |
| [claude-mem](https://github.com/thedotmack/claude-mem) | Cross-session memory + search | `/plugin marketplace add thedotmack/claude-mem` |
| MCP servers | perplexity, deepwiki, exa, context7, morph | Configure in `.mcp.json` |
| Security tools | schemathesis, nuclei, sqlmap, spectral | `pip install schemathesis sqlmap` / `brew install nuclei` |

### Capability Tiers

| Tier | What you have | Skill capability |
|------|--------------|-----------------|
| **Full** | OpenCode + oh-my-openagent + OMC + superpowers + MCP servers | Multi-model routing, cross-model review, full agent catalog |
| **Claude+Plugins** | OMC + superpowers (no OpenCode) | Claude-only routing with OMC agents and workflow skills |
| **Bare** | Just x-skills | Claude-only fallback — skills still work using native Agent tool |

## Setup

`/x-skills:setup` detects your environment and offers to install missing dependencies:

```
$ /x-skills:setup

  Working: omo-agent, opencode (166 models), perplexity MCP
  Missing: oh-my-claudecode, superpowers, claude-mem

  Would you like me to install the missing plugins? [1,2,3 / all / skip]
```

Setup is idempotent — safe to run any number of times. Each run detects current state and only acts on what's missing.

### Manual Setup

If you prefer to set up manually:

```bash
# The bin/ directory is auto-added to PATH when the plugin is enabled
# omo-agent is available immediately after install

# Run the setup script directly to generate capabilities manifest
~/.claude/plugins/cache/x-skills-marketplace/x-skills/*/bin/setup

# Or with --check for read-only detection
~/.claude/plugins/cache/x-skills-marketplace/x-skills/*/bin/setup --check
```

## Plugin Structure

```
x-skills/
├── .claude-plugin/
│   ├── plugin.json           # Plugin manifest
│   └── marketplace.json      # Marketplace registration
├── bin/
│   ├── omo-agent             # OpenCode multi-model wrapper
│   ├── setup                 # Setup script (binding + detection)
│   └── find-plugin-dir       # Plugin path resolver
├── commands/
│   └── setup.md              # /x-skills:setup command
├── lib/
│   └── feature-gate.md       # Fallback routing reference
├── skills/
│   ├── x-do/                 # Execution router
│   ├── x-research/           # Research router
│   ├── x-review/             # Review orchestrator
│   ├── x-bugfix/             # Debugging workflow
│   ├── x-design/             # Design system integration
│   ├── x-api-pentest/        # API security testing
│   ├── x-omo/                # OpenCode bridge
│   └── x-shared/             # Shared references
├── CLAUDE.md                 # Plugin instructions
└── package.json
```

## Development

Test locally without installing:

```bash
claude --plugin-dir ./x-skills
```

Run setup in check mode (no modifications):

```bash
./bin/setup --check
```

## License

MIT
