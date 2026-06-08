# init Interview Templates

The LLM driving `x-qa init` walks the user through scan findings using these prompts. The shell script (`init.sh`) only handles persistence — interaction lives in the LLM turn.

## Per-finding prompt (HTTP example)

For each scanner-detected entry point, ask:

> **Detected HTTP service: `<name>`** (source: `<source>`, confidence: `<high|medium|low>`)
>
> Suggested launch command: `<command>` — correct?
>
> Options:
> 1. Use as-is
> 2. Edit the command
> 3. Skip this entry point

If accepted, follow up with:

> **Base URL template?** Suggested: `<template>`. Edit or accept?

> **Health check?** Suggested: `<method> <path>` expecting `<status>`. Edit / replace / none?

> **Auth required for tests?** `[none / bearer / cookie / api-key / oauth-flow]`
>
> If not none: token source `[env:<NAME> / file:<path>]` — never literal.

> **Use this entry point as primary target for `run` (default `--service`)?** `[Y/N]`

## Per-worktree isolation (docker-compose entries only)

Ask only when `launch.kind == "docker-compose"`:

> **Do parallel runs of this service share state (database, ports, container names)?**
>
> If yes (the default for any docker-compose stack with hardcoded `container_name` or fixed host ports), this entry needs `x-worktree-isolate` so parallel worktrees (e.g. driven by `/x-skills:x-team`) do not collide.
>
> Set `launch.uses_isolate_profile: true` and rewrite `launch.command` to stack env-files so `compose.override.yml` and `.env.worktree` actually take effect:
>
> Canonical command (when a base `.env` exists):
> ```
> docker compose --env-file .env --env-file .env.worktree up -d <service>
> ```
>
> Canonical command (no base `.env`):
> ```
> docker compose --env-file .env.worktree up -d <service>
> ```
>
> ⚠ `init.sh` will refuse the profile if `uses_isolate_profile: true` is set but the command does not include `--env-file .env.worktree`. Compose v2 does NOT auto-load `.env.worktree` — without the flag, the override is silently inert and parallel worktrees collide on default ports / share the parent-dir-derived `COMPOSE_PROJECT_NAME`.
>
> Also remember to update `base_url_template` to use `${ISOLATE_PORT_<NAME>}` so the probe URL matches the per-worktree allocated port:
> ```
> "base_url_template": "http://localhost:${ISOLATE_PORT_API}",
> "base_url_fallback": "http://localhost:3000"
> ```

## Free-form additions

After processing all detected entries:

> **Did we miss any entry point?** List them now (name + type + launch command).

## Channel Enumeration

After entry points are settled, enumerate **channels** — every way QA reaches
the system. Seed the question with `scan_channels` hints (multiple ports, bot
SDKs, web-UI configs) AND an x-research semantic pass (see "x-research scan"
below):

> **How is this system driven for testing?** I detected: <scan_channels hints>.
> For each surface, confirm: name, driver (`http` / `browser` / `computer-use`),
> audience (`admin` / `user` / `external` / `system`), and how it's reached.

Per channel, then ask:

> **Reach** — base URL (http/browser), or app + target conversation (chat).
> **Credentials** — where do THIS channel's creds live? `env:<NAME>` / `file:<path>` / "ask team". **Never paste the secret** — it goes in a git-tracked file.
> **Env/config** — which `.env` files and which vars are load-bearing here?
> **Session** (browser/computer-use) — how is the logged-in session bootstrapped (QR/2FA, one-time)?

## Stateful channel mapping (isolate-aware)

When `<repo_root>/.worktree-isolate/profile.json` exists, after each channel is
confirmed, offer to link stateful-looking channels (bots, webhook receivers,
schedulers) to an isolate singleton:

> **Is `<channel-name>` a stateful singleton** (one live listener per platform —
> Slack/Telegram/WhatsApp bot, webhook receiver)? If so, which isolate singleton
> gates it? I see: `<singletons[].id list>`.
> - Pick one → sets `channels[].singleton_id` (the channel is then **skipped**
>   unless this worktree owns the singleton; an owned **http** channel is driven).
> - "stateless" → sets `singleton_id: null` (default QA target, port-isolated).

The enabling env var is **not** copied into the profile — it is looked up via the
singleton (`singleton_id → singletons[].suggested_env_var`) so the two profiles
cannot drift. `singleton_id` is optional: existing profiles without it keep working
(absence = stateless).

`x-qa update` runs the **same** mapping over channels that lack a `singleton_id`,
cross-referencing the isolate profile. Channels already carrying `singleton_id`
are left untouched. This is the x-qa half of the spec's §4c committed-profile
migration — additive, never a hard gate.

## Test Setup, Monitoring, Environment, Database

These populate `QA_MEMORY.md` (narrative), not `profile.json`:

> **Test setup** — how do I get the system into a testable state (seed, migrations)?
> **Monitoring** — where are logs/metrics/traces? How do I watch one request end-to-end?
> **Environment** — which env files matter; any required secrets (by location)?
> **Database** — connection, and how to seed / reset / inspect it?

## x-research scan (semantic discovery)

Before the channel question, dispatch a focused x-research pass to enrich the
deterministic `scan_channels` hints with semantic findings (how tests are set
up, where monitoring lives, which env/db setup running requires). Borrow
x-research's dispatch (OMO `explore` + a `agy-agent` reading) —
do NOT invoke the full `/x-research` router (its bootstrap/classification is
redundant here). The bash `scan-helpers.sh` output remains the ground truth for
*entry-point existence* (anti-hallucination, gotcha #4); x-research only adds
the channel/audience/monitoring/env/db semantic layer.

## QA_MEMORY.md authoring

After the interview, author `QA_MEMORY.md` per `references/qa-memory-schema.md`
and persist via `init.sh --memory-md <path>`. In `--non-interactive`, write the
template skeleton with `<!-- TODO: fill -->` markers and `auto_managed: true`.

## Fixtures

> **Test fixture seed command?** (optional, runs once before first case)

> **Per-case DB reset command?** (optional)

> **Reset strategy?** `[per-case / per-category / none]`

## Smoke verification offer

> **Run smoke verification now?** (launches each entry point, hits health, tears down. Slow.)
>
> `[Y/N]`

If `Y`: invoke `launch-entry-point.sh` per entry, capture verdict, set `verified` field.

## Non-interactive mode (`--non-interactive`)

Accept all detected defaults. Set `auto_managed: true` and `verified: false` for every entry. Skip smoke verification. Useful for CI.

## Profile-from-import (`--profile-from <path>`)

Read pre-written profile YAML/JSON, validate against schema, copy to `.x-skills/x-qa/profile.json`. Skip interview.

### Step N: Auth Case Detection

If the scanner found a login/auth endpoint, prompt:

> Detected potential auth endpoint: `POST /api/auth/login`. Should I generate a login case and pin it as the default authentication precondition?
> [Y] Generate `tc-login-bearer-default` and set `auth_case_id`
> [s] Skip — no auth, or auth handled differently
> [c] Use an existing case ID I'll provide

On `[Y]`: emit a stub `kb/cases/tc-login-bearer-default.yaml` with the detected endpoint and a TODO for the credentials source. Set `profile.json.auth_case_id`.
