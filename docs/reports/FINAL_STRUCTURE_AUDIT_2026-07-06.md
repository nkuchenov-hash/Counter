# Final Structure Audit — 2026-07-06

**Project:** Counter / Life OS (Flutter + PocketBase)  
**Scope:** Repository inventory, architecture boundaries, long-file risk, duplicate-responsibility watchlist, documentation parity, permanent Structure Growth Law.  
**Pass type:** Audit + documentation law only — **no production Dart moves, no refactors, no deletions.**

**Baseline SHA at audit start:** `db079b0` · **Post-audit commit:** `dbba57d`

---

## 1. Audit scope

| In scope | Out of scope |
| :--- | :--- |
| Tracked vs ignored inventory | Production behavior changes |
| `architecture_guard.ps1 -Strict` | File moves / splits |
| Import-boundary grep | Feature implementation |
| Long-file line counts | HTML deploy / `update.ps1` |
| Doc parity vs tracked tree | PocketBase schema changes |
| Structure Growth Law in governing docs | Deleting repo files |

**Governing docs read:** `docs/APP_STRUCTURE.md`, `docs/APP_STRUCTURE_DETAILED.md`, `docs/ARCHITECTURE.md`, `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/DEPLOY.md`, `AGENTS.md`, `AGENT_NAVIGATION.md` (legacy `CLAUDE.md` renamed 2026-07-03), `CHANGELOG.md`, `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`.

---

## 2. Commands run

| Command | Result |
| :--- | :--- |
| `git status --short` | Clean working tree at audit start (no unstaged product changes) |
| `git ls-files` | **538** tracked paths |
| `git status --ignored --short` | **31** ignored roots/paths (see §3) |
| `architecture_guard.ps1 -Strict` | **0 violations**, 6 warnings (2 large files, 4 RAW_UI counts) |
| Manual grep: `lib/data` → `features/` | **0 matches** |
| Manual grep: `lib/core` → `features/` | **0 matches** |
| Manual grep: relative `../` imports in `lib/` | **0 matches** |
| Manual grep: `package:pocketbase` in `lib/` | **2 files** — `database_service.dart`, `auth_bridge.dart` (Brain/auth only) |
| Manual grep: Flutter → `pb_hooks/` | **0 matches** |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Run at verification (§8) |
| `flutter test` | Run at verification (§8) |
| `python scripts/manual/generate_app_structure_detailed.py` | Run after doc changes (§8) |

---

## 3. Repository inventory summary

### 3.1 Tracked files by category

| Category | Count (paths) | Notes |
| :--- | ---: | :--- |
| `lib/` app source | 298 | Brain, core, features, shell, l10n, services |
| Platform (`android`, `ios`, `web`, `windows`, `linux`, `macos`) | 127 | Flutter embedders + resources |
| `test/` + `integration_test/` | 37 | Unit/widget tests |
| `docs/` | 26 | Governing + reports + website copy |
| `scripts/` | 25 | Audit, deploy, structure generators |
| `installer/` | 6 | Windows Inno Setup + STT helper binary |
| `pb_hooks/` | 2 | Server-side PocketBase hooks |
| Root / other | 17 | `pubspec.*`, `AGENTS.md`, workflows, etc. |

### 3.2 Top-level inventory table

