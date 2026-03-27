# App structure (Life OS)

See **`ARCHITECTURE.md`** (vaults: DNA `lib/data/models.dart`, Brain `lib/data/database_service.dart`, Shell `lib/app_shell.dart`, ignition `lib/main.dart`) and **`lib/DATA_MAP.md`** (Noco fields).

| Area | Location |
|------|----------|
| Timeline | `lib/features/timeline/` |
| Planning | `lib/features/planning/` |
| Categories | `lib/features/categories/` |
| Profile & timezone | `lib/features/profile/` |
| Shared sheets (record/plan edit) | `lib/features/shared/shared_widgets.dart` |
| Theme | `lib/core/theme.dart` |
| Strings | `lib/l10n/dictionary.dart` |

All user-facing strings go through `t()`; Brain holds HTTP + profile settings; UI never writes Noco directly except via `DatabaseService`.
