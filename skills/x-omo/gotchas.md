# x-omo Gotchas

Known failure patterns and compatibility issues for the `omo-agent` wrapper.

## OpenCode 2 — different `run` contract, emulated role agents (2026-10-12)

**Versions:** verified on opencode 2.0.27 (`@opencode/cli`) next to 1.17.16. `omo-agent`
detects the major version per invocation and builds the argv for it.

| | OpenCode 1.x | OpenCode 2.x |
|---|---|---|
| Model mode | `run --pure --agent build --model <id> --dir <cwd>` | `run --standalone --agent build --model <id>` |
| Agent mode | `run --agent <name> --dir <cwd>` | `run --standalone --agent <name> [--model <pinned>]` |
| Model list | `opencode models` | `opencode models --standalone` |

- **`--pure` and `--dir` are hard errors on v2** (`Unrecognized flag`, exit 1). The
  working directory is the process cwd.
- **`--standalone` is deliberate.** By default v2 clients attach to one shared
  background service. Killing the client (our `OMO_TIMEOUT`) then leaves the session
  running server-side — measured: a `sleep` started by the shell tool survived the
  client kill through the service and died with it under `--standalone`.
- **Role agents are emulated.** v2 does not load v1 plugins; its log shows
  `failed to load plugin target=oh-my-openagent@latest … Plugin must export a default
  definition`. So for `oracle`, `explore`, `librarian` and `multimodal-looker`:
  1. `omo-agent` first asks v2 for an agent of that name — a native definition wins.
  2. On `Error: Agent not found: "<name>"` it re-runs on v2's built-in read-only
     `explore` agent with a one-line `[ROLE: …]` hint prepended (verified: `explore`
     reads files and runs `git`, and refuses to create files).
  3. Either way the model is the one `~/.config/opencode/oh-my-openagent.json` pins for
     the role (`model` + `variant` → `provider/model#variant`). No config or no `jq` →
     v2's default model; `Error: Model unavailable` → one re-run on the default model.

  The stand-in answers from v2's generic `explore` prompt, not OMO's role prompt, and
  costs one extra ~3s startup per call for the failed native lookup. `bin/setup` keeps
  `omo_plugin`/`omo_mode_all` pinned on v2 because the roles stay callable. Other names
  (`momus`, `atlas`, …) are passed through and fail with a v2-specific explanation; the
  v1 whitelist, broken-agent gate and momus plan-path workaround are skipped on v2.
- **Re-runs never repeat a billed run.** Every automatic re-run (cold start, missing
  agent, unavailable model) requires the error in the first 2 KB of output and no
  `> agent · model` banner, which v2 prints once the model has started.
- **Cold-start race.** A private server gives plugins about 5s to activate. npm plugin
  packages listed in the config but not cached yet are installed in that window, roughly
  one per attempt, and the CLI dies with `ServiceUnavailableError: Location plugins did
  not finish activating` before the model is called. `omo-agent` retries up to 5 times
  on exactly that error.
- **Side-by-side installs:** `OPENCODE_BIN=opencode2 omo-agent …` (same variable for
  `bin/setup`).

**Re-probe:** `opencode run --help | grep -E -- '--(pure|dir|standalone)'` shows which
contract a binary speaks; `bash bin/tests/omo-agent.test.sh` checks the argv for both.

## Plugin compat bug — 5 parenthesized-display-name agents are unresolvable (2026-04-09)

**Affected:** `hephaestus` `atlas` `prometheus` `metis` `momus`
**Versions:** opencode 1.4.0 + oh-my-opencode 3.15.3 (loaded via opencode.json plugin key `oh-my-openagent`)

**Current behavior (after wrapper fix):** `omo-agent` now fails fast with an
`UNAVAILABLE` error explaining the plugin bug and listing workarounds.

**Historical symptom (before wrapper fix):**

```
[omo-agent] started momus at HH:MM:SS (timeout=480s)
Error: OpenCode does not recognize agent 'momus' → 'Momus (Plan Critic)' (silent fallback detected)
```

**Underlying opencode behavior** (still reproduces via direct call):

```
agent "momus" not found. Falling back to default agent
error: default agent "Sisyphus - Ultraworker" not found
```

The short name `momus` fails, and the display name `"Momus (Plan Critic)"` also fails.

**Root cause:** The plugin's `remapAgentKeysToDisplayNames()` (dist/index.js around
line 140925) renames agent config keys to their parenthesized display names
(e.g. `momus` → `"Momus (Plan Critic)"`) before passing them to opencode via
`params.config.agent`. opencode 1.4.0's `--agent` CLI lookup cannot resolve
agents stored under these parenthesized keys — not by the short name, not by
the display name, and the fallback default (`Sisyphus - Ultraworker`) is also
unknown to opencode, so the process errors out.

The 4 identity-named agents (`oracle`, `explore`, `librarian`, `multimodal-looker`)
work because their display name equals their short name, so `remapAgentKeysToDisplayNames`
leaves the key as the lowercase short name, which opencode can match.

**Verification (empirical):**