| Path | Tracked / ignored / untracked | Category | Should exist? | Action needed? |
| :--- | :--- | :--- | :--- | :--- |
| `lib/` | tracked | App source | Yes | None — canonical product code |
| `test/`, `integration_test/` | tracked | Tests | Yes | None |
| `docs/` | tracked | Docs | Yes | Keep governing docs in sync after tree changes |
| `scripts/` | tracked | Tooling | Yes | None |
| `pb_hooks/` | tracked | Server hooks | Yes | Deploy beside PocketBase on VPS; not imported by Flutter |
| `android/`, `ios/`, `web/`, `windows/`, `linux/`, `macos/` | tracked | Platform wrapper | Yes | None — no product logic absorption |
| `installer/` | tracked | Windows installer | Yes | `counter_stt_helper.exe` is large binary — intentional for setup payload |
| `.github/` | tracked | CI | Yes | Matches `docs/DEPLOY.md` GitHub Pages workflow |
| `pubspec.yaml`, `pubspec.lock` | tracked | Dependencies | Yes | None |
| `CHANGELOG.md` | tracked | History | Yes | Append on shipped sessions |
| `.cursor/`, `.cursorrules` | tracked | AI rules | Yes | Optional for runtime; keep for Cursor |
| `.dart_tool/` | ignored | Generated | Yes (local) | Already in `.gitignore` |
| `build/` | ignored | Generated | Yes (local) | Already in `.gitignore` |
| `.idea/`, `*.iml` | ignored | IDE metadata | Yes (local) | Already in `.gitignore` |
| `android/.gradle/`, `local.properties` | ignored | Android local | Yes (local) | None |
| `lib/core/env/env.dart` | ignored | Local secrets template copy | Yes (local) | Copy from `env.dart.example`; documented in DEPLOY |
| `installer/windows/output/` | ignored | Installer output | Yes (local) | None |
| `docs/archive/` | ignored | Archive scratch | Optional local | Documented repo-only |
| `docs/reports/_*.tmp` | ignored | Scan temp | Yes (local) | `.gitignore` pattern OK |
| `tools/` | ignored | Local tooling | Optional | Not in tracked tree; OK if local-only |
| `*_perf_capture.txt`, `shell_timeline_swipe_capture.txt` | ignored | Perf captures | Yes (local) | `.gitignore` OK |
| `scripts/manual/__pycache__/` | ignored | Python cache | Yes (local) | None |
| `counter/` (folder at root) | **not present** | — | N/A | No stray nested repo; package name only in Kotlin path |

**Suspicious tracked (reviewed, acceptable):**

| Path | Note |
| :--- | :--- |
| `installer/windows/stt_helper_build/counter_stt_helper.exe` | ~184k lines in line-count tools (binary). Tracked intentionally for installer payload — **do not split**; not Dart source. |
| `docs/APP_STRUCTURE_DETAILED.md` | ~12.6k lines — **generated reference**; regenerate via script; do not hand-edit body. |

**No blockers** found in inventory (nothing required deleted; ignored roots match `.gitignore` intent).

---

## 4. Architecture boundary results

### 4.1 Guard summary

```
architecture_guard.ps1 -Strict → Violations: 0
Warnings: plan_service.dart (5118 lines), planning_page.dart (2394 lines),
          RAW_UI FilledButton/OutlinedButton/TextButton/IconButton in features
```

### 4.2 Manual boundary checks

| Rule | Status | Evidence |
| :--- | :--- | :--- |
| `lib/data/` must not import `lib/features/` | **PASS** | 0 grep matches |
| `lib/core/` must not import feature UI | **PASS** | 0 grep matches for `features/` |
| `lib/core/` must not import `database_service.dart` | **PASS** | 0 grep matches |
| `lib/features/` uses `package:counter/...` | **PASS** | 0 relative `../` imports in `lib/` |
| `lib/l10n/` translation-only | **PASS** | No `data/` or `features/` imports in `l10n/` |
| `lib/services/` no feature UI | **PASS** | No `features/` imports in `services/` |
| `pb_hooks/` not imported by Flutter | **PASS** | 0 matches |
| PocketBase SDK confined to Brain/auth | **PASS** | Only `database_service.dart`, `auth_bridge.dart` import `package:pocketbase` |
| `PbCollections` / `kPocketBaseUrl` in Brain parts | **Expected** | Used inside `lib/data/*` extensions; **one follow-up:** `lib/features/auth/auth_view.dart` imports `pb_config.dart` directly — prefer Brain-facing API for new auth UI work |

**Verdict:** **No architecture boundary blockers.** One minor follow-up (auth UI → `pb_config`) — not a guard violation today.

---

## 5. Long-file and growth-risk audit

### 5.1 Threshold summary

| Threshold | Dart files | Non-Dart notes |
| :--- | ---: | :--- |
| **>600 lines** | 31 | Includes tests and l10n |
| **>1000 lines** | 8 | See table below |
| **>2000 lines** | 2 | `plan_service.dart`, `planning_page.dart` |
| **>2000 (non-Dart)** | `APP_STRUCTURE_DETAILED.md`, `counter_stt_helper.exe`, Python generators | Generated / binary / tooling |

### 5.2 Top 30 largest tracked files (by line count)

