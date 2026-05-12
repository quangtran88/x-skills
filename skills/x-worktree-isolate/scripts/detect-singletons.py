#!/usr/bin/env python3
"""detect-singletons.py — Heuristic scanner across three tiers.

Usage:
  detect-singletons.py --repo <repo_root> [--guardrails <json>]

Output:
  {"singletons": [...], "warnings": [...]}  on stdout (pretty JSON).
"""

from __future__ import annotations
import argparse, json, sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
import importlib.util
spec = importlib.util.spec_from_file_location("singleton_patterns", SCRIPT_DIR / "singleton-patterns.py")
sp = importlib.util.module_from_spec(spec)
sys.modules["singleton_patterns"] = sp
spec.loader.exec_module(sp)

spec2 = importlib.util.spec_from_file_location("parse_compose", SCRIPT_DIR / "parse-compose.py")
pc = importlib.util.module_from_spec(spec2)
sys.modules["parse_compose"] = pc
spec2.loader.exec_module(pc)


def find_compose_files(repo: Path, guard: dict | None = None) -> list[Path]:
    names = ("docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml")
    found: list[Path] = []
    g = guard or {}
    for entry in sorted(repo.rglob("*")):
        if not (entry.is_file() and entry.name in names and "override" not in entry.name):
            continue
        depth = len(entry.relative_to(repo).parts) - 1
        if depth > 2:
            continue
        # Honor exclude_dirs so vendored copies under node_modules/vendor/etc.
        # don't pollute compose-tier singleton detection.
        if g and _path_excluded(entry, repo, g):
            continue
        found.append(entry)
    return found


def detect_compose(repo: Path, guard: dict | None = None) -> list[dict]:
    """Emit one entry per (pattern, compose_service) match.

    ID contract: ``id`` is the stable pattern id (e.g. ``"slack-listener"``).
    The same ``id`` may appear multiple times if the same pattern matches
    multiple compose services; entries differ by ``compose_service``. CLI
    ``enable <id>`` / ``disable <id>`` toggles all entries with that id.
    """
    out: list[dict] = []
    seen_pairs: set[tuple[str, str]] = set()
    for cf in find_compose_files(repo, guard):
        parsed = pc.parse_compose_file(str(cf))
        for svc_name, svc in parsed.get("services", {}).items():
            env = svc.get("environment") or {}
            image = svc.get("image") or ""
            for pat in sp.TIER_COMPOSE:
                hits: list[str] = []
                for m in pat.matchers:
                    for env_key in env.keys():
                        if m in env_key:
                            hits.append(f"{cf.name}:services.{svc_name}.environment.{env_key}")
                    if isinstance(image, str) and m in image:
                        hits.append(f"{cf.name}:services.{svc_name}.image={image}")
                if hits:
                    pair = (pat.id, svc_name)
                    if pair in seen_pairs:
                        continue
                    seen_pairs.add(pair)
                    out.append({
                        "id": pat.id,
                        "kind": "compose-service",
                        "evidence": hits,
                        "rationale": pat.rationale,
                        "default_in_worktree": "disabled",
                        "severity": pat.severity,
                        "compose_service": svc_name,
                        # Default to profile-gate: docker compose v2 standalone does
                        # not consistently honor deploy.replicas:0 (Swarm-mode key);
                        # profiles:[xwi-disabled] is the documented "don't start
                        # this service" mechanism. Edit to replicas-zero by hand
                        # if you specifically want it (Swarm only).
                        "disable_method": "profile-gate",
                    })
    return out


DEFAULT_GUARDRAILS = {
    "scan_max_depth": 4,
    "scan_max_file_bytes": 1048576,
    "exclude_dirs": ["node_modules", "vendor", ".git", "dist", "build",
                     "__pycache__", "target", ".next", ".venv", "tests/fixtures"],
    "exclude_globs": ["*.min.js", "*.lock", "package-lock.json",
                      "pnpm-lock.yaml", "yarn.lock", "Cargo.lock"],
}

SOURCE_EXTS = {".ts", ".tsx", ".js", ".jsx", ".mjs", ".cjs",
               ".py", ".rb", ".go", ".rs", ".java", ".kt",
               ".env", ".env.example", ".env.sample"}


