# APP_STRUCTURE (Life OS)

Physical map of the Flutter application: what exists, which layer owns it, who may import it, and who must not.

**Package name:** `counter` — all Dart imports use `package:counter/...` (no relative imports).

---

## 0. Current status (2026-07-03)

| Item | Value |
| :--- | :--- |
| **Structure baseline SHA** | `5360d71` (final parity pass) |
| **UI decomposition** | Pass 3 / 3B complete (shell, planning, timeline, lists, shared edit sheets, plan card) |
| **Brain decomposition** | Pass 4A–4D complete (`plans/*`, `records/*`, `categories/*`, `profile/*`) |
| **Strict architecture guard** | Green (0 violations) |
| **Detailed file guide** | [`docs/APP_STRUCTURE_DETAILED.md`](APP_STRUCTURE_DETAILED.md) — bilingual EN/RU per tracked file |
| **Scan report** | [`docs/reports/FILE_STRUCTURE_SCAN_2026-07-03.md`](reports/FILE_STRUCTURE_SCAN_2026-07-03.md) |
| **Final parity report** | [`docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`](reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md) |

Regenerate the detailed guide after large tree changes:

```powershell
python scripts/manual/generate_app_structure_detailed.py
.\scripts\manual\structure_scan.ps1
```

---

## 1. Layer model

| Layer | Path | Owns | May import | Must NOT import |
| :--- | :--- | :--- | :--- | :--- |
| **Entry** | `lib/main.dart`, `lib/app_shell.dart`, `lib/shell/` | Boot, auth gate, shell navigation, cross-tab wiring | `data/`, `core/`, `features/`, `l10n/`, `services/` | — |
| **Brain** | `lib/data/` | PocketBase I/O, in-memory cache, optimistic UI, offline outboxes, domain models | `core/` (utilities only), `services/` (device bridge), other `data/` | `features/` |
| **Foundation** | `lib/core/` | Theme, tokens, shared widgets, time helpers, diagnostics, performance flags | `core/`, `data/models.dart` (types only) | `features/`, `data/database_service.dart` |
| **UI modules** | `lib/features/` | Screens, sheets, feature-specific layout | `data/`, `core/`, `l10n/`, `features/shared/` | other features except via `shared/` or explicit shell routing |
| **Voice** | `lib/l10n/` | Locale catalog and `t()` lookup | Flutter SDK only | `data/`, `features/` |
| **Device bridge** | `lib/services/` | OS capabilities without UI | `data/models.dart`, Flutter/plugins | `features/` |

### Import boundary summary

```
features  →  data, core, l10n, services   ✓
data      →  core, services, data        ✓
data      →  features                    ✗
core      →  data/models.dart, core       ✓
core      →  features, database_service   ✗
services  →  data/models, plugins         ✓
services  →  features                      ✗
l10n      →  (self + langs)               ✓
main/app_shell → all layers               ✓
```

**Brain rule:** `lib/data/database_service.dart` is the only file that performs HTTP/PocketBase calls. Domain logic lives in `part of` extensions (`db_core.dart`, `record_service.dart`, `records/*`, `plan_service.dart`, `plans/*`, `category_service.dart`, `categories/*`, `profile_service.dart`, `profile/*`).

**Optimistic UI rule:** User mutations update local Brain cache first, notify UI, then sync PocketBase in the background (`database_service.dart` and its parts).

---

## 2. Shell injection (main → core)

These core abstractions stay free of Brain imports; `main.dart` and `app_shell.dart` wire them at runtime:

| Symbol | File | Wired from | Purpose |
| :--- | :--- | :--- | :--- |
| `AppClock` | `core/time/app_clock.dart` | `main.dart` `_wireAppClock()` | Profile-timezone wall clock and tick stream for headers |
| `ProfileTimezoneActions` | `core/time/profile_timezone_actions.dart` | `main.dart` `_wireProfileTimezoneActions()` | Profile timezone label, settings stream, and save hook for header picker |
| `PlanCategoryLookup` | `core/plan_category_lookup.dart` | `main.dart` `_wirePlanCategoryLookup()` | Category color, icon, breadcrumb for plan cards without importing Brain in widgets |
| `TagDisplayModeScope` | `core/widgets/tag_display_mode_scope.dart` | `app_shell.dart` | Inherited tag display mode from profile settings |

---

## 3. `lib/` directory map

### 3.1 Entry

| File | Role |
| :--- | :--- |
| `main.dart` | `runApp`, PocketBase bootstrap, auth gate, Wear entry, locale init, shell injection |
| `app_shell.dart` | Re-exports `shell/life_os_dashboard.dart` (thin entry) |

**Shell tabs (bottom nav index):** 0 Timeline · 1 Plans · 2 Calendar · 3 Lists · 4 More (Categories, Profile, admin Component Lab).