| Lines | Path | Classification |
| ---: | :--- | :--- |
| 184354 | `installer/.../counter_stt_helper.exe` | **generated/reference** — binary; do not split |
| 12603 | `docs/APP_STRUCTURE_DETAILED.md` | **generated/reference** — regen script |
| 5118 | `lib/data/plan_service.dart` | **watchlist** — coordinator; parts exist under `plans/*` |
| 2394 | `lib/features/planning/planning_page.dart` | **watchlist** — Time View + day body |
| 1727 | `lib/features/categories/category_list_view.dart` | **watchlist** — large feature screen |
| 1718 | `lib/features/shared/planning_task_edit_sheet.dart` | **watchlist** — shared sheet |
| 1557 | `scripts/manual/generate_app_structure_detailed.py` | **generated/reference** — doc generator |
| 1553 | `scripts/manual/structure_guide_data.py` | **generated/reference** — doc data |
| 1486 | `pubspec.lock` | **OK** — lockfile |
| 1377 | `lib/data/records/record_crud.dart` | **watchlist** — Brain domain part |
| 1188 | `scripts/manual/structure_ru_class_adapters.py` | **generated/reference** |
| 1084 | `lib/features/calendar/calendar_view.dart` | **watchlist** |
| 1072 | `lib/features/shared/timeline_record_edit_sheet.dart` | **watchlist** |
| 1026 | `CHANGELOG.md` | **OK** — history |
| 1018 | `lib/features/lists/lists_view.dart` | **watchlist** |
| 978 | `lib/data/plan_time_sequential_cascade.dart` | **watchlist** — Brain helper |
| 964 | `lib/features/dev/component_lab_view.dart` | **OK for now** — admin lab surface |
| 942 | `test/plan_time_target_drop_test.dart` | **OK** — large test |
| 930 | `lib/core/services/desktop_stt_helper_service.dart` | **watchlist** — platform voice bridge |
| 914 | `lib/data/categories/category_crud.dart` | **watchlist** |
| 901 | `lib/data/records/record_timeline_vm.dart` | **watchlist** |
| 855 | `lib/core/widgets/plan_time_task_card/plan_card_layouts.dart` | **OK for now** — canonical card layouts |
| 855 | `lib/data/voice_command_parser.dart` | **watchlist** |
| 854 | `lib/data/record_service.dart` | **OK for now** — thin coordinator post–Pass 4 |
| 799 | `lib/features/shared/voice_input_sheet.dart` | **watchlist** |
| 783 | `lib/features/planning/time_view/planning_time_view.dart` | **OK for now** — extracted from planning_page |
| 778 | `lib/l10n/langs/ru.dart` | **OK** — locale catalog |
| 776 | `lib/l10n/langs/en.dart` | **OK** — locale catalog |
| 771 | `lib/features/shared/desktop_voice_widget.dart` | **watchlist** — voice UI |
| 754 | `lib/data/database_service.dart` | **OK for now** — singleton host (~754 lines; domain in parts) |

**Coordinator growth post-decomposition:** `plan_service.dart` remains the main growth risk; `record_service.dart` / `database_service.dart` are within accepted coordinator size after Pass 4.

**No immediate splits required** — matches `docs/APP_STRUCTURE.md` §8 acceptance table.

---

## 6. Duplicate responsibility watchlist

