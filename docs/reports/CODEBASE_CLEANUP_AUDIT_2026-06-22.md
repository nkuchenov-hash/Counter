# Codebase Cleanup Audit — 2026-06-22

**Pass type:** AUDIT ONLY — no production Dart files modified, moved, deleted, or refactored.

**Scope:** `lib/` Dart tree, architecture boundaries, diagnostic/temporary artifacts, doc drift vs `docs/APP_STRUCTURE.md`.

**Governing docs read:** `docs/ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/APP_STRUCTURE.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md`, `CLAUDE.md`, `docs/AI_CONTEXT.md`, `CHANGELOG.md`.

---

## 1. Full `lib/` Dart file tree

```
lib/
├── app_shell.dart
├── auth_screen.dart              # legacy barrel → features/auth/auth_screen.dart
├── auth_service.dart             # legacy OAuth vault (doc drift)
├── database_service.dart         # legacy barrel → data/database_service.dart
├── deploy.ps1                    # ⚠ non-Dart; misplaced deploy script
├── main.dart
├── models.dart                   # legacy barrel → data/models.dart
├── notes                           # ⚠ non-Dart text file
│
├── core/
│   ├── app_build_info.dart
│   ├── app_colors.dart
│   ├── app_diag.dart
│   ├── app_snackbar.dart
│   ├── category_color_palette.dart
│   ├── constants.dart
│   ├── date_pager_settle_gate.dart
│   ├── date_swipe_physics.dart
│   ├── link_scalar.dart
│   ├── p0_date_nav_diag.dart
│   ├── p0n_perf_diag.dart
│   ├── p0o_warm_diag.dart
│   ├── perf_diag.dart
│   ├── perf_flags.dart
│   ├── picker_entry_modes.dart
│   ├── pre_white_swipe_restore.dart
│   ├── shell_adaptive.dart
│   ├── shell_layout_state.dart
│   ├── theme.dart
│   ├── url_strategy_stub.dart
│   ├── env/
│   │   ├── env.dart
│   │   └── env.dart.example
│   ├── services/
│   │   ├── speech_engine_handle.dart
│   │   └── speech_listen_locale.dart
│   ├── subscription/
│   │   └── app_tier.dart
│   └── widgets/
│       ├── app_bar_live_clock.dart
│       ├── app_button.dart
│       ├── app_icon_button.dart
│       ├── app_loading.dart
│       ├── app_state_views.dart
│       ├── compact_nav_controls.dart
│       ├── confirm_dialog.dart
│       ├── global_app_header.dart
│       ├── lazy_indexed_stack.dart
│       ├── life_card.dart
│       ├── mouse_drag_scroll_behavior.dart
│       ├── omni_date_time_picker_dialog.dart
│       ├── plan_card.dart
│       └── plan_time_task_card.dart
│
├── data/
│   ├── auth_bridge.dart
│   ├── base_database.dart
│   ├── category_fuzzy_match.dart
│   ├── category_service.dart       # part of database_service
│   ├── database_service.dart       # Brain root + part coordinator
│   ├── db_core.dart                # part of database_service
│   ├── html_stub.dart
│   ├── models.dart
│   ├── pb_config.dart
│   ├── plan_service.dart           # part of database_service
│   ├── profile_service.dart        # part of database_service
│   ├── record_service.dart         # part of database_service
│   ├── voice_audio_stub.dart
│   ├── voice_audio_web.dart
│   ├── warm_day_window.dart
│   ├── web_history.dart            # conditional export barrel
│   ├── web_history_stub.dart
│   ├── web_history_web.dart
│   ├── local_sync/
│   │   ├── offline_sync_state.dart
│   │   ├── plan_create_outbox.dart # legacy re-export
│   │   ├── plan_mutation_outbox.dart
│   │   ├── record_mutation_outbox.dart
│   │   └── sync_manager.dart
│   └── models/
│       ├── _shared.dart
│       ├── category.dart
│       ├── planning.dart
│       ├── profile.dart
│       ├── record.dart
│       ├── stats.dart
│       └── tag.dart
│
├── features/
│   ├── auth/
│   │   ├── auth_screen.dart
│   │   └── auth_view.dart
│   ├── calendar/
│   │   └── calendar_view.dart
│   ├── categories/
│   │   ├── category_list_view.dart
│   │   ├── category_recursive_tree.dart
│   │   ├── category_visibility_prefs.dart
│   │   └── create_category_dialog.dart
│   ├── dev/
│   │   ├── component_lab_cards_demo.dart  # part of component_lab_view
│   │   └── component_lab_view.dart
│   ├── lists/
│   │   └── lists_view.dart
│   ├── more/
│   │   └── more_view.dart
│   ├── planning/
│   │   ├── bulk_planning_edit_sheet.dart
│   │   ├── planning_day_start_prefs.dart
│   │   ├── planning_view.dart
│   │   ├── smart_input_parser.dart
│   │   └── smart_plan_sheet.dart
│   ├── profile/
│   │   ├── profile_view.dart
│   │   ├── tag_default_duration_settings_view.dart
│   │   ├── tag_manager_page.dart
│   │   ├── tag_settings_hub.dart
│   │   ├── tag_settings_view.dart
│   │   ├── timezone_settings.dart
│   │   └── wall_clock.dart
│   ├── shared/
│   │   ├── chip_component.dart
│   │   ├── shared_widgets.dart
│   │   ├── tag_contrast.dart
│   │   ├── voice_capture_config.dart
│   │   └── voice_input_sheet.dart
│   ├── stats/
│   │   ├── plan_vs_fact_tab.dart
│   │   └── stats_view.dart
│   ├── timeline/
│   │   ├── timeline_view.dart
│   │   └── timeline_widgets.dart
│   └── wear/
│       ├── wear_main_wrapper.dart
│       ├── wear_platform.dart
│       ├── wear_runtime.dart
│       └── wear_timer_screen.dart
│
├── l10n/
│   ├── app_locales.dart
│   ├── category_db_display.dart
│   ├── dictionary.dart
│   └── langs/
│       ├── ar.dart
│       ├── de.dart
│       ├── en.dart               # ⚠ duplicate of inline en in dictionary.dart
│       ├── es.dart
│       ├── fr.dart
│       ├── it.dart
│       ├── ko.dart
│       ├── ru.dart               # ⚠ duplicate of inline ru in dictionary.dart
│       └── zh.dart
│
└── services/
    └── notification_service.dart
```

