# Life OS — Agent navigation map

> **Legacy filename:** was `CLAUDE.md` (2026-07-03 renamed to neutral `AGENT_NAVIGATION.md`). No external Claude service reads this path — repo-local AI orientation only.

Flutter time tracker. Owner: Nick (UX designer, not a developer). Goal: best time tracker possible, tidy codebase where every reusable thing lives in one place.

**Current velocity track (2026-06-11):** Feature work paused · active project is V3/V7 only: `docs/UX_CONTRACT.md`, `docs/DESIGN_SYSTEM.md`, canonical Flutter components, and admin-only Component Lab.

---

## Key documents

| File | Purpose |
| :--- | :--- |
| `docs/ROADMAP.md` | Current plan — phases, bugs, component work. **Read this first before suggesting any structural changes.** |
| `docs/APP_STRUCTURE.md` | Physical directory map and module interaction rules. |
| `docs/APP_STRUCTURE_DETAILED.md` | Bilingual EN/RU file-by-file guide (regen: `scripts/manual/generate_app_structure_detailed.py`). |
| `docs/ARCHITECTURE.md` | Iron Laws (incl. **PERFORMANCE_KILL_SWITCH_LAW**), core contracts, data flow. Authoritative technical reference. |
| `docs/POCKETBASE_MANIFEST.md` | PocketBase URL, collection names, relation fields. |
| `docs/DATA_MAP.md` | Field names and business IDs (`user_id`, `record_id`, etc.). |
| `docs/UX_CONTRACT.md` | Behavior contract: taps, save/edit/delete, loading/empty/error, offline, optimistic UI, **performance & responsiveness (P0V)**. |
| `docs/DEPLOY.md` | GitHub Pages deploy, PocketBase auth admin, Windows installer. |
| `docs/DESIGN_SYSTEM.md` | Figma → Flutter mapping, tokens, canonical component categories, and forbidden local UI rule. |
| `AGENTS.md` | Compact Codex/agent routing at repo root. |
| `docs/PROJECT_KNOWLEDGE_PACK.md` | Upload checklist (14-doc pack, ≤25 limit) — not architecture law. |
| `docs/reports/FINAL_STRUCTURE_AUDIT_2026-07-06.md` | Final structure audit verdict + watchlist (repo-only). |

---

## Structure check (vs `docs/APP_STRUCTURE.md`)

Verified 2026-06-10. **Core layout matches** the documented map: `lib/data/` (Brain + part files), `lib/data/local_sync/` (offline outboxes), `lib/features/` (UI modules), `lib/core/` (theme + widgets), `lib/l10n/`, `lib/services/`, `app_shell.dart`, `main.dart`.

**Known drift** (harmless; do not “fix” unless asked):