### 3.1.1 `lib/shell/` — dashboard modules (Pass 3)

| File | Role |
| :--- | :--- |
| `life_os_dashboard.dart` | `LifeOSDashboard`, `ShellDashboardState`, scaffold build |
| `shell_core.dart` | Core shell logic mixin (date header, tasks load, nav) *(part)* |
| `shell_tab_host.dart` | Tab `IndexedStack` builders *(part)* |
| `shell_edit_hosts.dart` | Timeline/plan edit modal hosts *(part)* |
| `shell_more_menu.dart` | More bottom sheet *(part)* |
| `shell_voice_routing.dart` | Voice hotkey + submit routing *(part)* |
| `shell_offline_banner.dart` | Offline sync banner column slot |
| `shell_shared.dart` | Shell-local date helpers *(part)* |
| `shell_side_navigation.dart` | Desktop/web side navigation rail |
| `profile_hydration_status_bar.dart` | Profile hydration failure banner |
| `settings_page.dart` | Language/TZ settings page (shell route) |

Re-export stubs remain at `core/navigation/shell_side_navigation.dart`, `features/shared/profile_hydration_status_bar.dart`, `features/profile/settings/settings_page.dart`.

### 3.2 `lib/data/` — Brain & models

| File / folder | Role |
| :--- | :--- |
| `database_service.dart` | Singleton root: shared state, streams, static helpers; `part` coordinator |
| `db_core.dart` | Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes *(part)* |
| `record_service.dart` | Records coordinator: cache, fetch, upsert, start/stop entry, streams *(part)* |
| `records/record_crud.dart` | Record CRUD, PATCH/DELETE network phases, `writeRecord` / `updateRecord` / `stopRecord` *(part)* |
| `records/record_optimistic.dart` | Optimistic stop overlay, sacred handoff, pending-start map *(part)* |
| `records/record_realtime.dart` | PocketBase records realtime subscribe/unsubscribe *(part)* |
| `records/record_timeline_vm.dart` | Timeline day index, warm window, row VM builders *(part)* |
| `records/record_outbox_helpers.dart` | Record mutation outbox enqueue/flush/replay, Highlander server phase *(part)* |
| `records/record_overlap_helpers.dart` | Highlander local apply, singleton reconcile, overlap probes *(part)* |
| `records/record_ghost_cleanup.dart` | 404 deadletter prune against live cache *(part)* |
| `records/record_cache_helpers.dart` | Per-day filter, `recordsStream`, display-time helpers *(part)* |
| `plan_service.dart` | Plans/lists coordinator: CRUD, streams, wall-time projection, alarms, AI parse *(part)* |
| `plans/plan_projection_types.dart` | `TimeModeProjectedPlan`, `PlanTimeModeProjection` *(part)* |
| `plans/plan_recurrence_helpers.dart` | RRULE JIT expansion, exception-date parse helpers *(part)* |
| `plans/plan_time_cascade_helpers.dart` | Time View cascade, duration consts, `planningWallEstimateSeconds` *(part)* |
| `plans/plan_tags_helpers.dart` | Plan/list tag catalog fetch + PB `tags_link` sync *(part)* |
| `plans/plan_cache_helpers.dart` | Plan dedupe/scrub, title link scoring heuristics *(part)* |
| `plans/plan_outbox_helpers.dart` | Plan mutation outbox enqueue/flush/replay *(part)* |
| `category_service.dart` | Category coordinator: flatten/PB bridge statics, stats duration helpers, local task prefs helpers *(part)* |
| `categories/category_cache_helpers.dart` | Category fetch, slug reservation, `_loadRulesFromNoco` *(part)* |
| `categories/category_tree.dart` | Category hierarchy build/sort, parent/child, subtree record ids *(part)* |
| `categories/category_lookup.dart` | Fuzzy/smart match, path resolution, business id ↔ PB id *(part)* |
| `categories/category_crud.dart` | Category create/update/archive, PB payloads, ordering writes *(part)* |
| `categories/category_stats.dart` | Category-scoped stats aggregation, duration rollups *(part)* |
| `categories/category_record_bridge.dart` | Record/category relation repair, REST id resolution, ghost purge *(part)* |
| `categories/category_default_time.dart` | `default_plan_time` read/write, inherited schedule lookup *(part)* |
| `profile_service.dart` | Profile coordinator: shared Brain state, display label resolver *(part)* |
| `profile/profile_hydration.dart` | Profile fetch/hydration lifecycle, PB map apply, retry *(part)* |
| `profile/profile_settings.dart` | Profile PATCH/save, diff fields, locale sync *(part)* |
| `profile/profile_timezone.dart` | Timezone normalize/offset, projected today, TZ writes *(part)* |
| `profile/profile_cache_helpers.dart` | Device prefs mirror/hydrate for profile settings *(part)* |
| `profile/profile_preferences.dart` | Data region reload hook *(part)* |
| `profile/profile_admin.dart` | Admin bool parse helper for hydration *(part)* |
| `profile/tag_catalog.dart` | Tag catalog fetch/CRUD, sort order, PB `tags_link` id resolution *(part)* |
| `profile/tag_display_settings.dart` | List tag strip visibility prefs, display-mode prefs merge *(part)* |
| `models.dart` | `part` declarations; export surface for all model types |
| `models/_shared.dart` | Shared model helpers *(part)* |
| `models/profile.dart` | `UserSettings`, profile fields *(part)* |
| `models/category.dart` | `CategoryRule` *(part)* |
| `models/record.dart` | `TimelineRecord` *(part)* |
| `models/planning.dart` | `PlanningTask` *(part)* |
| `models/tag.dart` | `Tag`, `TagCatalogScope` *(part)* |
| `models/stats.dart` | Stats aggregates *(part)* |
| `pb_config.dart` | PocketBase URL, collection names, expand constants |
| `auth_bridge.dart` | Session check, OAuth routing |
| `category_fuzzy_match.dart` | Category name scoring |
| `price_reporter_client_match.dart` | Price Reporter client-category token guard for voice parse |
| `voice_command_parser.dart` | Deterministic desktop/mobile voice command parse (`parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`) |
| `smart_input_parser.dart` | Natural-language plan/list parse (client + AI backend hook) |
| `recurrence_edit_scope.dart` | `RecurrenceEditScope` enum for recurring plan edit/delete scope |
| `plan_time_sequential_cascade.dart` | Plan time sequential layout math + `computeTimeViewInsertionCascade` |
| `time_view_fixed_time_policy.dart` | Local prefs `time_view_fixed_tag_ids_v1`; `isPlanFixedInTimeView` (schema gap: no PB sync yet) |
| `cache/day_snapshot_window.dart` | Rolling warm day snapshots for date paging |
| `cache/rendered_day_body_cache.dart` | Rendered day-body LRU cache |
| `cache/render_snapshot.dart` | Render snapshot helpers for day strips |
| `local_sync/record_mutation_outbox.dart` | Offline queue: record start/stop/update/delete |
| `local_sync/plan_mutation_outbox.dart` | Offline queue: plan/list create/update/delete |
| `local_sync/plan_create_outbox.dart` | Re-export of `plan_mutation_outbox.dart` |
| `local_sync/offline_sync_state.dart` | Pending count, syncing, auth-paused UI state |
| `local_sync/sync_manager.dart` | Connectivity / resume → flush trigger |
| `voice_audio_stub.dart` | Non-web voice audio stub |
| `voice_audio_web.dart` | Web voice audio implementation |
| `web_history.dart` | Web history API conditional export |
| `web_history_stub.dart` | Non-web history stub |
| `web_history_web.dart` | Web history implementation |

