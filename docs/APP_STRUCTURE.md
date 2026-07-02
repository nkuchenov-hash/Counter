# APP_STRUCTURE (Life OS)

Physical map of the Flutter application: what exists, which layer owns it, who may import it, and who must not.

**Package name:** `counter` — all Dart imports use `package:counter/...` (no relative imports).

---

## 1. Layer model

| Layer | Path | Owns | May import | Must NOT import |
| :--- | :--- | :--- | :--- | :--- |
| **Entry** | `lib/main.dart`, `lib/app_shell.dart` | Boot, auth gate, shell navigation, cross-tab wiring | `data/`, `core/`, `features/`, `l10n/`, `services/` | — |
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

**Brain rule:** `lib/data/database_service.dart` is the only file that performs HTTP/PocketBase calls. Domain logic lives in `part of` extensions (`db_core.dart`, `record_service.dart`, `plan_service.dart`, `category_service.dart`, `profile_service.dart`).

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
| `app_shell.dart` | Bottom/side nav, tab `IndexedStack`, FAB/voice, offline banner, edit-sheet host, `TagDisplayModeScope` |

**Shell tabs (bottom nav index):** 0 Timeline · 1 Plans · 2 Calendar · 3 Lists · 4 More (Categories, Profile, admin Component Lab).

### 3.2 `lib/data/` — Brain & models

| File / folder | Role |
| :--- | :--- |
| `database_service.dart` | Singleton root: shared state, streams, static helpers; `part` coordinator |
| `db_core.dart` | Bootstrap: `loadInitialData`, PocketBase health, lifecycle, flush outboxes *(part)* |
| `record_service.dart` | Records CRUD, optimistic start/stop, realtime *(part)* |
| `plan_service.dart` | Plans/lists CRUD, rrule, alarms, AI parse *(part)* |
| `category_service.dart` | Category CRUD, fuzzy match *(part)* |
| `profile_service.dart` | Profile, timezone, tags catalog *(part)* |
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
| `plan_time_task_card.dart` | Plan/list/time card (re-exports `plan_card/*` metrics) |
| `plan_card/plan_card_metrics.dart` | Time View card height constants, `PlanCardSurface`, duration→px helpers |
| `plan_card/plan_time_card_density.dart` | `PlanTimeCardVisualDensity` bands + footer/progress visibility helpers |
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
| `timeline/` | `timeline_view.dart` | `TimelineSwipeWrapper`, `TimelinePage`; list/stats sub-tabs |
| `stats/` | `stats_view.dart`, `plan_vs_fact_tab.dart` | Productivity stats (embedded in Timeline) |
| `planning/` | `planning_view.dart`, `plan_time_view_layout.dart`, `plan_time_gesture_contract.dart`, `planning_day_start_prefs.dart`, `bulk_planning_edit_sheet.dart`, `recurrence_scope_dialog.dart`, `smart_plan_sheet.dart`, **`time_view/`** (interaction block, drag state, fixed-time settings), **`settings/`** (timeline bounds, record-link, no-tags, default category/TZ search), **`widgets/`** (menu overlay, keep-alive, reorder settle) | Plans tab, Time View canvas + gestures, settings sheets, bulk edit, smart add |
| `lists/` | `lists_view.dart` | Lists/backlog tab |
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

### 3.4.1 Structure refactor modules (2026-07-02)

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
| `docs/APP_STRUCTURE.md` | This file — physical geography |
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
```
