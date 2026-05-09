#!/usr/bin/env python3
"""parse-compose.py — extract structural facts from a docker-compose YAML.

Output: JSON document on stdout describing services, container_names, ports,
volumes (with identity-mount detection), labels, environment, profiles, plus
service_dns_references (substring matches between env values and stripped names).

Hard requirement: PyYAML. Aborts with an install instruction on ImportError.
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import Any


def die(msg: str, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    sys.exit(code)


try:
    import yaml  # type: ignore
except ImportError:
    die(
        "x-worktree-isolate: PyYAML is required. Install it with:\n"
        "  pip install --user pyyaml\n"
        "(or: pip3 install --user pyyaml)"
    )


PORT_RE = re.compile(
    r"""^
    (?:(?P<host_ip>\d{1,3}(?:\.\d{1,3}){3}):)?
    (?:
        (?P<host_var>\$\{[A-Za-z_][A-Za-z0-9_]*\})
        |
        (?P<host_lit>\d+)
    )?
    (?::(?P<container>\d+))?
    (?:/(?P<proto>tcp|udp))?
    $""",
    re.VERBOSE,
)

VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")


def parse_port_entry(entry: Any) -> dict[str, Any]:
    """Normalize a compose ports[] entry to {host_literal, host_var, container_port, proto, raw}."""
    raw = entry
    out: dict[str, Any] = {
        "raw": entry,
        "host_literal": None,
        "host_var": None,
        "container_port": None,
        "host_ip": None,
        "proto": None,
    }
    if isinstance(entry, dict):
        # Long-form: {target: 80, published: "${VAR}", protocol: tcp}
        target = entry.get("target")
        published = entry.get("published")
        out["container_port"] = int(target) if target is not None else None
        if isinstance(published, str) and published.startswith("${"):
            m = VAR_RE.match(published)
            out["host_var"] = m.group(1) if m else None
        elif published is not None:
            try:
                out["host_literal"] = int(published)
            except (TypeError, ValueError):
                out["host_literal"] = None
        out["proto"] = entry.get("protocol")
        out["host_ip"] = entry.get("host_ip")
        return out

    if isinstance(entry, int):
        out["container_port"] = entry
        return out

    if not isinstance(entry, str):
        return out

    m = PORT_RE.match(entry)
    if not m:
        return out
    if m.group("host_ip"):
        out["host_ip"] = m.group("host_ip")
    if m.group("host_var"):
        var_match = VAR_RE.match(m.group("host_var"))
        if var_match:
            out["host_var"] = var_match.group(1)
    if m.group("host_lit"):
        out["host_literal"] = int(m.group("host_lit"))
    if m.group("container"):
        out["container_port"] = int(m.group("container"))
    if m.group("proto"):
        out["proto"] = m.group("proto")
    return out


def parse_volume_entry(entry: Any) -> dict[str, Any]:
    """Normalize compose volumes[] entry to {host, container, identity_mount, raw}."""
    out: dict[str, Any] = {
        "raw": entry,
        "host": None,
        "container": None,
        "identity_mount": False,
        "host_var": None,
        "container_var": None,
    }
    if isinstance(entry, dict):
        out["host"] = entry.get("source")
        out["container"] = entry.get("target")
    elif isinstance(entry, str):
        # host:container[:ro] — split at most twice
        parts = entry.split(":")
        if len(parts) >= 2:
            out["host"] = parts[0]
            out["container"] = parts[1]
    if isinstance(out["host"], str):
        m = VAR_RE.fullmatch(out["host"])
        if m:
            out["host_var"] = m.group(1)
    if isinstance(out["container"], str):
        m = VAR_RE.fullmatch(out["container"])
        if m:
            out["container_var"] = m.group(1)
    if (
        out["host_var"] is not None
        and out["container_var"] is not None
        and out["host_var"] == out["container_var"]
    ):
        out["identity_mount"] = True
    return out


def normalize_environment(env: Any) -> dict[str, str]:
    """Compose accepts environment as either dict or list of KEY=VALUE strings."""
    if env is None:
        return {}
    if isinstance(env, dict):
        return {str(k): "" if v is None else str(v) for k, v in env.items()}
    if isinstance(env, list):
        out: dict[str, str] = {}
        for item in env:
            if not isinstance(item, str):
                continue
            if "=" in item:
                k, v = item.split("=", 1)
                out[k] = v
            else:
                out[item] = ""
        return out
    return {}


def normalize_labels(labels: Any) -> list[str]:
    """labels can be a dict {k: v} or a list of "k=v" strings."""
    out: list[str] = []
    if isinstance(labels, dict):
        for k, v in labels.items():
            out.append(f"{k}={v}")
    elif isinstance(labels, list):
        for item in labels:
            if isinstance(item, str):
                out.append(item)
    return out


def parse_compose_file(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as fh:
        try:
            doc = yaml.safe_load(fh)
        except yaml.YAMLError as e:
            die(f"x-worktree-isolate: failed to parse {path}: {e}")

    if not isinstance(doc, dict):
        return {"file": path, "services": {}}

    services_raw = doc.get("services") or {}
    services_out: dict[str, Any] = {}
    container_names: list[str] = []

    for svc_name, svc in services_raw.items():
        if not isinstance(svc, dict):
            continue
        ports = [parse_port_entry(p) for p in (svc.get("ports") or [])]
        volumes = [parse_volume_entry(v) for v in (svc.get("volumes") or [])]
        env = normalize_environment(svc.get("environment"))
        labels = normalize_labels(svc.get("labels"))
        profiles = svc.get("profiles") or []
        cname = svc.get("container_name")
        if isinstance(cname, str) and cname.strip():
            container_names.append(cname)
        services_out[svc_name] = {
            "container_name": cname if isinstance(cname, str) else None,
            "image": svc.get("image"),
            "ports": ports,
            "volumes": volumes,
            "environment": env,
            "labels": labels,
            "profiles": profiles if isinstance(profiles, list) else [],
        }

    # service_dns_references: substring scan of env values against container names
    dns_refs: list[dict[str, Any]] = []
    for svc_name, svc in services_out.items():
        for env_var, env_val in svc["environment"].items():
            if not isinstance(env_val, str):
                continue
            for cname in container_names:
                if cname and cname in env_val:
                    dns_refs.append(
                        {
                            "service": svc_name,
                            "env_var": env_var,
                            "value": env_val,
                            "matches_stripped_name": cname,
                            "service_name_matches": cname in services_out,
                        }
                    )

    return {
        "file": path,
        "services": services_out,
        "container_names": container_names,
        "service_dns_references": dns_refs,
    }


def main() -> None:
    if len(sys.argv) < 2:
        die("usage: parse-compose.py <compose.yml> [<compose.yml> ...]", code=1)
    paths = sys.argv[1:]
    for p in paths:
        if not os.path.isfile(p):
            die(f"x-worktree-isolate: not a file: {p}", code=1)

    parsed = [parse_compose_file(p) for p in paths]
    json.dump({"compose_files": parsed}, sys.stdout, indent=2, default=str)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
