# Repository Instructions for Codex

This repository is Counter / Life OS: a Flutter time tracker and planning app backed by self-hosted PocketBase. Treat this file as the compact root guide for future Codex work. It is not a replacement for the governing docs; it tells you what to read and what rules to keep in force before editing.

## Start Here

Future Codex work should usually start by reading:

- `docs/APP_STRUCTURE.md`
- `docs/ARCHITECTURE.md`
- `docs/UX_CONTRACT.md`
- `AGENT_NAVIGATION.md`
- `CHANGELOG.md`
- task-specific docs listed below

Use `CHANGELOG.md` and `docs/ROADMAP.md` to understand what is already built before recreating or redesigning behavior. Do not copy roadmap content into prompts or code; use it to determine current status and priority.

## Project Identity and Stack

- Flutter package name: `counter`.
- Imports in Dart code use `package:counter/...`; do not add relative imports.
- Backend: PocketBase via the official Dart SDK and app-owned PocketBase hooks in `pb_hooks/`.
- Main targets: Android, iOS, Web, Windows, macOS, Linux, and Wear OS.
- Live web deploy uses GitHub Pages with base href `/Counter/`.

## Active Priorities

- Correctness and performance regressions outrank design, feature, preload, cache, or cleanup work.
- Active foundation tracks are V3/V7: `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, canonical Flutter components, and admin-only Component Lab.
- Feature work is paused unless explicitly requested or required by the current task.
- **Structure Growth Law:** new features must extend existing layers and canonical components; split mixed/large files early (`docs/ARCHITECTURE.md` §11, `docs/APP_STRUCTURE.md` §7). Final audit: `docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md`.
- Structure cleanup is governed by `docs/APP_STRUCTURE.md`, `docs/APP_STRUCTURE_DETAILED.md`, and `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`; do not perform opportunistic architecture moves.
- Brain/UI structure decomposition (Passes 3–4D) is **complete** as of 2026-07-03 (`d7e7c12`). Further splits need explicit product scope — see `docs/APP_STRUCTURE.md` §8.

## Task-Specific Document Routing

- PocketBase, schema, auth, records, plans, categories, tags: read `docs/DATA_MAP.md` and `docs/POCKETBASE_MANIFEST.md`.
- Paths / project strategy / Path → Planner / future AI Path tooling: start with `lib/features/paths/paths_page.dart`, `lib/data/paths/path_repository.dart`, `docs/ARCHITECTURE.md` §6.1, issue #93, and `docs/reports/PATHS_FIRST_CLASS_AND_REPO_AUDIT_2026-08-17.md`.
- UI components, design system, cards, buttons, chips, tabs, sheets, Component Lab: read `docs/DESIGN_SYSTEM.md` and `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.
- Deploy, build, release, GitHub Pages, OAuth/admin production setup: read `docs/DEPLOY.md`.
- File structure, moves, import boundaries, architecture cleanup: read `docs/APP_STRUCTURE.md`, `docs/APP_STRUCTURE_DETAILED.md`, and `docs/reports/FINAL_STRUCTURE_PARITY_AND_DOC_CLEANUP_2026-07-03.md`.
- Feature status, shipped work, accepted work, or "what is already built": read `CHANGELOG.md` and `docs/ROADMAP.md`.
- UX behavior, tap/save/delete/loading/offline/swipe contracts: read `docs/UX_CONTRACT.md`.
- Runtime architecture, optimistic UI, performance, time rules, and PocketBase relation contracts: read `docs/ARCHITECTURE.md`.
- **Notes editor, Notes block wrappers/reorder, mobile keyboard, caret visibility, or gray/blank editor regressions:** read `docs/NOTES_EDITOR_CONTRACT.md` before editing production Notes UI.
- Project Knowledge upload list (14 docs, ≤25): read `docs/PROJECT_KNOWLEDGE_PACK.md`.

## Architecture Boundaries

