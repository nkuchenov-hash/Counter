# Life OS — Claude Context

Flutter time tracker. Owner: Nick (UX designer, not a developer). Goal: best time tracker possible, tidy codebase where every reusable thing lives in one place.

**Current velocity track (2026-06-10):** O1 Offline-first ✅ shipped · V1 ✅ shipped · F1 Lists ✅ shipped · next: F2 Plans.

---

## Key documents

| File | Purpose |
| :--- | :--- |
| `docs/ROADMAP.md` | Current plan — phases, bugs, component work. **Read this first before suggesting any structural changes.** |
| `docs/reports/AUDIT_NOTES.md` | Full April 2026 audit findings that produced the roadmap. |
| `docs/APP_STRUCTURE.md` | Physical directory map and module interaction rules. |
| `docs/ARCHITECTURE.md` | Iron Laws, core contracts, data flow. The authoritative technical reference. |
| `docs/POCKETBASE_MANIFEST.md` | PocketBase URL, collection names, relation fields. |
| `docs/DATA_MAP.md` | Field names and business IDs (`user_id`, `record_id`, etc.). |

---

## Structure check (vs `docs/APP_STRUCTURE.md`)

Verified 2026-06-10. **Core layout matches** the documented map: `lib/data/` (Brain + part files), `lib/data/local_sync/` (offline outboxes), `lib/features/` (UI modules), `lib/core/` (theme + widgets), `lib/l10n/`, `lib/services/`, `app_shell.dart`, `main.dart`.

**Known drift** (harmless; do not “fix” unless asked):

| Item | Actual | Doc says |
| :--- | :--- | :--- |
| Brain import path | `package:counter/data/database_service.dart` | same; plus legacy barrel `lib/database_service.dart` → re-exports `data/` |
| Models import path | `package:counter/data/models.dart` | same; plus legacy barrel `lib/models.dart` |
| Planning widget name | `PlanningPage` / `PlanningSwipeWrapper` in `planning_view.dart` | file name only (no `PlanningView` class) |
| Lists widget name | `ListsPage` in `lists_view.dart` | file name only |
| Extra at `lib/` root | `auth_service.dart`, `auth_screen.dart` (OAuth legacy) | only `features/auth/` listed |
| Extra data files | `base_database.dart`, `voice_audio_web.dart` | stubs only in doc |
| Local sync (O1) | `lib/data/local_sync/*.dart` | not in older `APP_STRUCTURE.md` tree — see **Local sync** section below |
| Governing docs path | `counter/docs/*.md` | some older refs say `lib/DATA_MAP.md` |

---

## Local sync & offline-first (O1 ✅)

SharedPreferences mutation queues + global sync indicator. Retriable network/auth failures **enqueue** (optimistic UI kept); flush on boot, reconnect, app resume, tap-to-retry. Details: `docs/ROADMAP.md` O1.