### 3.3 `lib/core/` — Foundation

**Root**

| File | Role |
| :--- | :--- |
| `theme.dart` | `ThemeData`, density, input decoration |
| `app_colors.dart` | Color tokens |
| `constants.dart` | UI limits, global keys |
| `app_snackbar.dart` | `AppSnack` toasts |
| `app_build_info.dart` | Build metadata |
| `app_icons.dart` | Canonical icon tokens (timezone family, shared glyphs) |
| `category_color_palette.dart` | Category tile palette |
| `date_pager_settle_gate.dart` | Shared date `PageView` settle coordinator |
| `date_swipe_physics.dart` | Date swipe physics |
| `link_scalar.dart` | Plan link scalar helper |
| `picker_entry_modes.dart` | Platform-aware picker entry (keyboard vs touch) |
| `plan_category_lookup.dart` | Category presentation lookup (shell-injected) |
| `shell_adaptive.dart` | Side vs bottom navigation breakpoint |
| `shell_layout_state.dart` | `ShellLayoutController` / FAB clearance |
| `tag_contrast.dart` | Tag foreground/background contrast |
| `url_strategy_stub.dart` | Web URL strategy conditional import |

**`core/diagnostics/`**

| File | Role |
| :--- | :--- |
| `runtime_log.dart` | Uncaught error logging |
| `platform_log.dart` | Platform-specific log sinks |
| `startup_log.dart` | Boot-phase structured logs |
| `plan_duplicate_log.dart` | Plan duplicate detection logs |
| `desktop_voice_log.dart` | `DesktopVoiceLog` — concise desktop-voice pipeline markers (debug/profile only; release quiet) |
| `desktop_voice_pipeline.dart` | Desktop-voice pipeline step helpers built on `DesktopVoiceLog` |

**`core/navigation/`**

| File | Role |
| :--- | :--- |
| `app_navigator.dart` | `appRootNavigatorKey` — root navigator for desktop overlays when main window is hidden |