- `lib/main.dart` and `lib/app/shell/` (via root `lib/app_shell.dart` re-export) own boot, form-factor shell, auth gate, global wiring, and navigation.
- `lib/data/` is the Brain. It owns PocketBase I/O, domain models, in-memory cache, optimistic state, and offline outboxes.
- `lib/data/database_service.dart` is the Brain root. Domain logic lives in its `part of` files: `db_core.dart`; coordinators `record_service.dart`, `plan_service.dart`, `category_service.dart`, `profile_service.dart`; and focused parts under `records/*`, `plans/*`, `categories/*`, `profile/*`.
- `lib/data/paths/` owns durable first-class Path interpretation and validation over dedicated PocketBase `paths` plus append-only `path_revisions`. `PathRepository` is the domain-facing repository; durable PocketBase I/O stays in `path_service.dart` as a `DatabaseService` part. `plans` is not Path storage, and feature UI must not parse historical marker rows.
- `lib/features/paths/` owns Paths screens and interactions. `lib/app/shell/` only selects the destination; new Path UI/domain policy must not move back into shell files.
- `lib/data/` must not import `lib/features/`.
- `lib/data/plans/diagnostics/` owns Planning-domain Brain diagnostics (`plan_duplicate_log.dart`) — not shared diagnostics, not feature UI. Brain plan helpers emit these logs.
- `lib/core/` owns theme, tokens, shared widgets, and desktop tray/main-window infrastructure. It must not import feature UI or `database_service.dart` except where the documented structure explicitly allows model-only types.
- `lib/shared/time/` owns multi-consumer wall-clock, timezone catalog, and injectable clock/timezone hooks. It must not import `features/` or `database_service.dart`. Feature-only time math belongs under the owning feature; shell date coordination stays in `lib/app/shell/`.
- `lib/shared/diagnostics/` owns general runtime logs (`runtime_log`, `platform_log`, `startup_log`) and performance kill switches / metrics under `performance/` (`runtime_flags.dart`, `shell_flags.dart`, `rebuild_metrics.dart`). It must not import `features/` or `database_service.dart`.
- `lib/shared/voice/` owns the one Voice system used by phone, desktop, web, and Wear: `commands/`, `recognition/`, `routing/` (acceptance bridge only), `ui/`, `platforms/{desktop,mobile}/`, and `diagnostics/`. Desktop Voice activation/recognition/overlay adapters live here — not a separate product. It must not import `features/`, `data/voice/`, `database_service.dart`, or `app/shell/`. Generic active-tab FAB/VoiceInputSheet routing lives in `lib/app/shell/shared/shell_voice_input.dart`; desktop overlay/command routing lives in `shell_voice_routing.dart`; tray/global-hotkey attachment lives in `shell_voice_integration.dart`.
- `lib/shared/categories/` owns reusable category presentation, tree, and picker (`presentation/`, `tree/`, `picker/`). It may import `data/models.dart` for `CategoryRule` only. It must not import `features/`, `database_service.dart`, or `app/shell/`. Brain wires `CategoryTreeSource` / `CategoryPickerActions` / `PlanCategoryLookup` from `main.dart`.
- `lib/data/voice/` owns Brain-coupled Voice work: command parser, domain resolver, normalize, record-submit / command execution, glossary builder, contamination/postprocess, PocketBase cloud STT transport, and parser-tied benchmarks.
- `lib/features/voice/` owns desktop Flutter Voice overlay UI (widget, capsule, correction sheet, command panel).
- `lib/features/settings/voice/` owns user-facing Voice settings UI (moved out of `features/profile/`).
- `lib/features/settings/categories/` owns Categories manager UI (More → Categories). Lists owns `category_filter_tree_field.dart`. Plan/record category draft helpers live in `features/shared/edit_sheet/category_edit_draft.dart`.
- `lib/features/` owns screens, sheets, and feature-specific layout. It composes Brain APIs and canonical core/shared widgets.
- `lib/l10n/langs/en.dart` and `lib/l10n/langs/ru.dart` are the canonical EN/RU locale sources.
- `pb_hooks/` is server-side PocketBase hook code. Flutter client code does not import it.

## PocketBase and Schema Rules

