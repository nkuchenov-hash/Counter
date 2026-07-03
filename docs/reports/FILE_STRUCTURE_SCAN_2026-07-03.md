# File Structure Scan — 2026-07-03

**Scan date:** 2026-07-03 (local)  
**Baseline / tree SHA:** `d7e7c12`  
**Pass type:** Documentation-only — full repo scan vs governing structure docs

---

## Scan method

1. Verified clean baseline: `git status`, `architecture_guard -Strict`, `flutter analyze` (0 errors).
2. Tracked files: `git ls-files` → `docs/reports/_tracked_files.tmp` (gitignored).
3. Working tree: `git status --short` → `docs/reports/_working_tree_status.tmp` (gitignored).
4. Filesystem tree (depth-limited, excludes build caches): `scripts/manual/structure_scan.ps1` → `docs/reports/_structure_tree_snapshot.tmp` (gitignored).
5. Bilingual detailed guide generated: `python scripts/manual/generate_app_structure_detailed.py` → `docs/APP_STRUCTURE_DETAILED.md`.

### Commands

```powershell
git rev-parse --short HEAD
git ls-files
git status --short
.\scripts\audit\architecture_guard.ps1 -Strict
flutter analyze --no-fatal-infos --no-fatal-warnings
.\scripts\manual\structure_scan.ps1
python scripts/manual/generate_app_structure_detailed.py
```

---

## Included paths

| Category | Tracked count | Notes |
| :--- | ---: | :--- |
| **All tracked** | 588 | `git ls-files` |
| `lib/` (all) | 298 | Includes Dart + assets under lib if any |
| `lib/**/*.dart` | 296 | Application source |
| `test/` | 37 | Unit/widget tests |
| `docs/` | 47 | Governing docs + reports |
| `scripts/` | 35 | Audit, deploy, extraction history |
| `assets/` | 0 | No tracked assets at scan time |
| Platform (`android/`, `web/`, …) | (in 588 total) | Build/embedder configs |

### lib/ breakdown (tracked Dart files)

| Path | Files |
| :--- | ---: |
| `lib/data/plans/` | 6 |
| `lib/data/records/` | 8 |
| `lib/data/categories/` | 7 |
| `lib/data/profile/` | 8 |
| `lib/data/local_sync/` | 5 |
| `lib/data/models/` | 7 |
| `lib/data/cache/` | 3 |
| Brain coordinators + helpers | ~25 top-level `lib/data/*.dart` |
| `lib/features/*` | ~120 (all feature UI modules) |
| `lib/core/*` | ~90 (widgets, services, time, diagnostics) |
| `lib/shell/*` | ~12 |
| `lib/l10n/*` | ~12 |
| `lib/services/` | 1 |
| Entry (`main.dart`, `app_shell.dart`) | 2 |

---

## Excluded from detailed file-level docs

| Category | Reason |
| :--- | :--- |
| `.git/` | VCS metadata |
| `.dart_tool/`, `build/`, `.gradle/` caches | Generated / gitignored |
| `android/build/`, `ios/Pods/` | Platform build outputs |
| `docs/reports/_*.tmp` | Ephemeral scan outputs (gitignored) |
| Deep platform boilerplate below depth 3 | Documented at folder level in `APP_STRUCTURE_DETAILED.md` §Platform boilerplate |
| `scripts/__pycache__/` | Python bytecode (not tracked; may appear on disk only) |

---

## Compact tree snapshot (tracked, by top folder)

### `lib/` (296 `.dart` files)

```
lib/main.dart
lib/app_shell.dart
lib/data/database_service.dart          # Brain root + part host
lib/data/db_core.dart
lib/data/plan_service.dart + plans/*    # 6 parts
lib/data/record_service.dart + records/* # 8 parts
lib/data/category_service.dart + categories/* # 7 parts
lib/data/profile_service.dart + profile/*     # 8 parts
lib/data/local_sync/*
lib/data/models/*
lib/features/auth/
lib/features/timeline/
lib/features/stats/
lib/features/planning/ + time_view/ + settings/ + widgets/
lib/features/lists/
lib/features/calendar/
lib/features/categories/
lib/features/profile/
lib/features/dev/
lib/features/wear/
lib/features/shared/ + edit_sheet/
lib/shell/
lib/core/ + widgets/ + services/ + time/ + diagnostics/
lib/l10n/ + langs/
lib/services/notification_service.dart
```

