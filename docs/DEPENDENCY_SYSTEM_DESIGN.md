# X-Skills Dependency System Design Document

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Problem Statement](#problem-statement)
3. [Design Goals](#design-goals)
4. [Architecture Overview](#architecture-overview)
5. [Dependency Registry](#dependency-registry)
6. [Artifact Storage](#artifact-storage)
7. [Resolution Strategy](#resolution-strategy)
8. [Management Workflow](#management-workflow)
9. [CLI Reference](#cli-reference)
10. [Implementation Plan](#implementation-plan)
11. [Appendix](#appendix)

---

## Executive Summary

X-Skills currently relies on multiple external plugins (`superpowers`, `oh-my-claudecode`) for specialized tasks. Installing full plugins is heavyweight and pulls in 50+ unused skills. This document proposes a **lazy dependency system** that:

- Downloads only the specific skills/agents x-skills needs
- Stores them on the **user's machine** (not in this repo)
- Provides version pinning via lock files
- Offers a simple CLI for dependency management

**Key principle:** Dependencies are extracted prompts and agent definitions stored as flat `.md` files, invoked via `Read` + `Agent` tools rather than `Skill` tool with namespace prefixes.

---

## Problem Statement

### Current State

X-Skills references external capabilities in three ways:

1. **Plugin Skills** via `Skill` tool: `superpowers:writing-plans`, `superpowers:code-reviewer`
2. **OMC Agents** via `Agent` tool: `oh-my-claudecode:code-reviewer`, `oh-my-claudecode:executor`
3. **OMO Agents** via `Bash` tool: `omo-agent oracle`, `omo-agent --model gpt`

### Problems

| Problem | Impact |
|---------|--------|
| Full plugin installation required | Users must install `superpowers` (20+ skills) to use 3 of them |
| No version pinning | Plugin updates may break x-skills behavior unexpectedly |
| Namespace conflicts | User may have different plugin version than x-skills expects |
| Setup friction | `bin/setup` detects plugins but can't install selective skills |
| Offline unavailability | If plugins aren't installed, fallbacks are generic and inconsistent |

### What We Need

A system where x-skills:
1. Declares exactly which external skills/agents it depends on
2. Downloads only those artifacts during plugin installation
3. Pins versions to ensure reproducible behavior
4. Works without requiring full plugin installation

---

## Design Goals

1. **Selective:** Download only needed artifacts, not entire plugins
2. **Lazy:** Artifacts downloaded during plugin installation, not stored in repo
3. **Version-pinned:** Lock file records exact versions
4. **Isolated:** Dependencies stored in x-skills' own directory, not shared with user plugins
5. **Simple:** Flat `.md` files, no plugin registration, no namespaces
6. **Manageable:** CLI for add/update/delete/list operations

---

## Architecture Overview

### High-Level Flow

```
User runs /plugin install x-skills
    ↓
Claude Code installs x-skills plugin
    ↓
SessionStart hook triggers
    ↓
Hook calls: bin/setup --pull-deps
    ↓
Setup reads dependencies/registry.json
    ↓
For each dependency:
    - Check if already downloaded
    - Download from source (git sparse checkout or raw URL)
    - Store in ~/.claude/plugins/cache/x-skills-marketplace/x-skills/deps/
    - Record SHA in lock file
    ↓
Skills reference deps via Read tool
    ↓
If dependency missing → fallback to generic prompt
```

### Directory Structure (on User's Machine)

After installation:

```
~/.claude/plugins/cache/x-skills-marketplace/x-skills/
├── skills/                    # X-Skills native skills (x-do, x-review, etc.)
├── deps/                      # Downloaded dependencies
│   ├── prompts/               # Skill prompts (extracted instructions)
│   │   ├── superpowers-writing-plans.md
│   │   ├── superpowers-verification-before-completion.md
│   │   └── superpowers-requesting-code-review.md
│   └── agents/                # Agent definitions (system prompts)
│       ├── superpowers-code-reviewer.md
│       ├── oh-my-claudecode-code-reviewer.md
│       └── oh-my-claudecode-executor.md
├── dependencies/
│   ├── registry.json          # Source of truth (shipped in repo)
│   └── lock.json              # Installed versions (generated on user machine)
├── hooks/
│   └── inject-capabilities.sh
└── bin/
    └── xskill-deps            # Dependency management CLI
```

### What's in the Repo vs. User's Machine

| Location | In Repo? | On User's Machine? | Notes |
|----------|----------|-------------------|-------|
| `dependencies/registry.json` | ✅ Yes | ✅ Yes (copied) | Source of truth, defines what to download |
| `dependencies/lock.json` | ❌ No | ✅ Yes (generated) | Records what was actually installed |
| `deps/prompts/*.md` | ❌ No | ✅ Yes (downloaded) | Extracted skill prompts |
| `deps/agents/*.md` | ❌ No | ✅ Yes (downloaded) | Extracted agent definitions |
| `bin/xskill-deps` | ✅ Yes | ✅ Yes (copied) | CLI tool |

---

## Dependency Registry

### Format: `dependencies/registry.json`

```json
{
  "version": "1.0.0",
  "format": "xskill-dep-v1",
  "last_updated": "2026-05-03",
  "sources": {
    "superpowers": {
      "repo": "https://github.com/obra/superpowers.git",
      "ref": "main",
      "type": "plugin",
      "license": "MIT",
      "artifacts": {
        "writing-plans": {
          "type": "prompt",
          "path": "skills/writing-plans/SKILL.md",
          "needed_by": ["x-do"],
          "description": "Produces structured implementation plans with TDD orientation"
        },
        "code-reviewer": {
          "type": "agent",
          "path": "skills/code-reviewer/SKILL.md",
          "needed_by": ["x-review"],
          "description": "Multi-perspective code review with severity rubric",
          "model": "claude-opus-4",
          "mode": "auto"
        },
        "verification-before-completion": {
          "type": "prompt",
          "path": "skills/verification-before-completion/SKILL.md",
          "needed_by": ["x-do", "x-bugfix", "x-api-pentest"],
          "description": "Verification checklist before claiming done"
        },
        "requesting-code-review": {
          "type": "prompt",
          "path": "skills/requesting-code-review/SKILL.md",
          "needed_by": ["x-review"],
          "description": "Structured review request workflow"
        },
        "brainstorming": {
          "type": "prompt",
          "path": "skills/brainstorming/SKILL.md",
          "needed_by": ["x-do"],
          "description": "Idea generation and requirement exploration"
        }
      }
    },
    "oh-my-claudecode": {
      "repo": "https://github.com/Yeachan-Heo/oh-my-claudecode.git",
      "ref": "main",
      "type": "plugin",
      "license": "MIT",
      "artifacts": {
        "code-reviewer": {
          "type": "agent",
          "path": "skills/ralph/SKILL.md",
          "needed_by": ["x-do", "x-verify"],
          "description": "OMC code reviewer agent",
          "model": "claude-opus-4",
          "mode": "auto"
        },
        "executor": {
          "type": "agent",
          "path": "agents/executor.md",
          "needed_by": ["x-do"],
          "description": "OMC executor agent for applying code changes",
          "model": "claude-sonnet-4",
          "mode": "auto"
        },
        "ralph": {
          "type": "prompt",
          "path": "skills/ralph/SKILL.md",
          "needed_by": ["x-do"],
          "description": "Self-referential implementation loop"
        }
      }
    }
  }
}
```

### Schema Fields

**Top Level:**
- `version`: Registry format version
- `format`: Schema identifier
- `last_updated`: Manual timestamp for human reference
- `sources`: Map of provider names to source definitions

**Per Source:**
- `repo`: Git repository URL
- `ref`: Branch, tag, or commit SHA to checkout
- `type`: `plugin` | `repo` | `url`
- `license`: License identifier (for compliance)
- `artifacts`: Map of artifact names to definitions

**Per Artifact:**
- `type`: `prompt` | `agent`
  - `prompt`: Skill instructions invoked via `Read` + follow
  - `agent`: System prompt invoked via `Read` + `Agent` tool
- `path`: Path within the repo to the source file
- `needed_by`: List of x-skills that require this artifact
- `description`: Human-readable purpose
- `model`: (agents only) Preferred model
- `mode`: (agents only) Agent mode (`auto`, etc.)

---

## Artifact Storage

### Download Location

All artifacts stored in plugin cache:

```
~/.claude/plugins/cache/x-skills-marketplace/x-skills/deps/
```

This location is:
- **Writeable** by the user
- **Isolated** from other plugins
- **Persistent** across Claude Code sessions
- **Discoverable** by x-skills skills

### Artifact File Format

Downloaded artifacts are stored as `.md` files with YAML frontmatter:

```markdown
---
source: https://github.com/obra/superpowers
artifact: code-reviewer
provider: superpowers
version: abc123def456
extracted: 2026-05-03
type: agent
model: claude-opus-4
mode: auto
---

# [Original content from source file]
```

This metadata allows:
- Tracing back to source
- Version comparison
- Type-aware invocation

### Lock File

`dependencies/lock.json` records what was actually installed:

```json
{
  "version": "1.0.0",
  "generated": "2026-05-03T10:00:00Z",
  "registry_sha": "sha256:abc...",
  "artifacts": {
    "superpowers/writing-plans": {
      "sha": "def789...",
      "downloaded": "2026-05-03T10:05:00Z",
      "path": "deps/prompts/superpowers-writing-plans.md"
    },
    "superpowers/code-reviewer": {
      "sha": "abc123...",
      "downloaded": "2026-05-03T10:05:00Z",
      "path": "deps/agents/superpowers-code-reviewer.md"
    }
  }
}
```

---

## Resolution Strategy

### How Skills Reference Dependencies

**Prompt Type (e.g., `writing-plans`):**

```markdown
# In x-do SKILL.md

## Mode B: New Feature

1. Read: deps/prompts/superpowers-writing-plans.md
2. Follow the instructions from that file to produce a plan
3. Save plan to docs/plan.md
```

**Agent Type (e.g., `code-reviewer`):**

```markdown
# In x-review step-02-review.md

## Cross-Model Review

1. Read: deps/agents/superpowers-code-reviewer.md
2. Agent: model="opus", prompt="[content from file above]\n\nReview this code:\n[code]"
```

### Resolution Cascade

When a skill needs an external dependency:

1. **Check if artifact exists** in `deps/`:
   - Yes → Use it (`Read` the `.md` file)
   - No → Continue to fallback

2. **Fallback** (when dependency not downloaded):
   - For agents → Use `Agent` tool with generic prompt
   - For prompts → Use inline simplified instructions
   - Log: "Using fallback — dependency X not available"

3. **Update available** (when lock SHA differs from registry):
   - Log: "Dependency X has update available"
   - Continue with current version
   - Suggest: `xskill-deps update`

### Capabilities Integration

The existing capability system in `bin/setup` is extended:

```json
// capabilities.json
{
  "deps": {
    "superpowers": {
      "available": true,
      "artifacts": ["writing-plans", "code-reviewer", "verification-before-completion"]
    },
    "oh-my-claudecode": {
      "available": true,
      "artifacts": ["code-reviewer", "executor", "ralph"]
    }
  }
}
```

This allows skills to check at bootstrap which dependencies are available and adjust behavior accordingly.

---

## Management Workflow

### Installation Flow

```bash
# User installs x-skills plugin
/plugin install x-skills@x-skills-marketplace
/reload-plugins

# SessionStart hook runs automatically:
# 1. Checks if deps/ exists
# 2. Reads dependencies/registry.json
# 3. Downloads missing artifacts
# 4. Generates lock.json

# Result: All dependencies ready
```

### Manual Pull

```bash
# Pull all dependencies defined in registry
xskill-deps pull

# Pull specific provider only
xskill-deps pull --provider superpowers

# Pull specific artifact only
xskill-deps pull --provider superpowers --artifact code-reviewer
```

### Update Flow

```bash
# Check for updates (compare lock SHAs to registry refs)
xskill-deps check

# Output:
# superpowers/code-reviewer: abc123 → def789 (update available)
# oh-my-claudecode/ralph: no update

# Update specific artifact
xskill-deps update superpowers/code-reviewer

# Update all artifacts
xskill-deps update --all

# Update and verify (read back to ensure integrity)
xskill-deps update --all --verify
```

### Add New Dependency

```bash
# Add new artifact to registry
xskill-deps add \
  --provider superpowers \
  --artifact test-driven-development \
  --type prompt \
  --path skills/test-driven-development/SKILL.md \
  --needed-by x-do,x-bugfix

# This updates dependencies/registry.json
# Then run pull to download:
xskill-deps pull --provider superpowers --artifact test-driven-development
```

### Remove Dependency

```bash
# Remove artifact from registry
xskill-deps remove superpowers/test-driven-development

# Remove downloaded file (optional)
xskill-deps clean

# Or manually:
rm deps/prompts/superpowers-test-driven-development.md
```

### List Dependencies

```bash
# List all registered artifacts
xskill-deps list

# Output:
# PROVIDER          ARTIFACT                      TYPE     STATUS     NEEDED BY
# superpowers       writing-plans                 prompt   ✓ ready  x-do
# superpowers       code-reviewer                 agent    ✓ ready  x-review
# superpowers       verification-before-completion prompt   ✓ ready  x-do, x-bugfix
# oh-my-claudecode  code-reviewer                 agent    ✓ ready  x-do, x-verify
# oh-my-claudecode  ralph                         prompt   ✗ missing x-do

# List with versions
xskill-deps list --verbose
```

---

## CLI Reference

### `xskill-deps`

Location: `bin/xskill-deps`

#### Commands

| Command | Description | Options |
|---------|-------------|---------|
| `pull` | Download artifacts from registry | `--provider`, `--artifact`, `--force` |
| `update` | Update artifacts to latest | `<artifact-path>`, `--all`, `--verify` |
| `check` | Check for available updates | `--provider` |
| `add` | Add artifact to registry | `--provider`, `--artifact`, `--type`, `--path`, `--needed-by` |
| `remove` | Remove artifact from registry | `<artifact-path>` |
| `list` | List registered artifacts | `--verbose`, `--provider`, `--missing-only` |
| `clean` | Remove downloaded artifacts not in registry | `--dry-run` |
| `verify` | Verify integrity of downloaded artifacts | `--provider`, `--artifact` |
| `init` | Initialize dependencies directory | (runs automatically) |

#### Global Options

| Option | Description |
|--------|-------------|
| `--registry <path>` | Custom registry file path |
| `--deps-dir <path>` | Custom dependencies directory |
| `--verbose` | Detailed output |
| `--quiet` | Minimal output |
| `--dry-run` | Show what would happen without doing it |

#### Examples

```bash
# Pull all missing dependencies
xskill-deps pull

# Check what would be downloaded without doing it
xskill-deps pull --dry-run

# Update single artifact and verify
xskill-deps update superpowers/code-reviewer --verify

# Add new dependency artifact
xskill-deps add \
  --provider superpowers \
  --artifact finishing-a-development-branch \
  --type prompt \
  --path skills/finishing-a-development-branch/SKILL.md \
  --needed-by x-do

# List only missing artifacts
xskill-deps list --missing-only

# Clean orphaned files
xskill-deps clean --dry-run
xskill-deps clean
```

---

## Implementation Plan

### Phase 1: Registry + Pull (Week 1)

**Tasks:**
1. Create `dependencies/registry.json` with current x-skills dependencies
2. Implement `bin/xskill-deps pull` command
3. Add `Read`-based invocation to x-do, x-review, x-bugfix
4. Update `bin/setup` to run `xskill-deps pull` during plugin setup
5. Test with one skill (x-review)

**Files Created:**
- `dependencies/registry.json`
- `bin/xskill-deps`
- `deps/.gitkeep` (placeholder)

**Files Modified:**
- `skills/x-review/steps/step-02-review.md`
- `bin/setup`

### Phase 2: Update + Management (Week 2)

**Tasks:**
1. Implement `update`, `check`, `list` commands
2. Add lock file generation
3. Add SHA verification
4. Create GitHub Action to validate registry on PR
5. Document migration path for skill authors

**Files Created:**
- `.github/workflows/validate-deps.yml`
- `docs/DEPENDENCY_MANAGEMENT.md`

### Phase 3: Add/Remove + Cleanup (Week 3)

**Tasks:**
1. Implement `add`, `remove`, `clean` commands
2. Add `--dry-run` support
3. Create dependency audit in x-skill-review
4. Add update notifications in skill bootstrap

**Files Modified:**
- `skills/x-skill-improve/SKILL.md` (dependency audit)
- `skills/x-do/SKILL.md` (bootstrap check)

### Phase 4: Advanced Features (Week 4+)

**Future enhancements:**
- `xskill-deps diff` — compare local vs upstream
- `xskill-deps fork` — create local override of dependency
- `xskill-deps vendor` — vendor into repo (if needed)
- Automatic update checking on SessionStart
- Dependency conflict detection

---

## Appendix

### A. Alternative Approaches Considered

#### Approach 1: Stub Plugins (Rejected)

Create minimal plugins (`dep-superpowers/`, `dep-oh-my-claudecode/`) with `.claude-plugin/plugin.json` to register custom namespaces.

**Why rejected:**
- Requires plugin registration and `/reload-plugins`
- User must manage plugin conflicts
- Overhead for simple prompt storage
- Namespace system is buggy in Claude Code

#### Approach 2: Companion Skills (Rejected)

Git clone external skills into `~/.claude/skills/` as companion skills.

**Why rejected:**
- Mixes x-skills dependencies with user skills
- No version pinning
- Name collisions possible
- No structured management

#### Approach 3: Vendoring (Rejected)

Store dependency artifacts directly in the x-skills repo.

**Why rejected:**
- Bloats repo with external content
- License compliance issues
- No automatic updates
- Hard to track upstream changes

**Selected approach (flat files + lazy download):**
- ✅ Minimal overhead
- ✅ Version pinned
- ✅ No plugin registration
- ✅ Clean separation
- ✅ Easy to audit

### B. License Compliance

All dependencies tracked in registry include license field. Artifacts are extracted under fair use for interoperability. Users should review licenses before installing.

Recommended licenses for dependencies:
- MIT ✅
- Apache-2.0 ✅
- BSD ✅
- Proprietary ⚠️ (requires explicit approval)

### C. Security Considerations

1. **Source verification:** Registry should use HTTPS only
2. **SHA verification:** Lock file records commit SHAs
3. **No arbitrary code:** Artifacts are markdown only, no scripts executed
4. **Sandboxed:** Dependencies are prompts, not executable code

### D. Troubleshooting

**Dependency not found:**
```bash
# Check if pulled
xskill-deps list --missing-only

# Pull missing
xskill-deps pull

# If still missing, check registry
xskill-deps list --verbose
```

**Wrong version:**
```bash
# Check lock vs registry
xskill-deps check

# Update to latest
xskill-deps update <artifact-path>
```

**Corrupt file:**
```bash
# Force re-download
xskill-deps pull --force

# Or verify and fix
xskill-deps verify --fix
```

---

*Document Version: 1.0.0*
*Last Updated: 2026-05-03*
*Status: Design Complete, Ready for Implementation*