def _path_excluded(p: Path, repo: Path, guard: dict) -> bool:
    import fnmatch
    rel = p.relative_to(repo)
    parts = rel.parts
    for ex in guard.get("exclude_dirs") or []:
        ex_parts = tuple(Path(ex).parts)
        if any(parts[i:i+len(ex_parts)] == ex_parts for i in range(len(parts))):
            return True
    name = p.name
    for glob in guard.get("exclude_globs") or []:
        if fnmatch.fnmatch(name, glob):
            return True
    return False


def _eligible_files(repo: Path, guard: dict):
    max_depth = int(guard.get("scan_max_depth", 4))
    max_bytes = int(guard.get("scan_max_file_bytes", 1048576))
    for p in repo.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo)
        if len(rel.parts) - 1 > max_depth:
            continue
        if _path_excluded(p, repo, guard):
            continue
        ext = p.suffix.lower()
        is_env = p.name.startswith(".env")
        is_procfile = p.name == "Procfile"
        if ext not in SOURCE_EXTS and not is_env and not is_procfile:
            continue
        try:
            if p.stat().st_size > max_bytes:
                continue
        except OSError:
            continue
        yield p


def detect_env_flag(repo: Path, guard: dict) -> list[dict]:
    out: list[dict] = []
    seen_ids: set[str] = set()
    regexes = sp.env_flag_regexes()
    for f in _eligible_files(repo, guard):
        try:
            text = f.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for pat, regex in regexes:
            # procfile-worker regex (^worker:/^scheduler:) is loose enough to
            # match any source file with a top-level `worker:` token (YAML
            # config, dict literal at column 0). Scope it to Procfile only.
            if pat.id == "procfile-worker" and f.name != "Procfile":
                continue
            m = regex.search(text)
            if not m:
                continue
            rel = f.relative_to(repo).as_posix()
            line_no = text[:m.start()].count("\n") + 1
            cand_id = pat.id
            if cand_id in seen_ids:
                continue
            seen_ids.add(cand_id)
            out.append({
                "id": cand_id,
                "kind": "env-flag",
                "evidence": [f"{rel}:{line_no}: {m.group(0)[:80]}"],
                "rationale": pat.rationale,
                "default_in_worktree": "disabled",
                "severity": pat.severity,
                "env_var": pat.suggested_env_var,
                "env_disabled_value": "false",
            })
    return out


def detect_host(repo: Path, guard: dict) -> list[dict]:
    import fnmatch as _fnmatch
    out: list[dict] = []
    seen_ids: set[str] = set()
    max_depth = int(guard.get("scan_max_depth", 4))
    for p in repo.rglob("*"):
        if not p.is_file():
            continue
        rel = p.relative_to(repo)
        if len(rel.parts) - 1 > max_depth:
            continue
        if _path_excluded(p, repo, guard):
            continue
        rel_posix = rel.as_posix()
        for pat in sp.TIER_HOST:
            if pat.id in seen_ids:
                continue
            matched = False
            for m in pat.matchers:
                if _fnmatch.fnmatch(p.name, m) or _fnmatch.fnmatch(rel_posix, m):
                    matched = True
                    break
            if matched:
                seen_ids.add(pat.id)
                out.append({
                    "id": pat.id,
                    "kind": "host",
                    "evidence": [rel_posix],
                    "rationale": pat.rationale,
                    "default_in_worktree": "disabled",
                    "severity": pat.severity,
                    "host_artifact": rel_posix,
                    "manual_fix_hint": (
                        f"Disable or scope {rel_posix} before running parallel worktrees, "
                        "or run `x-worktree-isolate ack-host-singletons` to acknowledge."
                    ),
                })
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", required=True)
    ap.add_argument("--guardrails", default="{}")
    args = ap.parse_args()
    repo = Path(args.repo).resolve()
    if not repo.is_dir():
        print(f"detect-singletons: not a directory: {repo}", file=sys.stderr)
        sys.exit(1)

    try:
        guard_in = json.loads(args.guardrails) if args.guardrails else {}
    except json.JSONDecodeError as e:
        print(f"detect-singletons: invalid --guardrails JSON: {e}", file=sys.stderr)
        sys.exit(1)
    merged = {**DEFAULT_GUARDRAILS, **(guard_in or {})}

    singletons: list[dict] = []
    singletons.extend(detect_compose(repo, merged))
    singletons.extend(detect_env_flag(repo, merged))
    singletons.extend(detect_host(repo, merged))

    print(json.dumps({"singletons": singletons, "warnings": []}, indent=2))


if __name__ == "__main__":
    main()
