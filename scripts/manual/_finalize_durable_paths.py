#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8-sig")


def write(path: str, body: str) -> None:
    (ROOT / path).write_text(body.rstrip() + "\n", encoding="utf-8", newline="\n")


def replace_required(path: str, old: str, new: str) -> None:
    body = read(path)
    if old not in body:
        raise SystemExit(f"required anchor missing in {path}: {old[:140]!r}")
    write(path, body.replace(old, new))


# DatabaseService remains the single PocketBase I/O owner; Paths persistence is a part.
replace_required(
    "lib/data/database_service.dart",
    "part 'profile_service.dart';\npart 'plans/plan_projection_types.dart';",
    "part 'profile_service.dart';\npart 'paths/path_service.dart';\npart 'plans/plan_projection_types.dart';",
)

# Paths UI no longer exposes old plan-root duplicate diagnostics because durable
# schema enforces one Path per owner/category.
paths_page = read("lib/features/paths/paths_page.dart")
paths_page = paths_page.replace(
    "PathCatalogSnapshot _catalog = const PathCatalogSnapshot(\n    paths: <ProjectPathSnapshot>[],\n    duplicateActiveRootCategoryIds: <int>{},\n  );",
    "PathCatalogSnapshot _catalog = const PathCatalogSnapshot(\n    paths: <ProjectPathSnapshot>[],\n  );",
)
paths_page = paths_page.replace(
    "      () => _catalog = PathCatalogSnapshot(\n        paths: next,\n        duplicateActiveRootCategoryIds: _catalog.duplicateActiveRootCategoryIds,\n      ),",
    "      () => _catalog = PathCatalogSnapshot(paths: next),",
)
paths_page = paths_page.replace(
    "    final duplicate = _catalog.duplicateActiveRootCategoryIds.contains(\n      path.category.id,\n    );\n",
    "",
)
old_warning = """        if (duplicate) ...[\n          const SizedBox(height: 14),\n          _warningCard(\n            _ru\n                ? 'Для этого проекта найдено несколько активных корневых записей старого формата. Экран ничего не удаляет автоматически; нужен отдельный безопасный ремонт данных.'\n                : 'Multiple active old-format root rows were detected for this project. The screen does not delete anything automatically; an explicit safe repair is required.',\n          ),\n        ],\n"""
paths_page = paths_page.replace(old_warning, "")
write("lib/features/paths/paths_page.dart", paths_page)

# The giant mixed compatibility/governance runtime is replaced by server migration
# history plus the canonical repository/Planner bridge.
compat = ROOT / "lib/data/paths/compatibility/path_governance_service.dart"
if not compat.exists():
    raise SystemExit("compatibility service unexpectedly missing")
compat.unlink()
compat_dir = compat.parent
try:
    compat_dir.rmdir()
except OSError:
    pass

