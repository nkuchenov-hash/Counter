# GitHub Copilot Instructions — Life OS (Counter)

Flutter time tracker. PocketBase backend. Owner is a UX designer, not a developer. Goal: best time tracker possible with a tidy codebase where every reusable thing lives in one place.

## Read governing docs first

Before any structural, behavior, data, PocketBase, performance, or UI/design change, read the relevant governing docs:

- `docs/ROADMAP.md` — current plan, phases, bugs. Read first before suggesting structural changes.
- `docs/ARCHITECTURE.md` — Iron Laws, core contracts, data flow, PERFORMANCE_KILL_SWITCH_LAW.
- `docs/UX_CONTRACT.md` — behavior contract: taps, save/edit/delete, loading/empty/error, offline, optimistic UI, performance.
- `docs/APP_STRUCTURE.md` — physical directory map and module import rules.
- `docs/DATA_MAP.md` — field names and business IDs (single source of truth for PocketBase schema).
- `docs/POCKETBASE_MANIFEST.md` — PocketBase URL, collections, relation fields, API rules.
- `docs/DESIGN_SYSTEM.md` — Figma → Flutter mapping, tokens, canonical components.
- `docs/reports/DESIGN_SYSTEM_INVENTORY.md` — legacy UI exceptions.
- `docs/DEPLOY.md` — GitHub Pages deploy path.
- `AGENT_NAVIGATION.md` — navigation map and AI laws.

Do not paste these docs into code or instructions; reference them.

## Performance is P0 correctness

Performance regressions are correctness bugs, not polish. Any lag, freeze, crash, swipe jank, broken optimistic UI, missing instant record/plan create, log spam, or "impossible to work" outranks feature/design/preload work. See `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW.

If a change causes any hard-stop condition (slower startup, freeze, crash, swipe jank, UI not reflecting within ~100ms, optimistic UI broken, mounted widget explosion, network wait before local UI), stop immediately: disable the offending experiment by default, restore stable behavior, restore instant optimistic UI, remove hot-path overload, then continue.

## Preserve optimistic UI and zero-await

- User-driven Start/Stop/Update/Delete on records and Planning/Lists CRUD must never block the UI on a network round-trip.
- Apply a local shadow (cache + streams) in <100ms, then sync PocketBase async. Roll back only on non-retriable validation errors; retriable network failures enqueue to the offline outbox and keep optimistic state.
- Do not `await` network, DB writes, or Wear sync before the UI updates for that action. Use `unawaited` background sync with rollback on failure.
- Already loaded content must not be replaced by blank/loading state for a background refresh.

## Do not block user actions on network writes

No user action may wait on a network write before reflecting in the UI. Record/plan/category/tag mutations update local Brain cache first, notify UI, then sync PocketBase in the background. The Brain (`lib/data/database_service.dart` and its `part of` extensions) is the only layer that performs PocketBase calls.

## Investigate before fixing

For unclear bugs, investigate first and report the root cause before changing code. Reproduce, trace data flow, and test one hypothesis at a time. Do not guess-and-patch.

## One issue at a time, with approval

Do not continue to the next roadmap issue without explicit user approval. Finish, verify, and report before moving on.

## PocketBase schema/id/relation rules

PocketBase schema, id, and relation work must follow `docs/DATA_MAP.md` and `docs/POCKETBASE_MANIFEST.md`:

- All primary keys and system references are 15-char strings. No integer IDs.
- REST URL paths use the 15-char system `id` only. Business UUIDs (`record_id`, `plan_id`, `category_id` slug) stay in JSON body or logic only.
- `records.category_id` and `records.category_link` both expect the 15-char `categories.id` in POST/PATCH — never the business slug. The Brain normalizes before network I/O.
- Every query filters by current user via `user_id`.
- Storage is UTC; profile `timezone_offset` / `preferred_timezone` drive wall-clock grouping. Never use `DateTime.now().toLocal()` for persisted date keys.
- `lib/data/database_service.dart` is the only file that performs PocketBase calls. Domain logic lives in `part of` extensions (`db_core.dart`, `record_service.dart`, `plan_service.dart`, `category_service.dart`, `profile_service.dart`).

## Use canonical design-system components

Use canonical components from `lib/core/widgets/` where available (`AppButton`, `AppIconButton`, `AppLoading`, `AppEmptyState`, `AppErrorState`, `showConfirmDialog`, `GlobalAppHeader`, `LifeCard`/`AppTaskCard`). Feature screens compose them; do not recreate local copies. Variations are parameters, not copied widgets. See `docs/DESIGN_SYSTEM.md` and `docs/reports/DESIGN_SYSTEM_INVENTORY.md` for legacy exceptions.

## Preserve user-approved UX decisions

Do not remove user-approved UX decisions unless explicitly requested. This includes large comfortable checkboxes, visible plan time labels, horizontal date swipe in Timeline/Planning (required product behavior), and the Omni-Picker law (date+time selection in a single unified dialog).

## Report changes clearly

For code changes, report:
- Files changed.
- Behavior impact.
- Tests run (with results).
- Remaining risks.

## Deploy only with approval

For web/UI/runtime changes, use the `docs/DEPLOY.md` verification path only when the user approves deploy/commit. Do not run `update.ps1`, `git push`, or `flutter build web` for deploy purposes without explicit approval.

## Always ask before state-changing operations

Always ask before commit, push, deploy, or APK build unless explicitly requested. This includes `git add`/`git commit`, `git push`, `update.ps1`, `scripts/manual/td.ps1`, and any APK build script.

## Stack

Flutter · PocketBase (self-hosted) · Dart. Targets: Android, iOS, Web, Windows, macOS, Linux, Wear OS. Live: `nkuchenov-hash.github.io/Counter/`.