| Item | Actual | Doc says |
| :--- | :--- | :--- |
| Brain import path | `package:counter/data/database_service.dart` | canonical — no root barrel |
| Models import path | `package:counter/data/models.dart` | canonical — no root barrel |
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
| **Flush record queue** | `lib/data/records/record_outbox_helpers.dart` | `RecordOutboxSyncExtension.flushPendingRecordMutations` |
| **Flush plan/list queue** | `lib/data/plans/plan_outbox_helpers.dart` | `PlanOutboxSyncExtension.flushPendingPlanMutations` (alias: `flushPendingPlanCreates`) |
| **Boot / resume flush** | `lib/data/db_core.dart` | `loadInitialData` → `_loadInner` ends with `flushPendingLocalMutations`; lifecycle `onResumed` same |
| **Offline / sync banner** | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` — tap → `flushPendingLocalMutations`; labels via `offline_sync_*` in `dictionary.dart` |
| Record offline enqueue (start) | `lib/data/records/record_outbox_helpers.dart` | `_enqueueHighlanderStartMutation`, `_highlanderPrimaryServerSync` |
| Record offline enqueue (stop/edit/delete) | `lib/data/records/record_outbox_helpers.dart` | `_enqueueStopPatchMutation`, `_enqueueRecordUpdateMutation`, `_enqueueRecordDeleteMutation` |
| Plan offline enqueue | `lib/data/plan_service.dart` | `_enqueuePlanCreateMutation`, `_enqueuePlanUpdateMutation`, `_enqueuePlanDeleteMutation` |

---

## Screen & sheet navigation (open these first)

Short routing map for Cursor / AI. Symbols in backticks.

| What | File | Entry symbol / notes |
| :--- | :--- | :--- |
| **Lists screen** | `lib/features/lists/lists_view.dart` | `ListsPage` — wired in `app_shell.dart` IndexedStack index 3 |
| **Plans screen** | `lib/features/planning/planning_view.dart` (barrel), `planning_page.dart`, `planning_page_shell.dart` | `PlanningSwipeWrapper` → `PlanningPage`; shell index 1 |
| **Component Lab (admin-only)** | `lib/features/dev/component_lab_view.dart` | `ComponentLabPage`; More → Dev / Design Lab only when `DatabaseService.instance.settings.isAdmin` |
| **Shared edit sheets** | `lib/features/shared/activity_detail_sheet.dart` | `ActivityDetailSheet` (router) → `PlanningTaskEditSheet` (plans/lists) or `TimelineRecordSheetContent` (timeline records); barrel: `shared_widgets.dart` |
| **Omni-Picker / autosave** | `lib/features/shared/edit_sheet/sheet_time_picker.dart`, `sheet_autosave_gate.dart` | `showAppDateTimePicker`, `EditSheetAutosaveGate` |
| **Bulk plan edit** | `lib/features/planning/bulk_planning_edit_sheet.dart` | bulk date/time moves (also uses `showAppDateTimePicker`) |
| **Sheet host (modal)** | `lib/app_shell.dart` | `_openEditDialog` / `_showEditRecordSheetForTimeline` → `showModalBottomSheet` + `ActivityDetailSheet` |
| **Category create** | `lib/features/categories/create_category_dialog.dart` | dialog; calls `DatabaseService.addNestedCategory` |
| **Category edit** | `lib/features/categories/category_list_view.dart` | `CategoryEditorSheet`, `_showCategoryEditorSheet`; appearance quick sheet `_showCategoryAppearanceSheet` |
| **Category tree picker** | `lib/features/categories/category_recursive_tree.dart` | `showCategoryTreePicker` |
| **Tag data (Brain)** | `lib/data/profile/tag_catalog.dart` | `fetchTagsForCurrentUser`, `createTagForCurrentUser`, `patchTagForCurrentUser`, `deleteTagByPocketRecordId`, `notifyTagsCatalogChanged` |
| **Tag model** | `lib/data/models/tag.dart` | `Tag`, `TagCatalogScope` |
| **Tag UI — manager** | `lib/features/profile/tag_manager_page.dart` | `TagManagerPage` (`pocketTagDomain: 'plan'` or `'list'`) |
| **Tag UI — display prefs** | `lib/features/profile/tag_settings_view.dart` | `tag_display_mode` on profile |
| **Tag UI — default durations** | `lib/features/profile/tag_default_duration_settings_view.dart` | per-tag `default_plan_duration_minutes` (Durations tab) |
| **Tag UI — pickers** | `lib/features/shared/chip_component.dart` | `TagQuickPickStrip`, `TagChip` |
| **Tag UI in edit sheet** | `lib/features/shared/planning_task_edit_sheet.dart` | tag strip inside `PlanningTaskEditSheet` |
| **PB config** | `lib/data/pb_config.dart` | `kPocketBaseUrl`, `PbCollections`, expand constants |
| **PB — records** | `lib/data/records/record_crud.dart` + coordinator | `writeRecord`, `stopRecordByDocId`, `updateRecord`, `patchRecord`, `deleteRecordByDocId`, `flushPendingRecordMutations`, realtime |
| **PB — plans & lists** | `lib/data/plan_service.dart` | `fetchPlans`, `fetchBacklogPlans`, `addPlanningTask`, `updatePlanningTask`, `deletePlanningTask`, `deletePlanningTasksBulk`, `flushPendingPlanMutations`, `planningStream`, `_syncPlanTagsPocket` |
| **Offline sync banner** | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` (top of shell `IndexedStack`) |
| **PB — categories** | `lib/data/categories/category_crud.dart` + `category_lookup.dart` + coordinator | `addNestedCategory`, `updateCategory`, `findCategoryByFuzzyMatch` |
| **PB — tags** | `lib/data/profile/tag_catalog.dart` | (same as tag data row above) |
| **PB — auth / bootstrap** | `lib/data/auth_bridge.dart`, `lib/data/db_core.dart` | session, `ensurePocketBaseReady`, `loadInitialData`, `flushPendingLocalMutations` |
| **Date/time header strip** | `lib/core/widgets/global_app_header.dart` | `GlobalAppHeader` + `AppBarLiveClock` |
| **Per-screen header chrome** | `lib/features/timeline/timeline_view.dart` | List/stats `SegmentedButton` + day PageView chrome **inlined** (removed orphan `timeline_widgets.dart` in Stage A) |
| | `lib/features/planning/planning_view.dart` | custom `Material` + `kToolbarHeight` row hosting `GlobalAppHeader` (~L2286) |
| | `lib/features/lists/lists_view.dart` | same pattern (~L1137) |
| **More overflow menu** | `lib/app_shell.dart` | `_openMoreMenu()` modal bottom sheet — Categories, Profile, admin Component Lab (removed orphan `more_view.dart` in Stage A) |
| **Material `AppBar` (opaque nav bar)** | not on main tabs | Main tabs use **no** `Scaffold.appBar`; header is the surface strip above. `AppBar` remains on secondary routes: `category_list_view.dart`, `profile_view.dart`, `tag_settings_*.dart`, `SettingsPage` in `app_shell.dart`, and nested Lists tag-manager push |

