#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


# Keep optimistic Paths UI responsive while maintaining a confirmed revision
# snapshot for correct rollback under rapid serialized edits.
page = read("lib/features/paths/paths_page.dart")
state_anchor = """  int? _selectedCategoryId;

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
"""
state_replacement = """  int? _selectedCategoryId;
  final Map<String, ProjectPathSnapshot> _confirmedPaths =
      <String, ProjectPathSnapshot>{};
  final Map<String, int> _saveGenerationByPath = <String, int>{};

  bool get _ru => currentLocale.value.toLowerCase().startsWith('ru');
"""
if state_anchor not in page:
    raise SystemExit("PathsPage state anchor missing")
page = page.replace(state_anchor, state_replacement)

load_anchor = """      setState(() {
        _catalog = catalog;
        _selectedCategoryId = selectedStillExists
            ? _selectedCategoryId
            : (catalog.paths.isEmpty ? null : catalog.paths.first.category.id);
        _loading = false;
      });
"""
load_replacement = """      _confirmedPaths
        ..clear()
        ..addEntries(catalog.paths.map((path) => MapEntry(path.pathId, path)));
      setState(() {
        _catalog = catalog;
        _selectedCategoryId = selectedStillExists
            ? _selectedCategoryId
            : (catalog.paths.isEmpty ? null : catalog.paths.first.category.id);
        _loading = false;
      });
"""
if load_anchor not in page:
    raise SystemExit("PathsPage load anchor missing")
page = page.replace(load_anchor, load_replacement)

save_anchor = """  Future<void> _saveOptimistic(
    ProjectPathSnapshot before,
    ProjectPathSnapshot after,
  ) async {
    _replaceLocal(after);
    final ok = await _repository.saveActivePath(after);
    if (ok || !mounted) return;

    _replaceLocal(before);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _ru
                ? 'Не удалось сохранить изменение пути.'
                : 'Could not save the Path change.',
          ),
        ),
      );
  }
"""
save_replacement = """  Future<void> _saveOptimistic(
    ProjectPathSnapshot before,
    ProjectPathSnapshot after,
  ) async {
    final generation = (_saveGenerationByPath[after.pathId] ?? 0) + 1;
    _saveGenerationByPath[after.pathId] = generation;
    _confirmedPaths.putIfAbsent(after.pathId, () => before);
    _replaceLocal(after);

    final saved = await _repository.saveActivePath(after);
    if (!mounted) return;
    if (saved != null) {
      _confirmedPaths[after.pathId] = saved;
      if (_saveGenerationByPath[after.pathId] == generation) {
        _replaceLocal(saved);
      }
      return;
    }

    // A newer optimistic edit owns the visible state and its queued save. Only
    // the latest failed save rolls UI back to the last server-confirmed revision.
    if (_saveGenerationByPath[after.pathId] != generation) return;
    _replaceLocal(_confirmedPaths[after.pathId] ?? before);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _ru
                ? 'Не удалось сохранить изменение пути.'
                : 'Could not save the Path change.',
          ),
        ),
      );
  }
"""
if save_anchor not in page:
    raise SystemExit("PathsPage save anchor missing")
page = page.replace(save_anchor, save_replacement)
write("lib/features/paths/paths_page.dart", page)

# The governing PocketBase manifest must cover every literal app-owned collection,
# including the already-shipped closed server collections discovered by the new gate.
manifest = read("docs/POCKETBASE_MANIFEST.md")
relation_anchor = "| **path_revisions** | `user_id` | `profiles.id` | **Owner** | Append-only Path snapshots; project linkage by stable `path_id`. |"
if relation_anchor not in manifest:
    raise SystemExit("Path relation manifest anchor missing")
if "| **sleep_sync_connections** |" not in manifest:
    manifest = manifest.replace(
        relation_anchor,
        relation_anchor
        + "\n| **sleep_sync_connections** | `user_id` | `profiles.id` | **Owner (server-only)** | Closed collection for encrypted Google Fit connection/sync state; clients use `/api/sleep-sync/*`. |"
        + "\n| **calendar_integrations** | `user_id` | `profiles.id` | **Owner (server-only)** | Closed Microsoft/Google calendar connection state; clients use `/api/calendar-integrations/*`. |",
    )