### `test/` (37 files)

Domain tests: plan Time View, desktop voice, timezone, outbox, smart input, widget smoke, perf diagnostics.

### `scripts/` (35 tracked)

- `scripts/audit/architecture_guard.ps1` — structure/import guard (Strict mode)
- `scripts/manual/td.ps1` — deploy (`update.ps1`)
- `scripts/manual/structure_scan.ps1` — tree snapshot helper (**added this scan**)
- `scripts/manual/generate_app_structure_detailed.py` — detailed doc generator (**added this scan**)
- `scripts/sync_locales.dart` — locale sync
- Historical Pass 3/4 extraction scripts (kept for reference; do not re-run blindly)

### `docs/` (47 tracked)

Governing: `ARCHITECTURE.md`, `DATA_MAP.md`, `POCKETBASE_MANIFEST.md`, `UX_CONTRACT.md`, `DESIGN_SYSTEM.md`, `ROADMAP.md`, `APP_STRUCTURE*.md`, decomposition Pass 3–4 reports.

### Platform / CI

- `web/` — GitHub Pages shell
- `android/`, `ios/`, `windows/`, `linux/`, `macos/` — Flutter embedders
- `.github/workflows/` — deploy + Windows installer
- `pb_hooks/` — PocketBase server hooks (JS)
- `installer/windows/` — Inno Setup packaging

---

## Stale docs found and fixed

| Finding | Fix |
| :--- | :--- |
| No `APP_STRUCTURE_DETAILED.md` | **Created** — 296 lib Dart files + tests/scripts/docs with EN/RU entries |
| `APP_STRUCTURE.md` missing Pass 4D status / SHA | **Added** §0 Current status |
| `planning_page.dart` listed as ~2.6k lines | **Updated** to ~2.4k (architecture_guard: 2394) |
| `AGENTS.md` still said E1 profile split pending | **Updated** — Pass 4D complete, Brain parts listed |
| `AGENTS.md` Brain `part` list missing `plans/*`, `records/*`, etc. | **Updated** |
| No scan report / regen commands | **Added** this file + `structure_scan.ps1` + generator script |
| Ephemeral scan `.tmp` files could be staged | **Added** `docs/reports/_*.tmp` to `.gitignore` |

Intentionally **not** rewritten in the 2026-07-03 scan (superseded by final parity pass): intermediate decomposition reports, blueprint, lockdown audit CSV — **removed** 2026-07-03; acceptance summary consolidated in `FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`.

---

## Files intentionally not documented at file level

| Group | Why |
| :--- | :--- |
| Deep `android/**`, `ios/**` Gradle/Xcode generated files | Platform boilerplate; folder-level note in detailed guide |
| `scripts/manual/structure_scan.ps1`, `generate_app_structure_detailed.py` | Documented regen helpers |
| Untracked `build/`, `.dart_tool/` | Gitignored generated output |

Every **tracked** `lib/**/*.dart` file has an entry in `docs/APP_STRUCTURE_DETAILED.md`.

---

## Conclusion

**Docs now match the current tree** as of the final parity pass (baseline SHA `19d794a`):

- Concise map: `docs/APP_STRUCTURE.md`
- Detailed bilingual guide: `docs/APP_STRUCTURE_DETAILED.md` (regenerated after cleanup)
- Russian short guide: `docs/APP_STRUCTURE_EXPLAINED_RU.md`
- Final acceptance: `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`

No production Dart files were modified. No files were moved or renamed.

---

## Regeneration

After the next large structural change:

```powershell
python scripts/manual/generate_app_structure_detailed.py
.\scripts\manual\structure_scan.ps1
# Then manually refresh APP_STRUCTURE.md §0 SHA if needed
```