# Canonical physical map.
structure = read("docs/APP_STRUCTURE.md")
structure = structure.replace(
    "| **Structure baseline SHA** | `dbba57d` (final structure audit + Structure Growth Law) |",
    "| **Structure baseline** | Live `main`; guarded by Architecture Guard + documentation parity + repository hygiene + PocketBase schema parity |",
)
structure = structure.replace(
    "| **Structure audit verdict** | **ACCEPTED WITH WATCHLIST** — see [`docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md`](reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md) |",
    "| **Structure audit verdict** | **STRICT PARITY** — zero accepted structural drift; historical audit reports remain historical records only |",
)
structure = structure.replace(
    "| **Paths ownership** | 2026-08-18: first-class UI under `lib/features/paths/`; Path repository + marker-era compatibility/governance under `lib/data/paths/`; shell owns navigation only; opening Paths performs no migration or Planner generation |",
    "| **Paths ownership** | 2026-08-18: durable revisions under dedicated PocketBase `paths` / `path_revisions`; domain in `lib/data/paths/`; the only Path → Planner boundary is `lib/data/plans/path_planner_bridge.dart`; shell owns navigation only |",
)
structure = structure.replace(
    "**Brain rule:** `lib/data/database_service.dart` is the only file that performs HTTP/PocketBase calls. Domain logic lives in `part of` extensions (`db_core.dart`, `record_service.dart`, `records/*`, `plan_service.dart`, `plans/*`, `category_service.dart`, `categories/*`, `profile_service.dart`, `profile/*`) plus focused domain adapters such as `paths/path_repository.dart` that delegate persistence to existing Brain APIs.",
    "**Brain rule:** `lib/data/database_service.dart` and its `part of` extensions are the only files that perform HTTP/PocketBase calls. Domain logic lives in focused repositories/services; `paths/path_repository.dart` delegates durable persistence to `paths/path_service.dart` (a DatabaseService part).",
)
structure = structure.replace(
    "| `app/shell/shared/shell_lifecycle.dart` | Shell startup/dispose wiring; delegates Planning baseline to `PlannerStartupService` and does not import Paths compatibility *(part)* |",
    "| `app/shell/shared/shell_lifecycle.dart` | Shell startup/dispose wiring; delegates Planning baseline to `PlannerStartupService`; no Path migration/governance runs from shell startup *(part)* |",
)
structure = structure.replace(
    "Compatibility re-exports (remove when callers migrate): root `lib/app_shell.dart`, `core/navigation/shell_side_navigation.dart`, `app/shell/shared/settings_page.dart`.",
    "Compatibility entry surface retained intentionally: root `lib/app_shell.dart` is a thin re-export of the canonical shell root.",
)
structure = structure.replace(
    "| `plans/planner_startup_service.dart` | Planning-owned startup baseline: category refresh, daily routine ensure, and isolated historical Path-generated-row cleanup |",
    "| `plans/planner_startup_service.dart` | Planning-owned startup baseline: category refresh + daily routine ensure only; no Paths migration or scheduling side effects |\n| `plans/path_planner_bridge.dart` | Sole Path → Planner boundary: exposes executable actions from the active durable revision; Planner alone owns scheduling/materialization |",
)
structure = structure.replace(
    "| `paths/path_repository.dart` | First-class Path domain boundary: transition storage interpretation, explicit Path/stage/action snapshots, duplicate-root reporting, generic structure audit, writes delegated to existing Brain plan APIs |\n| `paths/compatibility/path_governance_service.dart` | Compatibility-era project-specific Paths governance/migrations; exposes a cleanup hook but is not a shell startup dependency |",
    "| `paths/path_models.dart` | Path lifecycle, immutable revision snapshot types, stages/actions, project-independent structure audit |\n| `paths/path_repository.dart` | Durable Path revision orchestration; reads active revision pointer and publishes append-only revisions through Brain persistence |\n| `paths/path_service.dart` | PocketBase `paths` / `path_revisions` persistence *(part of DatabaseService)* |",
)
# Add migration root if not already present.
if "| `pb_migrations/` |" not in structure:
    structure = structure.replace(
        "| `pb_hooks/` | PocketBase server hooks (JS) |",
        "| `pb_migrations/` | PocketBase schema/data migrations | Versioned server migrations; applied before client release |\n| `pb_hooks/` | PocketBase server hooks (JS) |",
    )
write("docs/APP_STRUCTURE.md", structure)

# Architecture law: durable Path revisions are the normal state, not a transition.
architecture = read("docs/ARCHITECTURE.md")
architecture = architecture.replace(
    "| `lib/data/paths/` | **Path domain** | `PathRepository` owns first-class Path interpretation and generic validation. Current storage is an adapter over existing plan-backed Path rows; marker-era Path → Planner compatibility is isolated under `paths/compatibility/`; feature UI and shell must not parse marker rows directly. |",
    "| `lib/data/paths/` | **Path domain** | Durable Path models/revisions + repository; PocketBase I/O is `path_service.dart` as a DatabaseService part. No project-specific templates, Planner scheduling, or marker parsing. |",
)
architecture = architecture.replace(
    "- **PATH_DOMAIN_OWNERSHIP:** Paths is a first-class domain: feature UI lives in `lib/features/paths/`; storage interpretation and validation live in `lib/data/paths/`; shell owns navigation only. New Paths code must not parse `LIFEOS_PATH::*` markers directly outside the compatibility repository/migration layer.",
    "- **PATH_DOMAIN_OWNERSHIP:** Paths is a first-class domain: feature UI lives in `lib/features/paths/`; models/revision orchestration live in `lib/data/paths/`; PocketBase I/O stays in the DatabaseService part `paths/path_service.dart`; shell owns navigation only. Runtime marker parsing and project-specific Path templates are forbidden.",
)
architecture = architecture.replace(
    "- **ACTIVE_PATH_GATE:** Planner may consume only an explicitly active/published Path revision. Draft/review proposals must not leak into the executable schedule. Current marker-backed storage is compatibility only until durable Path revision storage ships.",
    "- **ACTIVE_PATH_GATE:** `paths.active_revision_id` is the sole executable revision pointer. Planner may consume only that revision through `PathPlannerBridge`; draft/review/unreferenced published revisions never leak into the schedule.",
)
architecture = architecture.replace(
    "- The current `PathRepository` is a compatibility adapter over existing plan-backed Path roots; this does **not** redefine `plans` as the permanent Path schema.\n- Marker-era audit and Path-action → Planner orchestration is transitional Brain logic under `lib/data/paths/compatibility/`; it is never a shell/page-open responsibility and must disappear when durable Path revisions + the explicit Planner bridge replace it.\n- Opening Paths is read-only. User edits are explicit and local-first; migration/repair/publish/scheduling are separate operations.\n- Planner generation must be idempotent and traceable to one active Path revision so revising a draft cannot silently reschedule the user.",
    "- Durable project identity lives in PocketBase `paths`; append-only snapshots live in `path_revisions`. `plans` is not Path storage.\n- `paths.active_revision_id` selects one executable revision; editing an active Path writes a new revision before switching the pointer.\n- Opening Paths is read-only. User edits publish explicit revisions; schema/data migration is server-owned under `pb_migrations/`; scheduling is Planner-owned.\n- Every Path → Planner flow must enter through `lib/data/plans/path_planner_bridge.dart`, whose source tuple is `path_id + revision_id + action_id`; direct Path scheduling elsewhere is forbidden.\n- Project names/content are data, never runtime architecture. No KADR/GOLOS/Игропоиск/etc. bootstrap profiles may live in `lib/data/paths/`.",
)
write("docs/ARCHITECTURE.md", architecture)

