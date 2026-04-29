# Life OS — Claude Context

Flutter time tracker. Owner: Nick (UX designer, not a developer). Goal: best time tracker possible, tidy codebase where every reusable thing lives in one place.

---

## Key documents

| File | Purpose |
| :--- | :--- |
| `docs/ROADMAP.md` | Current plan — phases, bugs, component work. **Read this first before suggesting any structural changes.** |
| `AUDIT_NOTES.md` | Full April 2026 audit findings that produced the roadmap. |
| `docs/APP_STRUCTURE.md` | Physical directory map and module interaction rules. |
| `docs/ARCHITECTURE.md` | Iron Laws, core contracts, data flow. The authoritative technical reference. |
| `docs/POCKETBASE_MANIFEST.md` | PocketBase URL, collection names, relation fields. |
| `docs/DATA_MAP.md` | Field names and business IDs (`user_id`, `record_id`, etc.). |

---

## Where things live

Routing map for AI assistants: open these first instead of grepping. Update this table whenever a canonical symbol moves or is renamed.

| Concept | File | Symbol |
| :--- | :--- | :--- |
| Voice input dispatcher (routes by active tab) | `lib/app_shell.dart` | `_startVoiceInput` |
| UI dispatch wrappers (shell-side, debounced) | `lib/app_shell.dart` | `_stopRecordByDocId` / `_deleteRecordByDocId` / `_startTaskFromInput` |
| Start a record (user taps Start) | `lib/data/database_service.dart` | `DatabaseService.writeRecord` |
| Stop a record (user taps Stop) | `lib/data/database_service.dart` | `DatabaseService.stopRecordByDocId` |
| Update / edit a record | `lib/data/database_service.dart` | `DatabaseService.updateRecord` |
| Delete a record | `lib/data/database_service.dart` | `DatabaseService.deleteRecordByDocId` |
| Optimistic shadow — Start | `lib/data/database_service.dart` | `DatabaseService._startAtomicTaskSequenceApplyLocalPrimary` |
| Optimistic shadow — Stop | `lib/data/database_service.dart` | `DatabaseService._applyOptimisticStopUiSnapshot` |
| Singleton / stale-open detection | `lib/data/database_service.dart` | `_rowStartWallDayIsBeforeProjectedToday` / `_mergeSacredStaleOpenCandidates` |
| Realtime subscribe handler | `lib/data/database_service.dart` | `DatabaseService._onPbRecordsSubscriptionEvent` |
| Record cache mutation (atomic upsert) | `lib/data/database_service.dart` | `DatabaseService._upsertFlatRecordFromPbModel` |
| ID resolution (legacy UUID → PB row id) | `lib/data/database_service.dart` | `DatabaseService._resolveRecordIdForStopOrDelete` [internal but high-traffic] |
| Category smart-link / fuzzy match | `lib/data/database_service.dart` | `DatabaseService.findCategoryByFuzzyMatch` |
| Category create | `lib/data/database_service.dart` | `DatabaseService.addNestedCategory` |
| Category update | `lib/data/database_service.dart` | `DatabaseService.updateCategory` |
| Plan / planning task write | `lib/data/plan_service.dart` | `DatabaseService.addPlanningTask` (extension) |
| Plan / planning task CRUD (full) | `lib/data/plan_service.dart` | `PlanServiceExtension` — addPlan, updatePlanningTask, deletePlanningTask, bulkUpdatePlans |
| Plan stream / optimistic cache | `lib/data/plan_service.dart` | `DatabaseService.planningStream` / `applyOptimisticPlanningTask` (extension) |
| Plan rrule expansion | `lib/data/plan_service.dart` | `DatabaseService.expandRecurringPlans` (extension) |
| Plan alarm scheduling | `lib/data/plan_service.dart` | `DatabaseService._requestPlanAlarmReschedule` (extension) |
| AI task parse | `lib/data/plan_service.dart` | `DatabaseService.parseTaskViaAiBackend` / `parsePlanningItemsViaAiBackend` (extension) |
| Plan link scoring (title similarity) | `lib/data/plan_service.dart` | `PlanServiceExtension.titleSimilarityForPlanLink` (static) |
| Plan wall-estimate seconds | `lib/data/plan_service.dart` | `PlanServiceExtension.planningWallEstimateSeconds` (static) |
| Plan / planning task done-toggle | `lib/features/planning/planning_view.dart` | `_PlanningViewState._toggleDone` |
| Tag link to plan | `lib/data/plan_service.dart` | `DatabaseService._syncPlanTagsPocket` (extension) |
| Timeline render (list) | `lib/features/timeline/timeline_view.dart` | `TimelinePage` |
| Timeline edit sheet | `lib/features/shared/shared_widgets.dart` | `ActivityDetailSheet` |
| Inline edit widget (child / parallel record) | `lib/features/shared/shared_widgets.dart` | `_ChildParallelEditBar` |
| Voice input → record submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitTimeline` |
| Voice input → planning task submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitPlanning` |
| Voice input → backlog submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitBacklog` |
| Auth / session bootstrap | `lib/data/auth_bridge.dart` | `AuthBridge.checkSession` |
| Profile timezone resolution | `lib/data/profile_service.dart` | `DatabaseService.getProjectedToday` (extension) |
| Profile settings getter | `lib/data/profile_service.dart` | `DatabaseService.settings` (extension) |
| Save user settings | `lib/data/profile_service.dart` | `DatabaseService.saveSettings` (extension) |
| Update timezone | `lib/data/profile_service.dart` | `DatabaseService.updateTimeZone` (extension) |
| Fetch tags (current user) | `lib/data/profile_service.dart` | `DatabaseService.fetchTagsForCurrentUser` (extension) |
| Get / fetch user profile | `lib/data/profile_service.dart` | `DatabaseService.getUserProfile` (extension) |
| Date key bucketing (UTC → wall-day string) | `lib/data/database_service.dart` | `DatabaseService._timelineDeviceLocalDayKeyFromUtc` |
| Initial data load (full) | `lib/data/database_service.dart` | `DatabaseService.loadInitialData` |
| Wear OS lite data load | `lib/data/database_service.dart` | `DatabaseService.loadInitialDataWearLite` |

---

## Confirmed bugs (fix before anything else)

See `ROADMAP.md` Phase 1 for the full list. Two critical ones to know:

- **`models/category.dart`** — category ID hash collision → **fixed** with `_stableStringHash` (FNV-style polynomial, cross-platform deterministic)
- **`models/record.dart`** — `dateKey` uses device timezone, not profile timezone → **fixed** with `timezoneOffsetHours` parameter on `TimelineRecord`

**Never use `DateTime.now().toLocal()` for persisted date keys.** Use profile timezone helpers already in the codebase.

---

## UI component rules

- Shared primitives belong in `core/widgets/`. Feature folders compose them, never reimplement.
- Variations are parameters, not copies.
- `EditRecordSheet` has been deleted — all entry points route to `_TimelineRecordSheetContent`.
- `AppLoading(size)`, `showConfirmDialog()`, `AppButton`, `AppErrorState`, `AppEmptyState` are all built in `core/widgets/`. Use them; don't add new inline equivalents.

---

## Architecture rules (from Iron Laws)

- **Optimistic UI:** Start/Stop/Update on records must never block the UI. Apply local shadow first (<100ms), sync to PocketBase async, roll back on failure.
- **No `await` before UI update** for user-driven record actions.
- **Storage is UTC.** Profile `timezone_offset` / `preferred_timezone` drive wall-clock grouping.
- **Every query filters by current user** via `user_id`.
- **God Object:** `database_service.dart` is ~9,400 lines (V5.1: profile/tag domain → `lib/data/profile_service.dart`; V5.2: plan domain → `lib/data/plan_service.dart`). Both are `part of 'database_service.dart'` files using named `extension …Extension on DatabaseService`. V5.2 result: `database_service.dart` ~6,634 lines, `plan_service.dart` ~2,803 lines. Add plan-domain code to `plan_service.dart`, profile/tag to `profile_service.dart`, everything else to `database_service.dart`.

---

## Stack

Flutter · PocketBase (self-hosted) · Dart
Targets: Android, iOS, Web, Windows, macOS, Linux, Wear OS
Live: `nkuchenov-hash.github.io/Counter/`

---

## Changelog discipline
At the end of any session where code was shipped (committed and verified clean by `flutter analyze`), append a CHANGELOG.md entry under today's date. Newest entries at the top. Match the existing format: terse, technical, name specific files and symbols. Tag entries [shipped], [rollback], or [wip] so the codebase state is readable at a glance. Never modify or delete existing entries.

---

## Doc sync reminder
Maintain a running list of every governing doc modified during the session. At session end, print the full list and remind the user to re-upload them to the Claude.ai Project. Do not rely on memory of what was last edited. Governing docs that must be tracked: `docs/APP_STRUCTURE.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `CLAUDE.md`.