| Concept | File | Symbol / notes |
| :--- | :--- | :--- |
| **Record mutation outbox** | `lib/data/local_sync/record_mutation_outbox.dart` | `RecordMutationOutbox` — kinds: `highlander_start`, `stop_patch`, `record_update`, `record_delete`; `coalesceQueue` on enqueue |
| **Plan / list mutation outbox** | `lib/data/local_sync/plan_mutation_outbox.dart` | `PlanMutationOutbox` — kinds: `plan_create`, `plan_update`, `plan_delete`; migrates legacy `plan_create_outbox_v1` |
| **Legacy re-export** | `lib/data/local_sync/plan_create_outbox.dart` | `export 'plan_mutation_outbox.dart'` only |
| **Sync UI state** | `lib/data/local_sync/offline_sync_state.dart` | `OfflineSyncController` — `pendingCount`, `isSyncing`, `authPaused`, `refreshPendingCount`, `resumeAfterAuthIfNeeded`, `isFullySynced` |
| **Brain accessor** | `lib/data/database_service.dart` | `DatabaseService.instance.offlineSync` |
| **Connectivity → drain** | `lib/data/local_sync/sync_manager.dart` | `SyncManager.instance.attachIfNeeded` — calls `flushPendingLocalMutations` when online |
| **Flush all outboxes** | `lib/data/db_core.dart` | `DbCoreExtension.flushPendingLocalMutations` — records then plans; resumes auth if `authStore.isValid` |
| **Flush record queue** | `lib/data/record_service.dart` | `RecordServiceExtension.flushPendingRecordMutations` |
| **Flush plan/list queue** | `lib/data/plan_service.dart` | `PlanServiceExtension.flushPendingPlanMutations` (alias: `flushPendingPlanCreates`) |
| **Boot / resume flush** | `lib/data/db_core.dart` | `loadInitialData` → `_loadInner` ends with `flushPendingLocalMutations`; lifecycle `onResumed` same |
| **Offline / sync banner** | `lib/app_shell.dart` | `_OfflineSyncStatusBar` — tap → `flushPendingLocalMutations`; labels via `offline_sync_*` in `dictionary.dart` |
| Record offline enqueue (start) | `lib/data/record_service.dart` | `_enqueueHighlanderStartMutation`, `_highlanderPrimaryServerSync` |
| Record offline enqueue (stop/edit/delete) | `lib/data/record_service.dart` | `_enqueueStopPatchMutation`, `_enqueueRecordUpdateMutation`, `_enqueueRecordDeleteMutation` |
| Plan offline enqueue | `lib/data/plan_service.dart` | `_enqueuePlanCreateMutation`, `_enqueuePlanUpdateMutation`, `_enqueuePlanDeleteMutation` |

---

## Screen & sheet navigation (open these first)

Short routing map for Cursor / AI. Symbols in backticks.

| What | File | Entry symbol / notes |
| :--- | :--- | :--- |
| **Lists screen** | `lib/features/lists/lists_view.dart` | `ListsPage` — wired in `app_shell.dart` IndexedStack index 3 |
| **Plans screen** | `lib/features/planning/planning_view.dart` | `PlanningSwipeWrapper` → `PlanningPage`; shell index 1 |
| **Shared edit sheets** | `lib/features/shared/shared_widgets.dart` | `ActivityDetailSheet` (router) → `_PlanningTaskEditSheet` (plans/lists) or `_TimelineRecordSheetContent` (timeline records); `showAppDateTimePicker` (Omni-Picker entry) |
| **Bulk plan edit** | `lib/features/planning/bulk_planning_edit_sheet.dart` | bulk date/time moves (also uses `showAppDateTimePicker`) |
| **Sheet host (modal)** | `lib/app_shell.dart` | `_openEditDialog` / `_showEditRecordSheetForTimeline` → `showModalBottomSheet` + `ActivityDetailSheet` |
| **Category create** | `lib/features/categories/create_category_dialog.dart` | dialog; calls `DatabaseService.addNestedCategory` |
| **Category edit** | `lib/features/categories/category_list_view.dart` | `CategoryEditorSheet`, `_showCategoryEditorSheet`; appearance quick sheet `_showCategoryAppearanceSheet` |
| **Category tree picker** | `lib/features/categories/category_recursive_tree.dart` | `showCategoryTreePicker` |
| **Tag data (Brain)** | `lib/data/profile_service.dart` | `fetchTagsForCurrentUser`, `createTagForCurrentUser`, `patchTagForCurrentUser`, `deleteTagByPocketRecordId`, `notifyTagsCatalogChanged` |
| **Tag model** | `lib/data/models/tag.dart` | `Tag`, `TagCatalogScope` |
| **Tag UI — manager** | `lib/features/profile/tag_manager_page.dart` | `TagManagerPage` (`pocketTagDomain: 'plan'` or `'list'`) |
| **Tag UI — display prefs** | `lib/features/profile/tag_settings_view.dart` | `tag_display_mode` on profile |
| **Tag UI — pickers** | `lib/features/shared/chip_component.dart` | `TagQuickPickStrip`, `TagChip` |
| **Tag UI in edit sheet** | `lib/features/shared/shared_widgets.dart` | tag strip inside `_PlanningTaskEditSheet` |
| **PB config** | `lib/data/pb_config.dart` | `kPocketBaseUrl`, `PbCollections`, expand constants |
| **PB — records** | `lib/data/record_service.dart` | `writeRecord`, `stopRecordByDocId`, `updateRecord`, `patchRecord`, `deleteRecordByDocId`, `flushPendingRecordMutations`, realtime |
| **PB — plans & lists** | `lib/data/plan_service.dart` | `fetchPlans`, `fetchBacklogPlans`, `addPlanningTask`, `updatePlanningTask`, `deletePlanningTask`, `deletePlanningTasksBulk`, `flushPendingPlanMutations`, `planningStream`, `_syncPlanTagsPocket` |
| **Offline sync banner** | `lib/app_shell.dart` | `_OfflineSyncStatusBar` (top of shell `IndexedStack`) |
| **PB — categories** | `lib/data/category_service.dart` | `addNestedCategory`, `updateCategory`, `findCategoryByFuzzyMatch` |
| **PB — tags** | `lib/data/profile_service.dart` | (same as tag data row above) |
| **PB — auth / bootstrap** | `lib/data/auth_bridge.dart`, `lib/data/db_core.dart` | session, `ensurePocketBaseReady`, `loadInitialData`, `flushPendingLocalMutations` |
| **Date/time header strip** | `lib/core/widgets/global_app_header.dart` | `GlobalAppHeader` + `AppBarLiveClock` |
| **Per-screen header chrome** | `lib/features/timeline/timeline_widgets.dart` | `TimelineTopDateStrip` (timeline) |
| | `lib/features/planning/planning_view.dart` | custom `Material` + `kToolbarHeight` row hosting `GlobalAppHeader` (~L2286) |
| | `lib/features/lists/lists_view.dart` | same pattern (~L1137) |
| **Material `AppBar` (opaque nav bar)** | not on main tabs | Main tabs use **no** `Scaffold.appBar`; header is the surface strip above. `AppBar` remains on secondary routes: `category_list_view.dart`, `profile_view.dart`, `more_view.dart`, `tag_settings_*.dart`, `SettingsPage` in `app_shell.dart`, and nested Lists tag-manager push |