**Counts:** 122 `.dart` files under `lib/` (excluding `deploy.ps1`, `notes`, `env.dart.example`).

---

## 2. Line count per Dart file

| Lines | File | Threshold flag |
|------:|------|----------------|
| 6120 | `lib/features/planning/planning_view.dart` | **>1800 — high-priority architecture review** |
| 5266 | `lib/data/plan_service.dart` | **>1800 — high-priority architecture review** |
| 3991 | `lib/data/record_service.dart` | **>1800 — high-priority architecture review** |
| 3408 | `lib/features/shared/shared_widgets.dart` | **>1800 — high-priority architecture review** |
| 3281 | `lib/data/category_service.dart` | **>1800 — high-priority architecture review** |
| 2312 | `lib/app_shell.dart` | **>1800 — high-priority architecture review** |
| 2035 | `lib/features/lists/lists_view.dart` | **>1800 — high-priority architecture review** |
| 1863 | `lib/core/widgets/plan_time_task_card.dart` | **>1800 — high-priority architecture review** |
| 1728 | `lib/features/categories/category_list_view.dart` | **>1200 — split candidate if mixed responsibilities** |
| 1294 | `lib/l10n/dictionary.dart` | **>1200 — localization reference (exception)** |
| 1115 | `lib/features/timeline/timeline_view.dart` | **>800 — review recommended** |
| 1084 | `lib/features/calendar/calendar_view.dart` | **>800 — review recommended** |
| 940 | `lib/data/profile_service.dart` | **>800 — review recommended** |
| 894 | `lib/features/dev/component_lab_view.dart` | **>800 — review recommended** |
| 799 | `lib/features/shared/voice_input_sheet.dart` | review recommended (just under 800) |
| 715 | `lib/features/profile/profile_view.dart` | — |
| 704 | `lib/data/models/category.dart` | — |
| 678 | `lib/data/database_service.dart` | — |
| 623 | `lib/features/stats/plan_vs_fact_tab.dart` | — |
| 615 | `lib/features/planning/smart_plan_sheet.dart` | — |
| 596 | `lib/data/models/planning.dart` | — |
| 595 | `lib/main.dart` | — |
| 588 | `lib/features/shared/chip_component.dart` | — |
| 554 | `lib/data/models/record.dart` | — |
| 536 | `lib/core/perf_diag.dart` | diagnostic file |
| 530 | `lib/data/auth_bridge.dart` | — |
| 510 | `lib/features/planning/smart_input_parser.dart` | — |
| 505 | `lib/features/categories/category_recursive_tree.dart` | — |
| 486 | `lib/features/auth/auth_view.dart` | — |
| 484 | `lib/data/db_core.dart` | — |
| 435 | `lib/features/stats/stats_view.dart` | — |
| 425 | `lib/core/widgets/omni_date_time_picker_dialog.dart` | — |
| 423 | `lib/l10n/langs/ru.dart` | duplicate l10n |
| 420 | `lib/l10n/langs/en.dart` | duplicate l10n |
| 408 | `lib/features/profile/tag_manager_page.dart` | — |
| 381 | `lib/l10n/langs/{de,es,it,fr}.dart` | — |
| 369 | `lib/l10n/langs/ko.dart` | — |
| 368 | `lib/data/models/profile.dart` | — |
| 364 | `lib/l10n/langs/{ar,zh}.dart` | — |
| 328 | `lib/core/widgets/life_card.dart` | canonical, unimported |
| 296 | `lib/features/planning/bulk_planning_edit_sheet.dart` | — |
| 284 | `lib/features/wear/wear_timer_screen.dart` | — |
| 256 | `lib/data/local_sync/plan_mutation_outbox.dart` | — |
| 238 | `lib/data/local_sync/record_mutation_outbox.dart` | — |
| 235 | `lib/features/profile/tag_default_duration_settings_view.dart` | — |
| 224 | `lib/core/widgets/app_button.dart` | — |
| 213 | `lib/features/categories/create_category_dialog.dart` | — |
| 192 | `lib/features/dev/component_lab_cards_demo.dart` | part file |
| 191 | `lib/data/local_sync/offline_sync_state.dart` | — |
| 190 | `lib/auth_service.dart` | legacy root |
| 174 | `lib/services/notification_service.dart` | — |
| 173 | `lib/core/widgets/plan_card.dart` | — |
| 170 | `lib/features/profile/tag_settings_view.dart` | — |
| 149 | `lib/core/widgets/app_icon_button.dart` | — |
| 149 | `lib/data/warm_day_window.dart` | P0O warm cache |
| 148 | `lib/features/profile/wall_clock.dart` | — |
| 148 | `lib/core/services/speech_listen_locale.dart` | — |
| 147 | `lib/core/theme.dart` | — |
| 143 | `lib/data/models/tag.dart` | — |
| 142 | `lib/data/models/_shared.dart` | — |
| 138 | `lib/core/widgets/global_app_header.dart` | — |
| 120 | `lib/data/category_fuzzy_match.dart` | — |
| 115 | `lib/core/p0o_warm_diag.dart` | diagnostic |
| 102 | `lib/core/widgets/app_state_views.dart` | — |
| 101 | `lib/l10n/app_locales.dart` | — |
| 98 | `lib/core/date_swipe_physics.dart` | — |
| 97 | `lib/features/more/more_view.dart` | orphaned |
| 97 | `lib/core/p0n_perf_diag.dart` | diagnostic |
| 96 | `lib/core/app_colors.dart` | — |
| 91 | `lib/features/profile/timezone_settings.dart` | — |
| 90 | `lib/core/widgets/compact_nav_controls.dart` | — |
| 89 | `lib/features/shared/tag_contrast.dart` | — |
| 80 | `lib/features/timeline/timeline_widgets.dart` | orphaned |
| 72 | `lib/data/models/stats.dart` | — |
| 70 | `lib/features/profile/tag_settings_hub.dart` | — |
| 67 | `lib/core/shell_layout_state.dart` | — |
| 65 | `lib/features/categories/category_visibility_prefs.dart` | — |
| 60 | `lib/data/pb_config.dart` | — |
| 58 | `lib/core/widgets/{lazy_indexed_stack,app_loading,confirm_dialog}.dart` | confirm_dialog unimported |
| 57 | `lib/l10n/category_db_display.dart` | — |
| 54 | `lib/features/planning/planning_day_start_prefs.dart` | — |
| 51 | `lib/core/app_snackbar.dart` | — |
| 47 | `lib/core/category_color_palette.dart` | — |
| 42 | `lib/data/base_database.dart` | legacy stub |
| 42 | `lib/core/widgets/app_bar_live_clock.dart` | — |
| 41 | `lib/data/local_sync/sync_manager.dart` | — |
| 35 | `lib/core/date_pager_settle_gate.dart` | — |
| 29 | `lib/core/picker_entry_modes.dart` | — |
| 28 | `lib/data/models.dart` | — |
| 25 | `lib/features/wear/wear_platform.dart` | — |
| 25 | `lib/core/constants.dart` | — |
| 23 | `lib/core/app_build_info.dart` | — |
| 21 | `lib/core/p0_date_nav_diag.dart` | diagnostic |
| 21 | `lib/data/voice_audio_web.dart` | conditional |
| 19 | `lib/features/shared/voice_capture_config.dart` | — |
| 18 | `lib/core/link_scalar.dart` | — |
| 18 | `lib/features/wear/wear_main_wrapper.dart` | — |
| 15 | `lib/core/pre_white_swipe_restore.dart` | diagnostic |
| 15 | `lib/core/perf_flags.dart` | perf bisect flags |
| 14 | `lib/core/widgets/mouse_drag_scroll_behavior.dart` | — |
| 14 | `lib/core/shell_adaptive.dart` | — |
| 11 | `lib/data/web_history_web.dart` | conditional |
| 9 | `lib/data/html_stub.dart` | orphaned stub |
| 8 | `lib/core/app_diag.dart` | diagnostic |
| 7 | `lib/features/auth/auth_screen.dart` | — |
| 7 | `lib/core/services/speech_engine_handle.dart` | — |
| 6 | `lib/core/env/env.dart` | local secrets placeholder |
| 5 | `lib/core/subscription/app_tier.dart` | orphaned |
| 3 | `lib/models.dart` | legacy barrel |
| 3 | `lib/database_service.dart` | legacy barrel |
| 2 | `lib/data/voice_audio_stub.dart` | conditional |
| 2 | `lib/auth_screen.dart` | legacy barrel |
| 2 | `lib/core/url_strategy_stub.dart` | conditional |
| 2 | `lib/features/wear/wear_runtime.dart` | — |
| 1 | `lib/data/web_history_stub.dart` | conditional |
| 1 | `lib/data/local_sync/plan_create_outbox.dart` | re-export |
| 1 | `lib/data/web_history.dart` | conditional barrel |

