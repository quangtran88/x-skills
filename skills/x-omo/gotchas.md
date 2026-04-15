# x-omo Gotchas

Known failure patterns and compatibility issues for the `omo-agent` wrapper.

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
OMO_TIMEOUT=60 ~/.claude/skills/x-omo/omo-agent oracle "$(printf 'Hello.\n\nReply with OK.')"
```