---

## Where things live (symbols)

Routing map for AI assistants: open these first instead of grepping. Update this table whenever a canonical symbol moves or is renamed.

| Concept | File | Symbol |
| :--- | :--- | :--- |
| Voice input dispatcher (routes by active tab) | `lib/app_shell.dart` | `_startVoiceInput` |
| Desktop Price Reporter voice command (kill switch) | `lib/app_shell.dart` | `_toggleDesktopVoiceCommandPanel`, `_desktopVoiceSubmitParsed` |
| Desktop voice command parser | `lib/data/voice_command_parser.dart` | `parsePriceReporterVoiceCommand`, `VoiceCommandCategoryIndex`, `parseVoiceCommand` |
| Desktop voice pipeline log | `lib/core/diagnostics/desktop_voice_log.dart` | `DesktopVoiceLog` — debug/profile pipeline markers |
| Desktop voice widget UI (GOLOS STT) | `lib/features/shared/desktop_voice_widget.dart` | `DesktopVoiceWidget`, `showDesktopVoiceWidget` |
| Desktop GOLOS STT helper | `lib/core/services/desktop_stt_helper_service.dart` | `DesktopSttHelperService` |
| Desktop voice recognizer | `lib/core/services/desktop_voice_recognizer_factory.dart` | `createDesktopVoiceRecognizer` |
| Desktop tray | `lib/core/services/desktop_tray_service.dart` | `DesktopTrayService` |
| Desktop voice settings (local) | `lib/core/services/desktop_voice_settings.dart` | `DesktopVoiceSettings` |
| Desktop voice hotkey | `lib/core/services/desktop_voice_hotkey.dart` | `DesktopVoiceHotkey` |
| Profile desktop voice settings UI | `lib/features/profile/desktop_voice_settings_section.dart` | `DesktopVoiceSettingsSection` |
| Desktop voice shell wiring | `lib/app_shell.dart` | `_toggleDesktopVoiceWidget`, `_desktopVoiceSubmitParsed`, `_initDesktopVoiceLayer` |
| UI dispatch wrappers (shell-side, debounced) | `lib/app_shell.dart` | `_stopRecordByDocId` / `_deleteRecordByDocId` / `_startTaskFromInput` |
| Start a record (user taps Start) | `lib/data/records/record_crud.dart` | `DatabaseService.writeRecord` (`RecordCrudExtension`) |
| Stop a record (user taps Stop) | `lib/data/records/record_crud.dart` | `DatabaseService.stopRecordByDocId` (`RecordCrudExtension`) |
| Update / edit a record | `lib/data/records/record_crud.dart` | `DatabaseService.updateRecord` (`RecordCrudExtension`) |
| Delete a record | `lib/data/records/record_crud.dart` | `DatabaseService.deleteRecordByDocId` (`RecordCrudExtension`) |
| Optimistic shadow — Start | `lib/data/records/record_overlap_helpers.dart` | `DatabaseService._startAtomicTaskSequenceApplyLocalPrimary` (`RecordOverlapExtension`) |
| Optimistic shadow — Stop | `lib/data/records/record_optimistic.dart` | `DatabaseService._applyOptimisticStopUiSnapshot` (`RecordOptimisticExtension`) |
| Offline queue — records | `lib/data/local_sync/record_mutation_outbox.dart` | `RecordMutationOutbox.enqueue` / `coalesceQueue` |
| Offline queue — plans | `lib/data/local_sync/plan_mutation_outbox.dart` | `PlanMutationOutbox.enqueue` / `coalesceQueue` |
| Flush pending mutations (all) | `lib/data/db_core.dart` | `DatabaseService.flushPendingLocalMutations` (extension) |
| Flush pending records | `lib/data/records/record_outbox_helpers.dart` | `DatabaseService.flushPendingRecordMutations` (`RecordOutboxSyncExtension`) |
| Flush pending plans / lists | `lib/data/plan_service.dart` | `DatabaseService.flushPendingPlanMutations` (extension) |
| Sync state / auth resume | `lib/data/local_sync/offline_sync_state.dart` | `OfflineSyncController` on `DatabaseService.offlineSync`; `resumeAfterAuthIfNeeded` |
| Connectivity watcher | `lib/data/local_sync/sync_manager.dart` | `SyncManager.instance` |
| Shell sync / offline banner | `lib/features/shared/offline_sync_status_bar.dart` | `OfflineSyncStatusBar` |
| Singleton / stale-open detection | `lib/data/records/record_overlap_helpers.dart` | `_rowStartWallDayIsBeforeProjectedToday` / `_mergeSacredStaleOpenCandidates` (`RecordOverlapExtension`) |
| Realtime subscribe handler | `lib/data/records/record_realtime.dart` | `DatabaseService._onPbRecordsSubscriptionEvent` (`RecordRealtimeExtension`) |
| Record cache mutation (atomic upsert) | `lib/data/record_service.dart` | `DatabaseService._upsertFlatRecordFromPbModel` (extension) |
| ID resolution (legacy UUID → PB row id) | `lib/data/record_service.dart` | `DatabaseService._resolveRecordIdForStopOrDelete` (extension) |
| Category smart-link / fuzzy match | `lib/data/categories/category_lookup.dart` | `DatabaseService.findCategoryByFuzzyMatch` (`CategoryLookupExtension`) |
| Category create | `lib/data/categories/category_crud.dart` | `DatabaseService.addNestedCategory` (`CategoryCrudExtension`) |
| Category update | `lib/data/categories/category_crud.dart` | `DatabaseService.updateCategory` (`CategoryCrudExtension`) |
| Category → PB row ID mapping (cold-start) | `lib/data/categories/category_record_bridge.dart` | `DatabaseService._normalizeRecordCategoryFieldsForPbApi` (`CategoryRecordBridgeExtension`) |
| Plan / planning task write | `lib/data/plan_service.dart` | `DatabaseService.addPlanningTask` (extension) |
| Plan / planning task CRUD (full) | `lib/data/plan_service.dart` | `PlanServiceExtension` — addPlan, updatePlanningTask, deletePlanningTask, bulkUpdatePlans |
| Backlog / list items fetch | `lib/data/plan_service.dart` | `DatabaseService.fetchBacklogPlans` (extension) |
| Plan stream / optimistic cache | `lib/data/plan_service.dart` | `DatabaseService.planningStream` / `applyOptimisticPlanningTask` (extension) |
| Plan rrule expansion | `lib/data/plans/plan_recurrence_helpers.dart` | `DatabaseService.expandRecurringPlans` (`PlanRecurrenceExtension`) |
| Plan alarm scheduling | `lib/data/plan_service.dart` | `DatabaseService._requestPlanAlarmReschedule` (extension) |
| AI task parse | `lib/data/plan_service.dart` | `DatabaseService.parseTaskViaAiBackend` / `parsePlanningItemsViaAiBackend` (extension) |
| Plan link scoring (title similarity) | `lib/data/plans/plan_cache_helpers.dart` | `titlePlanLinkScore`, `titleSimilarityForPlanLink` (top-level) |
| Plan wall-estimate seconds | `lib/data/plans/plan_time_cascade_helpers.dart` | `planningWallEstimateSeconds` (top-level) |
| Plan / planning task done-toggle | `lib/features/planning/planning_page.dart` | `_PlanningPageState._toggleDone` |
| List done-toggle (optimistic; rollback only on hard failure) | `lib/features/lists/lists_view.dart` | `_ListsPageState._onListToggleDone` → `updatePlanningTask(isDone:)` (queues offline) |
| Tag link to plan | `lib/data/plan_service.dart` | `DatabaseService._syncPlanTagsPocket` (extension) |
| Timeline render (list) | `lib/features/timeline/timeline_view.dart` | `TimelinePage` |
| Timeline edit sheet | `lib/features/shared/timeline_record_edit_sheet.dart` | `TimelineRecordSheetContent`; entry via `ActivityDetailSheet` |
| Inline edit widget (child / parallel record) | `lib/features/shared/edit_sheet/parallel_record_panels.dart` | `ChildParallelEditBar` |
| Voice input → record submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitTimeline` |
| Voice input → planning task submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitPlanning` |
| Voice input → backlog submission | `lib/app_shell.dart` | `_LifeOSDashboardState._voiceSubmitBacklog` |
| Auth / session bootstrap | `lib/data/auth_bridge.dart` | `AuthBridge.checkSession` |
| Profile timezone resolution | `lib/data/profile/profile_timezone.dart` | `DatabaseService.getProjectedToday` (`ProfileTimezoneExtension`) |
| Profile settings getter | `lib/data/profile_service.dart` | `DatabaseService.settings` (`ProfileServiceExtension`) |
| Save user settings | `lib/data/profile/profile_settings.dart` | `DatabaseService.saveSettings` (`ProfileSettingsExtension`) |
| Update timezone | `lib/data/profile/profile_timezone.dart` | `DatabaseService.updateTimeZone` (`ProfileTimezoneExtension`) |
| Fetch tags (current user) | `lib/data/profile/tag_catalog.dart` | `DatabaseService.fetchTagsForCurrentUser` (`TagCatalogExtension`) |
| Tag create | `lib/data/profile/tag_catalog.dart` | `DatabaseService.createTagForCurrentUser` (`TagCatalogExtension`) |
| Tag delete | `lib/data/profile/tag_catalog.dart` | `DatabaseService.deleteTagByPocketRecordId` (`TagCatalogExtension`) |
| Tag update | `lib/data/profile/tag_catalog.dart` | `DatabaseService.patchTagForCurrentUser` (`TagCatalogExtension`) |
| Tag stream notification | `lib/data/profile/tag_catalog.dart` | `DatabaseService.notifyTagsCatalogChanged` / `tagsCatalogUpdated` (`TagCatalogExtension`) |
| Get / fetch user profile | `lib/data/profile/profile_hydration.dart` | `DatabaseService.getUserProfile` (`ProfileHydrationExtension`) |
| PocketBase init / health check | `lib/data/db_core.dart` | `DbCoreExtension.ensurePocketBaseReady` |
| Realtime reconnect bridge | `lib/data/db_core.dart` | `DbCoreExtension.ensureRecordsRealtimeBridge` |
| Sign-out / state clear | `lib/data/db_core.dart` | `DbCoreExtension.clearLocalStateOnSignOut` |
| Initial data load (full) | `lib/data/db_core.dart` | `DbCoreExtension.loadInitialData` |
| Wear OS lite data load | `lib/data/db_core.dart` | `DbCoreExtension.loadInitialDataWearLite` |
| Date key bucketing (UTC → wall-day string) | `lib/data/record_service.dart` | `DatabaseService._timelineDeviceLocalDayKeyFromUtc` (extension) |