---

## 3. Temporary / diagnostic-looking files

Pattern scan: `p0*`, `p1*`, `pj*`, `pk*`, `diag`, `debug`, `probe`, `tmp`, `old`, `backup`, `hotfix`.

### In `lib/` (Dart)

| Path | Imported? | Import sites | Safe to delete? | Rename/move? | Risk |
|------|-----------|--------------|-----------------|--------------|------|
| `lib/core/p0n_perf_diag.dart` | Yes | `database_service.dart`, `planning_view.dart`, `timeline_view.dart` | **No** — active P0N logs | Consolidate into `perf_diag.dart` later | **Medium** — delete breaks warm/swipe diagnostics |
| `lib/core/p0o_warm_diag.dart` | Yes | `database_service.dart` (import); calls in `record_service.dart`, `plan_service.dart` | **No** — active P0O warm-window logs | Consolidate later | **Medium** |
| `lib/core/p0_date_nav_diag.dart` | Yes | `database_service.dart`, `planning_view.dart`, `timeline_view.dart` | **No** — shipped P0 date-nav guard logs | Consolidate later | **Medium** |
| `lib/core/pre_white_swipe_restore.dart` | Yes | `planning_view.dart`, `timeline_view.dart` | **No** — emergency restore pass still `[wip]` per CHANGELOG | Keep until PageView path stable | **Low–Medium** |
| `lib/core/perf_diag.dart` | Yes | `main.dart`, `app_shell.dart`, `database_service.dart`, `planning_view.dart`, `timeline_view.dart`, `global_app_header.dart`, `plan_card.dart`, `plan_time_task_card.dart`; tests | **No** — gated by `--dart-define=PERF_DIAG=true` | Keep; document flag in ARCHITECTURE | **Low** (release silent) |
| `lib/core/perf_flags.dart` | Yes | `app_shell.dart`, `planning_view.dart` | **No** — bisect toggles from 2026-06-21 lag hunt | Remove after culprit confirmed | **Medium** — wrong flag breaks shell/timeline |
| `lib/core/app_diag.dart` | Yes | `planning_view.dart` only | **Maybe** — thin wrapper over `debugPrint` | Inline or merge into `perf_diag` | **Low** |
| `lib/data/warm_day_window.dart` | Yes | `database_service.dart`; used by record/plan services | **No** — production P0O cache (not diag-only) | Stay in `data/` | **High** if deleted |
| `lib/core/app_build_info.dart` | Yes | `main.dart`, `profile_view.dart` | **No** — version/build display | Stay | **Low** |

