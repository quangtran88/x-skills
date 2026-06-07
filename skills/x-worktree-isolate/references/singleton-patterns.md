# singleton-patterns.md — v0.2 singleton catalog & detection rationale

The singleton-aware layer detects stateful features that must not run concurrently across parallel worktrees (Slack bot listeners, schedulers, webhook receivers, host crontabs). Three tiers, each with a disable mechanism that fits its level.

## Pattern catalog

Source: `scripts/singleton-patterns.py`. Each entry binds:
- `id` — stable pattern key (used in `singletons[].id` and CLI `enable`/`disable`)
- `rationale` — why parallel execution is harmful
- `matchers` — strings or regexes scanned per tier
- `suggested_env_var` — env-flag tier writes `<VAR>=false` to `.env.worktree`
- `severity` — `blocker` | `warning` | `info`

### Tier 1 — `TIER_COMPOSE` (compose service env vars + image)

Detection scans `services.*.environment` keys + `services.*.image` strings.

| id | matchers | rationale |
|---|---|---|
| `slack-listener` | `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`, `SLACK_SIGNING_SECRET` | Socket Mode / RTM duplicate connections receive events twice |
| `discord-bot` | `DISCORD_BOT_TOKEN`, `DISCORD_TOKEN` | Discord gateway duplicate bots double-respond |
| `telegram-bot` | `TELEGRAM_BOT_TOKEN`, `TELEGRAM_TOKEN` | Telegram long-poll/webhook duplicate listeners cause 409 conflicts |
| `stripe-webhook` | `STRIPE_WEBHOOK_SECRET` | Duplicate listeners double-process events |
| `github-app-webhook` | `GITHUB_APP_PRIVATE_KEY`, `GITHUB_WEBHOOK_SECRET` | Same — duplicate listeners |
| `ngrok-tunnel` | `ngrok/ngrok`, `NGROK_AUTHTOKEN`, `localtunnel` | Fixed public URL only one worktree may own |
| `watchtower` | `containrrr/watchtower` | watchtower is singleton by design |
| `whatsapp` | `WHATSAPP_TOKEN`, `WHATSAPP_SESSION`, `WHATSAPP_` | WhatsApp Web session is single-device; two listeners fight over the session |

Disable: emits `services.<svc>.profiles: [xwi-disabled]` in `compose.override.yml` (default — `disable_method=profile-gate`). The sentinel name is namespaced so an unrelated `COMPOSE_PROFILES` setting can't accidentally re-enable disabled services; never include `xwi-disabled` in `COMPOSE_PROFILES`. The alternative `disable_method=replicas-zero` (emits `deploy.replicas: 0`) is honored by Docker Swarm but is a no-op on standalone Compose v2 — use it only if you're running Swarm.

### Tier 2 — `TIER_ENV_FLAG` (source-code library signatures)

Detection greps files matching `SOURCE_EXTS` (`.ts/.tsx/.js/.jsx/.mjs/.cjs/.py/.rb/.go/.rs/.java/.kt/.env*`) with the per-pattern regex.

| id | matchers (regex) | rationale |
|---|---|---|
| `node-cron` | `\bcron\.schedule\b`, `from\|require ['"]node-cron['"]` | Duplicate schedulers fire jobs twice |
| `bullmq-worker` | `new Worker(`, `from ['"]bullmq['"]` | Duplicate workers cause double-execution |
| `celery-beat` | `celery beat`, `CELERY_BEAT_SCHEDULER` | Beat is singleton by design |
| `slack-bolt` | `from slack_bolt`, `from ['"]@slack/bolt['"]`, `SocketModeClient`, `RTMClient` | Duplicate listeners receive events twice |
| `discord-client` | `discord.Client(`, `new Discord.Client` | Duplicate gateway connections |
| `telegraf` | `new Telegraf(`, `from ['"]telegraf['"]` | Telegram long-poll dual-listener |
| `agenda` | `new Agenda(`, `from ['"]agenda['"]` | Duplicate workers |
| `chokidar-shared-watch` | `chokidar.watch(`, `from ['"]chokidar['"]` | Duplicate watchers fire twice |
| `procfile-worker` | `^worker:`, `^scheduler:` (in Procfile) | foreman/honcho run these as singletons |
| `whatsapp-web` | `@whiskeysockets/baileys`, `whatsapp-web\.js`, `makeWASocket(`, `new Client(` | Baileys / whatsapp-web.js single-device session; duplicate listeners fight over it |

Disable: writes `<env_var>=false` to `.env.worktree`. App code must read the flag and short-circuit the listener/worker. The skill cannot enforce this — it's a contract between the env-flag and your code.

### Tier 3 — `TIER_HOST` (repo-tracked host artifacts)

Detection: fnmatch over repo-relative paths.

| id | matchers (glob) | severity |
|---|---|---|
| `host-crontab` | `*.crontab`, `crontab` | `blocker` |
| `systemd-service` | `*.service`, `*.timer` | `blocker` |

**Disable: NONE.** Host state is shared across the whole machine. The skill cannot per-worktree disable a host crontab. Tier 3 is **detect + warn + block apply** until the user runs `x-worktree-isolate ack-host-singletons`. The ack writes `{"id": ..., "state": "acknowledged"}` to `<worktree>/.worktree-isolate/feature-overrides.local.json` — explicit acknowledgement that the user will manually disable the host state before running the second worktree's stack.

## Why no auto-disable for host state

Host crontabs, systemd units, and file watchers run on the host's clock — not inside any worktree. There is no per-worktree toggle the skill can flip without modifying the host's running daemon configuration, which is far outside this skill's scope (and would require root). The honest answer is to detect and refuse to proceed until the user confirms they've handled it manually. Acknowledgement is **per-worktree** — each new worktree must re-ack so the user doesn't accidentally bring up a second stack assuming an old ack still applies.

## ID contract

`id` is the stable pattern key (e.g. `slack-listener`, not `slack-listener:slack-listener`). If the same pattern matches multiple compose services, the `singletons[]` array contains multiple entries with the same `id` but different `compose_service` — and CLI `enable <id>` / `disable <id>` toggles all matching entries together. This trade-off keeps the CLI surface small and is correct in practice (you rarely want one Slack listener disabled and another enabled in the same worktree).

## Evidence format

Each `singletons[].evidence` is a list of `<file>:<line>: <match>` strings for env-flag/host tiers, or `<file>:services.<svc>.environment.<KEY>` / `<file>:services.<svc>.image=<value>` for compose-service tier. Enough for the user to verify the match without re-running detection.

## Severity assignment

- Tier 1/2: default `warning`. They get auto-disabled in worktrees (replicas:0 or env-flag), so the user doesn't need an explicit acknowledgement.
- Tier 3: hard-coded `blocker`. The skill cannot disable host state, so the user must explicitly ack before apply will proceed.

## Interaction with `services_to_strip`

A compose service can appear in both `services_to_strip[]` (because it has hardcoded `container_name` or `ports`) AND `singletons[]` (because its environment matches a Tier 1 pattern). `apply.sh` merges both contributions into ONE `services.<svc>:` block in `compose.override.yml` — never two duplicate keys. This is verified by `tests/integration/test_20_singleton_dedup_with_services_to_strip.sh`.
