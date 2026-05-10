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

## Free-form additions

After processing all detected entries:

> **Did we miss any entry point?** List them now (name + type + launch command).

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