### Repo root / scripts (non-`lib/`)

| Path | Imported? | Safe to delete? | Action | Risk |
|------|-----------|-----------------|--------|------|
| `p0b_logcat.txt` | N/A | **Yes** — captured log artifact | Archive or `.gitignore` | **None** |
| `scripts/p0b_build_apk.ps1` | N/A | **Investigate** — may be local perf build helper | Move to `scripts/` only (already there); document or delete if superseded | **Low** |

### Pattern matches not found in `lib/`

No files matching `p1*`, `pj*`, `pk*`, `probe`, `tmp`, `old`, `backup`, or `hotfix` in `lib/`. CHANGELOG references removed untracked experiments (`canonical_date_pager.dart`, `p0b–p0l_date_diag.dart`, etc.) — those are already absent from the tree (good).

---

## 4. Unimported Dart files

Static import graph scan (excluding `part of` / `part` / conditional-export indirection). Manual verification applied for false positives.

| Path | Evidence | Dynamic/conditional risk | Recommended action |
|------|----------|--------------------------|-------------------|
| `lib/core/widgets/confirm_dialog.dart` | Zero `import` of file; zero `showConfirmDialog(` call sites outside the file itself | None | **INVESTIGATE → wire or DELETE** — canonical component exists but is dead code |
| `lib/core/widgets/life_card.dart` | Zero imports; `LifeCard` / `AppTaskCard` only referenced inside file | Component Lab docs reference it but production does not | **KEEP** for V7 migration; do not delete until card pass |
| `lib/core/subscription/app_tier.dart` | Zero imports; `appIsProUser` unused | Could be intended for future paywall | **ARCHIVE or INVESTIGATE** — dead monetization stub |
| `lib/core/env/env.dart` | Zero imports; placeholder only | Local secrets pattern | **KEEP** — `.gitignore` companion to `env.dart.example` |
| `lib/data/base_database.dart` | Zero imports; Supabase/YDB abstract interface | Legacy hybrid-cloud stub | **ARCHIVE** — superseded by PocketBase Brain |
| `lib/data/html_stub.dart` | Zero imports anywhere | Was likely for conditional `dart:html` | **DELETE** candidate after confirm no build.dart reference |
| `lib/features/more/more_view.dart` | `MoreMenuPage` never imported; `app_shell.dart` implements `_openMoreMenu` inline bottom sheet | None — duplicate More UX | **DELETE** or **wire** — currently dead route |
| `lib/features/timeline/timeline_widgets.dart` | `TimelineTopDateStrip` never imported; timeline header inlined elsewhere | None | **DELETE** candidate — stale extract |
| `lib/l10n/langs/en.dart` | Not imported; `dictionary.dart` embeds full `'en'` map inline | Duplicate source of truth | **ARCHIVE or sync** — drift risk vs inline dict |
| `lib/l10n/langs/ru.dart` | Same as en — inline `'ru'` in `dictionary.dart` | Duplicate source of truth | **ARCHIVE or sync** — drift risk |
| `lib/data/local_sync/plan_create_outbox.dart` | Re-export only; no direct importers | Legacy alias | **KEEP** — documented in CLAUDE.md / APP_STRUCTURE |
| `lib/data/web_history_stub.dart` | Imported only via conditional export in `web_history.dart` | Web build | **KEEP** |
| `lib/data/web_history_web.dart` | Conditional via `web_history.dart` | Web-only | **KEEP** |
| `lib/auth_screen.dart` | Root barrel; consumers import `features/auth/auth_screen.dart` | Re-export indirection | **KEEP** until barrel removal pass |
| `lib/database_service.dart` | Legacy barrel | Wide external habit | **KEEP** until import migration |
| `lib/models.dart` | Legacy barrel | Wide external habit | **KEEP** until import migration |

