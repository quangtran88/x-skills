# Stateful / Stateless Channel Isolation across x-qa + x-worktree-isolate

**Date:** 2026-06-06
**Status:** Design approved — pending implementation plan
**Skills touched:** `x-qa`, `x-worktree-isolate`
**Related prior art:** `2026-05-11-x-worktree-isolate-singletons.md`, `2026-06-02-x-qa-real-qa-overhaul.md`

## Problem

A project exposes multiple channels / endpoints. Some are **stateless** (HTTP APIs — each
worktree can bind a different port, no conflict) and some are **stateful** singletons
(Slack / Telegram / WhatsApp bots — a platform tolerates only one live listener at a time;
two worktrees both connected cause duplicate event delivery, 409 long-poll conflicts, etc.).

We want both skills to be **deeply aware** of this split:

1. Each worktree should **prioritize testing stateless channels** (API on isolated ports) so
   parallel worktrees never conflict.
2. Stateful channels must be **mutually exclusive per platform** — only one worktree may own
   Slack/Telegram/WhatsApp at a time.
3. Each channel links to the **env var(s) that enable it**; the default worktree keeps stateful
   channels **off** (their env disabled).
4. Stateless channels are the **default QA target**, each on its own port.

## What already exists (do not rebuild)

- **`x-worktree-isolate` v0.2** already detects stateful singletons in 3 tiers
  (compose-service / env-flag / host) and **default-disables them per worktree**
  (`profiles: [xwi-disabled]` for compose, `<VAR>=false` for env-flag). → **Requirement #3/#4
  (stateful off by default) is already met.**
- **Port isolation for stateless channels already works end-to-end**: `apply` writes
  `state.local.json.allocated_ports`; x-qa's `service-launch.md` substitutes
  `${ISOLATE_PORT_<NAME>}` from it. → **Requirement #1/#4 (stateless on isolated ports) is
  mostly *selection logic*, not new plumbing.**
- **`x-qa`** already has a `channels[]` model with `driver` (http/browser/computer-use),
  `audience`, and per-driver feature-gating.

## The three real gaps

1. **`singleton_owners` is declarative, not enforced.** `allocate-ports.sh`'s
   `xwi_set_singleton_owners` reassigns `owners[id]=wpath` with **no conflict check** (comment at
   `allocate-ports.sh:292`: "Not a runtime lock"). Two worktrees can both "own" Slack. → **This is
   the core gap for requirement #2.**
2. **x-qa channels carry no stateful/stateless classification** and no link to the gating
   singleton or its enabling env var.
3. **WhatsApp is absent from the singleton catalog** (Slack/Telegram/Discord present; WhatsApp
   was named explicitly by the user).

## Decisions locked during brainstorming

| # | Decision | Choice |
|---|---|---|
| D1 | Source of truth for statefulness | **Single source in x-worktree-isolate**; x-qa references it via one link field (Approach A). No duplicated model → no drift. |
| D2 | x-qa scope this iteration | **Skip + prioritize, with one carve-out (R1).** Default to stateless. Stateful channels are *skipped* (never failed) with a precise reason — **except** an **http** stateful channel that *this worktree owns*, which is **driven via the existing http path** (no new driver). Stateful channels on **chat** drivers (browser/computer-use) stay deferred (capture-only today). |
| D3 | Cross-worktree lock recovery | **Liveness auto-steal + `--force`.** Refuse a live owner; auto-reclaim a dead one; `--force`/`--steal` overrides a live owner explicitly. Liveness signal sharpened by R3 (below). |
| D4 | Pre-existing conflict on upgrade | **Refuse-until-resolved** (safe), matching the host-singleton "detect + block until acknowledged" philosophy. Not auto-demote. |
| R1 | http stateful when owned | Carve http stateful channels out of the D2 deferral — drive them via the existing http path when this worktree owns the singleton. Only **chat-driver** stateful driving stays deferred. |
| R2 | x-qa ↔ isolate coupling | x-qa derives ownership from its **own** `feature-overrides.local.json` ("enabled here" ⇒ "owned here"); it never reads isolate's global registry. |
| R3 | compose-tier liveness | A compose-tier lock is also **dead** when the owner's `COMPOSE_PROJECT_NAME` has zero running containers, not only when its worktree path is gone. |

## Architecture — the shared contract (the seam)

One link key ties the two skills: **`x-qa channels[].singleton_id` → `x-worktree-isolate
singletons[].id`**.

x-qa reads **two worktree-local** isolate artifacts (it already reads the first) — and **never** the
global registry (R2):

| Artifact | Owner | x-qa uses it for | Status |
|---|---|---|---|
| `state.local.json` → `allocated_ports` | isolate `apply` | stateless channel ports (`${ISOLATE_PORT_*}`) | **already wired** |
| `feature-overrides.local.json` → `overrides[]` | isolate `enable`/`disable` | "is this channel's singleton `enabled` (⇒ owned) *here*?" | **new read** |

