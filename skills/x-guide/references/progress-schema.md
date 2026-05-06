# progress.json Schema — Reference

## Top-level fields

| Field | Type | Required | Description |
|---|---|---|---|
| `slug` | string | yes | kebab-case topic slug; matches `.x-guide/<slug>/` |
| `source` | object | yes | See Source object |
| `parts` | array | yes | Ordered list of Part objects |
| `current` | integer or null | yes | 1-based index into `parts` of the active part; `null` after WRAP |
| `started_at` | ISO 8601 string | yes | When Phase 3 first ran |
| `completed_at` | ISO 8601 string or null | yes | Set by WRAP; `null` until then |
| `level_default` | string | yes | Always `"mid"` in v1 |
| `version` | integer | yes | Schema version; v1 is `1` |

## Source object

| Field | Type | Required | Values |
|---|---|---|---|
| `type` | string | yes | `file` / `dir` / `url` / `paste` / `vague` |
| `ref` | string | yes | path / URL / `(pasted)` literal / vague phrase verbatim |
| `ingest_method` | string | yes | `claude-direct` / `x-gemini` / `x-research` |
| `ingested_at` | ISO 8601 string | yes | When `_ingest.md` was written (or when Phase 2 completed for `claude-direct`) |

## Part object

| Field | Type | Required | Values |
|---|---|---|---|
| `n` | integer | yes | 1-based part index, matches array position |
| `title` | string | yes | Part title (matches `## Part N: <title>` in GUIDE.md) |
| `status` | string | yes | `pending` / `current` / `done` / `skipped` |
| `level_used` | string or null | yes | `null` until first render, then `mid` / `deeper` / `simpler` |
| `completed_at` | ISO 8601 string or null | yes | Set when `status` first becomes `done`; `null` for skipped |

## Validation Rules

1. `parts.length >= 5 AND parts.length <= 15` after Phase 3 (or after `rewrite outline`).
2. Exactly zero or one `parts[i].status == "current"`.
3. If `completed_at` on top level is non-null, every part is `done` or `skipped` and `current` is `null`.
4. `parts[i].n == i + 1` for all `i` (no gaps).

## Example

```json
{
  "slug": "auth-flow",
  "source": {
    "type": "file",
    "ref": "src/auth.ts",
    "ingest_method": "claude-direct",
    "ingested_at": "2026-05-06T20:14:00Z"
  },
  "parts": [
    {"n": 1, "title": "Token shape", "status": "done", "level_used": "mid", "completed_at": "2026-05-06T20:18:00Z"},
    {"n": 2, "title": "Verify path", "status": "done", "level_used": "deeper", "completed_at": "2026-05-06T20:25:00Z"},
    {"n": 3, "title": "Refresh", "status": "current", "level_used": null, "completed_at": null},
    {"n": 4, "title": "Edge cases", "status": "pending", "level_used": null, "completed_at": null}
  ],
  "current": 3,
  "started_at": "2026-05-06T20:00:00Z",
  "completed_at": null,
  "level_default": "mid",
  "version": 1
}
```
