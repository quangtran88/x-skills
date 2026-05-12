#!/usr/bin/env python3
"""singleton-patterns.py — Pattern catalog for stateful singleton detection.

Three tiers:
  TIER_COMPOSE   — token env vars + image substrings that mark a compose service
                   as a singleton (e.g., SLACK_BOT_TOKEN in a service's environment).
  TIER_ENV_FLAG  — token env-var name patterns + source-code library signatures
                   that mark a feature flag the user should toggle in worktrees.
  TIER_HOST      — repo-tracked host artifacts (crontabs, systemd unit files)
                   that share OS-level state and cannot be per-worktree disabled.

Each entry: id, regex (compiled), rationale, suggested_env_var (env-flag only).
"""

from __future__ import annotations
import re
from typing import NamedTuple


class Pattern(NamedTuple):
    id: str
    rationale: str
    matchers: tuple[str, ...]
    suggested_env_var: str = ""
    severity: str = "warning"     # "blocker" | "warning" | "info"


TIER_COMPOSE: tuple[Pattern, ...] = (
    Pattern(
        id="slack-listener",
        rationale="Slack Socket Mode / RTM listener — duplicate connections receive events twice.",
        matchers=("SLACK_BOT_TOKEN", "SLACK_APP_TOKEN", "SLACK_SIGNING_SECRET"),
        suggested_env_var="SLACK_LISTENER_ENABLED",
    ),
    Pattern(
        id="discord-bot",
        rationale="Discord gateway connection — duplicate bots double-respond.",
        matchers=("DISCORD_BOT_TOKEN", "DISCORD_TOKEN"),
        suggested_env_var="DISCORD_BOT_ENABLED",
    ),
    Pattern(
        id="telegram-bot",
        rationale="Telegram long-poll / webhook — duplicate listeners cause 409 conflicts.",
        matchers=("TELEGRAM_BOT_TOKEN", "TELEGRAM_TOKEN"),
        suggested_env_var="TELEGRAM_BOT_ENABLED",
    ),
    Pattern(
        id="stripe-webhook",
        rationale="Stripe webhook receiver — duplicate listeners double-process events.",
        matchers=("STRIPE_WEBHOOK_SECRET",),
        suggested_env_var="STRIPE_WEBHOOK_ENABLED",
    ),
    Pattern(
        id="github-app-webhook",
        rationale="GitHub App webhook — duplicate listeners double-process events.",
        matchers=("GITHUB_APP_PRIVATE_KEY", "GITHUB_WEBHOOK_SECRET"),
        suggested_env_var="GITHUB_WEBHOOK_ENABLED",
    ),
    Pattern(
        id="ngrok-tunnel",
        rationale="Public tunnel — fixed public URL only one worktree may own at a time.",
        matchers=("ngrok/ngrok", "NGROK_AUTHTOKEN", "localtunnel"),
        suggested_env_var="NGROK_ENABLED",
    ),
    Pattern(
        id="watchtower",
        rationale="watchtower auto-updater — singleton by design.",
        matchers=("containrrr/watchtower",),
        suggested_env_var="WATCHTOWER_ENABLED",
    ),
)


TIER_ENV_FLAG: tuple[Pattern, ...] = (
    Pattern(
        id="node-cron",
        rationale="node-cron scheduler — duplicate workers will fire jobs twice.",
        matchers=(r"\bcron\.schedule\b", r"from\s+['\"]node-cron['\"]", r"require\(['\"]node-cron['\"]\)"),
        suggested_env_var="RUN_SCHEDULER",
    ),
    Pattern(
        id="bullmq-worker",
        rationale="BullMQ worker — duplicate workers cause double-execution.",
        matchers=(r"new\s+Worker\(", r"from\s+['\"]bullmq['\"]"),
        suggested_env_var="RUN_BULLMQ_WORKER",
    ),
    Pattern(
        id="celery-beat",
        rationale="Celery beat scheduler — singleton by design.",
        matchers=(r"celery\s+beat", r"CELERY_BEAT_SCHEDULER"),
        suggested_env_var="RUN_CELERY_BEAT",
    ),
    Pattern(
        id="slack-bolt",
        rationale="Slack Bolt app — duplicate listeners receive events twice.",
        matchers=(r"from\s+slack_bolt", r"from\s+['\"]@slack/bolt['\"]", r"SocketModeClient", r"RTMClient"),
        suggested_env_var="SLACK_LISTENER_ENABLED",
    ),
    Pattern(
        id="discord-client",
        rationale="Discord client — duplicate connections double-respond.",
        matchers=(r"discord\.Client\(", r"new\s+Discord\.Client"),
        suggested_env_var="DISCORD_BOT_ENABLED",
    ),
    Pattern(
        id="telegraf",
        rationale="Telegraf (Telegram) — duplicate long-poll causes 409.",
        matchers=(r"new\s+Telegraf\(", r"from\s+['\"]telegraf['\"]"),
        suggested_env_var="TELEGRAM_BOT_ENABLED",
    ),
    Pattern(
        id="agenda",
        rationale="Agenda scheduler — duplicate workers double-execute.",
        matchers=(r"new\s+Agenda\(", r"from\s+['\"]agenda['\"]"),
        suggested_env_var="RUN_SCHEDULER",
    ),
    Pattern(
        id="chokidar-shared-watch",
        rationale="chokidar watch on shared host path — duplicate watchers fire twice.",
        matchers=(r"chokidar\.watch\(", r"from\s+['\"]chokidar['\"]"),
        suggested_env_var="RUN_FILE_WATCHER",
    ),
    Pattern(
        id="procfile-worker",
        rationale="Procfile worker line — foreman/honcho run these as singletons; gate with an env flag.",
        matchers=(r"^worker:", r"^scheduler:"),
        suggested_env_var="RUN_PROCFILE_WORKER",
    ),
)


# TIER_HOST entries all default to severity=blocker — host state cannot be auto-disabled
# per worktree, so apply.sh hard-blocks until `ack-host-singletons` is invoked. Procfile
# was considered for this tier but reclassified to env-flag in TIER_ENV_FLAG above (its
# natural disable is `RUN_PROCFILE_WORKER=false`, not a host-level toggle).
TIER_HOST: tuple[Pattern, ...] = (
    Pattern(
        id="host-crontab",
        rationale="Repo-tracked crontab — host-shared state, cannot be auto-disabled per worktree.",
        matchers=("*.crontab", "crontab"),
        severity="blocker",
    ),
    Pattern(
        id="systemd-service",
        rationale="systemd unit file — host-shared state, cannot be auto-disabled per worktree.",
        matchers=("*.service", "*.timer"),
        severity="blocker",
    ),
)


def env_flag_regexes() -> list[tuple[Pattern, re.Pattern[str]]]:
    """Compile env-flag matchers into a single alternation regex per pattern.

    MULTILINE matters for procfile-worker (`^worker:`, `^scheduler:`) — real
    Procfiles have those entries on line 2+, and without MULTILINE the `^`
    only matches the start of the file.
    """
    out = []
    for p in TIER_ENV_FLAG:
        joined = "|".join(f"(?:{m})" for m in p.matchers)
        out.append((p, re.compile(joined, re.MULTILINE)))
    return out