**`core/performance/`**

| File | Role |
| :--- | :--- |
| `runtime_flags.dart` | Feature kill switches (date strip, warm window, etc.) |
| `shell_flags.dart` | Shell tab stack behavior flags |
| `rebuild_metrics.dart` | Rebuild/frame metrics (`--dart-define=PERF_DIAG` gated) |

**`core/time/`**

| File | Role |
| :--- | :--- |
| `app_clock.dart` | Injectable wall clock + timezone label |
| `profile_timezone_actions.dart` | Injectable profile timezone read/write hooks (`ProfileTimezoneActions`) |
| `profile_timezone_catalog.dart` | Canonical profile timezone catalog, IANA IDs, DST labels |
| `web_redirect.dart` | Production web OAuth redirect URI helper |
| `wall_clock.dart` | Wall-clock formatting helpers |
| `plan_time_labels.dart` | Plan time label formatting |
| `plan_time_visible_window.dart` | Extended Time View day window math (−3..27 h) |
| `category_timezone_options.dart` | Per-category timezone option list |

**`core/env/`**

| File | Role |
| :--- | :--- |
| `env.dart` | Compile-time environment constants (gitignored copy from example) |

**`core/services/`**

| File / pattern | Role |
| :--- | :--- |
| `speech_engine_handle.dart` | Speech-to-text engine lifecycle |
| `speech_listen_locale.dart` | STT locale resolution |
| `pcm_audio_utils.dart` | PCM/WAV audio helpers for desktop STT |
| `desktop_hotkey_codec.dart` | Desktop hotkey string encode/decode |
| `desktop_stt_diagnostics.dart` | STT helper diagnostics markers |
| `desktop_stt_helper_service.dart` | Desktop GOLOS STT helper subprocess and HTTP transcribe |
| `desktop_tray_service.dart` | System tray entry (conditional export) |
| `desktop_tray_service_io.dart` | Windows tray implementation |
| `desktop_tray_service_stub.dart` | Non-desktop tray stub |
| `desktop_voice_settings.dart` | Local desktop voice prefs (SharedPreferences) |
| `desktop_voice_hotkey.dart` | Global desktop voice hotkey coordinator |
| `desktop_voice_hotkey_io.dart` | Windows hotkey registration |
| `desktop_voice_hotkey_stub.dart` | Non-desktop hotkey stub |
| `desktop_voice_hotkey_markers.dart` | Hotkey self-test / acceptance markers |
| `desktop_voice_recognizer.dart` | Desktop voice recognizer interface |
| `desktop_voice_recognizer_factory.dart` | Platform recognizer factory |
| `desktop_voice_recognizer_io.dart` | Windows recognizer implementation |
| `desktop_voice_recognizer_stub.dart` | Non-desktop recognizer stub |
| `desktop_voice_engine.dart` | Desktop voice engine lifecycle |
| `desktop_voice_audio_capture.dart` | Mic capture for desktop voice |
| `desktop_voice_overlay_service.dart` | Native overlay state machine |
| `desktop_voice_native_overlay.dart` | Native overlay channel bridge |
| `desktop_voice_overlay_bridge.dart` | Overlay ↔ Flutter bridge |
| `desktop_voice_overlay_host.dart` | Overlay host conditional export |
| `desktop_voice_overlay_host_io.dart` | Windows overlay host |
| `desktop_voice_overlay_host_stub.dart` | Non-desktop overlay host stub |
| `desktop_voice_window_flags.dart` | Desktop window visibility flags |
| `desktop_voice_confirmation.dart` | Start/stop voice confirmation copy |
| `desktop_voice_command_normalize.dart` | Transcript normalization before parse/submit |
| `desktop_voice_record_submit.dart` | Parsed voice command → `writeRecord` bridge |
| `desktop_voice_user_error.dart` | Friendly desktop voice error mapping |
| `desktop_voice_attempt_log.dart` | Persisted voice attempt history for profile UI |
| `desktop_voice_acceptance_bridge.dart` | Acceptance-test hooks for desktop voice |
| `desktop_voice_smoke_bridge.dart` | Smoke-test hooks for desktop voice |
| `desktop_voice_benchmark_service.dart` | Desktop voice benchmark harness |
| `desktop_win_speech_service.dart` | Windows speech platform adapter |

Desktop voice modules follow the `desktop_voice_*.dart` naming pattern under `core/services/`; new modules should stay in this folder and be listed here.

**`core/widgets/`** — canonical shared UI

