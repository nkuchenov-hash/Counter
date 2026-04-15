# 🏗️ APP_STRUCTURE (Life OS)

> **WARNING:** This is the foundational map of the application. Do NOT summarize, truncate, or refactor this document. It defines the physical geography of the codebase and how modules interact.

## 1. Directory Map

lib/
├── data/                       // THE BRAIN & DNA (Logic Only)
│   ├── models.dart             // [DNA] Pure Classes (Record, Category, PlanningTask, Profile, Tag). No UI code.
│   ├── database_service.dart   // [CRUD] The God Object. All PocketBase logic, HTTP calls, and local state caching.
│   ├── pb_config.dart          // [CONFIG] PocketBase URL, Collections, & Expands.
│   ├── auth_bridge.dart        // [GATE] Auth session management & providers.
│   └── stubs/                  // [STUBS] Web/Platform stubs for IO and HTML.
├── l10n/                       // THE VOICE
│   └── dictionary.dart         // [TRANSLATIONS] EN/RU Maps & t() localization helper.
├── core/                       // THE FOUNDATION
│   ├── theme.dart              // [STYLE] Global ThemeData, Colors, & InputStyles.
│   └── constants.dart          // [RULES] Hard limits, UI constants, & global keys.
├── services/                   // OS & DEVICE BRIDGE (non-UI)
│   └── notification_service.dart // [ALARMS] flutter_local_notifications + timezone; [DatabaseService] debounces into [syncAlarms].
├── features/                   // THE SHELLS (UI Modules)
│   ├── timeline/               // Activity Feed & Time Blocks
│   │   ├── timeline_view.dart
│   │   ├── timeline_widgets.dart
│   │   └── stats/              // [SUB-MODULE] Productivity Analytics
│   │       └── stats_view.dart
│   ├── planning/               // Day Planning & Task List
│   │   ├── planning_view.dart
│   │   └── task_widgets.dart
│   ├── calendar/               // Monthly View
│   │   └── calendar_view.dart
│   ├── categories/             // Management UI
│   │   ├── category_list_view.dart
│   │   └── category_editor_sheet.dart
│   ├── profile/                // Account & Settings
│   │   ├── profile_view.dart
│   │   └── settings_widgets.dart
│   └── shared/                 // [COMMON] Global UI
│       ├── shared_widgets.dart // Shared UI components (Dropdowns, Sheets)
│       └── category_folder_tile.dart  // Shared Category UI
├── app_shell.dart              // THE NAVIGATOR (Dashboard & BottomNavBar logic)
├── auth_service.dart           // THE KEY (Legacy Auth wrapper / Bridge logic)
└── main.dart                   // THE IGNITION (Initialization & AuthGate only)

---

## 2. Module Interactions & Data Flow

This app operates on a strict **Unidirectional Data Flow** principle. 

* **`data/` (The Brain):** This is the single source of truth. It communicates with the PocketBase server and holds the active state in memory. **Rule:** The Data layer NEVER imports anything from `features/`. It does not know the UI exists.
* **`features/` (The Shells):** These are "dumb" UI layers. They read data from `database_service.dart` and render it. When a user takes an action (e.g., clicks "Save"), the feature does NOT mutate data directly. It calls a method in `database_service.dart`. **Rule:** Features can import from `data/` and `core/`, but should rarely cross-import from other features unless using `shared/`.
* **`core/` & `l10n/` (The Foundation):** These are pure utility layers. They provide styling, strings, and constants. They NEVER contain business logic or database calls.
* **`services/` (Device Bridge):** Platform capabilities (local notifications, time zones) without UI. **Rule:** May depend on `data/` models only; no `features/`. The Brain (`database_service.dart`) schedules work here via debounced fire-and-forget calls — never block record I/O.

---

## 3. The Constitution: Core Documentation

This `APP_STRUCTURE` file is just one piece of the project's governing documents. Cursor and human developers MUST consult the following files in tandem to understand the full system:

1. **`@APP_STRUCTURE` (The Geography):** You are here. Dictates *where* files live and the physical boundaries between UI and Logic.
2. **`@ARCHITECTURE.md` (The Laws of Physics):** Dictates *how* the app is built. It defines the specific state management patterns, error handling rules, and UI architectural standards. If `APP_STRUCTURE` is the map, `ARCHITECTURE.md` is the law.
3. **`@DATA_MAP.md` (The Schema & Iron Laws):** The absolute source of truth for the PocketBase database. It defines collections, field types, primary keys, and the strict rules for relationships (e.g., The Singleton Timeline Law). NEVER alter a database call without consulting this.
4. **`@pocketbase_MANIFEST` (The Backend):** Details the server-side environment, custom JS hooks (e.g., AI parsing endpoints, overlap truncation), and PB configuration. Explains what the server does so the client doesn't try to reinvent the wheel.
5. **`@.cursorrules` (The Enforcer):** The meta-document that forces the AI agent to read documents 1 through 4 before writing a single line of code.