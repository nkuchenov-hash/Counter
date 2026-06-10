# 🏗️ APP_STRUCTURE (Life OS)

> **WARNING:** This is the foundational map of the application. Do NOT summarize, truncate, or refactor this document. It defines the physical geography of the codebase and how modules interact.

## 1. Directory Map

lib/
├── data/                          // THE BRAIN & DNA (Logic Only)
│   ├── models.dart                // [DNA] Part coordinator — `part` declarations only; all types in models/
│   ├── models/                    // Part files: _shared, profile, category, record, planning, tag, stats
│   ├── database_service.dart      // [BRAIN ROOT] Singleton, shared state, streams, static helpers. Part files below.
│   ├── db_core.dart               // [BOOTSTRAP] PocketBase init, health/circuit, lifecycle, loadInitialData. (part of database_service)
│   ├── profile_service.dart       // [PROFILE] User settings, timezone, tags. (part of database_service)
│   ├── plan_service.dart          // [PLANS] Planning tasks, rrule, alarms, AI parse. (part of database_service)
│   ├── record_service.dart        // [RECORDS] Timeline CRUD, optimistic UI, realtime. (part of database_service)
│   ├── category_service.dart      // [CATEGORIES] Category CRUD, fuzzy match, stats helpers. (part of database_service)
│   ├── pb_config.dart             // [CONFIG] PocketBase URL, Collections, & Expands.
│   ├── auth_bridge.dart           // [GATE] Auth session management, OAuth, & Profile routing.
│   ├── category_fuzzy_match.dart  // Category name fuzzy-match scoring.
│   ├── local_sync/                // [OFFLINE-FIRST] SharedPreferences mutation outboxes + sync state
│   │   ├── record_mutation_outbox.dart // Records: start/stop/update/delete mutation queue
│   │   ├── plan_mutation_outbox.dart   // Plans/Lists: create/update/delete mutation queue
│   │   ├── plan_create_outbox.dart     // Legacy re-export to plan_mutation_outbox.dart
│   │   ├── offline_sync_state.dart     // Pending count, syncing/auth-paused/error state
│   │   └── sync_manager.dart           // Connectivity/app-resume drain trigger
│   └── (platform stubs)          // html_stub.dart, voice_audio_stub.dart, web_history*.dart
├── l10n/                          // THE VOICE
│   ├── dictionary.dart            // [TRANSLATIONS] EN/RU Maps & t() localization helper.
│   ├── app_locales.dart           // Locale codes, labels, supported language list.
│   ├── category_db_display.dart   // Category name display helpers.
│   └── langs/                     // Per-language maps: en, ru, de, fr, es, it, zh, ko, ar.
├── core/                          // THE FOUNDATION (Rules & UI Building Blocks)
│   ├── theme.dart                 // [STYLE] Global ThemeData, Colors, & InputStyles.
│   ├── constants.dart             // [RULES] Hard limits, UI constants, & global keys.
│   ├── picker_entry_modes.dart    // [WEB ACCELERATOR] Platform-aware picker logic (Keyboard vs Touch).
│   ├── shell_layout_state.dart    // ShellLayoutController / ShellLayoutScope (FAB clearance, edge scroll).
│   ├── app_snackbar.dart          // AppSnack — single-line success/failure toasts.
│   ├── category_color_palette.dart // Color palette for category tiles.
│   ├── env/                       // env.dart — compile-time environment constants.
│   ├── services/                  // speech_engine_handle.dart, speech_listen_locale.dart
│   ├── subscription/              // app_tier.dart — free/pro tier gate.
│   └── widgets/                   // [SHARED UI] Global system components (8 primitives).
│       ├── global_app_header.dart             // Unified Date/Time Header.
│       ├── omni_date_time_picker_dialog.dart  // Unified Web/Desktop Date+Time dialog.
│       ├── app_loading.dart                   // AppLoading(size:) — canonical spinner.
│       ├── confirm_dialog.dart                // showConfirmDialog() — canonical yes/no alert.
│       ├── app_button.dart                    // AppButton — canonical action button.
│       ├── app_state_views.dart               // AppErrorState, AppEmptyState.
│       ├── app_bar_live_clock.dart            // Live clock widget for app bars.
│       └── mouse_drag_scroll_behavior.dart    // Mouse-drag scroll for desktop/web.
├── services/                      // OS & DEVICE BRIDGE (non-UI)
│   └── notification_service.dart  // [ALARMS] flutter_local_notifications + timezone.
├── features/                      // THE SHELLS (UI Modules)
│   ├── auth/                      // [SECURITY] The Front Door
│   │   ├── auth_view.dart         // Sign In, Register, OAuth, Password Reset.
│   │   └── auth_screen.dart       // Re-export shim.
│   ├── timeline/                  // [TIME] Activity Feed & Time Blocks (Records)
│   │   ├── timeline_view.dart
│   │   └── timeline_widgets.dart
│   ├── stats/                     // [ANALYTICS] Productivity stats (was timeline/stats/)
│   │   ├── stats_view.dart
│   │   └── plan_vs_fact_tab.dart
│   ├── planning/                  // [FUTURE] Day Planning & Task List (Time-Bound)
│   │   ├── planning_view.dart
│   │   ├── bulk_planning_edit_sheet.dart
│   │   ├── smart_input_parser.dart
│   │   ├── smart_plan_sheet.dart
│   │   └── planning_day_start_prefs.dart
│   ├── lists/                     // [INBOX] GTD Backlog & Raw Ideas (Content-Bound)
│   │   └── lists_view.dart        // Bulk-edit, Category Trees, and Idea-to-Plan graduation.
│   ├── calendar/                  // [MACRO] Monthly View
│   │   └── calendar_view.dart
│   ├── categories/                // [SYSTEM] Management UI
│   │   ├── category_list_view.dart
│   │   ├── category_recursive_tree.dart
│   │   ├── category_visibility_prefs.dart
│   │   └── create_category_dialog.dart
│   ├── profile/                   // [USER] Account & Settings
│   │   ├── profile_view.dart
│   │   ├── tag_manager_page.dart
│   │   ├── tag_settings_hub.dart
│   │   ├── tag_settings_view.dart
│   │   ├── timezone_settings.dart
│   │   └── wall_clock.dart        // Profile timezone wall-clock helpers (PLANETARY_TIME).
│   ├── more/                      // [OVERFLOW] Categories + Profile nav hub
│   │   └── more_view.dart
│   ├── wear/                      // [WEAR OS] Watch companion
│   │   ├── wear_timer_screen.dart
│   │   ├── wear_main_wrapper.dart
│   │   ├── wear_platform.dart
│   │   └── wear_runtime.dart
│   └── shared/                    // [COMMON] Feature-level shared UI
│       ├── shared_widgets.dart    // Activity detail sheet, task edit sheets, dropdowns.
│       ├── chip_component.dart    // CategoryChip, TagChip primitives.
│       ├── tag_contrast.dart      // Tag color contrast helpers.
│       ├── voice_input_sheet.dart // Voice capture bottom sheet.
│       └── voice_capture_config.dart
├── app_shell.dart                 // THE NAVIGATOR (Dashboard & BottomNavBar routing)
└── main.dart                      // THE IGNITION (Initialization & AuthGate barrier)