---

## P0 / performance layer (active architecture debt)

**Not random garbage — active diagnostics + warm-cache for Timeline/Planning date paging (P0U track).** Consolidate later; do not delete while paging work is open. Full file list: `docs/APP_STRUCTURE.md` §5.3–5.4. Structure guard: `scripts/audit/architecture_guard.ps1 -Strict`.

| Concept | File | Notes |
| :--- | :--- | :--- |
| Master perf probe | `lib/core/perf_diag.dart` | `--dart-define=PERF_DIAG=true` |
| Bisect toggles | `lib/core/perf_flags.dart` | LazyIndexedStack, pager sync |
| Runtime diagnostics | `lib/core/diagnostics/runtime_log.dart` | Release-safe runtime markers |
| Runtime flags | `lib/core/performance/runtime_flags.dart` | Kill switches (default off) |
| Startup log | `lib/core/diagnostics/startup_log.dart` | Boot timing |
| Rebuild metrics | `lib/core/performance/rebuild_metrics.dart` | `--dart-define=PERF_DIAG=true` only |
| Shell flags | `lib/core/performance/shell_flags.dart` | Shell bisect toggles |
| Day cache | `lib/data/cache/day_snapshot_window.dart` | Warm day snapshot window |
| Render cache | `lib/data/cache/render_snapshot.dart`, `rendered_day_body_cache.dart` | Rendered day-body cache |
| Structure guard | `scripts/audit/architecture_guard.ps1` | `-Strict` enforces `docs/APP_STRUCTURE.md` |
| Structure guide (RU) | `docs/APP_STRUCTURE_DETAILED.md` | Bilingual EN/RU per-file guide |
| Plan dup trace | `lib/core/plan_dup_trace.dart` | Duplicate plan trace |
| Warm snapshot data | `lib/data/warm_day_window.dart` | WarmSnapshotWindow |
| Rendered body cache | `lib/data/rendered_day_body_cache.dart` | Day-body LRU |
| Render snapshot | `lib/data/p0t_render_snapshot.dart` | Snapshot helpers |
| Eager day strip | `lib/core/widgets/eager_day_content_strip.dart` | P0U widget |
| Mounted day window | `lib/core/widgets/mounted_day_window.dart` | P0U widget |
| Structure guard | `scripts/audit/architecture_guard.ps1` | Warning-mode audit |

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