# PocketBase manifest: collections, security, migration order.
manifest = read("docs/POCKETBASE_MANIFEST.md")
manifest = manifest.replace(
    "- **Child collections** (`records`, `categories`, `plans`, `tags`, …) store **`user_id` as a Relation** to **`profiles.id`** (same 15-char value), not arbitrary UUIDs in new rows.",
    "- **Child collections** (`records`, `categories`, `plans`, `tags`, `paths`, `path_revisions`, …) store **`user_id` as a Relation** to **`profiles.id`** (same 15-char value), not arbitrary UUIDs in new rows.",
)
manifest = manifest.replace(
    "| **categories** | `user_id` | `profiles.id` | **Owner** | Same ownership pattern. |",
    "| **categories** | `user_id` | `profiles.id` | **Owner** | Same ownership pattern. |\n| **paths** | `user_id` | `profiles.id` | **Owner** | Stable Path/project identity + single `active_revision_id` execution pointer. |\n| **path_revisions** | `user_id` | `profiles.id` | **Owner** | Append-only Path snapshots; project linkage by stable `path_id`. |",
)
path_sections = """
### 4.6 `paths`

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | PocketBase row id. |
| `user_id` | relation | → `profiles.id`; tenant owner. |
| `path_id` | text | Stable business identity; unique per owner. |
| `category_id` | integer | LIFE OS category business id; one Path per owner/category. |
| `title` | text | Project display title snapshot. |
| **`active_revision_id`** | text | **Only executable revision pointer.** Must reference this Path's business `revision_id`. |
| `archived` | bool | Archived Paths are excluded from normal repository reads. |

### 4.7 `path_revisions`

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | PocketBase row id. |
| `user_id` | relation | → `profiles.id`; tenant owner. |
| `path_id` | text | Parent Path business id. |
| `revision_id` | text | Immutable business revision id; unique within owner/path. |
| `version` | integer | Monotonic revision number per Path. |
| `lifecycle` | select | `draft` / `reviewed` / `published`; publication alone does not execute it — `paths.active_revision_id` does. |
| `goal` | text | Revision goal/end state. |
| `content` | JSON | Ordered `stages[]`, each with completion criteria and executable `actions[]`. |
| `source` | select | `manual` / `migration` / `ai` / `system`. |
| `parent_revision_id` | text | Previous revision business id when applicable. |

**Immutability:** client API has no update rule for `path_revisions`. Edit = create next revision, then switch `paths.active_revision_id`. If pointer update fails, the unreferenced revision is non-executable and may be deleted safely.

"""
if "### 4.6 `paths`" not in manifest:
    manifest = manifest.replace("---\n\n## 5. API rules", path_sections + "---\n\n## 5. API rules")
