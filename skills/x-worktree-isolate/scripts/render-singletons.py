#!/usr/bin/env python3
"""render-singletons.py — Compute singleton contributions to override + env files.

Usage:
  render-singletons.py --profile <path> [--overrides <path>]

Output (JSON on stdout):
  {
    "compose_service_fields": {
      "slack-listener": {"deploy": {"replicas": 0}},
      "watchtower":     {"profiles": ["xwi-disabled"]}
    },
    "env_lines": ["SLACK_LISTENER_ENABLED=false", "RUN_SCHEDULER=false"],
    "host_blockers": [{"id": "host-crontab", "host_artifact": "...", "manual_fix_hint": "..."}]
  }

Apply.sh merges compose_service_fields into its existing per-service override
dict before YAML serialization (one services.<svc>: block per service, never two).
"""

from __future__ import annotations
import argparse, json, os, sys


def load_overrides(path: str) -> dict[str, str]:
    if not path or not os.path.isfile(path):
        return {}
    try:
        data = json.load(open(path))
    except (OSError, json.JSONDecodeError):
        return {}
    return {o["id"]: o["state"] for o in data.get("overrides", []) if "id" in o and "state" in o}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profile", required=True)
    ap.add_argument("--overrides", default="")
    args = ap.parse_args()

    profile = json.load(open(args.profile))
    overrides = load_overrides(args.overrides)
    svc_fields: dict[str, dict] = {}
    env_lines: list[str] = []
    host_blockers: list[dict] = []
    warnings: list[str] = []

    for s in profile.get("singletons", []) or []:
        sid = s.get("id")
        default = s.get("default_in_worktree", "disabled")
        state = overrides.get(sid, default)
        kind = s.get("kind")

        if kind == "host":
            if state == "acknowledged":
                continue
            # Align with apply.sh's BLOCKER_LIST gate: only severity=blocker
            # host singletons populate host_blockers. A user-edited severity
            # below "blocker" intentionally downgrades to non-blocking.
            if s.get("severity") != "blocker":
                continue
            host_blockers.append({
                "id": sid,
                "host_artifact": s.get("host_artifact", ""),
                "manual_fix_hint": s.get("manual_fix_hint", ""),
            })
            continue

        if state == "enabled":
            continue

        if kind == "compose-service":
            svc = s.get("compose_service")
            method = s.get("disable_method", "replicas-zero")
            if not svc:
                continue
            entry = svc_fields.setdefault(svc, {})
            if method == "replicas-zero":
                entry["deploy"] = {"replicas": 0}
                warnings.append(
                    f"singleton '{sid}' uses disable_method=replicas-zero; "
                    "standalone docker compose v2 ignores deploy.replicas:0 "
                    "(Swarm-mode only). Switch to disable_method=profile-gate "
                    f"in profile.json or run on Swarm to actually disable {svc}."
                )
            elif method == "profile-gate":
                # Use a namespaced sentinel ("xwi-disabled") rather than a
                # generic name like "singleton" — Compose includes services
                # whose profile is named in COMPOSE_PROFILES. A user who
                # legitimately exports `COMPOSE_PROFILES=singleton` for an
                # unrelated reason would re-enable every disabled service.
                profs = entry.setdefault("profiles", [])
                if "xwi-disabled" not in profs:
                    profs.append("xwi-disabled")
        elif kind == "env-flag":
            var = s.get("env_var")
            val = s.get("env_disabled_value", "false")
            if var:
                env_lines.append(f"{var}={val}")

    print(json.dumps({
        "compose_service_fields": svc_fields,
        "env_lines": env_lines,
        "host_blockers": host_blockers,
        "warnings": warnings,
    }, indent=2))


if __name__ == "__main__":
    main()