| Concept | Canonical owner | Duplicate / suspicious paths | Severity | Follow-up |
| :--- | :--- | :--- | :--- | :--- |
| Action buttons | `AppButton` (`lib/core/widgets/app_button.dart`) | Raw `FilledButton`/`OutlinedButton`/`TextButton` in ~20–27 feature files (guard RAW_UI warnings) | **Medium** | V7 migration per `DESIGN_SYSTEM_INVENTORY.md` |
| Icon-only actions | `AppIconButton` | Raw `IconButton` in 24 feature files; heavy in `component_lab_view.dart` (intentional demos) | **Medium** | Migrate production screens incrementally |
| Plan/timeline cards | `PlanTimeTaskCard`, `LifeCard` | Feature-local card layout copies minimal; calendar/lists compose canonical widgets | **Low** | Continue V7; no second card framework |
| Loading / empty / error | `AppLoading`, `AppEmptyState`, `AppErrorState` | `empty_state_placeholder.dart`, `planning_empty_states.dart`, `lists_empty_state.dart` | **Low** | Consolidate when touching those screens |
| Timezone / wall clock | `lib/core/time/` + profile Brain | Scattered `DateTime` usage — governed by ARCHITECTURE §5 | **Low** | Enforce on new code; no new local TZ helpers |
| Category color/icon | `PlanCategoryLookup` (shell-injected) + category Brain | Direct category model reads in features — expected composition | **Low** | Keep lookup injection pattern |
| PB collection constants | `lib/data/pb_config.dart` | `auth_view.dart` imports `pb_config` | **Low** | Route new auth UI through Brain/auth_bridge |
| Offline / outbox | `lib/data/local_sync/*` + `DatabaseService.offlineSync` | No duplicate outbox implementations found | **None** | — |
| Voice / STT / tray | `desktop_stt_helper_service` (core), `features/shared/*voice*`, `shell_voice_routing`, Windows runner/installer | Split by layer is intentional (UI vs OS bridge vs native helper) | **Low** | Document in feature prompts; do not merge into platform |
| Edit sheets | `activity_detail_sheet.dart` → `planning_task_edit_sheet` / `timeline_record_edit_sheet` | `features/shared/edit_sheet/*` partials | **Low** | Keep router pattern; avoid third edit-sheet stack |
| PocketBase HTTP | `database_service.dart` + `part` files | No direct SDK in features except auth config read | **Low** | Block new feature-level PB clients |

**No duplicate Brain or parallel architecture detected.**

---

## 7. Documentation parity

| Check | Status | Notes |
| :--- | :--- | :--- |
| `docs/APP_STRUCTURE.md` layer map | **Updated** | §0 SHA + §7 Structure Growth Law added 2026-07-06 |
| `docs/APP_STRUCTURE_DETAILED.md` | **Regenerated** | After this audit; SHA stamped in header |
| `AGENTS.md` | **Updated** | Structure Growth Law + audit pointer |
| `AGENT_NAVIGATION.md` | **Updated** | Audit report in key docs table (`CLAUDE.md` → renamed) |
| `docs/ARCHITECTURE.md` | **Updated** | §11 Structure Growth Law |
| `docs/PROJECT_KNOWLEDGE_PACK.md` | **OK** | Still 14-doc checklist only; not architecture law |
| `CHANGELOG.md` | **Updated** | 2026-07-06 audit entry |
| `docs/DEPLOY.md` | **OK** | Matches `update.ps1` → `scripts/manual/td.ps1`, GitHub Actions → `gh-pages`, Windows installer section |
| `docs/UX_CONTRACT.md`, `DESIGN_SYSTEM.md`, `DATA_MAP.md`, `POCKETBASE_MANIFEST.md` | **OK** | No structure drift detected in this pass |

---

## 8. Structure Growth Law (added)

Permanent rule added to:

- `docs/ARCHITECTURE.md` §11
- `docs/APP_STRUCTURE.md` §7
- `AGENTS.md` (Active Priorities)
- `AGENT_NAVIGATION.md` (routing table)

Summary: integrate into existing layers; split early on mixed responsibilities; new-feature checklist (owner layer, extended module, canonical components, schema, file-size risk, docs/tests).

---

## 9. Remaining watchlist

1. **`lib/data/plan_service.dart` (5118 lines)** — monitor; split only with explicit product scope.
2. **`lib/features/planning/planning_page.dart` (2394 lines)** — monitor Time View / day shell coupling.
3. **Large feature screens** — `category_list_view`, `planning_task_edit_sheet`, `lists_view`, `calendar_view`.
4. **V7 RAW_UI debt** — migrate raw Material buttons to `AppButton` / `AppIconButton`.
5. **`auth_view.dart` → `pb_config.dart`** — prefer Brain-facing config for new work.
6. **Regenerate `APP_STRUCTURE_DETAILED.md`** after any large tree change.

---

## 10. Final verdict

### **ACCEPTED WITH WATCHLIST**

**Current structure requires no immediate correction.** Import boundaries are clean (strict guard **0 violations**). Pass 3–4D decomposition is reflected in docs and on-disk layout. Large files listed above are **known and documented** — not blockers for shipping or for new feature work **if** the Structure Growth Law is followed.

**Blockers:** none.

**Not claimed:** “ideal forever” — watchlist items must be re-checked when adding major features or when `plan_service.dart` / `planning_page.dart` grow materially.

---

## 11. Verification (post-doc pass)

Recorded in commit message session — see `CHANGELOG.md` [2026-07-06] entry for command results.
