# x-gemini gotchas

## agy backend (agy-agent)

- **No JSON.** agy print mode is plain text; there is no `--json`/`--output-format`. `agy-agent` emits the text directly.
- **Exit 0 lies.** agy exits 0 even on auth/quota/empty failures. `agy-agent` re-derives a real exit code from empty-stdout + `--log-file` tail; trust the wrapper's exit code, not agy's.
- **trustedWorkspaces.** agy hangs on a trust prompt for untrusted dirs in non-TTY. `agy-agent` preflights and warns; set `X_AGY_AUTO_TRUST=1` to auto-append CWD.
- **Grounding is prompt-driven** (no flag) AND load-bearing for currency. Without `--grounded`, agy trusts the repo over live docs and will return stale identifiers (verified: it returned a *legacy* OpenAI event the repo still contained instead of the current GA one). Pass `--grounded` for any "what's current / latest version" question.
- **Never `--add-dir` a large tree.** Pointing it at a repo root (e.g. a 65 GB monorepo with node_modules/build/vendored checkouts) makes agy's agentic traversal hang for 15–25 min with zero output. Scope to the relevant subtree(s) — a 572 KB scope returned in 79 s. `agy-agent` warns when a target looks large.
- **Serialize agy calls.** agy spawns a local gRPC language-server per invocation; concurrent calls contend and hang. Consumers that fan out (x-research, x-qa) MUST run agy lanes sequentially, not in parallel.
- **Auth noise in the log is NOT an auth failure.** Every run's log contains `not logged into Antigravity` / `failed to set auth token` (auxiliary caches), even on success. Don't classify on it; trust `agy-agent`'s status, which strips this noise.
- **Latency** ~2× a single scoped grounded run (≈79 s) — NOT 3–5×. The 3–5× only appears under the two pathologies above (huge `--add-dir`, concurrency). Route bulk work to `--model flash-low`.
