# gotchas.md — x-worktree-isolate

Failure modes you will hit if you skim past them.

## 1. `container_name` removal — only `!reset null` works

Verified empirically against Compose v2.40.3 (test in `/tmp/compose-null-test`):

| Override syntax | Result |
|---|---|
| `container_name: !reset null` | Field is removed from rendered `docker compose config`. Compose generates a default name like `<project>-<service>-1`. |
| `container_name: null` | Field is **retained** from the base file (silent). |
| `container_name: ""` | Schema validation error. |
| (field omitted) | Field is retained from the base file (silent). |

Apply must emit `!reset null` for every entry in `services_to_strip` that has a non-null `container_name`. No other form works. The override block is keyed by the service name (Compose merges by service KEY, not container_name).

## 2. `ports: !override` replaces, does not append

`!override` swaps the entire ports list. If you forget the tag and just write `ports: [...]`, Compose merges the lists, leaving the base file's hardcoded `127.0.0.1:18789:...` AND your override side-by-side, defeating the purpose.

## 3. DinD identity mounts (`${V}:${V}`)

Sandboxes spawned through the host docker socket must have `host_path == container_path`, otherwise the container path won't exist on the host filesystem when bind-mounted. The inspector flags volumes shaped `${VAR}:${VAR}` so apply can produce an absolute host path. **The user must NOT change the mount line** to `${VAR}:/something/different/in/container` — that breaks DinD silently.

The only true cross-worktree isolation for DinD that doesn't break the identity rule is rootless Docker per-context (e.g., OrbStack contexts). Out of scope for v1.

## 4. Service-name DNS vs container_name

Compose preserves service-name DNS regardless of `container_name`. Stripping is safe **iff** env values reference the service name (which is the convention 95%+ of the time). The inspector emits `service_dns_references` listing every env value that contains a stripped container name. If `service_name_matches: true` for that entry, you're fine. If it's `false`, the env value points at a name Compose will not resolve after stripping — the user must rewrite the env value.

## 5. Global Makefile label filters cross-tear-down

A Makefile target like:

```make
kill-sandboxes:
	docker ps -q --filter label=app.sandbox=1 | xargs -r docker rm -f
```

Tears down sandboxes from EVERY worktree, not just this one. Even with perfect compose isolation, the Makefile target will kill the parallel worktree's stack. Inspector emits this as `severity: blocker`; apply refuses to run unless `--ignore-warnings`. Fix by scoping the filter to `COMPOSE_PROJECT_NAME` or a worktree-prefixed label.

## 6. Stacked `--env-file` order

Compose merges `--env-file` flags left-to-right; the right-most file wins on key conflicts. The canonical launch is:

```
docker compose --env-file .env --env-file .env.worktree up
```

If your Makefile sets `COMPOSE_FILE` or env-files in a different order, the override may not win. Apply's "Next steps" prints the exact command — use it verbatim, or update the Makefile to match.

## 7. Image tags are shared across worktrees (benign)

`image: oneclaw-gateway:local` is content-addressed — both worktrees can resolve the same tag without conflict. The first `docker compose build` in a fresh worktree may rebuild from scratch. The skill never overrides image tags.

## 8. Compose v1 is unsupported

`docker-compose` (the Python CLI from 2014) does not understand `!reset` / `!override` merge tags or stacked `--env-file`. Init aborts on v1 detection with an install hint for Compose v2.

## 9. Slot 0 reuses raw defaults

The deterministic port formula is `default + N * 1000`. Slot 0 (the first worktree) uses the raw defaults from the profile. If the base default is `3001`, slot 0 gets `3001` — the same port the base compose intended. **This is fine** if the original repo expected those ports. If you want all worktrees to use elevated ports, edit `port_strategy.ports[].default` in `profile.json` to start above 18000.

## 10. Registry hash uses `realpath`

The registry directory is `~/.config/worktree-isolate/<sha1(realpath(git rev-parse --git-common-dir))>`. The `realpath` matters: a symlinked main checkout and a linked worktree resolve to different `--git-common-dir` strings if you skip `realpath`, which then map to different registry hashes — and the registry stops working. allocate-ports.sh always wraps in `realpath`.

## 11. `wt` not installed

`wt` (worktrunk) is optional. Without it, the user invokes `x-worktree-isolate apply` manually after `git worktree add`. The skill remains fully functional without `wt` — only the auto-trigger goes away.

## 12. Profile lives in main checkout

`apply` reads the profile from the linked worktree first, then falls back to the main checkout's `.worktree-isolate/profile.json`. Reason: a fresh worktree branched off main has the committed profile already; a worktree off a feature branch that never had `init` run still finds the profile via the common-dir lookup.

## 13. `parse-compose.py` requires PyYAML

Hard requirement, no stdlib fallback. The script aborts with `pip install --user pyyaml` if the import fails. A bespoke regex parser would silently mis-read anchors, multi-line scalars, and merge keys — the cost of those bugs is higher than asking the user to `pip install`.
