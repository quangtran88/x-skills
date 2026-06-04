# QA_MEMORY.md Schema

`.x-skills/x-qa/QA_MEMORY.md` is **git-tracked** narrative team memory — the
human-readable "how to QA this project" doc. It complements `profile.json`
(machine config) and the KB (proven cases); it never duplicates profile fields.

The LLM authors it during `init` from interview answers and pipes it to
`init.sh --memory-md`. `run` reads it as planner + runner ground-truth context.

## Required sections

```markdown
# QA Memory — <project>

## Overview
<one paragraph: what the system is, the main user journeys QA cares about>

## Channels
### <channel-name> (driver: <http|browser|computer-use>, audience: <admin|user|external|system>)
- Reach: <base_url, or app + target conversation>
- Env/config: <which .env files + which vars are load-bearing for THIS channel>
- Credentials: <LOCATION ONLY — env var name / vault path / "ask #team". NEVER the secret.>
- Session: <for stateful drivers: how the logged-in session is bootstrapped>
- Notes: <gotchas, rate limits, test-account caveats>

## Test Setup
<how to get the system into a testable state: seed data, migrations, services>

## Monitoring & Observability
<where logs/metrics/traces live; how to watch a request end-to-end during a test>

## Environment & Database
<env files, DB connection, how to seed/reset/inspect the DB>

## Known Gotchas
<flaky areas, ordering constraints, anything a returning QA should know>
```

## Hard rule — credentials

`QA_MEMORY.md` is committed. It records **where** credentials live, never the
secret value — identical to the `profile.json` `auth.token_source` rule
(`env:`/`file:` only). A reviewer seeing a literal token in this file MUST
treat it as a leaked secret to rotate. See `~/.claude/rules/security.md`.