- PocketBase system IDs are 15-character strings. Never parse, hash, cast, or convert them to `int`.
- Distinguish system IDs from business IDs. REST path segments and relation payloads use system `id`; `record_id`, `plan_id`, `category_id`, and `tag_id` are business metadata unless a doc states otherwise.
- The current auth identity comes from the PocketBase auth store (`pb.authStore.record.id` / model id depending on SDK usage). If auth is invalid, block network writes and surface the session issue.
- Every owned collection query/mutation must respect current-user ownership through `user_id`.
- `records.category_id` and `records.category_link` are PocketBase relations to `categories.id`. POST/PATCH must send the same resolved 15-character category system ID in both fields, never the business slug.
- `records.source_plan_id`, `plans.parent_plan_id`, category parents, and tag relations use PocketBase system IDs.
- Do not change PocketBase fields, relation payloads, collection names, or schema semantics without reading both `docs/DATA_MAP.md` and `docs/POCKETBASE_MANIFEST.md`.
- Do not introduce client-only schema assumptions for missing fields. If a field does not exist, document the schema gap and ask before implementing behavior that depends on it.

## Optimistic UI and Offline Sync

- User-driven record actions and Planning/Lists CRUD update local Brain cache/UI first, then sync PocketBase in the background.
- Do not `await` network I/O, PocketBase writes, Wear sync, heavy disk work, or expensive parsing before visible UI feedback for a user action.
- Target visible feedback within about 100 ms for taps, swipes, keyboard actions, record start/stop, plan edits, list toggles, and sheet actions.
- Retriable network/backoff failures should keep optimistic state and enqueue through existing outboxes where supported.
- Non-retriable validation/schema failures should roll back stable state and show one concise, debounced error.
- Do not introduce full refetch fan-out after small mutations unless unavoidable and justified.
- Pending sync and auth-paused sync belong in `lib/app/shell/shared/offline_sync_status_bar.dart` via `ShellTopStatusBars`, not per-row noise.

## Time and Wall-Clock Rules

- Persist record and plan instants as UTC ISO strings.
- Profile `timezone_offset` and `preferred_timezone` drive wall-clock day grouping, labels, projections, and stats.
- Do not use `DateTime.now().toLocal()` for persisted grid keys or durable day bucketing.
- Date/time picking must use the Omni-Picker flow (`showAppDateTimePicker`) when both date and time are part of the user intent. Date-only navigation may use date-only controls.
- Planning Time mode uses profile-projected wall time, a 10-minute minimum scheduled duration (`kPlanTimeMinDurationMinutes`), and no out-of-visible-range fallback bucket; interaction snapping must follow the current Time View controller policy rather than a duplicated doc constant.

## Performance Kill Switch

Performance, responsiveness, and stability are P0 correctness. Stop and disable the offending path by default if a change causes:

- slower startup, freeze, crash, or memory growth;
- swipe jank, broken short swipe, or broken date paging;
- user actions not reflecting within about 100 ms;
- record/plan create not appearing instantly without refresh;
- network wait before local UI update;
- mounted widget explosion, including mounted 7/21/41 day bodies;
- massive preload, projection, full-history scans, or full-plan projection on hot paths;
- log storms, repeated background success logs, or per-row/per-card release spam;
- snapshots or render caches replacing active live optimistic sources;
- snapshot-only active pages, stale active pages, or refresh-required UI;
- visible loader replacing already loaded content for background refresh.

Emergency response:

1. Disable the risky experiment by default.
2. Restore the last stable path and live optimistic sources.
3. Remove hot-path overload.
4. Gate verbose diagnostics behind debug/profile flags.
5. Continue only with a smaller scoped fix and verification.

## Design System and Canonical Components

