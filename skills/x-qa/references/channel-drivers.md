# Channel Drivers

A channel's `driver` decides how `run` reaches it.
Onboarding **captures every channel** regardless of driver; execution is
**feature-gated** — a driver runs
only when its required capability is present, otherwise the channel is captured
and skipped with a notice (same pattern as the `type != http` limit in gotcha #12).

| Driver | Reaches | Runner | Capability gate | Status (this plan) |
|---|---|---|---|---|
| `http` | API channels (admin/user/webhook) | `curl` (existing simple/complex runners) | always available | **executes** |
| `browser` | web dashboards / UIs | Playwright MCP (DOM/a11y, deterministic, CI-friendly) | `mcp.playwright` | capture-only (Plan 2) |
| `computer-use` | chat apps (Telegram/WhatsApp), native GUIs | web client → Claude-for-Chrome; desktop app → OS computer-use MCP | a computer-use / Chrome-control MCP | capture-only (Plan 3/4) |

## Why Playwright for dashboards, computer-use for chat

Dashboards run in x-qa's **controlled launch environment** — Playwright MCP's
determinism, headless/CI execution, and low token cost win there. Chat apps
require a **real logged-in session** with no clean DOM/API, so they need the
agentic/vision path (Claude-for-Chrome for web clients, OS computer-use for
desktop apps). See `docs/superpowers/plans/` roadmap for the driver build order.

## Security — agentic drivers

`browser`/`computer-use` drivers operate a real logged-in session with a large
prompt-injection blast radius. They MUST run against a **dedicated test
account**, never a personal one. `QA_MEMORY.md` records the session *location*,
never the secret (`~/.claude/rules/security.md`).

## Feature-gate at run time

`run` resolves the target channel, reads its `driver`, and checks the gate:
- gate satisfied → dispatch the driver's runner;
- gate unsatisfied → emit `CHANNEL_SKIPPED=<name> reason=driver '<driver>' not executable (capability <cap> absent)` and continue.