server_sections = """
### 4.8 `sleep_sync_connections` (server-owned)

Created by `pb_migrations/1785390000_server_sleep_sync.js`. Direct client collection rules are closed; authenticated Flutter uses the app-owned `/api/sleep-sync/*` routes.

| Field | Type | Notes |
| :--- | :--- | :--- |
| `user_id` | relation | → `profiles.id`; cascade delete. |
| `provider` | select | `google_fit`; unique together with owner. |
| `enabled` | bool | Background sync enabled. |
| `daily_sync_minutes` | integer | Profile-local minute of day, 0–1439. |
| `status` | select | `disconnected` / `connecting` / `connected` / `syncing` / `error`. |
| `refresh_token_enc`, `access_token_enc` | text | Server-encrypted OAuth credentials; never exposed as client data. |
| `access_token_expires_at` | date | OAuth token expiry. |
| `oauth_state`, `oauth_state_expires_at` | text/date | OAuth handshake state. |
| `last_sync_at`, `last_sync_local_day` | date/text | Last completed server sync. |
| `last_session_count`, `last_imported_count` | integer | Last sync diagnostics. |
| `last_error` | text | Bounded server diagnostic. |

The same migration adds `records.sleep_source` and `records.sleep_external_id` plus a partial unique owner/source/external-id index for idempotent imported sleep.

### 4.9 `calendar_integrations` (server-owned)

Created by `pb_migrations/1785960000_calendar_integrations.js`. Direct client collection rules are closed; authenticated Flutter uses `/api/calendar-integrations/*` routes.

| Field | Type | Notes |
| :--- | :--- | :--- |
| `user_id` | relation | → `profiles.id`; cascade delete. |
| `provider` | select | `microsoft` / `google`; unique together with owner. |
| `account_id`, `account_label` | text | Provider account identity/display label. |
| `enabled` | bool | Integration enabled. |
| `status` | select | `disconnected` / `connecting` / `connected` / `syncing` / `error`. |
| `calendars_json` | JSON | Selected calendars and per-calendar settings/fallbacks. |
| `sync_past_days`, `sync_future_days` | integer | Bounded server sync window. |
| `refresh_token_enc`, `access_token_enc` | text | Server-encrypted OAuth credentials. |
| `access_token_expires_at` | date | OAuth token expiry. |
| `oauth_state`, `oauth_state_expires_at` | text/date | OAuth handshake state. |
| `last_sync_at` | date | Last completed provider sync. |
| `last_error` | text | Bounded server diagnostic. |

The migration also adds the `plans.external_*` fields documented in `docs/CALENDAR_INTEGRATIONS.md` and a partial unique provider-occurrence index.

"""
if "### 4.8 `sleep_sync_connections`" not in manifest:
    marker = "---\n\n## 5. API rules"
    if marker not in manifest:
        raise SystemExit("PocketBase manifest API-rules anchor missing")
    manifest = manifest.replace(marker, server_sections + marker)
write("docs/POCKETBASE_MANIFEST.md", manifest)

# Future-proof PocketBase JS validation: every tracked hook/migration is syntax
# checked automatically instead of maintaining a fragile hand-written file list.
workflow = read(".github/workflows/deploy-pocketbase.yml")
start = workflow.find("      - name: Validate PocketBase JavaScript\n")
end = workflow.find("\n      - name: Check production deploy credentials", start)
if start < 0 or end < 0:
    raise SystemExit("deploy-pocketbase validation block not found")
validation = """      - name: Validate all PocketBase JavaScript
        shell: bash
        run: |
          mapfile -d '' files < <(find pb_hooks pb_migrations -type f -name '*.js' -print0 | sort -z)
          if (( ${#files[@]} == 0 )); then
            echo 'No PocketBase JavaScript files found.' >&2
            exit 1
          fi
          for file in "${files[@]}"; do
            echo "node --check $file"
            node --check "$file"
          done
"""
workflow = workflow[:start] + validation.rstrip() + workflow[end:]
write(".github/workflows/deploy-pocketbase.yml", workflow)

# Deployment docs must describe the actual automated production path.
deploy = read("docs/DEPLOY.md")
manual = """## PocketBase schema migrations

`pb_migrations/` is version-controlled server schema/data history. Before releasing a client commit that introduces a new PocketBase collection/field contract:

1. Copy the new migration files beside the production PocketBase executable (default `pb_migrations/` directory).
2. Apply them with `pocketbase migrate up` or restart `pocketbase serve` (unapplied migrations run automatically).
3. Only after migration success deploy Web/APK/Desktop clients that depend on that schema.

For durable Paths, `1787076000_durable_paths.js` must be applied before a client using `PbCollections.paths` / `PbCollections.pathRevisions` is considered release-complete.
"""
automated = """## PocketBase schema migrations

`pb_migrations/` is version-controlled server schema/data history. `.github/workflows/deploy-pocketbase.yml` syntax-checks **every** tracked `pb_hooks/**/*.js` and `pb_migrations/**/*.js` on pull requests. On push to `main` that changes either directory, the production job uploads the complete hooks+migrations bundle and restarts PocketBase; PocketBase applies unapplied migrations during startup before the new client release uses the schema.

For durable Paths, `1787076000_durable_paths.js` creates/imports the server schema. The PR validates it; merging the migration to `main` triggers the existing production PocketBase deployment before normal client use of `PbCollections.paths` / `PbCollections.pathRevisions`.
"""
if manual in deploy:
    deploy = deploy.replace(manual, automated)
elif "## PocketBase schema migrations" not in deploy:
    deploy += "\n\n" + automated
write("docs/DEPLOY.md", deploy)

print("durable_paths_followup: applied")
