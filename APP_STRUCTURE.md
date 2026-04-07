# 🏗️ APP_STRUCTURE (Life OS)

> **WARNING:** This is the foundational map of the application. Do NOT summarize, truncate, or refactor this document.

## Directory Map

lib/
├── data/                       // THE BRAIN & DNA (Logic Only)
│   ├── models.dart             // [DNA] Pure Classes (Record, Category, PlanningTask, Profile, Tag)
│   ├── database_service.dart   // [CRUD] All PocketBase logic & SDK calls
│   ├── pb_config.dart          // [CONFIG] PocketBase URL, Collections, & Expands
│   ├── auth_bridge.dart        // [GATE] Auth session management & providers
│   └── stubs/                  // [STUBS] Web/Platform stubs for IO and HTML
├── l10n/                       // THE VOICE
│   └── dictionary.dart         // [TRANSLATIONS] EN/RU Maps & t() localization helper
├── core/                       // THE FOUNDATION
│   ├── theme.dart              // [STYLE] Global ThemeData, Colors, & InputStyles
│   └── constants.dart          // [RULES] Hard limits, UI constants, & global keys
├── features/                   // THE SHELLS (UI Modules)
│   ├── timeline/               // Activity Feed (Time Blocks)
│   │   ├── timeline_view.dart
│   │   └── timeline_widgets.dart
│   ├── planning/               // Day Planning & Task List
│   │   ├── planning_view.dart
│   │   └── task_widgets.dart
│   ├── calendar/               // Monthly View
│   │   └── calendar_view.dart
│   ├── categories/             // Management UI
│   │   ├── category_list_view.dart
│   │   └── category_editor_sheet.dart
│   ├── stats/                  // Productivity Analytics
│   │   └── stats_view.dart
│   ├── profile/                // Account & Settings
│   │   ├── profile_view.dart
│   │   └── settings_widgets.dart
│   └── shared/                 // [COMMON] Global UI
│       ├── shared_widgets.dart // Shared UI components (Dropdowns, Sheets)
│       └── category_folder_tile.dart  // Shared Category UI
├── app_shell.dart              // THE NAVIGATOR (Dashboard & BottomNavBar logic)
├── auth_service.dart           // THE KEY (Legacy Auth wrapper / Bridge logic)
└── main.dart                   // THE IGNITION (Initialization & AuthGate only)

## Core Architectural Rules
1. **Localization:** All user-facing strings MUST go through the `t()` helper.
2. **Centralized Logic:** The Brain (`database_service.dart`) holds all database logic, payload construction, and profile settings.
3. **UI Isolation:** The UI modules (`features/`) NEVER write to PocketBase directly. They strictly call methods from `DatabaseService`.