## Design System / Component Lab

- `docs/UX_CONTRACT.md` is the behavior contract for taps, save/edit/delete, loading/empty/error, offline/pending sync, disabled states, sheet close, selection/bulk, drag/reorder, and optimistic UI.
- `docs/DESIGN_SYSTEM.md` is the Figma → Flutter design-system contract: token categories, canonical component categories, and the forbidden local UI rule.
- Component Lab lives at `lib/features/dev/component_lab_view.dart` (`ComponentLabPage`) and is reachable from More → Dev / Design Lab only for admins.
- Component Lab is gated by `profiles.is_admin`, parsed as `UserSettings.isAdmin`; missing/null is false.
- `profiles.is_admin` is read-only in client UI, managed manually in PocketBase Admin UI, and must never be PATCHed by normal profile settings.
- New reusable UI belongs in `lib/core/widgets/`.
- Feature screens compose canonical components; do not recreate local copies.
- Variations are parameters, not copies.
- Figma names use clean design language (`Button`, `Card`, `Chip`, `Tabs`, `Sheet`, `Header`).
- Flutter canonical components use app-namespaced names (`AppButton`, future `AppTaskCard` / `AppCard`, `AppTagChip` / `AppCategoryChip`, `AppSegmentedTabs`, `AppSheet`, `AppShellHeader`).
- App action buttons must use `AppButton` from `lib/core/widgets/app_button.dart`.
- Figma `Icon Button` maps to Flutter `AppIconButton`.
- `AppIconButton` lives in `lib/core/widgets/app_icon_button.dart`.
- Raw `FilledButton`, `ElevatedButton`, `OutlinedButton`, and `TextButton` are forbidden in feature screens for app actions unless documented as temporary legacy in `docs/reports/DESIGN_SYSTEM_INVENTORY.md`.
- Raw `IconButton` is legacy allowed temporarily, but new app-owned icon-only actions should use `AppIconButton` unless documented.
- Component Lab is the visual acceptance surface for canonical UI components.
- Component Lab examples must be explicitly labeled with Figma → Flutter mapping and state metadata.
- Component Lab must show labeled `AppIconButton` examples before production icon-button migration.