---

## Where things live (symbols)

Routing map for AI assistants: open these first instead of grepping. Update this table whenever a canonical symbol moves or is renamed.

| Concept | File | Symbol |
| :--- | :--- | :--- |
| Voice input dispatcher (routes by active tab) | `lib/app_shell.dart` | `_startVoiceInput` |
| UI dispatch wrappers (shell-side, debounced) | `lib/app_shell.dart` | `_stopRecordByDocId` / `_deleteRecordByDocId` / `_startTaskFromInput` |
| Start a record (user taps Start) | `lib/data/record_service.dart` | `DatabaseService.writeRecord` (extension) |
| Stop a record (user taps Stop) | `lib/data/record_service.dart` | `DatabaseService.stopRecordByDocId` (extension) |
| Update / edit a record | `lib/data/record_service.dart` | `DatabaseService.updateRecord` (extension) |
| Delete a record | `lib/data/record_service.dart` | `DatabaseService.deleteRecordByDocId` (extension) |
| Optimistic shadow — Start | `lib/data/record_service.dart` | `DatabaseService._startAtomicTaskSequenceApplyLocalPrimary` (extension) |
| Optimistic shadow — Stop | `lib/data/record_service.dart` | `DatabaseService._applyOptimisticStopUiSnapshot` (extension) |
| Offline queue — records | `lib/data/local_sync/record_mutation_outbox.dart` | `RecordMutationOutbox.enqueue` / `coalesceQueue` |
| Offline queue — plans | `lib/data/local_sync/plan_mutation_outbox.dart` | `PlanMutationOutbox.enqueue` / `coalesceQueue` |
| Flush pending mutations (all) | `lib/data/db_core.dart` | `DatabaseService.flushPendingLocalMutations` (extension) |
| Flush pending records | `lib/data/record_service.dart` | `DatabaseService.flushPendingRecordMutations` (extension) |
| Flush pending plans / lists | `lib/data/plan_service.dart` | `DatabaseService.flushPendingPlanMutations` (extension) |
| Sync state / auth resume | `lib/data/local_sync/offline_sync_state.dart` | `OfflineSyncController` on `DatabaseService.offlineSync`; `resumeAfterAuthIfNeeded` |
| Connectivity watcher | `lib/data/local_sync/sync_manager.dart` | `SyncManager.instance` |
| Shell sync / offline banner | `lib/app_shell.dart` | `_OfflineSyncStatusBar` |
| Singleton / stale-open detection | `lib/data/record_service.dart` | `_rowStartWallDayIsBeforeProjectedToday` / `_mergeSacredStaleOpenCandidates` (extension) |
| Realtime subscribe handler | `lib/data/record_service.dart` | `DatabaseService._onPbRecordsSubscriptionEvent` (extension) |
| Record cache mutation (atomic upsert) | `lib/data/record_service.dart` | `DatabaseService._upsertFlatRecordFromPbModel` (extension) |
| ID resolution (legacy UUID → PB row id) | `lib/data/record_service.dart` | `DatabaseService._resolveRecordIdForStopOrDelete` (extension) |
| Category smart-link / fuzzy match | `lib/data/category_service.dart` | `DatabaseService.findCategoryByFuzzyMatch` (extension) |
| Category create | `lib/data/category_service.dart` | `DatabaseService.addNestedCategory` (extension) |
| Category update | `lib/data/category_service.dart` | `DatabaseService.updateCategory` (extension) |
| Category → PB row ID mapping (cold-start) | `lib/data/category_service.dart` | `DatabaseService._mapCategoryIdToLinkForPb` (extension) |
| Plan / planning task write | `lib/data/plan_service.dart` | `DatabaseService.addPlanningTask` (extension) |
| Plan / planning task CRUD (full) | `lib/data/plan_service.dart` | `PlanServiceExtension` — addPlan, updatePlanningTask, deletePlanningTask, bulkUpdatePlans |
| Backlog / list items fetch | `lib/data/plan_service.dart` | `DatabaseService.fetchBacklogPlans` (extension) |
| Plan stream / optimistic cache | `lib/data/plan_service.dart` | `DatabaseService.planningStream` / `applyOptimisticPlanningTask` (extension) |
| Plan rrule expansion | `lib/data/plan_service.dart` | `DatabaseService.expandRecurringPlans` (extension) |
| Plan alarm scheduling | `lib/data/plan_service.dart` | `DatabaseService._requestPlanAlarmReschedule` (extension) |
| AI task parse | `lib/data/plan_service.dart` | `DatabaseService.parseTaskViaAiBackend` / `parsePlanningItemsViaAiBackend` (extension) |
| Plan link scoring (title similarity) | `lib/data/plan_service.dart` | `PlanServiceExtension.titleSimilarityForPlanLink` (static) |
| Plan wall-estimate seconds | `lib/data/plan_service.dart` | `PlanServiceExtension.planningWallEstimateSeconds` (static) |
| Plan / planning task done-toggle | `lib/features/planning/planning_view.dart` | `_PlanningViewState._toggleDone` |
| List done-toggle (optimistic; rollback only on hard failure) | `lib/features/lists/lists_view.dart` | `_ListsPageState._onListToggleDone` → `updatePlanningTask(isDone:)` (queues offline) |
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
| Tag create | `lib/data/profile_service.dart` | `DatabaseService.createTagForCurrentUser` (extension) |
| Tag delete | `lib/data/profile_service.dart` | `DatabaseService.deleteTagByPocketRecordId` (extension) |
| Tag update | `lib/data/profile_service.dart` | `DatabaseService.patchTagForCurrentUser` (extension) |
| Tag stream notification | `lib/data/profile_service.dart` | `DatabaseService.notifyTagsCatalogChanged` / `tagsCatalogUpdated` (extension) |
| Get / fetch user profile | `lib/data/profile_service.dart` | `DatabaseService.getUserProfile` (extension) |
| PocketBase init / health check | `lib/data/db_core.dart` | `DbCoreExtension.ensurePocketBaseReady` |
| Realtime reconnect bridge | `lib/data/db_core.dart` | `DbCoreExtension.ensureRecordsRealtimeBridge` |
| Sign-out / state clear | `lib/data/db_core.dart` | `DbCoreExtension.clearLocalStateOnSignOut` |
| Initial data load (full) | `lib/data/db_core.dart` | `DbCoreExtension.loadInitialData` |
| Wear OS lite data load | `lib/data/db_core.dart` | `DbCoreExtension.loadInitialDataWearLite` |
| Date key bucketing (UTC → wall-day string) | `lib/data/record_service.dart` | `DatabaseService._timelineDeviceLocalDayKeyFromUtc` (extension) |