---

## 5. Root-level `lib/*.dart` files

| File | APP_STRUCTURE.md allows? | Should stay root? | Recommended action |
|------|--------------------------|-------------------|-------------------|
| `main.dart` | ✅ Yes — "THE IGNITION" | Yes | **KEEP** |
| `app_shell.dart` | ✅ Yes — "THE NAVIGATOR" | Yes | **KEEP** |
| `database_service.dart` | ⚠ Doc lists only `data/database_service.dart`; CLAUDE.md notes legacy barrel | Temporary | **KEEP** barrel; migrate imports to `package:counter/data/database_service.dart` in Stage B |
| `models.dart` | ⚠ Same drift | Temporary | **KEEP** barrel; migrate to `data/models.dart` |
| `auth_screen.dart` | ⚠ Doc lists `features/auth/auth_screen.dart` only | Temporary | **KEEP** barrel or delete after grep-clean |
| `auth_service.dart` | ⚠ Doc: "Extra at lib/ root (OAuth legacy)" | No long-term | **MOVE** to `lib/data/auth_service.dart` or `lib/features/auth/` when OAuth path audited |
| `deploy.ps1` | ❌ Not documented | No | **MOVE** to `scripts/` (duplicate of root deploy flow) or **DELETE** |
| `notes` | ❌ Not documented | No | **INVESTIGATE** contents; likely personal scratch → delete or move out of `lib/` |

---

## 6. Folder-boundary violations

### Hard rules checked

| Rule | Violations found |
|------|------------------|
| `lib/data` must not import `lib/features` | **3 imports** in `database_service.dart`: `smart_input_parser.dart`, `wall_clock.dart`, `timezone_settings.dart` |
| `lib/core` must not import `lib/features` | **2 imports** in `plan_time_task_card.dart`: `tag_manager_page.dart`, `chip_component.dart` |
| `lib/core` must not import database/business services | **4 imports**: `global_app_header.dart`, `app_bar_live_clock.dart`, `plan_card.dart`, `plan_time_task_card.dart` → `database_service.dart`; plus `models.dart` in plan widgets |
| `lib/services` must not import `lib/features` | ✅ None |

### Cross-feature imports (non-`shared/`)

| Importer | Imports | Justified? |
|----------|---------|------------|
| `timeline_view.dart` | `stats/stats_view.dart` | **Weak** — embeds stats tab inside timeline; should route via shell or shared contract |
| `planning_view.dart` | `profile/tag_manager_page.dart`, `profile/tag_settings_hub.dart`, `profile/timezone_settings.dart` | **Acceptable** for now — tag/timezone pickers; better long-term: move picker APIs to `shared/` or `core/widgets/` |
| `lists_view.dart` | `planning/smart_input_parser.dart`, `categories/category_visibility_prefs.dart`, `profile/tag_manager_page.dart` | **Acceptable** — parser is domain helper living in planning folder; visibility prefs is categories sub-module |
| `shared_widgets.dart` | `categories/category_recursive_tree.dart`, `planning/smart_input_parser.dart`, `profile/tag_settings_hub.dart` | **Acceptable** — shared edit sheets compose feature widgets; candidate to extract neutral pickers |
| `chip_component.dart` | `profile/tag_manager_page.dart` | **Weak** — tag chip opens manager page; coupling chip primitive to profile feature |
| `tag_default_duration_settings_view.dart` | `profile/tag_manager_page.dart` | **OK** — same profile domain |
| `profile_view.dart` | `profile/timezone_settings.dart` | **OK** — same feature |
| `more_view.dart` | `categories/`, `dev/`, `profile/` | **N/A** — file is orphaned |
| `category_list_view.dart` | `categories/create_category_dialog.dart`, `categories/category_visibility_prefs.dart` | **OK** — same feature |
| `stats_view.dart` | `stats/plan_vs_fact_tab.dart` | **OK** — same feature |

**Highest-priority boundary fixes (later, not now):**

1. Move `smart_input_parser.dart` + `wall_clock.dart` timezone helpers to `lib/data/` or `lib/core/` so Brain stops importing features.
2. Remove `features/` imports from `plan_time_task_card.dart` — pass tag UI via callbacks or move tag strip to feature layer wrapper.

---

## 7. Raw local UI audit (`lib/features/`)

Search: `ElevatedButton`, `FilledButton`, `OutlinedButton`, `TextButton`, `IconButton`, `Card(`, chip variants, `TabBar`, `SegmentedButton`, progress indicators.

**Legend:** Canonical = exists in `lib/core/widgets/`. Legacy = allowed temporarily per `DESIGN_SYSTEM_INVENTORY.md`.

### Buttons