---

## 2. Module Interactions & Data Flow

This app operates on a strict **Unidirectional Data Flow** principle. 

* **`data/` (The Brain):** This is the single source of truth. It communicates with the PocketBase server and holds the active state in memory. **Rule:** The Data layer NEVER imports anything from `features/`. It does not know the UI exists.
* **`features/` (The Shells):** These are "dumb" UI layers. They read data from `database_service.dart` and render it. When a user takes an action (e.g., clicks "Save"), the feature does NOT mutate data directly. It calls a method in `database_service.dart`. **Rule:** Features can import from `data/`, `core/`, and `l10n/`, but should rarely cross-import from other features unless using `features/shared/`.
* **`core/` & `l10n/` (The Foundation):** These are pure utility layers. They provide styling, shared widgets (like the Omni-Picker), strings, and constants. They NEVER contain business logic or database calls.
* **`services/` (Device Bridge):** Platform capabilities (local notifications, time zones) without UI. **Rule:** May depend on `data/` models only; no `features/`. The Brain (`database_service.dart`) schedules work here via debounced fire-and-forget calls — never block record I/O.

---

## 3. The Constitution: Core Documentation

This `APP_STRUCTURE` file is just one piece of the project's governing documents. Cursor and human developers MUST consult the following files in tandem to understand the full system:

1. **`@APP_STRUCTURE` (The Geography):** You are here. Dictates *where* files live and the physical boundaries between UI and Logic.
2. **`@ARCHITECTURE.md` (The Laws of Physics):** Dictates *how* the app is built. It defines state management patterns, error handling rules, The Omni-Picker Law, and GTD Inbox paradigms. If `APP_STRUCTURE` is the map, `ARCHITECTURE.md` is the law.
3. **`@DATA_MAP.md` (The Schema & Iron Laws):** The absolute source of truth for the PocketBase database. It defines collections, field types, primary keys, and strict rules for relationships (e.g., The Singleton Timeline Law). NEVER alter a database call without consulting this.
4. **`@pocketbase_MANIFEST` (The Backend):** Details the server-side environment, custom JS hooks, and PB configuration. Explains what the server does so the client doesn't try to reinvent the wheel.
5. **`@.cursorrules` (The Enforcer):** The meta-document that forces the AI agent to read documents 1 through 4 before writing a single line of code.