manifest = manifest.replace(
    "- **Authenticated-only** mutations: **Create / Update / Delete** on `records`, `plans`, `categories`, `tags` require **`@request.auth.id != \"\"`** (or stricter).\n- **List / View** on those collections: restrict rows to the current user (e.g. **`user_id = @request.auth.id`** on the row’s relation).",
    "- **Authenticated-only** mutations: **Create / Update / Delete** on `records`, `plans`, `categories`, `tags`, `paths`, `path_revisions` require **`@request.auth.id != \"\"`** (or stricter).\n- **List / View** on those collections: restrict rows to the current user (e.g. **`user_id = @request.auth.id`** on the row’s relation).\n- **Path revisions:** client update is forbidden; revision snapshots are append-only. Only `paths.active_revision_id` activates a revision.",
)
if "### 5.4 `paths` / `path_revisions`" not in manifest:
    manifest = manifest.replace(
        "---\n\n## 6. Client (Brain) obligations",
        "### 5.4 `paths` / `path_revisions`\n\n- `user_id` must equal `@request.auth.id` on create and remain unchanged.\n- `path_revisions` are immutable through client update rules.\n- `paths.active_revision_id` is the sole active gate; no draft/review row may be consumed by Planner merely because it exists.\n- Owner + `path_id` and owner + category are unique for `paths`; owner + path + revision/version are unique for revisions.\n\n---\n\n## 6. Client (Brain) obligations",
    )
if "## 6.1 PocketBase migrations" not in manifest:
    manifest = manifest.replace(
        "---\n\n## 7. UI & performance laws",
        "\n### 6.1 PocketBase migrations\n\nVersioned server schema/data migrations live in **`pb_migrations/`** and are part of the release contract. Apply them before deploying a client that depends on the new schema. `1787076000_durable_paths.js` creates `paths` / `path_revisions` and imports existing `LIFEOS_PATH::V2` roots deterministically without mutating the source rows.\n\n---\n\n## 7. UI & performance laws",
    )
write("docs/POCKETBASE_MANIFEST.md", manifest)

# Field vocabulary.
data_map = read("docs/DATA_MAP.md")
path_map = """

## Paths — durable revision vocabulary

Paths are no longer encoded as Planner rows. Server schema is governed by `docs/POCKETBASE_MANIFEST.md` and `pb_migrations/`.

| Collection | Field | Meaning |
| :--- | :--- | :--- |
| `paths` | `path_id` | Stable Path/project business id. |
| `paths` | `category_id` | LIFE OS category business id attached to the project. |
| `paths` | `active_revision_id` | Sole revision permitted to feed Planner. |
| `paths` | `archived` | Path lifecycle archive flag. |
| `path_revisions` | `revision_id` | Immutable revision business id. |
| `path_revisions` | `version` | Monotonic revision number. |
| `path_revisions` | `lifecycle` | `draft`, `reviewed`, or `published`; not an execution gate by itself. |
| `path_revisions` | `goal` | Desired project end state for the revision. |
| `path_revisions` | `content.stages[]` | Ordered stages, completion criteria, actions and expected results. |
| `path_revisions` | `source` | `manual`, `migration`, `ai`, or `system`. |
| `path_revisions` | `parent_revision_id` | Previous revision business id. |

**Path → Planner source identity:** `path_id + revision_id + action_id`. Scheduling/materialization belongs only to `lib/data/plans/path_planner_bridge.dart` and downstream Planning code.
"""
if "## Paths — durable revision vocabulary" not in data_map:
    data_map += path_map
write("docs/DATA_MAP.md", data_map)

# Deployment must apply server migrations first.
deploy = read("docs/DEPLOY.md")
release_section = """

## PocketBase schema migrations

`pb_migrations/` is version-controlled server schema/data history. Before releasing a client commit that introduces a new PocketBase collection/field contract:

1. Copy the new migration files beside the production PocketBase executable (default `pb_migrations/` directory).
2. Apply them with `pocketbase migrate up` or restart `pocketbase serve` (unapplied migrations run automatically).
3. Only after migration success deploy Web/APK/Desktop clients that depend on that schema.

For durable Paths, `1787076000_durable_paths.js` must be applied before a client using `PbCollections.paths` / `PbCollections.pathRevisions` is considered release-complete.
"""
if "## PocketBase schema migrations" not in deploy:
    deploy += release_section
write("docs/DEPLOY.md", deploy)

# Agent navigation gets a canonical Path routing row without old compatibility language.
nav = read("AGENT_NAVIGATION.md")
if "**Paths domain**" not in nav:
    anchor = "| **PB — plans & lists** | `lib/data/plan_service.dart` |"
    idx = nav.find(anchor)
    if idx >= 0:
        line_end = nav.find("\n", idx)
        row = "\n| **Paths domain** | `lib/data/paths/path_models.dart`, `path_repository.dart`, `path_service.dart` | Durable revisions; `paths.active_revision_id` is the active gate |\n| **Path → Planner** | `lib/data/plans/path_planner_bridge.dart` | Sole executable projection boundary; no scheduling from Paths UI/domain |"
        nav = nav[:line_end] + row + nav[line_end:]
