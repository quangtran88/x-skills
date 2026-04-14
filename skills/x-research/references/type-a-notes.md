# Type A Notes

Variants and exceptions for Type A (Codebase) research.

## Local Research Repos

If the target is a local research repo and is small (<50 files), Claude may read files directly instead of dispatching `explore`. This is faster and more targeted for known local directories.

## Multi-Repo Parallel Scans

When targets span 3+ independent directories/repos, OMC Explore agents (`Agent` tool with `subagent_type=Explore`, `run_in_background: true`) are preferred over a single OMO explore call. Each agent gets one repo. Collect all results before synthesizing.

## Comparison Research

When the goal is to compare external patterns against internal code (e.g., "what can we adopt from repo X?"), read both sides before synthesizing. Structure findings as: what they do → our gap → optimization.

**Default ordering:** Read the external source first, then read the internal targets for comparison.

**Exception — local external source:** When the external source is a local research repo, both sides may be read in parallel (no network latency concern) — launch an OMC Explore agent for the internal repo while directly reading the external repo.

## Version Upgrade Analysis

When the goal is to assess a dependency upgrade (e.g., "compare v1 to v2, find breaking changes"), this is a distinct Type A variant with a specific workflow:

1. **Identify version range** — find our pinned version and the target version (tags, Dockerfile, package.json)
2. **Git range analysis** — `git log old..new --oneline` for commit overview, `git diff old..new --stat` for scope, `--grep` for breaking/feat/security commits
3. **Changelog review** — read CHANGELOG.md between versions for documented breaking changes and new features
4. **Import path verification** — grep our codebase for all imports from the dependency, then verify each path still exists at the target version (`git show tag:path`)
5. **Interface compatibility** — check that types/APIs we consume haven't changed required fields or signatures
6. **Breaking change impact matrix** — for each upstream breaking change, assess whether our code is affected (often most are not)
7. **New feature assessment** — identify adoptable new features relevant to our use case

**Two-pass verification:** Inline verification during research (step 4-5 via `git show`) satisfies synthesis verification requirements. A second pass after checking out the target version provides additional assurance but is optional — the user may request it.

**No agent dispatch needed.** Git range operations (`git log`, `git diff`, `git show`) are more targeted than `explore` for version comparison. Direct reads are the correct approach.