---

## F1 / Lists — shipped

O1 offline-first, V1, and F1 Lists are **shipped** (`docs/ROADMAP.md`). F2A and F2C are accepted; F2B/F3/all feature work are paused unless explicitly requested. Active work is V3/V7.

| Item | Status | Notes |
| :--- | :--- | :--- |
| List-domain tags | **Shipped** | `domain: list` tags load/filter in Lists, show on cards/edit sheet, and hydrate through plan/list tag catalogs |
| Export visible list as text | **Shipped** | Copies currently visible filtered list rows to clipboard as numbered text |
| Active chip first | **Shipped** | Active category/tag chips render first and scroll to start |
| Card checkbox/text alignment | **Shipped** | `_BacklogPlanCard` checkbox and title column are centered for one-line and two-line titles |
| No play button on list cards | **Shipped** | Lists cards expose checkbox/menu only; Planning play controls remain separate |
| Backlog pin / fix important items | **Schema gap** | No `plans.is_pinned` in PocketBase yet. Proposed: `plans.is_pinned` (bool) on backlog/list rows; sort pinned before unpinned. Do not implement client-only pin state. See `lists_pin_item_todo` in `dictionary.dart`. |

---

## F2 / Plans — partial accepted

| Item | Status | Notes |
| :--- | :--- | :--- |
| F2A compact tabs/header/play/repeat icon | **Accepted** | Functional/acceptable. Remaining pixel-perfect tabs/header/tags polish is deferred to V3 UX_CONTRACT / V7 Design Language. |
| F2C category default plan time | **Accepted** | `categories.default_plan_time` was manually added in PocketBase; selector/search UI is live and accepted. |
| F2B plan category filter | **Deferred** | Do not implement unless explicitly requested. |
| Recurring edit scope | **Partial shipped** | Virtual occurrence time/metadata edit materializes one-off row + parent `exception_dates`. Full series edit-scope dialog for other mutations remains future work. |