| Agent | `opencode run --agent <name>` | Status |
|-------|-------------------------------|--------|
| oracle | agent=oracle mode=all | ✅ |
| explore | ✅ | ✅ |
| librarian | ✅ | ✅ |
| multimodal-looker | ✅ | ✅ |
| hephaestus | "not found" | ❌ |
| atlas | "not found" | ❌ |
| prometheus | "not found" | ❌ |
| metis | "not found" | ❌ |
| momus | "not found" | ❌ |

**Fix applied:** `omo-agent` now fails fast when one of the 5 broken agents is
requested and prints a clear message explaining the plugin bug and the
workarounds. The mapping to display names was also removed (was useless since
opencode doesn't accept them anyway). Tracked in `resolve_agent_name()` /
`OMO_BROKEN_AGENTS` in the script.

**Workarounds for users:**
- Use a working agent (`oracle`, `explore`, `librarian`, `multimodal-looker`).
- Fall back to raw model access: `omo-agent --model gpt "<prompt>"` (or `codex`,
  `gemini-pro`). You lose the specialized agent prompt, but you get the model.

**Upstream fix watch:** Re-test the 5 broken agents when any of these change:
- opencode version > 1.4.0 (`opencode upgrade`)
- oh-my-opencode / oh-my-openagent version > 3.15.3
- Changes to the plugin's `remapAgentKeysToDisplayNames` logic

If the upstream fix lands, remove the BROKEN classification in the script
(`OMO_BROKEN_AGENTS=""`) and delete this gotcha entry (or update the date).

## Blank line in positional prompt hangs opencode (2026-04-11)

**Affected:** `opencode 1.4.0` — any `opencode run` invocation where the
positional `message` argument contains `\n\n` (a blank line / paragraph break).

**Symptom:** opencode starts, logs a single INFO line, produces **zero bytes**
of stdout/stderr, opens **zero network sockets**, spawns **zero child
processes**, and spins on the main thread until killed by an external timeout.
Single-newline prompts (`\n`) are fine; only `\n\n` triggers the hang. Affects
both `--agent` and `--model` invocations, from any cwd, and is independent of
shell quoting form (`"$(cat <<EOF)"` and `$'...\n\n...'` both repro).

**Historical impact:** Session `381ebed7-537d-4295-98c8-a90f8dcc2787` in
`/Users/randytran/Codes/oneclaw` burned two full 15-minute `omo-agent` timeouts
because a cross-model review prompt contained multi-paragraph instructions.

**Minimal repro (pre-fix):**

```sh
timeout 30 opencode run --agent oracle --dir "$(pwd)" "Hello.

Reply with OK."
# → exit 124, 0 bytes out
```

**Fix in omo-agent:** the wrapper now pipes `$PROMPT` to `opencode run` via
stdin (`printf '%s' "$PROMPT" | opencode run ...`) instead of passing it as a
positional argv. Stdin bypasses whatever opencode code path deadlocks on the
blank-line positional, and works reliably for all prompt shapes.

**Verification (post-fix):** the exact originally-failing review prompt runs
in ~28s end-to-end and returns a full structured blocker-finder report.

**Upstream fix watch:** retest with a bare positional-arg prompt on any new
opencode release. If fixed, the stdin pipe can stay (it's harmless) but this
note can be removed.

## Model mode fails without --pure (2026-04-13)

**Affected:** `opencode 1.4.3` + oh-my-opencode plugin — `omo-agent --model <alias>` fails
with `error: default agent "Sisyphus - Ultraworker" not found`.

**Root cause:** Same display-name bug as the 5 broken agents. When `opencode run --model X`
is called without `--agent`, opencode loads the plugin's default agent. The plugin sets the
default to "Sisyphus - Ultraworker" (a display name), which opencode can't resolve. The
error exits 0, so omo-agent's error classification reported "success" with an error dump
as output.

**Fix in omo-agent:** The model-mode execution path now passes `--pure` to bypass the
plugin entirely. Model mode doesn't need agent definitions (the user controls the prompt),
so `--pure` is safe and correct. Also added a default-agent error detection guard that
catches `default agent.*not found` in the output and exits 1.

**Verification (post-fix):** All 4 model aliases (gpt, codex, gemini-flash, gemini-pro)
return correct responses in <10s.

**Upstream fix watch:** Same as the agent compat bug above. If the plugin's default agent
naming is fixed, `--pure` can be removed (it's harmless either way).

## How to probe current state

```sh
# List what opencode actually registers
opencode agent list | grep -E '^[a-z][^[:space:]]*\s*\((primary|subagent|plan|all)\)'

# Test a single agent end-to-end (30s budget)
cd /tmp && timeout 30 opencode run --agent momus "hi" 2>&1 | head -5

# Upstream repro: direct `opencode run` with blank-line argv — bypasses the wrapper.
# Expected: HANGS (exit 124, 0 bytes) until opencode itself is upstream-fixed.
# If this returns quickly with exit 0, the upstream bug is resolved → the stdin
# pipe in omo-agent can be reverted to positional argv for simplicity.
timeout 30 opencode run --agent oracle --dir "$(pwd)" $'Hello.\n\nReply with OK.'

# Wrapper regression check: exercises the stdin pipe in omo-agent.
# Expected: succeeds in <30s with non-empty output.
# If this hangs, the wrapper fix has regressed, or opencode has broken stdin input.
OMO_TIMEOUT=60 omo-agent oracle "$(printf 'Hello.\n\nReply with OK.')"
```