| Widget | Total (features) | Canonical | Legacy? | Migrate later? |
|--------|-----------------:|-----------|---------|----------------|
| `ElevatedButton` | 0 | `AppButton` | — | — |
| `FilledButton` | 35 | `AppButton` | Yes | Yes — priority: `shared_widgets.dart` (6), `category_list_view.dart` (6), `timeline_view.dart` (5) |
| `OutlinedButton` | 9 | `AppButton.outlined` | Yes | Yes — `shared_widgets.dart` (4) |
| `TextButton` | 22 | `AppButton.ghost` | Yes | Yes — `shared_widgets.dart` (5), `planning_view.dart` (4) |
| `IconButton` | ~122 | `AppIconButton` | Yes (40 in Component Lab alone) | Yes — defer timer/plan play/search controls per inventory |

**Per-file `FilledButton` / `OutlinedButton` / `TextButton` / `IconButton` detail:**

| File | Filled | Outlined | Text | Icon | Notes |
|------|-------:|---------:|-----:|-----:|-------|
| `shared_widgets.dart` | 6 | 4 | 5 | 7 | Sheet actions — high migration value after UX contract review |
| `planning_view.dart` | 1 | 2 | 4 | 15 | Plan play/search — intentionally deferred |
| `category_list_view.dart` | 6 | 1 | 1 | 6 | Partial V7F.2 migration done |
| `timeline_view.dart` | 5 | 0 | 1 | 2 | Timer controls deferred |
| `lists_view.dart` | 3 | 0 | 3 | 7 | List selection/menu |
| `dev/component_lab_view.dart` | 0 | 0 | 0 | 40 | Demo only — allowed |
| `auth/auth_view.dart` | 1 | 2 | 1 | 1 | Auth deferred |
| Others | ≤3 each | ≤2 | ≤2 | ≤4 | Legacy allowed |

### Cards

| File | `Card(` count | Canonical | Legacy? | Migrate? |
|------|-------------:|-----------|---------|----------|
| `planning_view.dart` | 1 | `LifeCard` / `PlanCard` | Yes | Later — Time mode block chrome |
| `timeline_view.dart` | 1 | `AppTaskCard` (planned) | Yes | Later |
| `lists_view.dart` | 1 | `AppTaskCard` backlog | Yes | Later |
| `auth/auth_view.dart` | 1 | none | Yes | Low priority |
| `dev/component_lab_view.dart` | 1 | demo | Allowed | — |

Production cards mostly use custom containers / `PlanCard` / `_BacklogPlanCard` — raw `Card(` usage is minimal (5 sites).

### Chips

| File | Raw chip widgets | Canonical | Legacy? |
|------|-----------------|-----------|---------|
| `lists_view.dart` | 4× `FilterChip` | `TagChip` / `CategoryChip` in `chip_component.dart` | Yes — migrate in V7 chip pass |
| Others | 0 raw | — | — |

### Tabs / segmented

| Widget | Total | Canonical | Notes |
|--------|------:|-----------|-------|
| `TabBar` | 13 | none (`AppSegmentedTabs` planned) | `shared_widgets.dart` (9), `stats_view.dart` (2), `tag_settings_hub.dart` (2) |
| `SegmentedButton` | 12 | none | `planning_view.dart` (5), `timeline_view.dart` (2), others scattered |

### Progress

| Widget | Total | Canonical | Notes |
|--------|------:|-----------|-------|
| `CircularProgressIndicator` | 7 | `AppLoading` | Replace ad-hoc spinners in auth/profile/calendar/sheets |
| `LinearProgressIndicator` | 2 | none | `shared_widgets.dart`, `voice_input_sheet.dart` |

---

## 8. Mixed-responsibility large files

Classification key: **cohesive** | **mixed** | **l10n exception** | **needs no split** | **split candidate**.

| File | Lines | Classification | Rationale |
|------|------:|----------------|-----------|
| `planning_view.dart` | 6120 | **Split candidate** | PageView date nav + list mode + Time mode canvas + drag/resize + settings/search delegates + card assembly + perf hooks |
| `plan_service.dart` | 5266 | **Split candidate** | CRUD + offline outbox + rrule + AI parse + warm window + time-mode projection + alarms — all in one `part` |
| `record_service.dart` | 3991 | **Split candidate** | CRUD + optimistic UI + realtime + warm window + timeline VM cache + ghost cleanup |
| `shared_widgets.dart` | 3408 | **Split candidate** | Omni-picker entry + planning edit sheet + timeline record sheet + parallel child UI |
| `category_service.dart` | 3281 | **Split candidate** | CRUD + fuzzy match + stats + PB mapping — still one domain but oversized |
| `app_shell.dart` | 2312 | **Mixed; needs no split now** | Shell owns voice dispatch, nav, offline banner, settings — large but cohesive navigator role |
| `lists_view.dart` | 2035 | **Split candidate** | Filters + cards + bulk + export + local `_BacklogPlanCard` |
| `plan_time_task_card.dart` | 1863 | **Mixed; split later** | Canonical card — split private layout classes, fix feature imports first |
| `category_list_view.dart` | 1728 | **Split candidate** | List + editor sheets + search + visibility |
| `dictionary.dart` | 1294 | **l10n exception** | Inline EN/RU + merge maps — do not split by line count |
| `timeline_view.dart` | 1115 | **Cohesive large** | Single screen; review recommended, defer split |
| `calendar_view.dart` | 1084 | **Cohesive large** | Single screen |
| `profile_service.dart` | 940 | **Cohesive** (Brain part) | Review only |

### Split candidates — proposed targets

#### `planning_view.dart` → later (Stage E)