---

## Confirmed bugs (fix before anything else)

See `docs/ROADMAP.md` Phase 1 for the full list. Two critical ones to know:

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

## F1 / Lists — shipped

O1 offline-first, V1, and F1 Lists are **shipped** (`docs/ROADMAP.md`). Next roadmap item is **F2 Plans Feature Completion**. Do not start F2 unless explicitly requested.

| Item | Status | Notes |
| :--- | :--- | :--- |
| List-domain tags | **Shipped** | `domain: list` tags load/filter in Lists, show on cards/edit sheet, and hydrate through plan/list tag catalogs |
| Export visible list as text | **Shipped** | Copies currently visible filtered list rows to clipboard as numbered text |
| Active chip first | **Shipped** | Active category/tag chips render first and scroll to start |
| Card checkbox/text alignment | **Shipped** | `_BacklogPlanCard` checkbox and title column are centered for one-line and two-line titles |
| No play button on list cards | **Shipped** | Lists cards expose checkbox/menu only; Planning play controls remain separate |
| Backlog pin / fix important items | **Schema gap** | No `plans.is_pinned` in PocketBase yet. Proposed: `plans.is_pinned` (bool) on backlog/list rows; sort pinned before unpinned. Do not implement client-only pin state. See `lists_pin_item_todo` in `dictionary.dart`. |

