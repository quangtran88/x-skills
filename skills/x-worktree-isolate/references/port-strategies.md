# port-strategies.md

How `apply` allocates host ports. Deterministic-first, scan on collision.

## Slot formula

```
candidate = default + slot * 1000
```

- `default` is the per-port baseline declared in `profile.json` (the original host port literal from the base compose).
- `slot` is the monotonic integer the registry assigns to this worktree.
- If `candidate` collides with an already-claimed port (set in registry) OR with a port currently bound on the host (`lsof -iTCP:<port> -sTCP:LISTEN`), the allocator scans **upward by 1** until it finds a free port within `port_strategy.scan_range` (default `[18000, 29999]`).

The deterministic formula gives stable URLs for the common case (slot 0 always gets the same ports, slot 1 always gets defaults+1000, etc.). The scan handles real-world collisions when something else (another tool, a stale process) holds a port.

## Why not always +1000?

It would be simpler, but it loses determinism the moment any port is held by an unrelated process. Tools like wtc skip the lsof check entirely and pin ports by slot — they will fail at compose-up time if the port is held. We pay the lsof check up-front.

## Why 18000–29999?

- 18000 is above all standard system services (nothing common < 18000 except dev defaults like 3000, 5432, 6379, 8080, 8443).
- 29999 leaves room above 30000 for k8s NodePort range (30000–32767).
- Keeps room for the formula: a port with `default = 8090` lands at slot 0=8090, slot 1=9090, slot 2=10090, all inside the scan range as fallback.

**Caveat (per oracle review):** the design spec's claim that the range "avoids common dev ports by construction" is wrong. Slot 0 reuses raw defaults, so 3001 / 6006 / 8090 are still possible at slot 0. If you need every worktree on elevated ports, edit `port_strategy.ports[].default` in `profile.json` to start ≥ 18000.

## Registry path

```
~/.config/worktree-isolate/<sha1(realpath(git rev-parse --git-common-dir))>/registry.json
```

`realpath` is required — without it, a symlinked main checkout and a linked worktree resolve `--git-common-dir` to different strings, hash to different sha1s, and end up in separate registries that don't see each other's claims.

Format:

```json
{
  "slots": [
    {
      "slot": 0,
      "worktree_path": "/abs/path/to/worktree",
      "branch": "feature-x",
      "ports": { "GATEWAY_PORT": 18789, "DASHBOARD_PORT": 8090 },
      "data_dir": "/abs/path/to/worktree/data",
      "pid": 12345,
      "allocated_at": "2026-05-09T12:34:56Z"
    }
  ]
}
```

## Locking

POSIX-atomic via `mkdir <registry-dir>/registry.lock`. 5-retry, 200ms backoff. On stale lock (no other apply running but mkdir still fails), the error message names the lock dir for manual `rmdir`.

## Range exhaustion

If a port's slot candidate exceeds `scan_range[1]` and no free port appears, the allocator fails with the lsof snapshot of currently-bound ports in that range. The user reduces concurrent worktrees or widens `scan_range` in `profile.json`.