| Stable responsibility | Proposed target | APP_STRUCTURE allows? | Risk | When |
|----------------------|-----------------|----------------------|------|------|
| Time mode canvas + drag/resize | `features/planning/planning_time_mode.dart` | ✅ under `planning/` | **High** — gesture fights | After P0O/P0N stable |
| Settings/search delegate blocks | `features/planning/planning_settings_blocks.dart` | ✅ | Medium | Same pass |
| PageView swipe wrapper | keep in `planning_view.dart` | ✅ | High if moved wrong | Defer |

#### `plan_service.dart` / `record_service.dart` → later

| Responsibility | Proposed target | Allowed? | Risk | When |
|----------------|-----------------|----------|------|------|
| Warm day window | `data/warm_day_window.dart` (exists) + thin service API | ✅ | Medium | Partially done |
| Offline flush helpers | stay in service or `local_sync/` | ✅ | High | Defer |
| Time-mode projection | `data/plan_time_mode.dart` new part | ✅ | High | Defer |

#### `shared_widgets.dart` → later

| Responsibility | Proposed target | Allowed? | Risk |
|----------------|-----------------|----------|------|
| `_PlanningTaskEditSheet` | `features/shared/planning_task_edit_sheet.dart` | ✅ | Medium |
| `_TimelineRecordSheetContent` | `features/shared/timeline_record_sheet.dart` | ✅ | Medium |
| `showAppDateTimePicker` | keep as shared entry | ✅ | Low |

---

## 9. Architecture drift vs `docs/APP_STRUCTURE.md`

### Present in repo but missing or under-documented in APP_STRUCTURE

| Item | Notes |
|------|-------|
| `warm_day_window.dart` | P0O production cache — not in doc tree |
| `p0*_diag.dart`, `perf_diag.dart`, `perf_flags.dart`, `pre_white_swipe_restore.dart` | Performance/diagnostic layer |
| `app_build_info.dart`, `app_colors.dart`, `app_diag.dart` | Core utilities |
| `date_swipe_physics.dart`, `date_pager_settle_gate.dart`, `link_scalar.dart`, `shell_adaptive.dart` | Date pager infrastructure |
| `plan_card.dart`, `plan_time_task_card.dart`, `life_card.dart`, `app_icon_button.dart`, `lazy_indexed_stack.dart`, `compact_nav_controls.dart` | Doc says "8 primitives" — actual widget folder has 14 files |
| `component_lab_cards_demo.dart` | part of Component Lab |
| Root legacy barrels + `auth_service.dart` | Documented as drift in CLAUDE.md, not APP_STRUCTURE |
| `lib/deploy.ps1`, `lib/notes` | Non-Dart artifacts inside `lib/` |

### Documented but absent or stale

| Doc claim | Reality |
|-----------|---------|
| `core/widgets/` lists exactly 8 files | 14 widget files present |
| `features/auth/auth_screen.dart` only | Root `auth_screen.dart` barrel still exists |
| `more/more_view.dart` as More hub | **Orphaned** — shell uses inline bottom sheet |
| `timeline_widgets.dart` | **Orphaned** — strip not wired |
| Platform stubs "html_stub, voice_audio_stub, web_history*" | `html_stub.dart` appears unused |
| `core/env/env.dart` | Exists but undocumented |

### Required doc updates (Stage C — do not edit in this pass)

1. Expand `APP_STRUCTURE` widget inventory (PlanCard stack, perf/diag files, warm window).
2. Mark `more_view.dart` / `timeline_widgets.dart` as deprecated or remove from map.
3. Document `perf_flags.dart` bisect toggles and `--dart-define=PERF_DIAG`.
4. Sync CLAUDE.md symbol table if files move.
5. Note Brain → features import debt in ARCHITECTURE.md §1.

---

## 10. Proposed cleanup plan

### Stage A — safe deletes only

| Action | Files | Evidence | Risk | Behavior impact | Verification |
|--------|-------|----------|------|-----------------|--------------|
| Delete log artifact | `p0b_logcat.txt` | Untracked log dump | None | None | `git status` clean |
| Delete orphaned stub | `lib/data/html_stub.dart` | Zero imports | Low | None if grep confirms | `flutter analyze` |
| Delete duplicate More page | `lib/features/more/more_view.dart` | Never imported; shell has `_openMoreMenu` | Low | None if unused | `flutter analyze`; manual More tab |
| Delete stale timeline widgets | `lib/features/timeline/timeline_widgets.dart` | Never imported | Low | None | `flutter analyze`; timeline header OK |
| Remove `lib/notes` | personal scratch in `lib/` | Non-code | Low | None | inspect file first |
| Remove misplaced script | `lib/deploy.ps1` | Duplicate deploy; not Dart | Low | None if `scripts/` owns deploy | compare with `update.ps1` |

### Stage B — safe renames/moves

| Action | Files | Evidence | Risk | Impact | Verification |
|--------|-------|----------|------|--------|--------------|
| Move deploy script | `lib/deploy.ps1` → `scripts/` | Wrong vault | Low | None | path exists |
| Consolidate l10n | `langs/en.dart`, `langs/ru.dart` | Duplicate of inline dict | Medium drift | Wrong strings if not synced | diff maps vs dictionary |
| Move OAuth legacy | `auth_service.dart` → `data/` or `features/auth/` | APP_STRUCTURE drift | Medium | Import updates | `flutter analyze` |
| Deprecate root barrels | `database_service.dart`, `models.dart`, `auth_screen.dart` | CLAUDE drift table | Low | External imports | codemod + analyze |