- Feature screens should compose canonical components from `lib/core/widgets/` and approved shared widgets instead of recreating local copies.
- New app action buttons should use `AppButton` when it covers the action.
- New icon-only app actions should use `AppIconButton` when it covers the action, with tooltip/semantic label where practical.
- Use `AppLoading`, `AppEmptyState`, and `AppErrorState` for canonical loading/empty/error surfaces where applicable.
- `LifeCard` / `AppTaskCard` are card foundations; production card migration is scoped work, not a mass replacement.
- `CategoryChip`, `TagChip`, and `TagQuickPickStrip` currently live in the canonical shared widget file `lib/core/widgets/chip_component.dart`; future API renaming still follows `docs/DESIGN_SYSTEM.md`.
- Component Lab is admin-only, mock-data-only, and must not write to PocketBase or expose production user data.
- Do not add duplicate local UI components when a canonical component exists unless the inventory explicitly marks the old pattern as temporary legacy.

## Notes Editor Guardrail

For any production Notes editor change, `docs/NOTES_EDITOR_CONTRACT.md` is mandatory reading. In particular:

- keep the existing Notes body `ReorderableListView` as the single vertical scroll owner;
- every top-level widget returned by the reorderable `itemBuilder` must retain a stable `ValueKey<String>(block.id)` after any `Padding` / `Stack` / `Column` wrapper is added;
- do not reintroduce global focus/caret tree traversal or `EditableTextState.bringIntoView` keyboard hacks;
- a gray body with the surrounding Notes shell still visible is a P0 regression; inspect reorderable root keys and scroll ownership first.

## Hard Guardrails

- Do not perform broad speculative rewrites.
- Do not refactor architecture, split large files, rename modules, or move ownership boundaries unless the user asked for that work.
- Do not change production Dart code, tests, PocketBase hooks, build scripts, app behavior, UI, schema, or generated files for documentation-only tasks.
- Do not change PocketBase fields or relation payloads without `docs/DATA_MAP.md` and `docs/POCKETBASE_MANIFEST.md`.
- Do not block UI on network writes.
- Do not slow startup.
- Do not introduce swipe lag or break horizontal date swipe in Timeline/Planning.
- Do not add massive preload or broad invisible-data projection.
- Do not mount 7/21/41 day bodies or other large offscreen widget windows by default.
- Do not create log storms or repeated success logs from background loops.
- Do not make active pages depend only on snapshots/render caches.
- Do not run Path bootstrap/migration/governance/Planner generation as a side effect of opening Paths.
- Do not give AI arbitrary PocketBase/SQL/filesystem/shell writes; future Path AI must use whitelisted app-owned tools with validation, approval for sensitive actions, audit, and undo.
- Do not duplicate local UI components where canonical components already exist.
- Do not modify archived, quarantine, generated, or cleanup-report-listed legacy files unless explicitly requested.
- Do not commit or push unless explicitly asked.

## Verification

Run verification proportional to the change. Standard static check:

```powershell
flutter analyze --no-fatal-infos --no-fatal-warnings
```

For web/UI/runtime changes:

```powershell
flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run
```

For deploy when requested:

```powershell
.\update.ps1
```

For Android-impacting shared runtime/UI changes when requested or relevant:

```powershell
flutter build apk --release --target-platform android-arm64 --split-per-abi --no-tree-shake-icons
```

For structure/import-boundary work, also run:

```powershell
.\scripts\audit\architecture_guard.ps1 -Strict
python scripts/audit/repository_hygiene.py
python scripts/audit/documentation_parity.py
```

Before merge, architecture-changing branches must pass the GitHub Actions `Architecture Guard / strict-structure` check.

For documentation-only changes to `AGENTS.md`, do not run Flutter builds. Lightweight validation is enough:

```powershell
git diff -- AGENTS.md
git status --short
```

## Documentation Updates

- Update governing docs only when the code/task changes their contracts.
- Do not paste massive chunks from docs into new instruction files. Reference source docs by filename.
- If code is shipped and the working tree is verified clean by analyzer, add a concise top entry to `CHANGELOG.md` under today's date, preserving all existing entries.
- Maintain a list of governing docs changed during the session and report it at the end.

## Final Report Format

End work with a concise report covering:

- files changed;
- source docs inspected;
- important rules or behavior changed;
- verification commands run and results;
- git status summary;
- whether production code, tests, hooks, build scripts, schema, generated files, or UI were touched;
- any known limitations or follow-up risks.