write("AGENT_NAVIGATION.md", nav)

# Architecture guard: make the final Path boundary non-regressible.
guard = read("scripts/audit/architecture_guard.ps1")
path_guard = r'''
# --- 8b. Durable Paths ownership (hard structural law) ---
$pathCompatDir = Get-RepoPath @('lib', 'data', 'paths', 'compatibility')
if (Test-Path -LiteralPath $pathCompatDir) {
    Add-Violation "PATH_COMPATIBILITY_REGRESSION lib/data/paths/compatibility must not return"
}

$pathMarkerLeaks = Find-DartFilesMatching 'lib' 'LIFEOS_PATH::|LIFEOS_PATH_ACTION|LIFEOS_WEEK_ROUTINE'
foreach ($rel in $pathMarkerLeaks) {
    Add-Violation "PATH_MARKER_RUNTIME_LEAK $rel"
}

$pathToPlannerImports = Find-DartFilesMatching 'lib/data/paths' "import 'package:counter/data/plans/"
foreach ($rel in $pathToPlannerImports) {
    Add-Violation "PATH_DOMAIN_IMPORTS_PLANNER $rel"
}

$plannerPathImports = Find-DartFilesMatching 'lib/data/plans' "import 'package:counter/data/paths/"
foreach ($rel in $plannerPathImports) {
    if ($rel -ne 'lib/data/plans/path_planner_bridge.dart') {
        Add-Violation "PATH_PLANNER_BRIDGE_BYPASS $rel"
    }
}

$projectSpecificPathLeaks = Find-DartFilesMatching 'lib/data/paths' '(?i)KADR|КАДР|GOLOS|Игропоиск|Igropoisk|Price Reporter|Etnika|ZenMoney'
foreach ($rel in $projectSpecificPathLeaks) {
    Add-Violation "PATH_PROJECT_TEMPLATE_LEAK $rel"
}

$pathRepositoryBody = Get-Content -LiteralPath (Get-RepoPath @('lib','data','paths','path_repository.dart')) -Raw
if ($pathRepositoryBody -match 'PocketBase|\.collection\(') {
    Add-Violation "PATH_REPOSITORY_DIRECT_PB_IO path_repository.dart must delegate to DatabaseService path_service part"
}

$pathServiceBody = Get-Content -LiteralPath (Get-RepoPath @('lib','data','paths','path_service.dart')) -Raw
if ($pathServiceBody -notmatch "part of '../database_service.dart';") {
    Add-Violation "PATH_SERVICE_NOT_DATABASE_PART lib/data/paths/path_service.dart"
}
'''
if "# --- 8b. Durable Paths ownership" not in guard:
    guard = guard.replace("# --- Report ---", path_guard + "\n# --- Report ---")
write("scripts/audit/architecture_guard.ps1", guard)

workflow = read(".github/workflows/architecture-guard.yml")
if "pocketbase_schema_contract.py" not in workflow:
    workflow = workflow.replace(
        "      - name: Check repository hygiene\n        run: python scripts/audit/repository_hygiene.py",
        "      - name: Check repository hygiene\n        run: python scripts/audit/repository_hygiene.py\n\n      - name: Check PocketBase schema parity\n        run: python scripts/audit/pocketbase_schema_contract.py\n\n      - name: Check PocketBase migration syntax\n        run: node --check pb_migrations/1787076000_durable_paths.js",
    )
write(".github/workflows/architecture-guard.yml", workflow)

# Changelog.
changelog = read("CHANGELOG.md")
entry = """## 2026-08-18 — Durable Paths architecture [engineering]\n\n- Replaced plan-backed Path runtime compatibility with dedicated PocketBase `paths` + immutable `path_revisions` and a versioned server migration that imports existing V2 roots.\n- Added `path_models.dart`, DatabaseService-owned `path_service.dart`, append-only `PathRepository` revision publishing, and Planning-owned `path_planner_bridge.dart`.\n- Removed the mixed project-specific `path_governance_service.dart`; Planner startup no longer performs Path cleanup/migration.\n- Added hard Architecture Guard laws for Path ownership/marker leakage/project-specific runtime templates and a PocketBase schema parity guard.\n\n"""
if not changelog.startswith("## 2026-08-18 — Durable Paths architecture"):
    changelog = entry + changelog
write("CHANGELOG.md", changelog)

print("durable_paths_finalize: applied")