---

## Architecture rules (from Iron Laws)

- **Optimistic UI:** Start/Stop/Update/Delete on records and Planning/Lists CRUD must never block the UI. Apply local shadow first (<100ms), sync to PocketBase async. On **retriable** network failure → enqueue to `lib/data/local_sync/*_mutation_outbox.dart` and keep optimistic state; on **non-retriable** validation errors → roll back and snack.
- **No `await` before UI update** for user-driven record/plan actions.
- **Offline drain:** `flushPendingLocalMutations` on login (`loadInitialData`), reconnect (`SyncManager`), app resume, and tap-to-retry (`_OfflineSyncStatusBar`). 401/403 sets `offlineSync.authPaused` until `resumeAfterAuthIfNeeded` + valid session.
- **Storage is UTC.** Profile `timezone_offset` / `preferred_timezone` drive wall-clock grouping.
- **Every query filters by current user** via `user_id`.
- **God Object split complete:** `database_service.dart` started at ~10,000 lines and is now ~720 lines (the root singleton — shared state, streams, static helpers). All domain logic lives in `part of` files as named extensions: V5.1 profile/tag → `profile_service.dart`; V5.2 plan → `plan_service.dart`; V5.3 record → `record_service.dart`; V5.4 category → `category_service.dart`; V5.5 bootstrap/lifecycle → `db_core.dart`. Add bootstrap/lifecycle code to `db_core.dart`, category-domain to `category_service.dart`, record-domain to `record_service.dart`, plan-domain to `plan_service.dart`, profile/tag to `profile_service.dart`, everything else to `database_service.dart`.

---

## Stack

Flutter · PocketBase (self-hosted) · Dart
Targets: Android, iOS, Web, Windows, macOS, Linux, Wear OS
Live: `nkuchenov-hash.github.io/Counter/`

**Deploy (GitHub Pages):** `.\update.ps1` from repo root (`C:\Users\nkuch\Development\Apps\counter`). Implementation: `scripts/manual/td.ps1`. See `docs/DEPLOY.md`.

---

## Changelog discipline
At the end of any session where code was shipped (committed and verified clean by `flutter analyze`), append a CHANGELOG.md entry under today's date. Newest entries at the top. Match the existing format: terse, technical, name specific files and symbols. Tag entries [shipped], [rollback], or [wip] so the codebase state is readable at a glance. Never modify or delete existing entries.

---

## Doc sync reminder
Maintain a running list of every governing doc modified during the session. At session end, print the full list and remind the user to re-upload them to the Claude.ai Project. Do not rely on memory of what was last edited. Governing docs that must be tracked: `docs/APP_STRUCTURE.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `CLAUDE.md`.