### Stage C — documentation sync

| Action | Docs | Evidence |
|--------|------|----------|
| Update widget inventory | `APP_STRUCTURE.md` | 14 core widgets vs documented 8 |
| Document perf layer | `ARCHITECTURE.md`, `CLAUDE.md` | p0/warm/perf_diag/perf_flags |
| Mark dead files removed | `APP_STRUCTURE.md` | more_view, timeline_widgets |
| Update design inventory counts | `DESIGN_SYSTEM_INVENTORY.md` | Raw button/chip counts from §7 |

### Stage D — architecture_guard script

Proposed checks (new `scripts/architecture_guard.ps1` or CI step):

```powershell
# Fail if Brain imports features
rg "import 'package:counter/features/" lib/data lib/core lib/services

# Fail if core/widgets imports features (except allowlist during migration)
rg "import 'package:counter/features/" lib/core/widgets

# Warn on new root lib/*.dart except allowlist: main, app_shell, *barrel*
```

| Check | Expected | Risk if skipped |
|-------|----------|-----------------|
| data→features | 0 imports | Brain/UI coupling returns |
| core/widgets→features | 0 imports | Design system leaks |
| file line count report | informational | — |

Verification: run script in CI; `exit 1` on new violations.

### Stage E — justified splits only (defer until Stage A–D done)

| Priority | File | Split | Risk | Verification |
|----------|------|-------|------|--------------|
| 1 | `shared_widgets.dart` | Extract edit sheets | Medium | Sheet save/edit manual tests |
| 2 | `planning_view.dart` | Time mode module | **High** | Planning Time drag, date swipe |
| 3 | `plan_service.dart` / `record_service.dart` | Warm window already extracted; next: time-mode part | **High** | Offline + warm swipe tests |
| 4 | `plan_time_task_card.dart` | Private layout files + remove feature imports | Medium | Planning/Timeline/Calendar cards |

### Stage F — analyze / build / deploy

| Step | Command | Purpose |
|------|---------|---------|
| Static analysis | `flutter analyze` | No regressions |
| Tests | `flutter test` | perf diag tests + core |
| Android release | `flutter build apk --release` | P0 perf path |
| Web | `flutter build web --release` | Do **not** run `update.ps1` until user approves |

---

## Appendix A — Diagnostic import map (quick reference)

```
main.dart ── app_build_info, perf_diag
app_shell.dart ── perf_diag, perf_flags
database_service.dart ── p0_date_nav_diag, p0n_perf_diag, p0o_warm_diag, perf_diag, warm_day_window
record_service.dart ── P0OWarmDiag (via part)
plan_service.dart ── P0OWarmDiag (via part)
planning_view.dart ── app_diag, p0_*, pre_white_swipe_restore, perf_diag, perf_flags
timeline_view.dart ── p0_*, pre_white_swipe_restore, perf_diag
global_app_header.dart, plan_card.dart, plan_time_task_card.dart ── perf_diag
```

---

## Appendix B — Top orphaned canonical components

| Component | File | Production usage |
|-----------|------|------------------|
| `showConfirmDialog` | `confirm_dialog.dart` | **0 call sites** |
| `LifeCard` / `AppTaskCard` | `life_card.dart` | **0 imports** (Component Lab docs only) |
| `appIsProUser` | `app_tier.dart` | **0 imports** |

---

---

## Stage A applied (2026-06-22)

**Scope:** Safe deletes / non-code removal only. No P0/perf/warm production files touched.

### Files deleted

| Path | Reason |
|------|--------|
| `p0b_logcat.txt` | Captured log artifact |
| `lib/notes` | Personal scratch (non-Dart) |
| `lib/deploy.ps1` | Obsolete Firebase deploy script in wrong folder |
| `lib/data/html_stub.dart` | Zero imports; unused `dart:html` stub |
| `lib/features/more/more_view.dart` | Orphan — `MoreMenuPage` never imported |
| `lib/features/timeline/timeline_widgets.dart` | Orphan — `TimelineTopDateStrip` never imported |

### Files archived

| From | To |
|------|-----|
| `lib/notes` | `docs/archive/lib_notes_scratch.txt` |

### Stage A.1 compile repair (same cleanup track)

| File | Change |
|------|--------|
| `lib/features/planning/planning_view.dart` | Added `import 'package:counter/core/p0n_perf_diag.dart';`; restored `_PlanningDayCardListKeepAlive` keep-alive wrapper for offscreen PageView day bodies |

### Verification after A + A.1

| Check | Result |
|-------|--------|
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **Green** (0 errors) |
| `flutter test` | Loads and runs; **3 runtime failures remain** (not compile blockers): `perf_shell_date_settle_test.dart` assertion, `widget_test.dart` `pumpAndSettle` timeout, related perf/widget harness |
| P0/perf/warm files | **Not deleted or renamed** in Stage A |

### Product behavior

- More menu unchanged — inline `_openMoreMenu()` bottom sheet in `app_shell.dart`.
- Timeline header unchanged — inlined in `timeline_view.dart` (list/stats chrome + PageView).

---

*End of audit report. Stage A/A.1 applied to production files; Stage C updated this report only.*