| File | Role |
| :--- | :--- |
| `app_button.dart` | `AppButton` |
| `app_settings_layout.dart` | `AppSettingsPageBody`, `AppSettingsSectionCard`, settings row helpers |
| `app_icon_button.dart` | `AppIconButton` |
| `app_mic_level_bars.dart` | Mic level visualization bars for voice UI |
| `app_timezone_icon.dart` | Canonical solid timezone icon family |
| `app_loading.dart` | `AppLoading` |
| `app_state_views.dart` | `AppErrorState`, `AppEmptyState` |
| `confirm_dialog.dart` | `showConfirmDialog` |
| `global_app_header.dart` | Date/time header strip |
| `timezone_quick_picker.dart` | `HeaderTimezoneQuickSwitcher`, profile timezone quick picker |
| `app_bar_live_clock.dart` | Live clock chip |
| `omni_date_time_picker_dialog.dart` | Unified date+time picker |
| `compact_nav_controls.dart` | Compact segmented controls |
| `chip_component.dart` | `TagChip`, `CategoryChip`, tag quick-pick strip |
| `plan_time_task_card.dart` | Compatibility barrel → `plan_time_task_card/` package |
| `plan_time_task_card/plan_time_task_card.dart` | Public `PlanTimeTaskCard` widget |
| `plan_time_task_card/plan_card_metrics.dart` | Time View card height constants, `PlanCardSurface`, duration→px helpers |
| `plan_time_task_card/plan_card_density.dart` | Visual density bands, measure/gesture inset helpers |
| `plan_time_task_card/plan_card_geometry.dart` | Figma geometry, vertical spacing, visual tokens |
| `plan_time_task_card/plan_card_controls.dart` | Checkbox/play/menu/title rail, body tap shell, control rail |
| `plan_time_task_card/plan_card_sections.dart` | Time text, footer, watermark |
| `plan_time_task_card/plan_card_tags.dart` | Time View tag row/stack/pill widgets |
| `plan_time_task_card/plan_card_progress.dart` | Progress slot, invariant body, rail shell |
| `plan_time_task_card/plan_card_layouts.dart` | Time View CardPlan density layout variants |
| `plan_card/plan_card_metrics.dart` | Re-export stub → `plan_time_task_card/plan_card_metrics.dart` |
| `plan_card/plan_time_card_density.dart` | Re-export stub → `plan_time_task_card/plan_card_density.dart` |
| `plan_card/plan_card_geometry.dart` | Re-export stub → `plan_time_task_card/plan_card_geometry.dart` |
| `plan_card/plan_card_controls.dart` | Re-export stub → `plan_time_task_card/plan_card_controls.dart` |
| `plan_card/plan_card_sections.dart` | Re-export stub → `plan_time_task_card/plan_card_sections.dart` |
| `plan_card.dart` | `PlanCard` wrapper |
| `life_card.dart` | Card foundation for Component Lab |
| `day_content_strip.dart` | Day content pager strip |
| `day_window.dart` | Mounted day window |
| `lazy_indexed_stack.dart` | Optional lazy shell tab stack |
| `mouse_drag_scroll_behavior.dart` | Desktop/web drag scroll |
| `tag_display_mode_scope.dart` | Tag display mode inherited widget |

### 3.4 `lib/features/` — UI modules