- **Statefulness is derived, never re-declared:** `singleton_id` set = stateful; `null` = stateless.
- **Ownership is local (R2):** under the new enforcement a singleton can only reach `enabled` in this
  worktree's `feature-overrides.local.json` by *winning the claim*. So **"enabled here" ⇒ "owned
  here"**, guaranteed at claim time. x-qa never reads isolate's global `singleton_owners` registry — it
  trusts its own worktree-local file, keeping the two skills decoupled (Approach A's whole point).
- **The enabling env var is never copied** into the x-qa profile — it is looked up through the
  singleton (`channel → singleton_id → singletons[].suggested_env_var`) so the two profiles
  cannot drift.

## Component 1 — x-worktree-isolate: enforce the lock

The heart of "only one worktree per platform at a time."

- **`xwi_set_singleton_owners` → `xwi_claim_singleton`** (in `allocate-ports.sh`): before assigning
  `owners[id]`, check the current owner.
  - unowned / owned-by-self → claim.
  - owned by another → **liveness check** (dead → auto-steal: claim + emit
    `SINGLETON_LOCK_STOLEN=<id> from=<branch>`; live → **refuse** with
    `SINGLETON_CONFLICT=<id> owner=<branch>@<path>` unless `--force`). A lock is **dead** when:
    - the owner's `worktree_path` is gone from disk OR no longer holds a registry slot (**all tiers**); **or**
    - **(R3 — compose-tier only)** the owner's `COMPOSE_PROJECT_NAME` has **zero running containers**
      (query via `docker compose ls` / `docker ps --filter label=com.docker.compose.project=<name>`).
      For env-flag / host tiers, path-existence is the only honest signal — `--force` remains the escape
      hatch for a stopped-but-present owner.
- **Wire enforcement into both turn-on entry points:** `enable <id>` and `apply` (when a singleton
  resolves to `enabled` via overrides). Both gain `--force` / `--steal`.
- **Atomicity:** all claim/check logic runs **inside the existing registry lock** `apply` already
  acquires.
- **Registry entry enrichment:** `singleton_owners` becomes
  `{id: {worktree_path, branch, claimed_at}}` (was flat `{id: path}`) to support liveness +
  diagnostics. (Local state — migrated lazily, see Component 4.)
- **WhatsApp catalog additions** (`singleton-patterns.py`):
  - Tier 1 (compose env / image): `WHATSAPP_*` tokens (e.g. `WHATSAPP_TOKEN`,
    `WHATSAPP_SESSION`), Baileys / whatsapp-web.js service signals.
  - Tier 2 (source signatures): `@whiskeysockets/baileys`, `whatsapp-web.js`,
    `makeWASocket(`, `new Client(` from `whatsapp-web.js`.
  - Rationale: a WhatsApp Web session is single-device; two listeners fight over the session.
- **`list` / `features` / `doctor`:** show an `owner` column; `doctor` flags dead locks and offers
  to clear them.

### Honest guarantee statement (must be in skill docs, must not overclaim)

The registry makes the **claim** exclusive. **Runtime** exclusivity is only as strong as the tier:
- **compose-tier** `profiles:[xwi-disabled]` — a real gate.
- **env-flag tier** — advisory; the app must read the flag (the skill cannot enforce).
- **host-tier** — manual ack only.

The lock prevents two worktrees from both *believing* they own Slack; it cannot reach into app code.

## Component 2 — x-qa: stateless-first, stateful-aware selection

- **Schema:** add `singleton_id` (string | null) to the channel. Set during `init` by
  cross-referencing the isolate profile's `singletons[]` when present (interview offers the
  mapping; default null = stateless).
- **Default selection (Phase 4):** with no `--channel`, default to **stateless channels**
  (`singleton_id == null`) on the primary entry point. This realizes "stateless is the default for
  QA" — mostly selection logic since ports already isolate.
- **Ownership signal (R2):** "owned here" = this channel's `singleton_id` is `enabled` in the
  worktree's `feature-overrides.local.json`. No registry read.
- **Stateful channel resolution:**
  - owned here **and driver == http** → **EXECUTE** via the existing http drive path (R1). This is the
    payoff of owning the lock — e.g. driving a Stripe/GitHub webhook receiver this worktree holds. No
    new driver needed; it reuses the simple/complex http runners.
  - owned here **and driver ∈ {browser, computer-use}** →
    `CHANNEL_SKIPPED reason=stateful-owned-chat-driver-deferred` (needs the capture-only chat drivers —
    deferred).
  - **not** owned here (singleton `disabled`, the default) → `CHANNEL_SKIPPED reason=stateful-not-owned`.
  - isolate not set up at all → `CHANNEL_SKIPPED reason=stateful-unverifiable` (conservative — never
    test a stateful channel blind).
- **doctor:** validate `singleton_id` resolves against the isolate profile when present (warning on
  a dangling reference, never a hard fail — isolate is optional).

## Component 3 — Graceful degradation (isolate absent)

x-qa must stay useful Claude-only / without isolate:

| isolate present? | stateless channels | stateful channels (`singleton_id` set) |
|---|---|---|
| yes | tested, port-isolated | skip with precise reason (owned / not-owned) |
| no | tested on fallback ports | **skip** (`stateful-unverifiable`) — never blind-tested |