---

## AI laws (do not reintroduce)

### Record category payload

- `records.category_id` and `records.category_link` both expect **15-char `categories.id`** in POST/PATCH.
- Business slug (`categories.category_id`) is normalized in the Brain before network I/O; never send slug in record relation fields.

### Tag default duration

- `tags.default_plan_duration_minutes` — optional PB **number**; may return `10.0`; parser accepts `num`/`int`/`double`.

### Time mode

- UTC storage; profile TZ projection for filter/placement/now-line; wall-time create/edit; **5-min** snap/min; micro/compact/medium/large density; now-line above cards; no out-of-range bucket.

### Recurring edit

- Virtual occurrence edit → materialize one-off plan + `exception_dates` on parent series.

## Architecture rules (from Iron Laws)

- **Performance Kill Switch Law (P0V):** Speed, stability, and instant feedback are sacred. If any change causes slower startup, freeze/crash, swipe jank, broken optimistic UI, missing instant record/plan create, log spam, invisible-data projection storms, mounted-widget explosion, or network-before-UI — **stop all feature/preload/design work**, disable the offending experiment by default, restore stable behavior + live optimistic sources, remove hot-path overload, then continue. Full law: `docs/ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW. Flags: `lib/core/performance/runtime_flags.dart`, `lib/core/performance/shell_flags.dart`. **Banned:** “cache exists” / “snapshot ready” as excuses when the user sees lag or crash.
- **Optimistic UI:** Start/Stop/Update/Delete on records and Planning/Lists CRUD must never block the UI. Apply local shadow first (<100ms), sync to PocketBase async. On **retriable** network failure → enqueue to `lib/data/local_sync/*_mutation_outbox.dart` and keep optimistic state; on **non-retriable** validation errors → roll back and snack.
- **No `await` before UI update** for user-driven record/plan actions.
- **Offline drain:** `flushPendingLocalMutations` on login (`loadInitialData`), reconnect (`SyncManager`), app resume, and tap-to-retry (`OfflineSyncStatusBar`). 401/403 sets `offlineSync.authPaused` until `resumeAfterAuthIfNeeded` + valid session.
- **Storage is UTC.** Profile `timezone_offset` / `preferred_timezone` drive wall-clock grouping.
- **Every query filters by current user** via `user_id`.
- **God Object split complete:** `database_service.dart` started at ~10,000 lines and is now ~720 lines (the root singleton — shared state, streams, static helpers). Domain logic lives in `part of` files: V5.1 profile coordinator → `profile_service.dart` + `profile/*` (Pass 4D); V5.2 plan coordinator → `plan_service.dart` + `plans/*` (Pass 4A); V5.3 record coordinator → `record_service.dart` + `records/*` (Pass 4B); V5.4 category coordinator → `category_service.dart` + `categories/*` (Pass 4C); V5.5 bootstrap/lifecycle → `db_core.dart`.

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
Maintain a running list of every governing doc modified during the session. At session end, print the full list. Do not rely on memory of what was last edited. Current governing docs are committed in this repository. Governing docs that must be tracked: `docs/APP_STRUCTURE.md`, `docs/ARCHITECTURE.md`, `docs/DATA_MAP.md`, `docs/POCKETBASE_MANIFEST.md`, `docs/ROADMAP.md`, `CHANGELOG.md`, `AGENT_NAVIGATION.md`, `AGENTS.md`.