| Folder | Files | Role |
| :--- | :--- | :--- |
| `auth/` | `auth_view.dart`, `auth_screen.dart`, `oauth_session.dart` | Sign-in, register, OAuth, password reset |
| `timeline/` | `timeline_view.dart`, `timeline_header_controls.dart`, `timeline_day_page.dart`, `timeline_record_card.dart`, `timeline_helpers.dart` | `TimelineSwipeWrapper`, `TimelinePage`; header controls + day list + record cards |
| `stats/` | `stats_view.dart`, `plan_vs_fact_tab.dart` | Productivity stats (embedded in Timeline) |
| `planning/` | `planning_view.dart` (barrel), **`planning_page.dart`**, **`planning_page_shell.dart`**, **`planning_sort_mode.dart`**, `plan_time_view_layout.dart`, `plan_time_gesture_contract.dart`, `planning_day_start_prefs.dart`, `bulk_planning_edit_sheet.dart`, `recurrence_scope_dialog.dart`, `smart_plan_sheet.dart`, **`time_view/`**, **`settings/`**, **`widgets/`** | Plans tab: date pager shell + day page body, Time View modules, settings, bulk edit |
| `lists/` | `lists_view.dart`, `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart`, `lists_card.dart`, `lists_export.dart` | Lists/backlog coordinator + filter/bulk/inline/empty modules + card + export |
| `calendar/` | `calendar_view.dart` | Calendar tab |
| `categories/` | `category_list_view.dart`, `category_recursive_tree.dart`, `category_visibility_prefs.dart`, `create_category_dialog.dart` | Category manager (More menu) |
| `profile/` | `profile_view.dart`, **`settings/`** (account, notification, security sections), `tag_manager_page.dart`, `tag_settings_hub.dart`, `tag_settings_view.dart`, `tag_default_duration_settings_view.dart`, `timezone_settings.dart`, `desktop_voice_settings_section.dart`, `desktop_voice_settings_desktop.dart`, `desktop_voice_attempt_dialog.dart` | Profile & tag settings, timezone, desktop voice settings (Windows) |
| `dev/` | `component_lab_view.dart`, `component_lab_cards_demo.dart` | Admin-only Component Lab |
| `wear/` | `wear_timer_screen.dart`, `wear_main_wrapper.dart`, `wear_platform.dart`, `wear_runtime.dart` | Wear OS companion |
| `shared/` | `shared_widgets.dart` (barrel), `activity_detail_sheet.dart`, `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `empty_state_placeholder.dart`, **`edit_sheet/`** (autosave gate, time helpers/picker, checklist, repeat RRULE helpers, quill toolbar, parallel record panels), `offline_sync_status_bar.dart`, `voice_input_sheet.dart`, `voice_capture_config.dart`, `desktop_voice_widget.dart`, `desktop_voice_capsule.dart`, `desktop_voice_command_panel.dart` | Activity edit sheets, Omni-Picker entry, offline sync banner, mobile/web voice sheet, desktop Price Reporter voice UI |

**Key symbols:** `ActivityDetailSheet` router → `features/shared/activity_detail_sheet.dart`; `PlanningTaskEditSheet` / `TimelineRecordSheetContent` in dedicated files; `showAppDateTimePicker` / `EditSheetAutosaveGate` in `features/shared/edit_sheet/`; re-exported via `shared_widgets.dart`.

### 3.5 `lib/l10n/`

| File | Role |
| :--- | :--- |
| `dictionary.dart` | Assembles locale maps; exports `t()` and `currentLocale` |
| `app_locales.dart` | Supported locale codes and labels |
| `category_db_display.dart` | Localized category name display |
| `langs/en.dart` | **Canonical English** (`kEnL10n`) — SSOT for EN keys |
| `langs/ru.dart` | **Canonical Russian** (`kRuL10n`) — SSOT for RU keys |
| `langs/ar.dart`, `langs/de.dart`, `langs/es.dart`, `langs/fr.dart`, `langs/it.dart`, `langs/ko.dart`, `langs/zh.dart` | Partial locale maps layered on English |

### 3.6 `lib/services/`

| File | Role |
| :--- | :--- |
| `notification_service.dart` | Local notifications and plan alarms |

---

## 4. Repository root (non-`lib/`)

| Path | Role | Notes |
| :--- | :--- | :--- |
| `android/` | Android Gradle project | Flutter-generated + app manifest; build outputs under `android/build/` (gitignored) |
| `ios/` | iOS Xcode project | Flutter-generated; `Pods/` gitignored |
| `web/` | Web shell (`index.html`, icons, manifest) | GitHub Pages base-href `/Counter/` |
| `windows/`, `linux/`, `macos/` | Desktop embedders | Flutter platform runners |
| `test/` | Unit/widget tests | `flutter test`; perf and domain tests |
| `integration_test/` | Device integration tests | Emulator/device only |
| `scripts/` | Tooling | `audit/architecture_guard.ps1`, `sync_locales.dart`, `manual/td.ps1` (deploy), manual PB scripts |
| `installer/windows/` | Windows packaging | `counter.iss` (Inno Setup) → CI produces `CounterSetup.exe` |
| `docs/` | Governing documents | `ARCHITECTURE.md`, `DATA_MAP.md`, `POCKETBASE_MANIFEST.md`, `UX_CONTRACT.md`, `DESIGN_SYSTEM.md`, `DEPLOY.md`, `ROADMAP.md` |
| `pb_hooks/` | PocketBase server hooks (JS) | Deploy next to PocketBase binary on VPS |
| `design/` | Figma/reference assets | Design reference PNG/SVG |
| `build/` | Flutter build output | **Gitignored** — must not be tracked |
| `exports/` | Price Reporter / audit script output | **Gitignored** — local CSV/XLSX only |
| `tools/` | Sample data + migration helpers | `sample_data/` tracked; `tools/exports/` gitignored |
| `.dart_tool/` | Dart/Flutter tool cache | **Gitignored** — must not be tracked |
| `update.ps1` | Deploy wrapper | Calls `scripts/manual/td.ps1` |
| `.github/workflows/deploy.yml` | CI web deploy | Push `main` → `gh-pages` |
| `.github/workflows/windows-desktop-build.yml` | CI Windows installer | Manual `workflow_dispatch` → `CounterSetup.exe` |
| `pocketbase.service` | systemd unit example | VPS ops reference |
| `pubspec.yaml` | Flutter package manifest | |
| `analysis_options.yaml` | Analyzer rules | |

### PocketBase hooks (`pb_hooks/`)

| File | Role |
| :--- | :--- |
| `records.interval_sanitize.pb.js` | Enforces non-overlapping primary `records` intervals per `user_id` |
| `auth.request_password_reset.pb.js` | Password-reset request hook |

Copy `pb_hooks/` beside the PocketBase executable on the server. Client Brain code does not import these; behavior is documented in `docs/POCKETBASE_MANIFEST.md`.

### 3.4.1 Structure refactor modules (2026-07-02 — Pass 3 additions)

| File | Role |
| :--- | :--- |
| `planning/time_view/planning_time_view_host.dart` | `PlanningTimeViewHost` callback surface |
| `planning/time_view/planning_time_view_coordinator.dart` | Time View state fields |
| `planning/time_view/planning_time_view.dart` | Time View composition, cascade, edge scroll |
| `planning/time_view/time_view_canvas.dart` | Proportional day timeline canvas |
| `planning/time_view/time_view_hour_grid.dart` | Hour grid + unscheduled strip |
| `planning/time_view/time_view_card_layer.dart` | Scheduled card stack layer |
| `planning/time_view/time_view_drag_controller.dart` | Vertical drag state/helpers |
| `planning/time_view/time_view_resize_controller.dart` | Edge resize state/helpers |
| `planning/time_view/time_view_drop_preview.dart` | Drop intent / cascade preview |
| `planning/time_view/time_view_settings_sheet.dart` | Time View settings + default plan times |
| `planning/time_view/time_view_search_delegate.dart` | Category default-time search UI |
| `timeline/timeline_header_controls.dart` | List/stats segmented control + record input row |
| `timeline/timeline_day_page.dart` | `TimelineDayCardList`, lazy record list |
| `timeline/timeline_record_card.dart` | `TimelineRecordCard` |
| `timeline/timeline_helpers.dart` | Shared timeline time/duration helpers |
| `lists/lists_filters.dart` | Tag/category filter chips, chip bar, settings sheet |
| `lists/lists_bulk_actions.dart` | Select-mode header + bulk action bottom bar |
| `lists/lists_inline_add.dart` | Inline quick-add input row |
| `lists/lists_empty_state.dart` | Loading / filtered / no-category empty panels |
| `lists/lists_card.dart` | `BacklogPlanCard`, filter chips, semicircle menu |
| `lists/lists_export.dart` | Export visible list as clipboard text |
| `shell/life_os_dashboard.dart` | Shell dashboard entry (see §3.1.1) |
| `shell/shell_core.dart` | Shell core logic *(part)* |
| `shell/shell_tab_host.dart` | Tab host builders *(part)* |
| `shell/shell_edit_hosts.dart` | Edit sheet hosts *(part)* |
| `shell/shell_more_menu.dart` | More menu *(part)* |
| `shell/shell_voice_routing.dart` | Voice routing *(part)* |
| `shell/shell_offline_banner.dart` | Offline banner slot |
| `shell/shell_shared.dart` | Shell shared helpers *(part)* |
| `plan_time_task_card/plan_card_tags.dart` | Time View tag row/stack/pill widgets |
| `plan_time_task_card/plan_card_layouts.dart` | Time View CardPlan layout variants |
| `plan_time_task_card/plan_card_progress.dart` | Progress/invariant card shells |
| `plan_time_task_card/plan_card_density.dart` | Density bands + measure helpers |

### 3.4.2 Structure refactor modules (2026-07-02 — Pass 1–2)

Explicit manifest entries for `architecture_guard.ps1 -Strict`:

| File | Role |
| :--- | :--- |
| `planning/time_view/time_view_interaction_block.dart` | Time View card pointer/drag/resize zones |
| `planning/time_view/time_view_drag_state.dart` | `TimelineResizeEdge`, gesture phase enums |
| `planning/time_view/time_view_fixed_time_settings.dart` | Fixed-time tag chip settings block |
| `planning/settings/planning_timeline_bounds_sheet.dart` | Visible hour range slider sheet |
| `planning/settings/plan_record_link_settings.dart` | Record→plan suggestion prefs |
| `planning/settings/planning_no_tags_settings.dart` | Synthetic “No Tags” chip prefs |
| `planning/settings/default_plan_category_search.dart` | Default plan category search delegate |
| `planning/settings/default_plan_timezone_search.dart` | Default plan TZ search delegate |
| `planning/widgets/planning_menu_overlay.dart` | Semicircle plan card radial menu |
| `planning/widgets/planning_day_card_list_keep_alive.dart` | List keep-alive wrapper |
| `planning/widgets/plan_card_reorder_settle.dart` | Done-card reorder slide settle |
| `planning/planning_page.dart` | `PlanningPage` + day body state (~2.4k lines; coordinator delegates Time View) |
| `planning/planning_page_shell.dart` | `PlanningSwipeWrapper` date pager |
| `planning/planning_sort_mode.dart` | `PlanSortMode` + persist index helpers |
| `planning/widgets/planning_bulk_bar.dart` | Bulk selection bottom bar |
| `planning/widgets/planning_filter_controls.dart` | Sort-mode segmented control |
| `planning/widgets/planning_empty_states.dart` | Planning empty-state widgets |
| `planning/widgets/planning_quick_add_strip.dart` | Quick-add tag strip above inline task field |
| `planning/widgets/planning_list_helpers.dart` | Reorder list proxy decorator |
| `profile/settings/settings_page.dart` | Language/TZ settings page (shell route) |
| `shared/profile_hydration_status_bar.dart` | Profile hydration error banner |
| `core/navigation/shell_side_navigation.dart` | Desktop/web side navigation rail |
| `profile/settings/account_settings_section.dart` | Signed-in identity + logout row |
| `profile/settings/notification_settings_section.dart` | OS notification permission block |
| `profile/settings/security_settings_section.dart` | Password reset + biometric lock |
| `shared/activity_detail_sheet.dart` | Edit sheet router (`ActivityDetailKind`) |
| `shared/planning_task_edit_sheet.dart` | Plan/list task edit sheet |
| `shared/timeline_record_edit_sheet.dart` | Timeline record edit sheet |
| `shared/empty_state_placeholder.dart` | Shared empty-state placeholder |
| `shared/offline_sync_status_bar.dart` | O1 offline/sync tap-to-retry banner |
| `shared/edit_sheet/sheet_autosave_gate.dart` | Debounced edit-sheet autosave gate |
| `shared/edit_sheet/sheet_time_helpers.dart` | UTC/display time format helpers |
| `shared/edit_sheet/sheet_time_picker.dart` | `showAppDateTimePicker`, `AppEditSheetTimeButton` |
| `shared/edit_sheet/checklist_helpers.dart` | Checklist row sync/partition helpers |
| `shared/edit_sheet/plan_repeat_helpers.dart` | RRULE ↔ UI repeat preset helpers |
| `shared/edit_sheet/quill_link_launcher.dart` | Quill note external URL launcher |
| `shared/edit_sheet/quill_toolbar_config.dart` | Planning edit Quill toolbar config |
| `shared/edit_sheet/parallel_record_panels.dart` | Backlog sub-items + parallel child panels |

---

## 5. Governing documents

| Document | Purpose |
| :--- | :--- |
| `docs/APP_STRUCTURE.md` | This file — concise canonical structure |
| `docs/APP_STRUCTURE_DETAILED.md` | Bilingual file-by-file guide (EN/RU) |
| `docs/APP_STRUCTURE_EXPLAINED_RU.md` | Short Russian practical map for Nick |
| `docs/ARCHITECTURE.md` | Data flow, iron laws, optimistic UI, performance |
| `docs/DATA_MAP.md` | PocketBase field names and business IDs |
| `docs/POCKETBASE_MANIFEST.md` | URLs, collections, server hooks |
| `docs/UX_CONTRACT.md` | Tap/save/loading/offline behavior |
| `docs/DESIGN_SYSTEM.md` | Figma → Flutter canonical components |
| `docs/DEPLOY.md` | GitHub Pages deploy |
| `docs/ROADMAP.md` | Current work plan |

---

## 6. Structure audit

Run from repo root:

```powershell
.\scripts\audit\architecture_guard.ps1           # warnings, exit 0
.\scripts\audit\architecture_guard.ps1 -Strict   # fail on any violation
.\scripts\manual\structure_scan.ps1              # optional tree snapshot to docs/reports/
```

---

## 7. Do not split further without product reason

| Area | Why leave as-is |
| :--- | :--- |
| `plan_service.dart` coordinator | Shared plan cache, streams, wall-time reprojection, CRUD entry — tightly coupled |
| `planning_page.dart` | Time View state machine + day body; further split needs UX/product scope |
| `database_service.dart` root | Singleton host only (~720 lines); domain logic already in `part` files |
| `record_service.dart` / `category_service.dart` / `profile_service.dart` coordinators | Cross-domain static bridges and shared Brain state |
| Platform folders (`android/`, `ios/`, …) | Flutter-generated runners — not product logic |

One-off Pass 3/Pass 2 extraction scripts (`scripts/pass3_*`, `scripts/extract_*`, `scripts/split_planning_page.py`) were **removed** 2026-07-03 after decomposition shipped. See `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md` for acceptance summary.

Pass 4 regex/line Brain split scripts (`pass4_brain_split.py`, `pass4_split_fast.py`) were **removed** after a failed attempt. Pass 4A–4D used symbol-aware batches only.

---

## 8. Next product priorities (not structure)

From `docs/ROADMAP.md` — active velocity track is **V3 UX_CONTRACT / V7 Design System** (canonical components, Component Lab). Feature work (F2B plan category filter, list pin schema, etc.) remains paused unless explicitly requested.

---