## Component 4 — Migration for existing worktrees on upgrade

Split into **local self-healing state** (automatic) and **committed profile content** (explicit,
reuses existing patterns). Migration is **metadata-only** — it never touches a *running* stack's
`compose.override.yml` / `.env.worktree`.

### 4a. Registry reconciliation — automatic + lazy

The registry is machine-local (not committed) → self-upgrades on the next
`apply`/`enable`/`list`/`doctor` under the new version:
- Detect old-shape registry (flat `singleton_owners: {id: path}`, no `registry_schema` marker) →
  enrich to `{id: {worktree_path, branch, claimed_at}}`.
- **Rebuild owners from ground truth:** for each live worktree slot, read its
  `feature-overrides.local.json` and reconstruct what is actually enabled. Self-heals stale owners
  from dead worktrees **and** the old declarative-overwrite behavior. Idempotent — converges on
  re-run.

### 4b. Pre-existing conflict handling (D4 = refuse-until-resolved)

The old logic never enforced exclusivity, so two live worktrees may **already** both have the same
singleton enabled — illegal under the new model. Auto-picking a winner is unsafe. Surface loudly:
```
SINGLETON_CONFLICT_PREEXISTING=slack-listener owners=feat/a@/p/a, feat/b@/p/b
```
and **refuse to claim that singleton** until the user runs `disable <id>` in the loser worktree.
Nothing else is blocked.

### 4c. Committed-profile migration — explicit, reuses existing flows

- **x-worktree-isolate:** `singletons[]` is additive (new WhatsApp patterns) and the registry
  self-heals → **no profile schema bump.** `init --rescan` (existing v0.1→v0.2 path) picks up
  WhatsApp; bump `version` 0.2.0 → 0.3.0 with a migration banner in SKILL.md. *Softer* than the v0.2
  hard-reject because nothing here is load-bearing-incompatible.
- **x-qa:** `singleton_id` is optional (null = stateless = today's behavior) → existing profiles keep
  working untouched. `x-qa update` populates it by cross-referencing the isolate profile; `doctor`
  emits an **info-level nudge** ("channels present, none carry `singleton_id` — run `x-qa update`
  for stateful-aware selection"), never a hard fail. Bump profile `version` (schema stays 1).

### 4d. One convenience entry point

A thin `x-worktree-isolate migrate` that runs: registry heal → conflict report → rescan prompt →
points x-qa users at `x-qa update`. The heal stays automatic regardless, so users who never run
`migrate` still get safe behavior — `migrate` is just the single "what do I need to do to upgrade"
view.

### Why soft, not a hard gate

The v0.2 migration hard-rejected schema:1 because `singletons[]` was load-bearing for everything
after it. Here every new field is additive and self-healing, so a hard gate would be unjustified
friction. Hard rejection stays reserved for genuine incompatibility.

## Observability (envelope additions)

- **x-qa run envelope:** `CHANNELS_TESTED=<csv>`, `CHANNELS_SKIPPED=<name:reason,...>`.
- **x-worktree-isolate:** `SINGLETON_CONFLICT=<id> owner=<branch>@<path>` (refusal),
  `SINGLETON_LOCK_STOLEN=<id> from=<branch>` (auto-steal),
  `SINGLETON_CONFLICT_PREEXISTING=<id> owners=...` (migration), plus the `owner` column in `list`.

## Testing

- **x-worktree-isolate:** claim → second-worktree refuse → `--force` steal → dead-lock auto-steal
  (path-gone) → **compose-tier stopped-stack owner auto-stolen (R3)** → release clears owner; WhatsApp
  pattern detection unit test; registry lazy-migration (old flat shape → enriched) idempotency;
  pre-existing-conflict refuse-until-resolved.
- **x-qa:** doctor validation of `singleton_id` (resolves / dangling-warning); default selection picks
  stateless; **owned http stateful channel is driven (R1)**; the skip-reason branches
  (owned-chat-deferred / not-owned / unverifiable); ownership derived from `feature-overrides.local.json`
  only — no registry read (R2); degradation when isolate absent.

## Out of scope (this iteration)

- **Driving stateful channels on *chat* drivers** (browser / computer-use stay capture-only). Note:
  **http** stateful channels owned by the worktree **are** driven now (R1) — only chat-driver stateful
  driving is deferred.
- Auto-demote conflict resolution (D4 chose refuse-until-resolved).
- Non-compose stacks for isolate (k8s/Tilt/pm2 — still out per v0.2).

## Net effect for the user

Spin up N worktrees → each gets isolated ports and tests the API channel in parallel with zero
conflict; every worktree has Slack/Telegram/WhatsApp **off by default**; exactly one worktree can
`enable slack` and the rest are refused (isolate) or skip (x-qa) with a clear owner pointer; the
worktree that *does* own a platform additionally **drives its http stateful channel** (e.g. a webhook
receiver) via the existing http path (R1); a crashed *or stopped* worktree's lock auto-recovers (R3);
upgrading existing worktrees is a metadata-only, self-healing step that never breaks a running stack.
