# QA Memory — my-app

## Overview
my-app is a SaaS platform with a REST admin API and a Telegram bot for end-user
notifications. Core QA journeys: admin CRUD operations via the admin API, and
bot command flows (subscribe, status, unsubscribe) via the Telegram channel.

## Channels

### admin-api (driver: http, audience: admin)
- Reach: `http://localhost:4000` (local); `https://api.my-app.example.com` (staging)
- Env/config: `.env` + `.env.local` — load-bearing vars: `DATABASE_URL`, `JWT_SECRET_NAME` (location only), `PORT`
- Credentials: `env:ADMIN_TOKEN` — bearer token; value stored in team 1Password vault under "my-app admin QA token". NEVER paste the value here.
- Session: stateless JWT; obtain via `POST /auth/login` with test-account creds (location: `env:ADMIN_EMAIL` / `env:ADMIN_PASSWORD`).
- Notes: rate-limit is 100 req/min per IP; use `X-Test-Request: true` header to exempt test traffic. Pagination default page size = 20.

### telegram-bot (driver: computer-use, audience: external)
- Reach: Telegram app (web: https://web.telegram.org); target conversation: `@my_app_test_bot`
- Env/config: `.env` — `TELEGRAM_BOT_TOKEN` (location only), `WEBHOOK_SECRET` (location only)
- Credentials: bot token location: `env:TELEGRAM_BOT_TOKEN` — stored in 1Password "my-app bot QA token". NEVER paste here.
- Session: QR-code bootstrap required once per test machine; scan with the dedicated QA Telegram account (ask #qa-team for access). Session persists in browser localStorage.
- Notes: bot enforces a 1 msg/sec send limit. Use a dedicated test account, never a personal one. Webhook must be running for push-style commands; polling mode available via `TELEGRAM_POLLING=true`.

## Test Setup
1. Copy `.env.example` to `.env` and fill required vars (see Credentials above).
2. Run `docker compose up -d db` to start Postgres.
3. Run `npm run db:migrate` to apply migrations.
4. Run `npm run db:seed` to load fixture data (creates admin user + 3 test tenants).
5. Start the service: `npm run dev` (port 4000).

## Monitoring & Observability
- Application logs: `docker compose logs -f app` or `npm run dev` stdout.
- Structured JSON logs at `DEBUG` level when `LOG_LEVEL=debug`.
- Request trace: each response includes `X-Request-Id`; grep logs by that ID.
- Metrics (staging): Grafana at `https://grafana.my-app.example.com` — dashboard "API Overview".

## Environment & Database
- Env files: `.env` (committed skeleton), `.env.local` (gitignored, real secrets).
- DB: Postgres 15 on `localhost:5432`, db name `myapp_dev` (local) / `myapp_test` (CI).
- Seed/reset: `npm run db:seed:reset` truncates all tables then re-seeds.
- Inspect: `psql $DATABASE_URL` or `npm run db:studio` (Prisma Studio on port 5555).

## Known Gotchas
- The `POST /orders` endpoint is eventually-consistent; allow up to 200 ms after creation before querying status.
- Telegram webhook delivery can lag 2–5 s in local ngrok tunnels; adjust test timeouts accordingly.
- Admin token expires after 8 h; re-login if tests start returning 401 mid-session.
- `db:seed` is NOT idempotent — always run `db:seed:reset`, never plain `db:seed` twice.
