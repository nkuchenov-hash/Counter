# 📖 DEV_JOURNAL (Changelog)

> **WARNING FOR AI:** Read the latest entries to understand what features are ALREADY built and do not need to be recreated.
>
> 🚀 **FOUNDER'S VICTORY PROMPT (COPY & PASTE INTO CURSOR CHAT WHEN A FEATURE IS TESTED AND WORKS):**
> ***
> **CONTEXT:** We just successfully tested and completed a feature.
> **TASK FOR CURSOR:** > 1. Analyze our recent conversation history to understand exactly what technical logic, UI, or architectural rule we just successfully implemented.
> 2. Write a concise, highly technical 1-2 sentence bullet point summarizing the achievement (mention specific file names, hooks, or logic rules).
> 3. Add this bullet point to the top of the `@CHANGELOG.md` file under today's date (create a new date header if today's date doesn't exist yet). 
> 4. DO NOT delete or modify any existing entries.
> ***

## [2026-06-15] - P0U.5: canonical running id once per Timeline day VM build [wip]
* **`record_service.dart`:** [wip] `resolveCanonicalPrimaryRunningBusinessId()` computed once in `_buildTimelineRowVmsForDate`; passed into `_timelineRowVmFromMap` / subtitle — removes 11× `_cachedFlatRecords` scan.
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `canonicalPrimaryRunningBiz_once` step; per-row `canonicalPrimaryRunningBiz_call` no longer on hot path.

## [2026-06-15] - P0 Time View target drop adjacent insertion + darker canvas [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] `computeTimeViewTargetDropSchedule` — exact before/after target wall times, zero scheduled gap.
* **`planning_view.dart`:** [wip] target hit-test at commit; preview Y/label from target wall times not raw `yToTime`; free canvas still uses snap; canvas `surfaceContainerHigh`/`surfaceContainerHighest` blend darkened.
* **`test/plan_time_target_drop_test.dart`:** [wip] lower/upper half, yToTime ignored, preview=commit, cascade.

## [2026-06-15] - P0U.4R3: line-level Timeline VM diagnostics (microsecond accounting) [wip]
* **`p0u_timeline_vm_build_diag.dart`:** [wip] microsecond `Stopwatch` accounting; line-level `stepOrder`; `unmeasuredOtherMs` on DONE; nested subtitle steps; single `[P0U_TIMELINE_VM_SLOWEST_RECORD]` breakdown.
* **`record_service.dart`:** [wip] `_timelineRowVmFromMap` / `_timelineSubtitleForRecordMap` instrument `mapAccess_*`, `canonicalPrimaryRunningBiz_call`, `categoryDisplayPath_call`, `cachePut`, `loopOverhead`, etc.

## [2026-06-15] - P0U.4R2: deep per-record Timeline VM build diagnostics [wip]
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `P0uTimelineVmRecordBuildSession` per-record steps; day `STEP_TOTAL` with `explainedMs`/`unexplainedMs`; single `[P0U_TIMELINE_VM_SLOWEST_RECORD]` breakdown.
* **`record_service.dart`:** [wip] `_timelineRowVmFromMap` / `_timelineSubtitleForRecordMap` instrument `recordForTimelineCard`, `timeProjection`, `timezoneFormat`, `categoryLookup`, `breadcrumbPath`, `checklistNotesFlags`, `progressDuration`, `subtitleBuild`, `colorConversion`, `objectCreate`, `unmeasuredOther`.

## [2026-06-15] - P0 Time View sequential cascade (no conflict layout) [wip]
* **`plan_time_sequential_cascade.dart`:** [wip] pure `cascadeScheduledPlansForTimeViewDay` / `diffSequentialCascadePatches` — overlap → shift down, preserve duration, cascade chain.
* **`plan_service.dart`:** [wip] `applySequentialTimeViewCascadeIfNeeded` optimistic + background PATCH; `resolveAutoPlanSchedule` probe cascade; `addPlanningTask` day normalize after create.
* **`planning_view.dart`:** [wip] day-load normalize before projections; drag cascade all scheduled rows; `timelineScheduleConflict: false`.
* **`plan_time_view_layout.dart`:** [wip] removed `hasScheduleConflict` detection loop.
* **`test/plan_time_sequential_cascade_test.dart`:** [wip] overlap, drag-after, chain, duration, quick-add, virt recurring.

## [2026-06-15] - P0U.4R: disable adjacent VM warmup + VM builder step diagnostics [wip]
* **`p0u_feature_flags.dart`:** [wip] `kTimelineAdjacentRowVmWarmup = false` (P0U.4 rollback).
* **`p0u_timeline_vm_build_diag.dart`:** [wip] `[P0U_TIMELINE_VM_BUILD_*]` step timings; `[P0U_TIMELINE_ADJ_VM_WARM_DISABLED]`.
* **`record_service.dart`:** [wip] Instrument `_timelineRowVmFromMap` / `_buildTimelineRowVmsForDate` per-step (no per-record spam).
* P0U.4D swipe diagnostics preserved; no VM optimization yet.

## [2026-06-15] - P0 Time View VerySmall/Small reference element sizes [wip]
* **`plan_time_task_card.dart`:** [wip] Remove scaled-down VerySmall path (26px controls, 7px micro tags, 28px menu); restore 32px checkbox/play, 33px menu, CardPlan title typography, vertical tag stack with standard compact pills; 38px density threshold unchanged.

## [2026-06-15] - P0U.4: Timeline adjacent row-VM warmup [wip]
* **`record_service.dart`:** [wip] Post-firstFrame chunked warmup for ±1 day row VMs (`_timelineDayVmCache` + lazy per-row cache); kill switch `kTimelineAdjacentRowVmWarmup`.
* **`timeline_view.dart`:** [wip] Schedule warmup when Timeline tab visible; re-warm after page settle.
* **`p0u_feature_flags.dart`:** [wip] `kTimelineAdjacentRowVmWarmup` flag.
* P0U.4D swipe diagnostics preserved.

## [2026-06-15] - P0 Time View CardPlan responsive visual fix [wip]
* **`plan_time_task_card.dart`:** [wip] Remove list-row minHeight on explicit Time View density path; `_TimeViewResponsiveShell` / `_TimeViewVerticalShell` anchors (fixed rail + expanding center + menu cluster); `_TimeViewTagsRow` shows all tags; density bodies match CardPlan refs at 38–95px+ without fixed card width.
* **`plan_card.dart`:** unchanged — still passes parent width + `timelineBlockHeightPx` only.

## [2026-06-15] - P0U.4D: Timeline first-swipe diagnostics only [wip]
* **`p0u_timeline_swipe_diag.dart`:** [wip] First-swipe target logging, cache state, step timings, frame jank summary.
* **`timeline_view.dart`:** [wip] Correct swipe target date; TARGET_* probes on first swipe only.
* **`record_service.dart`:** [wip] `timelineTargetDayCacheSnapshot` / data+VM probes (no full scans).
* **`p0u_startup_diag.dart` / `main.dart`:** [wip] First-frame marker armed/fired/delay + deferred-before-frame guard.
* Diagnostics only — no paging/warmup behavior changes.

## [2026-06-15] - P0 Time View CardPlan density visual fix [wip]
* **`plan_time_task_card.dart`:** [wip] Explicit Time View layouts per CardPlan band (VerySmall→Medium); tags always visible; removed `timelineFillHeight` tag suppression.
* **`plan_card.dart`:** [wip] Pass `timelineVisualDensity` + fixed height; `timelineFillHeight: false` for Time View blocks.

## [2026-06-15] - P0U.3: emergency rollback of P0U.2 first-frame regression [wip]
* **`p0u_feature_flags.dart`:** [wip] Kill switch — `kShellDeferHiddenTabsUntilFirstFrame = false` (P0U.2 regressed firstFrameMs 4668 vs P0U.1 1511).
* **`p0u_startup_diag.dart`:** [wip] `scheduleAfterFirstFrame` + `[P0U_BOOT_DEFERRED_CONFIRMED_AFTER_FRAME]` logs.
* **`db_core.dart`:** [wip] Deferred boot (warm windows, sync, realtime) queued until after first rendered frame.
* P0U.1 profile cache, diagnostics, liveOptimistic, stable PageView preserved.

## [2026-06-15] - P0 Time View bounded layout regression fix [wip]
* **`plan_time_view_layout.dart`:** [wip] Separate stable card height (`kPlanTimeStableBaseCardPxPerMinute`) from bounded hour stretch; sequential one-column placement; 480px hour cap.
* **`plan_time_task_card.dart`:** [wip] `planTimeCardRenderedHeightPxForDuration`, layout constants.
* **`plan_service.dart`:** [wip] `_avoidPlanWallScheduleCollisions` — sequential auto-schedule when slots collide.
* **`test/plan_time_view_layout_test.dart`:** [wip] Density, 5/10min, dense-hour, y/time tests.

## [2026-06-15] - P0U.2: shrink firstShellBuild→firstFrame gap [wip]
* **`p0u_startup_diag.dart`:** [wip] `[P0U_FRAME_GAP_*]` / `[P0U_SHELL_BUILD]` / `[P0U_TAB_BUILD]` / `[P0U_HIDDEN_TAB_*]` diagnostics.
* **`app_shell.dart`:** [wip] `kShellDeferHiddenTabsUntilFirstFrame` → `LazyIndexedStack` (active tab only on first paint); defer timeline tasks + shell sync bootstrap post-frame.
* **`lazy_indexed_stack.dart`:** [wip] Boot defer + tab activation logs.
* **`timeline_view.dart`:** [wip] First paint from `peekTimelineRecordsForDate` only; defer `recordsStream` until post-frame; remove hot-path `timelineBodyEntryForDate`.
* P0U recovery preserved.

## [2026-06-15] - P0U.1: startup timing diagnostics + boot hot-path cleanup [wip]
* **`p0u_startup_diag.dart`:** [wip] `[P0U_BOOT_STAGE]` / `[P0U_BOOT_DEFERRED]` / `[P0U_BOOT_SUMMARY]` stopwatch logger.
* **`main.dart`:** [wip] Boot stage timings; defer non-current `initializeDateFormatting` locales; first shell/first frame markers.
* **`db_core.dart`:** [wip] Critical path only (categories + prefs records + disk warm restore); `_runDeferredBootWorkAfterFirstShell` for network fetch, warm windows, realtime, sync.
* **`profile_service.dart`:** [wip] Device cache-first profile boot (`cacheThenServer`); background PB refresh; `[P0U_PROFILE_*]` logs.
* **`record_service.dart`:** [wip] `bootstrapTimelineRecordsCacheFromPrefsAtBoot(criticalOnly: true)` skips warm/prebuild on hot path.
* **`app_shell.dart`:** [wip] STT init deferred post-first-frame.
* P0U recovery preserved (`kUseP0tMountedStrip=false`, stable PageView, live optimistic sources).

## [2026-06-15] - P0V: Performance Kill Switch Law — speed/stability as sacred project law [wip]
* **`docs/ARCHITECTURE.md`:** [wip] New Iron Rule § **PERFORMANCE_KILL_SWITCH_LAW** — hard-stop conditions, emergency response, preload/snapshot/logging/hot-path rules.
* **`docs/UX_CONTRACT.md`:** [wip] § **Performance & Responsiveness Contract** — ~100ms feedback, no partial cards, performance regression = P0 correctness bug.
* **`docs/AI_CONTEXT.md` / `CLAUDE.md` / `docs/ROADMAP.md`:** [wip] AI emergency stabilization protocol; performance regressions outrank V3/V7; banned “cache exists” excuses.
* **`lib/core/perf_flags.dart` / `p0u_feature_flags.dart` / `app_build_info.dart`:** [wip] P0V law comments; experimental paths default-off; `p0vPerfKillSwitchMarker`.
* **Not shipped** until docs reviewed and team confirms law is in force.

## [2026-06-15] - P0U: emergency recovery — disable P0S/P0T, restore stable paging [wip]
* **`p0u_feature_flags.dart` / `p0u_diag.dart` / `p0u_platform.dart`:** [wip] Global kill switch `kUseP0tMountedStrip=false`; `[P0U_*]` diagnostics (pager mode, first swipe, record optimistic, release log guard).
* **`planning_view.dart` / `timeline_view.dart`:** [wip] Restored stable `PageView.builder` + `DatePagerSettleGate` + `FeatherDateSwipePhysics`; active day uses live planning stream / live optimistic records; P0S/P0T `EagerDayContentStrip` behind flag only.
* **`database_service.dart` / `record_service.dart`:** [wip] `_emitTimelineRefreshRaw` clears `_timelineDayViewCache`; `peekTimelineRecordsForDate` skips stale view cache when day index dirty; record create optimistic `[P0U_RECORD_*]` logs.
* **`plan_service.dart`:** [wip] `TIME_TZ_PROJECT` per-row logs gated behind `kVerbosePlanTimeTzProjectionLogs` + `!kReleaseMode`.
* **`db_core.dart`:** [wip] Boot skips P0T mounted/render window when flag false; light `ensurePlansWarmWindow` / `ensureTimelineWarmWindow` only.
* **`main.dart`:** [wip] Biometric gate stays off; `FlutterError.onError` + `PlatformDispatcher.onError` → `[P0U_WEB_ERROR]` / `[P0U_ANDROID_ERROR]`.
* **P0S / P0T:** marked failed/superseded as production default — not shipped until user confirms web + APK.

## [2026-06-22] - Stage A cleanup + A.1 compile baseline + Stage C doc sync [shipped]
* **Stage A [shipped]:** Deleted proven orphans/non-code — `p0b_logcat.txt`, `lib/notes` (archived to `docs/archive/lib_notes_scratch.txt`), `lib/deploy.ps1`, `lib/data/html_stub.dart`, `lib/features/more/more_view.dart`, `lib/features/timeline/timeline_widgets.dart`. No P0/perf/warm files touched; More menu stays inline in `app_shell.dart` `_openMoreMenu`; Timeline header stays inline in `timeline_view.dart`.
* **Stage A.1 [shipped]:** `planning_view.dart` — added `p0n_perf_diag.dart` import; restored `_PlanningDayCardListKeepAlive` keep-alive wrapper for offscreen PageView day bodies. `flutter analyze --no-fatal-infos --no-fatal-warnings` green.
* **Stage C [shipped]:** Doc sync — `docs/APP_STRUCTURE.md`, `CLAUDE.md`, `docs/ROADMAP.md`, `docs/reports/CODEBASE_CLEANUP_AUDIT_2026-06-22.md`, `docs/reports/DESIGN_SYSTEM_INVENTORY.md` (cleanup note only).
* **Tests:** `flutter test` loads/runs; 3 runtime failures remain in perf/widget harness — not compile blockers, unrelated to Stage A deletes.

## [2026-06-15] - P0T: emergency stabilize + atomic fully-rendered date pages [wip]
* **`p0t_render_snapshot.dart` / `p0t_diag.dart`:** [wip] `PlanCardRenderDto` / `PlansDayRenderSnapshot` + `TimelineDayRenderSnapshot`; FULL_READY checks; `[P0T_*]` diagnostics.
* **`plan_service.dart` / `record_service.dart` / `db_core.dart`:** [wip] Critical ±1 boot only; background full window warm; render snapshots built at body prep; startup no longer blocks on 21-body mount.
* **`mounted_day_window.dart`:** [wip] Mount radius ±3 (7 bodies) — P0S ±10 superseded for widget mount.
* **`eager_day_content_strip.dart`:** [wip] P0T reveal gate blocks not-ready dates; scroll index guards; controller attach fix.
* **`planning_view.dart`:** [wip] Atomic frozen cards (play/tags/category from render DTO); inactive Time mode uses same hour grid; reveal gate wired.
* **`timeline_view.dart`:** [wip] `FeatherDateSwipePhysics` (20% threshold); reveal gate; critical render ready at open.
* **`main.dart`:** [wip] Biometric gate disabled (`kP0tBiometricGateDisabled`); `FlutterError.onError` → `[P0T_CRASH_TRACE]`.
* **P0S:** marked failed/superseded — not shipped.

## [2026-06-15] - Time View: CardPlan density + stretchable hour scale [wip]
* **`plan_time_view_layout.dart`:** [wip] Pure layout calculator — per-hour variable height, sequential card reflow (min 38px + 2px gap), `PlanTimeViewDurationGrid` y↔time mapping shared by render/drag/resize/now line.
* **`plan_time_task_card.dart`:** [wip] `PlanTimeCardVisualDensity` bands (VerySmall 38 / Small 39–54 / MoreCompact 55–77 / Compact 78–94 / Medium 95+); progress/breadcrumb gates per band.
* **`planning_view.dart` / `plan_card.dart`:** [wip] Wire stretchable grid; darker Time View canvas (`surfaceContainerHighest` blend); density from final rendered height.
* **`test/plan_time_view_layout_test.dart`:** [wip] Layout invariants — 11×5min dense hour, density bands, mixed dense/normal hour.

## [2026-06-15] - P0S: eager mounted content pages ±10 [failed — superseded by P0T]
* **`eager_day_content_strip.dart` / `mounted_day_window.dart` / `p0s_mount_diag.dart`:** [wip] Row-based horizontal strip mounts all ±10 day bodies eagerly (not lazy `PageView.builder`); extend/evict at 41 max; `[P0S_*]` diagnostics.
* **`planning_view.dart` / `timeline_view.dart`:** [wip] Replaced date `PageView.builder` with `EagerDayContentStrip`; static chrome unchanged outside strip.
* **`plan_service.dart` / `record_service.dart`:** [wip] `preparePlansMountedWindowBoot` / `prepareTimelineMountedWindowBoot`; Timeline warm snapshots disk persist (`warm_timeline_snapshots_v1`).
* **`db_core.dart`:** [wip] Boot: disk restore → prepare mounted window data → persist snapshots; network after.

## [2026-06-15] - P0R: critical adjacent prebuild + persistent warm snapshots [wip]
* **`rendered_day_body_cache.dart` / `p0r_prebuild_diag.dart`:** [wip] `TimelineDayBodyEntry` / `PlansDayBodyEntry` with `bodyReady`; critical sync prebuild (±1) before first swipe; chunked ±10 window prebuild; `[P0R_*]` diagnostics.
* **`plan_service.dart`:** [wip] `restorePlansWarmSnapshotsFromDiskAtBoot` / `persistPlansWarmSnapshotsToDisk` (`warm_plans_snapshots_v1`); `plansBodyEntryForDate` sync cache hit path.
* **`record_service.dart`:** [wip] `timelineBodyEntryForDate`; `prebuildTimelineCriticalBodiesSync`; boot disk restore log for Timeline flat records.
* **`db_core.dart`:** [wip] Boot sequence: restore disk → network → critical prebuild → background ±10.
* **`planning_view.dart` / `timeline_view.dart`:** [wip] PageView reads body cache; first-swipe `[P0R_FIRST_SWIPE_TARGET]` logs; screen open re-prebuilds critical 3.
* **Preserved:** content-only PageView (P0P), `PageView.builder`, `DatePagerSettleGate`, no full pages in cache.

## [2026-06-15] - P0P: content-only date paging + rendered day-body warm window [wip]
* **`timeline_view.dart`:** [wip] Static chrome (list/stats toggle, input) mounted once in [TimelinePage]; [PageView] pages only `_TimelineDayCardList` with real `_TimelineLazyRecordList` cards + `AutomaticKeepAliveClientMixin`.
* **`planning_view.dart`:** [wip] Static chrome (sort tabs, tag strip, quick-add) mounted once; [PageView] inside `_buildPlanningMainColumn` pages only day card lists; tag loader removed from date pages (`SizedBox.shrink` until tags ready); `FeatherDateSwipePhysics` preserved.
* **`rendered_day_body_cache.dart` / `p0p_content_diag.dart`:** [wip] Render warm radius 3 / max 7 bodies; `[P0P_*]` diagnostics.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, P0O data warm window (±10), shell `selectedDate`.

## [2026-06-15] - P0O: rolling warm day window for Plans/Timeline date paging [wip]
* **`warm_day_window.dart` / `p0o_warm_diag.dart`:** [wip] `TimelineDaySnapshot` / `PlansDaySnapshot` + `WarmSnapshotWindow` (radius 10, extend 10 @ threshold 3, max 41 LRU); `[WARM_*]` diagnostics.
* **`record_service.dart`:** [wip] `ensureTimelineWarmWindow` / `extendTimelineWarmWindowIfNeeded` / `timelineWarmSnapshotForDate`; boot hydrate builds ±10 snapshots from prefs day index; network merge keeps local + refreshes stale snapshots.
* **`plan_service.dart`:** [wip] `ensurePlansWarmWindow` / `extendPlansWarmWindowIfNeeded` / `plansWarmSnapshotForDate`; refresh on `notifyPlanningRefresh`.
* **`timeline_view.dart` / `planning_view.dart`:** [wip] PageView slots render from warm snapshots sync (no AppLoading/skeleton on swipe); active page seeds from snapshot then live stream patches; extend window on date commit.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, shell `selectedDate` — no P0H–P0L pager experiments.

## [2026-06-15] - P0N: restored PageView performance pass [wip]
* **`record_service.dart` / `db_core.dart`:** [wip] `bootstrapTimelineRecordsCacheFromPrefsAtBoot()` before network fetch (incl. PB backoff path); day index from prefs; `fetchRecords` keeps local cache when network returns empty (`TIMELINE_CACHE_REFRESH_MERGE`); `peekTimelineRecordsForDate` sync lookup + P0N logs.
* **`timeline_view.dart`:** [wip] SWIPE GUARD comment; adjacent slots render cached day list via `peekTimelineRecordsForDate` (no stream/network); `RepaintBoundary` on PageView children; preload coalesced records in `initState`.
* **`planning_view.dart`:** [wip] SWIPE GUARD comment; `FeatherDateSwipePhysics` (20% commit) vs default `PageScrollPhysics`; adjacent days use `planningDayTasksSnapshot` + frozen `PlanCard` list; active-only stream/listeners; P0N swipe/render logs.
* **`p0n_perf_diag.dart`:** [wip] `[TIMELINE_*]` / `[PLANS_*]` debug diagnostics.
* **Preserved:** `PageView.builder`, `DatePagerSettleGate`, shell `selectedDate` ownership — no P0H–P0L pager experiments.

## [2026-06-22] - Emergency: restore pre-white-design PageView date swipe [wip]
* **Root cause:** uncommitted P0H–P0L replaced working `PageView.builder` swipe with `CanonicalDatePager`, hot UI windows, opacity gates, and day-content slot experiments — never landed in git; broke phone tests.
* **Known-good baseline:** commit `10bebe5` (HEAD) — `PageView` + `DatePagerSettleGate` in `planning_view.dart` / `timeline_view.dart`.
* **Restored from HEAD:** `planning_view.dart`, `timeline_view.dart`, `app_shell.dart`, `database_service.dart`, `db_core.dart`, `record_service.dart`, `plan_service.dart`, `global_app_header.dart`, `main.dart`.
* **Removed/disabled (untracked):** `canonical_date_pager.dart`, `canonical_date_physics.dart`, `hot_day_window_*`, `planning/timeline_day_*`, `p0b–p0l_date_diag.dart`, `VisualReadyPageSlot`.
* **`pre_white_swipe_restore.dart`:** [wip] `[PRE_WHITE_SWIPE_RESTORE]` start/commit/cancel logs on PageView path only.
* **White card visuals preserved:** `PlanCard` / `PlanTimeTaskCard` / Time mode geometry commits unchanged.
* **P0H/P0I/P0J/P0K/P0L:** superseded failed experiments — do not re-enable.

## [2026-06-15] - P0: Timeline Android crash guard + reliable date swipe [shipped]
* **`record_service.dart` / `database_service.dart`:** [shipped] Lazy per-row `timelineRowVmForRecordMapOrNull` + `_timelineLazyRowVmByDay`; safe skip/fallback for legacy rows (`P0_CRASH_GUARD`); deferred full day-index rebuild when flat cache >480 rows; `_scanSingleDayFromFlat` serves one day while index rebuilds; prefetch warms record maps only (not bulk VMs).
* **`timeline_view.dart`:** [shipped] `DatePagerSettleGate` — debounced shell date commit, drag blocks external pager sync; standard `PageScrollPhysics`; lazy VM in `ListView.builder`; cancel record stream when page inactive; keep last coalesced list (no blank on refresh).
* **`planning_view.dart`:** [shipped] Same settle gate + `PageScrollPhysics`; pending external date during drag/Time lock; `StreamBuilder` keeps `_latestPlanningDayTasks` when stream is `waiting`.
* **`date_pager_settle_gate.dart` / `p0_date_nav_diag.dart`:** [shipped] Shared pager settle coordinator + debounced debug-only `[P0_*]` logs.

## [2026-06-15] - P0 hotfix: restore Timeline cards + lock Planning pager during Time drag [shipped]
* **`timeline_view.dart`:** [shipped] Removed `_deferHeavyList`/blank `StreamBuilder` — list renders immediately from VM cache; restored visible card chrome (elevation, border, category stripe); stream via lightweight subscription.
* **`planning_view.dart`:** [shipped] `_datePagerLocked` — `NeverScrollableScrollPhysics` on date `PageView` while Time card drag/resize active; fixes gesture fights.
* **`date_swipe_physics.dart`:** [shipped] `getTargetPixels` `@override` restored; Planning `FeatherDateSwipePhysics` + `BouncingScrollPhysics`.

## [2026-06-15] - P0 Fix D: Timeline VM cache + virtualized rows + card layout [shipped]
* **`models/record.dart`:** [shipped] `TimelineRecordRowVm` — Brain-built render-ready row (title, subtitle, category, meta flags).
* **`record_service.dart`:** [shipped] `_timelineDayVmCache`, `peekTimelineRowVmsForDate`; prefetch window prev-2/current/next-1; stale prefetch cancel via center key.
* **`timeline_view.dart`:** [shipped] `_TimelineLazyRecordList` (`ListView.builder`, cacheExtent 320); post-frame `_deferHeavyList`; removed per-card `IntrinsicHeight`/nested Theme; active stream only when today/running; VM-driven `_TimelineRecordCard`.
* **`date_swipe_physics.dart`:** [shipped] `FeatherDateSwipePhysics` (20% drag) for Planning; Timeline `LightDateSwipePhysics` at 22%.
* **`perf_diag.dart`:** [shipped] `TIMELINE_VIEW_CACHE_*`, `TIMELINE_VISIBLE_BUILD`, `timelineHeavyDay` action metrics.

## [2026-06-15] - P0 Fix C: light date-swipe physics + Timeline day cache/prefetch [shipped]
* **`date_swipe_physics.dart`:** [shipped] `LightDateSwipePhysics` — ~25% viewport drag commits adjacent day; 12px motion threshold; shared by Timeline + Planning PageViews.
* **`record_service.dart` / `database_service.dart`:** [shipped] Date-keyed `_timelineRecordsDayIndex` + `_timelineDayViewCache`; `peekTimelineRecordsForDate` / `prefetchTimelineDayNeighbors`; `recordsStream` no longer `await`s broad fetch on subscribe; one O(n) index rebuild vs per-day full-history scan.
* **`timeline_view.dart`:** [shipped] Prefetch neighbors on settle; seed coalesced list from cache; `DATE_SWIPE_THRESHOLD` logs.
* **`perf_diag.dart`:** [shipped] `TIMELINE_CACHE_*`, `TIMELINE_PREFETCH_*`, `PB_TIMELINE_QUERY` diagnostics behind `PERF_DIAG`.

## [2026-06-15] - P0 Fix B: Timeline date-swipe shell isolation + visible-page gate [shipped]
* **`app_shell.dart`:** [shipped] Fix B — `_selectedDateListenable` + cached `ListenableBuilder` tab hosts; `_applySharedSelectedDate` avoids full-shell `setState` on Timeline swipe; `_loadTasksForDate` bumps `_timelineTasksRevision` instead of shell rebuild; header/FAB listen to date notifier.
* **`timeline_view.dart`:** [shipped] Inactive `TimelinePage` returns cheap placeholder (no stream/list build); stream `waiting` no longer flashes `AppLoading`; settle log `shellSetState=false`.

## [2026-06-15] - P0 Fix A: defer hidden date pager until tab activation [shipped]
* **`planning_view.dart` / `timeline_view.dart`:** [shipped] Fix A — inactive `PlanningSwipeWrapper`/`TimelineSwipeWrapper` store `_pendingExternalPage` (`deferHidden`) instead of `jumpToPage`/`animateToPage`; one `jumpToPage` on `shellTabActive` activation; `isActivePlanningDay`/`isActivePage` gated on `shellTabActive`.
* **`perf_diag.dart`:** [shipped] P0 swipe diagnostics behind `kPerfDiagnosisEnabled` (false for release); `test/perf_shell_date_settle_test.dart` proves hidden Planning no longer jump/fetch on Timeline swipe.
* **`android.ps1`:** [shipped] APK build passes `GIT_COMMIT`/`BUILD_TIME` dart-defines for `APP_BUILD` stamp.

## [2026-06-15] - P0 perf bisect: revert LazyIndexedStack + stop hidden tab pager animate [shipped]
* **Bisect:** [shipped] Lag source = `62020e8` `LazyIndexedStack` + hidden `PlanningSwipeWrapper.animateToPage` on every Timeline date swipe (shared `_selectedDate`); `PlanCard` extraction is render-identical to old `_PlanningTaskCard`.
* **`perf_flags.dart`:** [shipped] Bisect toggles (`useLazyIndexedStack`, `syncHiddenTabDatePager`, etc.); defaults restore `IndexedStack` + silent off-tab `jumpToPage`.
* **`app_shell.dart` / swipe wrappers:** [shipped] `shellTabActive`; quiet `_loadTasksForDate` (no loading flash); Timeline `_visiblePageIndex` for swipe frame.

## [2026-06-15] - P0 rollback: revert 73e87e7 date-swipe perf regression [rollback]
* **Git:** [rollback] `git revert 73e87e7` — removed `lib/core/date_swipe/`, `shellTabActive`, `DateSwipePerfMonitor`, wrapper `visiblePageIndex`/`allowImplicitScrolling`/per-page `RepaintBoundary` changes that caused ~10× worse swipe jank.
* **Preserved:** [shipped] `62020e8` LazyIndexedStack, PlanCard, mobile Time rail, tab contrast, profile hydration, `appDebugDiag`.
* **Docs:** [shipped] Date Swipe Law kept in `UX_CONTRACT.md`, `APP_STRUCTURE.md`, `AI_CONTEXT.md` (docs-only; no reintroduce 73e87e7 architecture).

## [2026-06-15] - P0 performance + mobile Time compactness + PlanCard canonical + Design Lab [shipped]
* **`lazy_indexed_stack.dart` / `app_shell.dart`:** [shipped] `LazyIndexedStack` — lazy tab build, `Offstage` + `TickerMode(false)` off-screen; replaces eager `IndexedStack` for smoother horizontal nav.
* **`app_diag.dart` / `planning_view.dart`:** [shipped] `appDebugDiag()` gates `TIME_*` logs to debug; drag layout cache (`_dragInsertLayoutsCache`); projection cache; `RepaintBoundary` on timeline canvas.
* **`planning_view.dart`:** [shipped] Mobile Time rail 28px + compact hour labels (`15` not `15:00`); list padding 4px when width &lt; 600.
* **`compact_nav_controls.dart`:** [shipped] Segmented selected text inherits `onPrimary` (fixes black-on-black active tabs).
* **`plan_card.dart` / `planning_view.dart` / `component_lab_cards_demo.dart`:** [shipped] Canonical `PlanCard` shared by Planning + Component Lab; removed fake `AppTaskCard` card demos.
* **`profile_service.dart`:** [shipped] `PROFILE_SAVE_*` / `PROFILE_HYDRATED` gated to debug; boot `PROFILE_FETCH_*` remains in release.

## [2026-06-15] - V3/V7 neutral-black design tokens (no green primary) [shipped]
* **`app_colors.dart` / `theme.dart`:** [shipped] Central tokens (`actionPrimary` #111111, `appBackground` #FAFAF8, `cardSurface` #FFFFFF); explicit `ColorScheme` + M3 component themes (buttons, FAB, nav, segmented tabs, cards, inputs).
* **Canonical widgets:** [shipped] `AppIconButton` selected = black fill; `LifeCard` white surfaces; `compact_nav_controls` black selected segments; timeline running cards white + black border; calendar today/selected neutral.
* **Outliers:** [shipped] `AppSnack` success uses `AppColors.success`; planning move snackbar uses `scheme.primary`; checkbox pulse uses `scheme.primary`.

## [2026-06-15] - P0 profile hydration diagnostics + hard PB fetch [shipped]
* **`app_build_info.dart` / `main.dart` / `profile_view.dart`:** [shipped] `APP_BUILD commit=… builtAt=… route=…` console log + Profile footer build stamp via `--dart-define`.
* **`profile_service.dart`:** [shipped] Auth-only `profiles.getOne(authStore.record.id)`; no silent empty-settings fallback; `PROFILE_FETCH_SUCCESS`/`PROFILE_UI_SETTINGS_APPLIED`/`PROFILE_SAVE_PATCH payload=…`; `accountName`/`profileEmail` hydration; `retryProfileHydration()`.
* **`db_core.dart`:** [shipped] Profile loads before backoff skip; timeout/sign-out no longer seeds empty `UserSettings`; boot fails loud when PB profile missing.
* **`main.dart`:** [shipped] `_ProfileHydrationErrorScreen` with retry (keeps session).
* **`app_shell.dart` / `web/index.html`:** [shipped] Profile hydration retry banner; SW unregister + `--pwa-strategy=none` cache bust.
* **`profile_view.dart`:** [shipped] Display name from PB (`display_name` → `name` → email), not legacy `AuthService`.

## [2026-06-15] - P0 profile settings persistence (lang/TZ/admin) [shipped]
* **`profile_service.dart`:** [shipped] PB-first hydration: always `getOne(auth.id)`; removed device-prefs override of timezone/theme on boot; field-diff PATCH in `saveSettings` (never `is_admin`); `PROFILE_*` diagnostic logs.
* **`app_shell.dart`:** [shipped] Legacy SettingsPage no longer auto-PATCHes `Local` timezone when stored TZ not in dropdown.
* **`db_core.dart`:** [shipped] Sign-out clears profile TZ/theme prefs cache keys.

## [2026-06-15] - P0 default plan times timezone context [shipped]
* **`categories.default_plan_timezone`:** [shipped] Optional IANA text field documented in `DATA_MAP.md` / `POCKETBASE_MANIFEST.md`; null/`profile` = active profile TZ; backward compatible when missing.
* **`category_service.dart`:** [shipped] `effectiveDefaultPlanScheduleForCategory`, `wallUtcForCategoryDefaultWall`, `updateCategoryDefaultPlanSchedule`, `formatDefaultPlanTimeWithTimezoneLabel`; PB field-missing error detection.
* **`plan_service.dart`:** [shipped] `resolveAutoPlanSchedule` returns UTC instants for category-default path; `planningTaskWithAutoSchedule` + `profileDisplayWallsFromAutoSchedule`.
* **`planning_view.dart`:** [shipped] Default plan times sheet shows profile TZ notice + `09:00 · NY` rows; edit sheet with profile/fixed timezone picker.
* **`wall_clock.dart` / `timezone_settings.dart`:** [shipped] `wallClockToUtcForIanaId`, `kCategoryDefaultTimezoneOptions`.

## [2026-06-15] - P0 Time mode TZ placement + sane hour scale + bottom footer [shipped]
* **`plan_service.dart`:** [shipped] `projectPlanForTimeMode()` requires `startUtcInstant` only (rejects stale `startTime`/`dateKey` wall fallback); offline cache persists/parses `start_time` ISO; `TIME_TZ_PROJECT` adds `startMin`/`endMin`.
* **`planning_view.dart`:** [shipped] Fixed hour height = `planTimeCardMeasureHeight() * 1.5` clamped 120–160px (removed shortest-task 40px floor + 560px cap); `TIME_DURATION_LAYOUT` logs `profileTz`/`wallStart`/`wallEnd`.
* **`plan_time_task_card.dart`:** [shipped] `timelineFillHeight` + `anchorFooterBottom` pins progress/breadcrumb/time to card bottom in duration blocks; `PlanCardSurface.timeline` for embedded blocks.

## [2026-06-15] - P0 Time mode duration-true layout + profile TZ projection [shipped]
* **`plan_service.dart`:** [shipped] `TimeModeProjectedPlan` adds `durationMinutes`, `planId`, profile wall aliases; `TIME_TZ_PROJECT` log; `logTimeTzProjectForTimeMode`.
* **`planning_view.dart`:** [shipped] Replaced rubber/fixed-height layout with `_TimelineDurationGrid` (linear `pxPerMinute`, height = duration); placement/labels/filter/resize/drag/now-line all use `TimeModeProjectedPlan`; now badge in left rail, line above cards in canvas; auto-scroll to now on profile-today.

## [2026-06-15] - Restore Time mode current-time line [shipped]
* **`planning_view.dart`:** [shipped] Profile-today gate via `getProjectedTodayDateKey()`; `_PlanningTimelineNowLineOverlay` renders above cards (outer Stack, `IgnorePointer`, green `scheme.primary`); minute tick + `timeUpdates`; y from `grid.yForMinutesFromRangeStart` (rubber scale).

## [2026-06-15] - P0 Time mode card clipping fix [shipped]
* **`plan_time_task_card.dart`:** [shipped] `planTimeCardMeasureHeight()` computes full intrinsic height (title row includes 33px menu slot → 106px); `planTimeCardTimelineAllocatedHeight()` +2px border allowance; explicit `titleRowHeight` SizedBox; footer right safe pad 6px.
* **`planning_view.dart`:** [shipped] Rubber grid + `Positioned` use `planTimeCardTimelineAllocatedHeight`; removed timeline `ClipRRect` anti-alias clip; debounced `TIME_CARD_CONSTRAINTS` / `TIME_HOUR_ROW_METRICS` logs.

## [2026-06-15] - Footer time safe area + clear recurring icon [shipped]
* **`plan_time_task_card.dart`:** [shipped] Footer time cluster `mainAxisSize: min`, no ellipsis on time, 4px right safe pad; breadcrumbs ellipsize first. Recurring → `Icons.autorenew_rounded` 15px after title (5px gap).

## [2026-06-15] - Larger play triangle + inline recurring glyph [shipped]
* **`plan_time_task_card.dart`:** [shipped] Play glyph 22×24px filled rounded triangle (4px corners) in 32px slot; `_PlanCardRecurringGlyph` circular dual-arc icon inline after title (5px gap).

## [2026-06-15] - CardPlan alignment, filled play, progress pill [shipped]
* **`plan_time_task_card.dart`:** [shipped] Completed cards keep geometry — removed persistent `Transform.scale`, reserved play slot when done; title top aligned with checkbox (`titleTopInset=0`, `TextHeightBehavior`); tighter shared spacing (90px ref); 3px pill progress track+fill; filled rounded-corner play triangle (`PaintingStyle.fill`).

## [2026-06-15] - Time mode CardPlan visual parity [shipped]
* **`plan_time_task_card.dart`:** [shipped] Timeline uses same list CardPlan path (`PlanCardSurface.list`); capsule progress bar (3px, rounded ends); play icon triangle with rounded vertices via stroke-join (no rounded outer button).
* **`planning_view.dart`:** [shipped] Timeline cards `left:0/right:0` + symmetric 8px inset + `ClipRRect` — identical horizontal alignment, no edge protrusion.

## [2026-06-15] - P0 final CardPlan geometry + Category reorder [shipped]
* **`plan_time_task_card.dart`:** [shipped] Figma CardPlan_Medium constants — 95px ref height, pad 12/10, 1px progress bar, fixed tags/progress slots (no data-dependent height); `tagsToProgressGap` ≈56px anchor.
* **`planning_view.dart`:** [shipped] Category mode per-bucket `ReorderableListView` + `_onCategoryBucketReorder` → `persistPlanningTaskOrder`.

## [2026-06-15] - Plan reorder persistence (Tags / Custom) [shipped]
* **`plan_service.dart`:** [shipped] `persistPlanningTaskOrder` applies optimistic cache first; `_persistPlanningTaskOrdersBulkNow` PATCHes `{order}` via `_patchPlanUpdateNetworkPhase` (15-char PB id, plan outbox on retriable failure); baseline diff uses `t.order` not list index; skips `virt-`/`optimistic-`; `PLAN_REORDER_*` logs + rollback on total failure.
* **`planning_view.dart`:** [shipped] `_commitPlanningReorder` / `_planCanReorderTask`; Tags + Custom drag wired to Brain persist path (no stale `_dragOrder`-only UI).

## [2026-06-15] - Plan card completion moment before reorder [shipped]
* **`planning_view.dart`:** [shipped] `_planCompletionHoldKeys` delays sort/reorder **250ms** after check while optimistic `isDone` updates immediately; `_sortTreatAsDone` + `_PlanCardReorderSettle` slide settle on release; rollback cancels hold.
* **`plan_time_task_card.dart`:** [shipped] Staged completion feel — checkbox pulse/scale, `AnimatedDefaultTextStyle` strike-through, card opacity/scale settle (~260ms).

## [2026-06-15] - P0 Plan card repair: one shared compact card + rubber Time grid [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed `_PlanCardVerticalSpacing.timeline`, `pinFooter`, and `heightPx` visual branches; single `_PlanCardVerticalSpacing.shared` (top 9, title→tags 5, tags empty 4, progress gap 6, bar 2px, footer gap 6, bottom 8); `refHeightMedium` 90; `planTimeCardMeasureHeight()` for layout; Time mode uses same medium CardPlan as list.
* **`planning_view.dart`:** [shipped] `_TimelineRubberGrid` — per-hour `max(80px, content)` with iterative card stack + cascade; drag/resize/now-line Y↔minutes via rubber map; interaction wrapper unchanged; cards sized by intrinsic measure not duration strips.

## [2026-06-15] - Time mode TZ placement + drag restore [shipped]
* **`plan_service.dart`:** [shipped] `TimeModeProjectedPlan` + `projectPlanForTimeMode()` — UTC→profile wall for labels/placement/filter; `_coalescePlanningTaskWallUtcFields` prefers `startUtcInstant`; offline day cache stores `start_utc`/`end_utc`; `TIME_MODE_PROJECT` logs.
* **`planning_view.dart`:** [shipped] Layout/filter/drag use projected wall times; `TIME_MODE_LAYOUT`/`TIME_MODE_RAIL` logs; pointer-based move zone + early scroll lock restores web drag.
* **`global_app_header.dart`:** [shipped] Profile timezone short label (NY/MSK/UTC±N) beside live clock.

## [2026-06-15] - Time mode card compact vertical rhythm [shipped]
* **`plan_time_task_card.dart`:** [shipped] `_PlanCardVerticalSpacing.timeline` — top 6 / bottom 8, title→tags 6, tags slot 22, progress slot 16, progress→footer 6; removed timeline `Spacer` that pinned footer to card bottom; content top-aligned in timeline blocks.
* **`planning_view.dart`:** [shipped] Min timeline visual card height **88px** (was 108).

## [2026-06-15] - P0 Plan card invariant layout (fixed slots) [shipped]
* **`plan_time_task_card.dart`:** [shipped] Medium/large Plan cards use `_PlanCardInvariantBody` with fixed slots (title, tags 28px, progress 19px, footer 6px gap); `_PlanCardProgressSlot` always renders neutral track + reserved actual-time row; removed data-driven `showFooterRow` / `showProgressTrack` / `_PlanCardFooterSeparator` branches; medium/large share `_PlanCardRailShell`.

## [2026-06-15] - P0 Time mode visual rebase: full Plan cards on timeline [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed `_TimelinePlanCardMicro` and `_TimelinePlanCardCompactTimeline` one-line strip layouts; timeline uses CardPlan medium/large only; `planTimeCardDensityForBlock` returns medium (&lt;130px / &lt;60min) or large; timeline always shows progress separator + footer; subtler selected border (1.25px); watermark hidden only on short medium blocks (&lt;130px).
* **`planning_view.dart`:** [shipped] Min visual card height **108px** (matches CardPlan_Medium); 4px cascade gap; fixed 80px/hour scale; sequential stack when min height exceeds time-proportional slot — 5-min snap/duration data unchanged.

## [2026-06-15] - Plan list card footer consistency + spacing [shipped]
* **`plan_time_task_card.dart`:** [shipped] List/calendar cards always use medium layout with footer row; removed fixed 71px inner height that clipped breadcrumbs/time; progress separator always shows for plan list cards; footer bottom pad 10px, separator gap 6px; planned time from wall fields when label empty.

## [2026-06-15] - Time mode: revert shortest-task zoom; micro layout at fixed scale [shipped]
* **`planning_view.dart`:** [shipped] Removed dynamic `hourHeight` from shortest visible plan (was up to 720px/h); fixed **80px/hour** scale; short blocks use **38px min layout height** + sequential visual push (duration unchanged).
* **`plan_time_task_card.dart`:** [shipped] Micro one-line row ~38–44px with full time label; desktop wide row adds inline tags/category chip; density thresholds 45/70/110px.

## [2026-06-15] - Governing docs sync (category relations, Time mode, tag duration) [shipped]
* **Docs-only:** Aligned `DATA_MAP.md`, `POCKETBASE_MANIFEST.md`, `ARCHITECTURE.md`, `UX_CONTRACT.md`, `DESIGN_SYSTEM.md`, `AI_CONTEXT.md`, `CLAUDE.md`, `ROADMAP.md`, `APP_STRUCTURE.md` with shipped fixes.
* **Record category law (final):** `records.category_id` and `records.category_link` are PB relations → `categories.id` (15-char); business slug only in `categories.category_id` / Brain cache — never in record API payloads.
* **Supersedes:** Earlier [wip] sync-banner / category-duality doc wording; real fix is relation-id normalization in `category_service.dart` / `record_service.dart` (see 2026-06-14 changelog).

## [2026-06-15] - Time mode UX: 5-min snap, micro cards, timeline scale, resize handles [shipped]
* **`planning_day_start_prefs.dart` / `plan_service.dart`:** [shipped] Timeline snap + min duration 5 minutes (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`).
* **`plan_time_task_card.dart`:** [shipped] Height-based density tiers (micro/compact/medium/large); `_TimelinePlanCardMicro` + `_TimelinePlanCardCompactTimeline` for short blocks; footer/progress/watermark suppressed on micro/compact timeline; medium hides tags when block &lt;104px.
* **`planning_view.dart`:** [shipped] Dynamic `hourHeight` zoom (shortest plan ≥52px desktop / 64px touch, max 720px/h); 16px resize hit zones; hover resize dots + `resizeUpDown`/`grab` cursors; floating time preview preserved.

## [2026-06-15] - Time mode now-line z-order above cards [shipped]
* **`planning_view.dart`:** [shipped] Current-time indicator moved after plan cards in timeline Stack + `IgnorePointer` so line renders above cards without blocking taps.

## [2026-06-15] - Tag default duration persistence fix [shipped]
* **`models/tag.dart` / `profile_service.dart` / `tag_default_duration_settings_view.dart`:** [shipped] Parse PB number as int/double; verify PATCH response; optimistic UI + rollback; `TAG_DURATION_*` logs; no success toast unless persisted; schema-missing error key.

## [2026-06-15] - Time mode now-line TZ + remove out-of-range bucket + wall-first create [shipped]
* **`planning_view.dart`:** [shipped] Now-line uses `applyUserOffset(getPlanetaryNow())` for position/label; `PLAN_TIME_NOW_LINE` log; removed “Другое время (вне видимого диапазона)” fallback section.
* **`plan_service.dart`:** [shipped] `_coalescePlanningTaskWallUtcFields` / `_buildPocketPlanCreateBody` / PATCH body derive UTC from profile wall (wall wins over stale `startUtcInstant`); fixed `startTime.toUtc()` on naive wall in patch fallback.

## [2026-06-15] - Time mode card footer regression fix [shipped]
* **`plan_time_task_card.dart`:** [shipped] Timeline blocks never use compact density (`planTimeCardDensityForBlock` → medium/large only); footer row + `alwaysShowTrack` progress separator restored for scheduled Time mode cards; category fallback `uncategorized`; planned time from task wall fields when label empty.

## [2026-06-15] - Plan create/edit wall-clock timezone fix [shipped]
* **`plan_service.dart` / `planning_view.dart` / `app_shell.dart`:** [shipped] Plan create paths pass profile **wall** `startTime`/`endDateTime` (not UTC); `_coalescePlanningTaskWallUtcFields` sets `startUtcInstant` once and reprojects cache; fixes 7:45 Moscow showing as 4:45; `PLAN_TIME_CREATE_WALL_TO_UTC` / `PLAN_TIME_EDIT_WALL_TO_UTC` / `PLAN_TIME_CACHE_PROJECTED` logs.

## [2026-06-15] - Plan card separator + category color + recurring time edit [shipped]
* **`plan_time_task_card.dart`:** [shipped] Removed duplicate `_PlanCardDividerLine`; progress track is sole content/footer separator; breadcrumbs/progress use `getCategoryColor` (not hardcoded blue `#609CE1`).
* **`plan_service.dart` / `app_shell.dart` / `planning_view.dart`:** [shipped] Virtual recurring occurrence edits materialize one-off row + `exception_dates` skip; series-row time PATCH preserved; `RECURRENCE_INSTANCE_*` logs.

## [2026-06-15] - Tag default plan durations + sequential auto-schedule [shipped]
* **`models/tag.dart` / `profile_service.dart` / `plan_service.dart` / `tag_default_duration_settings_view.dart` / `tag_settings_hub.dart` / `planning_view.dart`:** [shipped] `tags.default_plan_duration_minutes` per-tag settings (Durations tab); `resolveAutoPlanSchedule` sequential placement (append after last plan, snap 15m); duration rule: explicit range → tag order → 30m fallback; `evaluatePlanDayScheduleOverload` warning snack.

## [2026-06-15] - Plan card polish: hover, footer, actual time [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart`:** [shipped] Full-card `MouseRegion` hover (border/shadow/tint) while controls stay independent; footer row `minHeight` 14 + pinned bottom pad/gaps fix breadcrumb/time clipping; removed legacy subtitle date/time row (`subtitleLabel`/`onSubtitleTap`); compact actual time right-aligned above progress via `_PlanCardMetricsBlock`; planned time only in `_PlanCardFooterRow`.

## [2026-06-16] - Time mode TZ projection + desktop side nav [shipped]
* **`plan_service.dart` / `models/planning.dart` / `profile_service.dart` / `planning_view.dart`:** [shipped] Plans store UTC instants (`startUtcInstant`/`endUtcInstant`); day filter + Time mode placement project via `_profileWallFromUtc` (fixes TZ switch misplacing blocks); `reprojectAllPlansForProfileTimezone` on profile TZ change; debounced `PLAN_TIME_TZ_PROJECT` logs.
* **`app_shell.dart`:** [shipped] Desktop/web side nav (≥900px) shows Timeline/Plan/Calendar/Lists/Categories/Profile directly; More (index 6) is secondary overflow (Dev Lab admin only); mobile bottom nav unchanged.

## [2026-06-16] - Plan Play button gesture + category fallback fix [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart`:** [shipped] Play/checkbox/menu no longer blocked — body tap/drag limited to content column (`_PlanCardBodyTapShell`); timeline `_TimelinePlanInteractionBlock` move zone excludes control rail + menu via `planCardBodyGestureLeftInsetPx` / `planCardBodyGestureRightInsetPx`.
* **`category_service.dart`:** [shipped] `_resolveColdStartRecordCategoryId` falls back to default/leaf when plan UI category is concrete but missing PB relation id — Play no longer aborts before optimistic Highlander shadow.

## [2026-06-16] - Record outbox highlander_start category relation fix [shipped]
* **`category_service.dart` / `record_service.dart`:** [shipped] PocketBase records POST/PATCH now send 15-char `categories.id` in both `category_id` and `category_link` (was business slug → `validation_missing_rel_records` 400); `_normalizeRecordCategoryFieldsForPbApi` with cache/default/fallback repair + `RECORD_*` diagnostics; outbox replay pre-sanitizes/drops unmappable rows; `_lastRecordCreateFailureHttpCode` so `SYNC_FLUSH_FAIL` reports actual HTTP 400 not 500.

## [2026-06-16] - Sync banner empty-outbox invariant [wip]
* **`offline_sync_state.dart` / `app_shell.dart`:** [wip] Red sync banner requires `hasBlockingSyncError` (pendingCount>0 && lastError); stale lastError with empty outbox suppressed via `SYNC_STALE_ERROR_SUPPRESSED`; `ensureBannerInvariant()` on every banner build.

## [2026-06-16] - Sync banner diagnostics + stale state fix v2 [wip]
* **`offline_sync_state.dart` / `db_core.dart` / `app_shell.dart` / `main.dart`:** [wip] Root cause: `debugPrint` silent on release web + boot `unawaited(flush)` race; `print`-based `SYNC_BANNER_VISIBLE` / `TAP_RETRY` / `AFTER_RETRY` / `SYNC_BOOTSTRAP`; `bootstrapFromOutboxes()` clears stale in-memory `lastError` when both outboxes empty; await flush on `loadInitialData`; banner wired to canonical `DatabaseService.instance.offlineSync` only.

## [2026-06-16] - Sync error banner stabilization [wip]
* **`offline_sync_state.dart` / `db_core.dart` / `record_service.dart` / `plan_service.dart` / `app_shell.dart`:** [wip] Fix sticky red sync banner when outboxes drain but `lastError` lingered — `reconcileAfterDrain()` after flush + boot refresh; debounced `SYNC_FLUSH_FAIL` / `SYNC_BANNER_ERROR` console logs; stale outbox rows without cache drop safely; unresolved PB id logs `resolve_failed` without blocking unrelated sync.

## [2026-06-15] - Unified PlanTimeTaskCard across all Plan modes [shipped]
* **`plan_time_task_card.dart` / `planning_view.dart` / `calendar_view.dart`:** [shipped] One CardPlan visual system via `PlanCardSurface` (`list` / `timeline` / `calendar`) — Category/Tags/Custom/Time list rows + Calendar day list use `PlanTimeTaskCard`; list intrinsic min-heights (`planTimeCardDensityForList` / `planTimeCardListMinHeight`); preserved checkbox/play/menu/tap-edit/long-press/subtitle-date callbacks; web hover on card border/shadow + control buttons.

## [2026-06-15] - Plan tab list cards visibility regression [shipped]
* **`planning_view.dart` (`_buildListPlanningCard`):** [shipped] Fix zero-height plan rows in Category/Tags/Custom sort modes — superseded by unified `PlanTimeTaskCard` list surface.

## [2026-06-15] - CardPlan_Small/Medium/Large Figma geometry pass [wip]
* **`plan_time_task_card.dart`:** [wip] Rebuilt `PlanTimeTaskCard` from recalculated Figma MCP metadata (328×54/95/147) — Small inline checkbox+play (x=12/48, content x=84); Medium/Large vertical 32px rail (content x=56); 1px divider + footer span full content width; rounded-triangle play + thin menu icon (33×33); watermark at Figma positions with wide-card scale; density thresholds Small &lt;59 / Medium 59–120 / Large ≥121.

## [2026-06-15] - CardPlan visual redesign (Planning Time + Calendar rows) [wip]
* **`plan_time_task_card.dart` / `planning_view.dart` / `calendar_view.dart`:** [wip] Canonical `PlanTimeTaskCard` (Small/Medium/Large densities per `design/CardPlan *.png`) — white surface, soft border/shadow, left control rail, unified text column, repeat inline with title, circular menu top-right, category watermark (4–8% opacity); Planning Time timeline blocks and Calendar focused-day rows use shared card; timeline gestures/scale/cascade unchanged.

## [2026-06-16] - Calendar full-screen + desktop side nav [wip]
* **`calendar_view.dart` / `shell_adaptive.dart` / `app_shell.dart`:** [wip] Calendar browsing state fills content area (month grid + week planner columns with event pills); focused-day state condenses calendar and shows task list; collapse via close/up controls; desktop ≥900px uses 200px left nav rail (Timeline/Plan/Calendar/Lists/More), bottom nav hidden on wide web.

## [2026-06-15] - Planning Time layout + Calendar screen [wip]
* **`planning_view.dart`:** [wip] Time-mode gesture arbitration — short tap opens edit via `_TimelinePlanInteractionBlock.onBodyTap`; touch long-press move (desktop/web keeps immediate drag); tap suppressed after drag/resize; timeline cards omit select-mode long-press; dynamic `_timelineHourHeightPx` from shortest scheduled duration; proportional block heights; exact-time insert/cascade (no 15-min gap); minimal one-row card layout (checkbox + play + title + time + menu).
* **`calendar_view.dart` / `plan_service.dart` / `app_shell.dart`:** [wip] Calendar tab — month grid + compact week strip, month/week toggle, category task indicators (+N), selected-day scheduled task list via `planningStream`, stays on Calendar tab (no jump to Timeline); `planningTasksGroupedByWallDayForRange` + `planningRefreshEvents` for indicators.

## [2026-06-15] - Planning Time resize handles [wip]
* **`planning_view.dart` / `planning_day_start_prefs.dart`:** [wip] Time-mode scheduled non-recurring plan blocks expose subtle top/bottom resize edges (12px zones, hover grip) that preview start/end changes with live `09:00 – 10:30 · 1h 30m` labels, 15-minute snap/min duration (`timelineMinDurationMinutes`), day-bound clamps, scroll lock + edge auto-scroll; commit reuses `applyOptimisticPlanningTask` + async `updatePlanningTask`; whole-card move drag (handle + body) unchanged.

## [2026-06-15] - Planning Time timeline, parser UX, drag, auto-recat persistence [shipped]
* **`planning_view.dart` / `planning_day_start_prefs.dart`:** [shipped] Planning “Время / Time” mode is a proportional vertical day timeline (hour rail, duration-sized blocks, overlap lanes, current-time line, empty-slot quick-add); non-recurring scheduled cards drag vertically via left handle with 15-minute snap (`timelineSnapMinutes`), live time-range label, placeholder ghost, scroll lock, edge auto-scroll; drop preserves duration through `applyOptimisticPlanningTask` + async `updatePlanningTask`.
* **`smart_input_parser.dart` / `planning_view.dart` / `plan_service.dart` / `shared_widgets.dart`:** [shipped] Smart time parsing infers schedule metadata but preserves user-visible/saved title text (`preservedTitleFromRaw`); edit-sheet `onChanged` no longer mutates `TextEditingController` while typing.
* **`category_service.dart` / `record_service.dart` / `plan_service.dart`:** [shipped] Title-change auto-recategorization persistence: record PATCH/POST sends both `category_id` + `category_link`; Play/start-from-plan resolves freshest Brain plan category (`resolveCurrentPlanCategoryForRecordStart`) before record create.

## [2026-06-15] - V7H Card Foundation [wip]
* **`life_card.dart` / `component_lab_view.dart`:** [wip] Added canonical `LifeCard` + `AppTaskCard` card foundation with parameterized normal/selected/completed/disabled/active states, compact/regular density, task/backlog/timeline types, and mock-only Component Lab examples; production cards remain unmigrated.
* **`docs/DESIGN_SYSTEM.md` / `docs/reports/DESIGN_SYSTEM_INVENTORY.md`:** [wip] Documented Figma `Card` → Flutter `LifeCard` / `AppTaskCard` mapping, supported variants, metadata parameters, and the explicit V7H no-production-migration boundary.

## [2026-06-15] - Profile password reset action [shipped]
* **`profile_view.dart` / `auth_bridge.dart` / `dictionary.dart`:** [shipped] Profile now shows a Security section with a localized email-based password reset action that uses the active PocketBase auth email, calls `AuthBridge.requestPasswordReset`, disables while sending, handles missing emails, and surfaces success/failure through one snackbar.

## [2026-06-15] - Plan create duplicate reconciliation [shipped]
* **`plan_service.dart`:** [shipped] Plan create now reconciles optimistic and server rows by stable business `plan_id`: `_upsertPlanInUserCache` replaces matching optimistic cache entries, `_dedupePlanningTasksByBusinessId` guards `planningStream` emits, `clearOptimisticPlanningForPlanRow` purges overlay+cache by `optimistic-{plan_id}`, and plans realtime clears the optimistic overlay when the confirmed row arrives.
* **`planning_view.dart`:** [shipped] Removed redundant UI-layer optimistic plan rows on quick-add/Smart Plan inject (Brain optimistic stream is sole source); added `_planQuickAddInFlight` guard and `plan_id`-aware merge fallback.

## [2026-06-13] - Password reset lookup and messaging [shipped]
* **`auth_bridge.dart` / `auth_view.dart` / `dictionary.dart`:** [shipped] Forgot password now calls the app-owned reset endpoint, shows explicit sent/not-registered/mail-unavailable messages, and offers a Register action when the email is not found.
* **`pb_hooks/auth.request_password_reset.pb.js` / `pb_config.dart` / `docs/DEPLOY.md` / `docs/POCKETBASE_MANIFEST.md`:** [shipped] Added `POST /api/auth/request-password-reset` so PocketBase checks `profiles.email` server-side and sends reset mail without exposing profile search or private fields; documented SMTP/template/action URL diagnostics.

## [2026-06-12] - Mid-session auth repair + PocketBase readiness docs [shipped]
* **`main.dart` / `offline_sync_state.dart`:** [shipped] The root auth gate now listens for mid-session `offlineSync.authPaused` from 401/403 record/plan mutations, routes to the login/session repair screen, marks syncing inactive while auth is paused, keeps outbox mutations paused, and resumes through the shared post-auth bootstrap after login.
* **`AndroidManifest.xml` / `constants.dart` / `docs/DEPLOY.md`:** [shipped] Removed Supabase-era Android callback schemes/constants and documented PocketBase `profiles` OAuth provider discovery, `/api/oauth2-redirect` setup, Android real-device verification status, and password-reset SMTP/template requirements.

## [2026-06-12] - Plan-link suggestion toggle persistence [shipped]
* **`planning_view.dart`:** [shipped] `_PlanRecordLinkSuggestionSettingsBlock` owns record-link suggestion prefs inside the Planning settings sheet so the master switch and mode selector rebuild and persist via `plans_record_link_suggestions_enabled` / `plans_record_link_suggestion_mode` (fixes frozen modal header that blocked turning suggestions off).

## [2026-06-12] - Auth gate and account recovery [shipped]
* **`main.dart` / `auth_bridge.dart` / `profile_service.dart`:** [shipped] Cold start and post-login now share one PocketBase auth bootstrap path; invalid profile/session verification clears unsafe auth state and surfaces login/session repair instead of falling back to cached profile data.
* **`auth_view.dart` / `dictionary.dart`:** [shipped] Auth screen shows configured Google/Yandex fast-login before email fallback, handles OAuth cancellation calmly, and keeps neutral password-reset messaging.
* **`docs/DEPLOY.md`:** [shipped] Documented required PocketBase auth, OAuth, SMTP, reset, and verification admin setup.

## [2026-06-12] - Biometric app-lock + plan-link suggestions [shipped]
* **`auth_bridge.dart` / `main.dart` / `auth_view.dart` / `profile_view.dart`:** [shipped] Removed stored-password biometric quick login; biometrics are now a real Android/iOS app-lock only, hidden on web/unavailable devices, with a 7-day local inactivity threshold.
* **`app_shell.dart` / `planning_view.dart` / `dictionary.dart`:** [shipped] Record-to-plan suggestions are device-local, non-blocking after record creation, configurable from Planning settings, and can be turned off from the suggestion snackbar; manual edit-sheet link/unlink remains available.

## [2026-06-12] - Tag pill text vertical alignment [shipped]
* **`chip_component.dart`:** [shipped] Letter-chip pills use fixed height + horizontal-only padding with `height: 1.0`, `StrutStyle`, and `TextHeightBehavior` so label text is optically centered; selected/unselected inner content stays identical.

## [2026-06-12] - Selected tag ring shrink-wrap [shipped]
* **`chip_component.dart`:** [shipped] Pill-mode `CategoryChip` and `_TagSelectionRing` use `Row(mainAxisSize: min)` so selected ring shrink-wraps the visible pill instead of expanding to stretched parent width.

## [2026-06-12] - Design Lab copy + interactive tag selected state [shipped]
* **`component_lab_view.dart`:** [shipped] Design Lab labels/spec text are selectable/copyable with lab-only `SelectableText`; chip examples now show compact, interactive unselected, interactive selected, and overflow scroll strip states.
* **`chip_component.dart`:** [shipped] Interactive tag selected state is now normal chip border + 2px transparent gap + 2px brand border; base pill content stays centered and selected/unselected states do not shift inner text.
* **`shared_widgets.dart` / `planning_view.dart`:** [shipped] Tag strip rows fit the 31px base interactive pill plus visible selected ring without changing scroll behavior.

## [2026-06-12] - Edit sheet tag strip scroll hotfix [shipped]
* **`chip_component.dart`:** [shipped] `TagQuickPickStrip` horizontal scroll fix — removed `shrinkWrap`, added `ScrollController`, `_TagStripScrollBehavior` (mouse/trackpad/touch drag), wheel-to-horizontal `PointerScrollEvent`; interactive pills ~31px (was 40px); compact cards ~22px.
* **`shared_widgets.dart` / `planning_view.dart` / `component_lab_view.dart`:** [shipped] edit-sheet tag row uses finite strip height; lab overflow strip with 8 tags.

## [2026-06-12] - P0 startup sync + tag pill regressions [shipped]
* **`db_core.dart` / `plan_service.dart` / `record_service.dart`:** [shipped] P0 foreground/resume refresh via `refreshForegroundData()` force-fetches records + today's plans and pumps planning streams; debounced plan cache refresh now re-emits streams; duplicate primary running records reconcile to newest-only (optimistic stop + existing `stopRecordByDocId` for older rows).
* **`chip_component.dart` / `shared_widgets.dart` / `component_lab_view.dart` / `timeline_view.dart`:** [shipped] Tag pill regression fix: stadium compact card pills vs larger interactive picker pills, horizontal scroll strip restored, removed invisible outer selection padding; timeline running UI uses canonical primary id only.

## [2026-06-12] - V7G.1 canonical state views [shipped]
* **`lists_view.dart` / `tag_manager_page.dart` / `plan_vs_fact_tab.dart` / `planning_view.dart` / `calendar_view.dart`:** [shipped] V7G.1 safely migrated simple visual loading/empty/error surfaces to `AppLoading` / `AppEmptyState` / `AppErrorState` where applicable; auth, boot, sync, voice, sheet, profile-save, timer/timeline-adjacent, and richer CTA state views remain documented legacy.

## [2026-06-11] - F2C default plan times selector wiring [shipped]
* **`app_icon_button.dart` / `category_list_view.dart` / `DESIGN_SYSTEM_INVENTORY.md`:** [shipped] V7F.2 safely migrated the Categories AppBar layout-toggle and add-category icon actions to `AppIconButton`; planning, timeline, selection, voice, tree, and destructive icon controls remain documented legacy.
* **`app_icon_button.dart` / `component_lab_view.dart` / `DESIGN_SYSTEM.md` / `DESIGN_SYSTEM_INVENTORY.md`:** [shipped] V7F Icon Button foundation added `AppIconButton` for Figma `Icon Button`, labeled Component Lab examples, and raw `IconButton` audit docs; no production icon-button migration yet.
* **`component_lab_view.dart` / `DESIGN_SYSTEM.md`:** [shipped] Component Lab examples now render lab-only labels with Figma name, Flutter mapping, variant, size, and state metadata for review without changing production UI.
* **`app_button.dart` / `component_lab_view.dart` / `DESIGN_SYSTEM.md`:** [shipped] V7E Action Buttons started: `AppButton` remains canonical and now supports Button Primary/Secondary/Danger/Ghost/Outlined variants, S/M/L sizing, loading/disabled/icon/full-width states, with Component Lab acceptance examples and inventory guardrails.
* **`profile_service.dart` / `app_shell.dart` / `more_view.dart`:** [wip] Admin Component Lab gate now fetches a fresh `profiles` row before falling back to cached auth data and adds temporary `[ADMIN_FLAG]` diagnostics plus `Admin flag: true/false` More markers while verifying `profiles.is_admin`.
* **`UX_CONTRACT.md` / `DESIGN_SYSTEM.md` / `component_lab_view.dart`:** [wip] V3/V7 foundation started: behavior/design-system docs added, UI inventory report created, `profiles.is_admin` parsed read-only into settings, and admin-only Component Lab skeleton exposed from More with mock-only canonical component samples.
* **`planning_view.dart`:** [shipped] Default plan time category search now opens with all category options visible, keeps path/name filtering case-insensitive while typing, and restores the full option list when the query is cleared.
* **`planning_view.dart`:** [shipped] Confirmed Plans gear → `_showPlanningSettingsSheet` → `_showDefaultPlanTimesSheet` is the sole default-times entry; added temporary `F2C selector UI` sanity marker at sheet bottom for web/APK verification after push to `main`.

## [2026-06-10] - F2A Plans UI polish slice [shipped]
* **`planning_view.dart` / `dictionary.dart`:** [shipped] F2C default plan times UI now uses a compact category selector with searchable picker, selected-category own/inherited status, set/clear-own actions, and a small configured-categories list instead of rendering the full category tree by default.
* **`category_service.dart` / `plan_service.dart` / `planning_view.dart`:** [shipped] F2C category default plan times accepted: category rows read optional `default_plan_time` (`HH:mm`), Plans settings exposes per-category set/clear controls with parent inheritance, and new scheduled plans without explicit parsed time apply the effective category default.
* **`app_shell.dart` / `android/.../styles.xml` / `chip_component.dart` / `shared_widgets.dart`:** Emergency Android F2A UI fix: removed duplicate native `Life OS` title bar (`Theme.Black.NoTitleBar`), collapsed to one compact `AppBar` with `Life OS` + date/time, picker tag chips tap only the visible chip (no outer active frame), and Timeline/Planning edit sheets share `AppEditSheetTimeButton` with full start/end labels.
* **`app_shell.dart` / `compact_nav_controls.dart` / `chip_component.dart` / `planning_view.dart` / `shared_widgets.dart`:** Final Android F2A visual correction: shell owns one compact black `Life OS` + date/time header, compact tabs/segments center labels without scaling, picker tags use a large explicit chip variant with outer selection outline, recurring plan icons attach to the title text, and start/end time buttons restore full EN/RU labels.
* **`app_shell.dart` / `global_app_header.dart` / `planning_view.dart` / `shared_widgets.dart` / `chip_component.dart`:** Corrected Android F2A visual regressions after device review: restored a readable dark compact top header/status bar, kept plan-card tags to one horizontal row, moved picker selection outlines onto the visible chip, restored the fourth dated-plan edit tab with `Repeat` separate from `Parallel plans`, and made end-time buttons fixed-height.
* **`compact_nav_controls.dart` / `global_app_header.dart` / `planning_view.dart` / `shared_widgets.dart` / `chip_component.dart`:** Android F2A regression polish: fixed tab/segment height with one-line ellipsis (no per-tab font shrink), enlarged edit-sheet tag visuals, moved repeat status directly into the Planning card title row, relabeled dated-plan recurrence UI as `Repeat`, and collapsed main Timeline/Plans/Lists headers to compact date/time chrome.
* **`compact_nav_controls.dart` / `planning_view.dart` / `timeline_view.dart` / `shared_widgets.dart`:** Added compact 44px tab/segment styling, moved `_PlanningTaskCard` play into the leading action column (hidden when done/selecting), and added repeat icon metadata for non-empty `rrule` plans. `docs/ROADMAP.md` marks F2A only; F2 remains open.

## [2026-06-10] - Docs cleanup: DATA_MAP and roadmap status [shipped]
* **`docs/DATA_MAP.md` / `docs/ROADMAP.md`:** Removed accidental assistant wrapper text from `DATA_MAP.md` and synced roadmap wording so O1, V1, and F1 are shipped with F2 Plans next.

## [2026-06-10] - CLAUDE.md F1 status sync [shipped]
* **`CLAUDE.md`:** F1 status synced after Lists shipped — top velocity line now points to F2 Plans, and the F1 table marks list tags/export/active chip/alignment/no-play work as shipped.

## [2026-06-10] - Docs sync: O1 local sync architecture [shipped]
* **`docs/APP_STRUCTURE.md` / `docs/ARCHITECTURE.md`:** Synced governing docs with shipped O1 local mutation queues, sync state, drain triggers, auth-paused behavior, and `_OfflineSyncStatusBar` anchors.

## [2026-06-10] - F1 Lists feature completion [shipped]
* **`lists_view.dart`:** F1 audit preserved existing list-tag filter/export/no-play behavior; active list tag now renders before “All tags”, and manual category chip mode uses the same scroll-to-start controller as normal mode.
* **`plan_service.dart` / `profile_service.dart`:** Plan/list tag hydration now uses a combined plan+list tag catalog for plain `tags_link` cache/replay paths, preserving `domain: list` tags through offline create/update sync and cache merges.
* **`docs/ROADMAP.md`:** F1 marked shipped with all five checklist items completed.

## [2026-06-10] - V1 CLAUDE.md nav map (post-O1 local sync) [shipped]
* **`CLAUDE.md`:** New **Local sync & offline-first** section — `record_mutation_outbox.dart`, `plan_mutation_outbox.dart`, `offline_sync_state.dart`, `sync_manager.dart`; symbols `flushPendingLocalMutations`, `flushPendingRecordMutations`, `flushPendingPlanMutations`, `resumeAfterAuthIfNeeded`, `_OfflineSyncStatusBar`; O1 shipped / F1 unblocked noted; Iron Laws updated for enqueue-on-retriable-failure.
* **`docs/ROADMAP.md`:** V1 marked shipped in execution order.

## [2026-06-09] - O1.4 offline-first audit & polish [shipped]
* **`offline_sync_state.dart`:** Banner quiet only when fully synced; online-with-pending shows “%s pending sync”; `resumeAfterAuthIfNeeded()` unblocks flush after re-auth.
* **`db_core.dart`:** `flushPendingLocalMutations` resumes sync when `authStore.isValid`; boot + app-resume + backoff-init paths refresh pending count and attempt flush.
* **`app_shell.dart`:** Distinct auth-paused banner string; online/offline pending labels split.
* **`docs/ROADMAP.md`:** O1.1–O1.4 marked shipped; restart/optimistic limitations documented; **F1 unblocked**.

## [2026-06-09] - O1.3 offline-first: Planning + Lists CRUD outbox [shipped]
* **`plan_mutation_outbox.dart`:** Generic plan queue (`plan_create`, `plan_update`, `plan_delete`) with O1 schema, coalescing (delete drops pending create/update for same `plan_id`), and auto-migration from legacy `plan_create_outbox_v1`.
* **`plan_service.dart`:** `addPlanningTask`, `updatePlanningTask`, `deletePlanningTasksBulk` keep optimistic UI; retriable failures enqueue to prefs; `flushPendingPlanMutations` replays on reconnect; `clearOptimisticPlanningForPlanRow('optimistic-…')` cancels never-synced pending creates.
* **Done-toggle:** unchanged UI in `lists_view.dart` / `planning_view.dart` — `updatePlanningTask(isDone:)` now returns `true` when queued so optimistic toggle is not rolled back offline.

## [2026-06-09] - O1.2 offline-first: record edit/delete outbox [shipped]
* **`record_mutation_outbox.dart`:** Added `record_update` and `record_delete` kinds with `coalesceQueue` — delete drops prior pending ops for same `businessId`; updates merge payloads to avoid duplicate PATCHes.
* **`record_service.dart`:** `updateRecord` / `patchRecord` apply cache edit immediately then async `_patchRecordUpdateNetworkPhase`; retriable failures enqueue update and keep optimistic row. `deleteRecordByDocId` keeps optimistic tombstone on failure via `_deleteRecordNetworkPhase` + delete outbox; 404 on replay = successful purge.
* **Replay:** `flushPendingRecordMutations` resolves PB id from stored `pocketBaseId`, cache, or server lookup before PATCH/DELETE.

## [2026-06-09] - O1 offline-first slice: record start/stop outbox [shipped]
* **`lib/data/local_sync/record_mutation_outbox.dart`:** SharedPreferences queue with O1 schema (`operation_id`, `collection`, `operation_type`, `business_id`, `pocketBaseId`, `payload`, `created_at`, `retry_count`, `last_error`, `sync_status`) for Highlander **start** and **stop** mutations.
* **`lib/data/record_service.dart`:** Primary `writeRecord` Highlander path and `stopRecordByDocId` keep optimistic UI on network failure — enqueue instead of rollback; `flushPendingRecordMutations()` replays on reconnect via `_runHighlanderStartServerPhase` / PATCH stop.
* **`lib/data/local_sync/sync_manager.dart` + `db_core.dart`:** `flushPendingLocalMutations()` drains records + plans outboxes; connectivity probe updates `OfflineSyncController`.
* **`lib/app_shell.dart`:** Subtle global banner — offline pending, syncing, auth/sync error (tap to retry flush).
* **`docs/ROADMAP.md`:** O1 phase added as highest priority before F1.

## [2026-06-09] - Repo layout, docs hygiene, analyzer & deploy scripts [shipped]
* **Folder flatten:** Real app moved from nested `counter/counter/` to `C:\Users\nkuch\Development\Apps\counter`; old outer Flutter skeleton backed up to sibling `counter_WRAPPER_BACKUP` (not in git).
* **Root cleanup:** Reports → `docs/reports/`; prompt/archive docs → `docs/archive/`; temp zips/screenshots/logs → `Archive/root_cleanup_backup/`; manual scripts → `scripts/manual/`; dev `tool/` → `Archive/tool/`.
* **Docs:** `docs/ROADMAP.md` is the single canonical roadmap; `docs/AI_CONTEXT.md` deduplicated to a pointer; `docs/DEPLOY.md` updated for flat repo root and `update.ps1`.
* **Analyzer hygiene:** `flutter analyze` reduced from 49 to 11 info-only issues (0 errors, 0 warnings) — mechanical lint/dead-code pass; no intended behavior change.
* **Deploy:** `update.ps1` at repo root calls `scripts/manual/td.ps1`; analyze uses `--no-fatal-infos --no-fatal-warnings`; web build uses `--no-tree-shake-icons --no-wasm-dry-run` (dynamic `IconData` — proper fix tracked in `docs/ROADMAP.md` V6).

## [2026-05-01] - C1 Sync & Reactivity: tag stream gaps, category silent drop, optimistic list toggle [shipped]
* **`profile_service.dart`:** `createTagForCurrentUser` adds new tag to `_userTagsCatalogCache` and calls `notifyTagsCatalogChanged()`; `deleteTagByPocketRecordId` removes tag from cache by `pbRecordId` and notifies; `patchTagForCurrentUser` calls `notifyTagsCatalogChanged()` after server write. All three mutations now push to UI immediately without manual refresh (#16).
* **`category_service.dart`:** `_mapCategoryIdToLinkForPb` else-branch now emits `debugPrint('[CAT_MAP] category_id dropped from payload — no resolved PB row id …')` instead of silent `merged.remove('category_id')` — cold-start category drops are now visible in debug logs (#9).
* **`lists_view.dart`:** `_onListToggleDone` rewired for true optimistic UI — snapshots `_flat`, immediately replaces the toggled task in `setState`, then fires `updatePlanningTask` async; rolls back `_flat` to snapshot on PATCH failure. Removed `notifyPlanningRefresh()` call (was triggering non-optimistic network reload). Added `TextDecoration.lineThrough` style to task title `Text` when `task.isDone` (#11).
* **Confirmed clean:** `flutter analyze` 0 new errors (64 issues, all pre-existing).

## [2026-05-01] - Restored omni_date_time_picker_dialog.dart to last known good state (4676e273) — reverting all May 1 changes [shipped]

## [2026-05-01] - Fix: omni-picker _DateSectionState minimal rewrite, onPageChanged no setState [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** Previous `_DateSectionState` called `setState` inside `onPageChanged`, which triggered a `build()`. During that rebuild, `TableCalendar` received an updated `focusedDay` prop and internally called `_pageController.jumpToPage` — creating a feedback loop that caused the visible month jump. Additionally, the date text field's `TextFormField` rebuild inside `_DateSectionState.build()` added unnecessary subtree churn on every calendar interaction.
* **Fix:** Replaced `_DateSectionState` with a minimal implementation: `onPageChanged` writes `_focusedDay` directly without `setState` (no rebuild, no `didUpdateWidget` on `TableCalendar`, no jump). Removed date text field from `_DateSection` entirely — calendar is the only date input. Removed `_clampDay`, `_tryParseDateField`, `_formatDateField`, `_validateDateText`, and `_onDateTextChanged` from `_DateSectionState`. `_dateTextController` kept and updated in `onDaySelected` for state tracking. Reverted `_OmniDateTimePickerDialogState` to construct `_DateSection` / `_TimeSection` inline in `build()` (with `ValueKey`s) — the `late final Widget` field approach was unnecessary complexity. Confirmed `CupertinoDatePicker.mode: CupertinoDatePickerMode.time`, `minuteInterval: 1`.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker child widgets constructed once in initState [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `_DateSection` and `_TimeSection` were constructed as local variables inside `_OmniDateTimePickerDialogState.build()`. Even with a `ValueKey`, Flutter rebuilds child widgets from the new widget object on every `build()` call. The key only prevents element/state teardown when the widget *type and key* match — but the state was still receiving new widget instances with potentially updated props, and `_DateSectionState.initState()` runs only once, so the stable element was correct. The real issue: `build()` creating new widget objects each frame caused prop diffing through `didUpdateWidget`, which TableCalendar uses internally to drive `_pageController.jumpToPage`. Any prop difference (even a re-created callback closure) could trigger a month jump.
* **Fix:** Promoted `_DateSection` and `_TimeSection` to `late final Widget` fields on `_OmniDateTimePickerDialogState`. Initialized once in `initState()` with stable references (no new closures or widget objects ever created after that). `build()` now reads `_dateSectionWidget` / `_timeSectionWidget` directly — Flutter sees the identical widget object every frame, so `didUpdateWidget` is never called on either child. Added `super.key` to `_TimeSection` constructor to accept the key param. Confirmed `CupertinoDatePicker.minuteInterval: 1` unchanged.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker _DateSection stability key + TableCalendar fixed row height [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `_DateSection` was constructed inline in the parent `build()` without a key. On any parent `setState`, Flutter diffed it as a new widget and could reset `_DateSectionState` (losing `_selectedDay`, `_focusedDay`). Separately, `sixWeekMonthsEnforced: true` alone does not pin pixel height — `TableCalendarBase` still computes row height from `daysOfWeekHeight` defaults, causing subtle width/height shifts on month change.
* **Fix:** Added `key: const ValueKey('date_section')` to the `_DateSection(...)` call in `_OmniDateTimePickerDialogState.build()` — Flutter now preserves the existing element rather than recreating it. Added `rowHeight: 42.0` to `TableCalendar` alongside `sixWeekMonthsEnforced: true` to enforce a fixed pixel height for every row regardless of month. Removed the stale unused `theme` local variable from `_OmniDateTimePickerDialogState.build()`. Added `super.key` to `_DateSection` constructor to accept the key param.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-05-01] - Fix: omni-picker calendar → TableCalendar with isolated _focusedDay [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CalendarDatePicker` does not render neighboring-month dates — a Flutter framework limitation. The fix was to restore `TableCalendar` (already a project dependency) inside `_DateSectionState.build()`.
* **Fix:** Replaced `CalendarDatePicker` with `TableCalendar` inside `_DateSectionState` only. Added `late DateTime _focusedDay` to `_DateSectionState`, initialized to `_selectedDay` in `initState`. `_focusedDay` is updated exclusively by `onDaySelected` and `onPageChanged` — the text field path updates `_selectedDay` only, leaving the calendar's scroll position untouched. Because `_focusedDay` lives entirely inside `_DateSectionState`, time-wheel `setState` calls in `_TimeSectionState` cannot reach it (separate widget subtrees). Applied `sixWeekMonthsEnforced: true`, `outsideDaysVisible: true`, `outsideTextStyle` with dimmed alpha, `formatButtonVisible: false`, `titleCentered: true`. Public API unchanged.
* **Result:** `flutter analyze` full project: 0 errors (63 info/warnings, all pre-existing).

## [2026-05-01] - Refactor: omni-picker split into _DateSection + _TimeSection widgets [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** All state lived in one `_OmniDateTimePickerDialogState`. Time-wheel `setState` calls (`_applyTimeFromWheel`, `_syncWheelFromTypedTime`) rebuilt the entire dialog tree including the `CalendarDatePicker`, causing layout jank on every drum scroll tick. A `ValueKey` on `year-month` was force-recreating the `CalendarDatePicker` on every month navigation, destroying its internal state and causing neighboring dates to disappear. A `RepaintBoundary` was papering over the rebuild cost without fixing it.
* **Fix:** Extracted date section into `_DateSection` (`StatefulWidget`) owning `_selectedDay` and `_dateTextController`. Extracted time section into `_TimeSection` (`StatefulWidget`) owning `_hourController`, `_minuteController`, `_wheelTime`, focus nodes, and `_ignoreWheelCallback`. Parent `_OmniDateTimePickerDialogState` holds only `_selectedDay`, `_hour`, `_minute` for submit, updated via `ValueChanged<DateTime> onDateChanged` and `void Function(int, int) onTimeChanged` callbacks. Removed `ValueKey` and `RepaintBoundary` from `CalendarDatePicker`. No `_dateTextFromCalendar` flag needed — Flutter's `TextFormField.onChanged` does not fire on programmatic controller changes. `TextFormField` validators in child widgets remain part of the parent `Form` via Flutter's `InheritedWidget` mechanism, so `_formKey.currentState!.validate()` covers all fields. Public API (`showOmniDateTimePickerDialog`) unchanged.
* **Result:** `flutter analyze` full project: 0 errors (63 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker TableCalendar → CalendarDatePicker [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `TableCalendar` inside the dialog was unstable when co-hosted with `CupertinoDatePicker`. Every `setState` from the time wheel (via `_applyTimeFromWheel`) caused `TableCalendar.didUpdateWidget` to run — even with a separate `_calendarFocusedDay` guard — leading to unpredictable month jumps and layout thrash inside the dialog's `SingleChildScrollView`.
* **Fix:** Replaced `TableCalendar` with Flutter's native `CalendarDatePicker` (no external dependency). Wrapped in `RepaintBoundary` to isolate repaints from time-wheel `setState` calls. Keyed with `ValueKey<String>('year-month')` — stable within a month so day-selection doesn't recreate the widget, but correctly resets when a cross-month date is typed into the text field. Removed `_calendarFocusedDay` state entirely (was only needed for `TableCalendar`). Removed `table_calendar` import from this file (pubspec unchanged — used by `calendar_view.dart`). Simplified `_onCalendarDateChanged` back to single `DateTime` parameter.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker CupertinoDatePicker ValueKey removal [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CupertinoDatePicker` had `key: ValueKey<int>(_wheelTime.hour * 60 + _wheelTime.minute)`. The key value changes on every time-wheel tick, forcing Flutter to destroy and recreate the `CupertinoDatePicker` widget on each callback from `onDateTimeChanged`. This full widget recreation triggered a dialog-level rebuild on every drum scroll tick, which in turn caused `TableCalendar.didUpdateWidget` to run and risk a month jump.
* **Fix:** Removed the `key:` line entirely. `CupertinoDatePicker` manages its own internal scroll state via `initialDateTime`; no external key is needed. Rebuilds from `_applyTimeFromWheel → setState` now update `_wheelTime` (used only as stable reference for `_syncWheelFromTypedTime`) without recreating the drum widget.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: omni-picker month jump / jank / outside-days [shipped]
* **Root cause (`omni_date_time_picker_dialog.dart`):** `CalendarDatePicker(initialDate: _selectedDay)` was used inside `_OmniDateTimePickerDialogState`. `TableCalendarBase.didUpdateWidget` (and Flutter's `CalendarDatePicker` equivalent) jump the displayed month whenever `initialDate`/`focusedDay` changes. The Cupertino time drum fires `_applyTimeFromWheel → setState` continuously while scrolling, rebuilding the calendar widget on every tick. Because `_selectedDay` is stable during time-wheel scrolling, the month wouldn't jump from THAT — but `CalendarDatePicker` also lacks `sixWeekMonthsEnforced`, producing variable-height rebuilds that cause layout jank on every time-wheel tick. Additionally, `CalendarDatePicker` had no external `focusedDay` tracking, so navigating months and then interacting with the time field could cause a jump back to `_selectedDay`'s month.
* **Fix:** Replaced `CalendarDatePicker` with `TableCalendar` (already a project dependency). Added `late DateTime _calendarFocusedDay` state to `_OmniDateTimePickerDialogState` (initialized in `initState`, updated only by `onDaySelected` and `onPageChanged`). Time-wheel rebuilds (`_applyTimeFromWheel`, `_syncWheelFromTypedTime`) do not touch `_calendarFocusedDay`, so `TableCalendar.didUpdateWidget` sees no `focusedDay` change and never jumps. `_onCalendarDateChanged` gains optional `focusedDay` parameter; `_onDateTextChanged` also updates `_calendarFocusedDay` so typing a date in a different month correctly jumps the calendar. Applied `sixWeekMonthsEnforced: true` (constant height, eliminates jank), `outsideDaysVisible: true`, `outsideTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.35))`.
* **ValueKey status:** Confirmed absent — was removed in the April 30 fix. Not re-introduced.
* **Call sites verified (all route through `showAppDateTimePicker` → `showOmniDateTimePickerDialog` on keyboard-friendly surfaces):** `shared_widgets.dart:1102`, `:1128`, `:1309`, `:1376`, `:2210`, `:2219`; `bulk_planning_edit_sheet.dart:141`, `:158`.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: calendar month jump / jank / outside-days (round 2) [shipped]
* **Root cause confirmed (`calendar_view.dart`):** `table_calendar`'s `TableCalendarBase.didUpdateWidget` (v3.1.3, line 113) calls `_pageController.jumpToPage` / `animateToPage` whenever `_focusedDay != widget.focusedDay`. If `_CalendarViewState` is ever re-created (state disposed under memory pressure, or `IndexedStack` lifecycle edge), `initState` re-copies `widget.focusedDay` from the parent. On the next parent rebuild the parent's `_focusedDay` (stale value) differs from what `TableCalendarBase` last stored, triggering an immediate page jump.
* **Fix — Bug 1 (month jump):** Added `AutomaticKeepAliveClientMixin` to `_CalendarViewState` (`wantKeepAlive => true`, `super.build(context)` called first in `build()`). State is now aggressively kept alive; `initState` is guaranteed to run only once per session, so `widget.focusedDay` can never re-seed local `_focusedDay` after first paint. `_focusedDay` remains exclusively owned by `onPageChanged` + `onDaySelected`. No `didUpdateWidget` override — parent rebuilds do not touch local state.
* **Fix — Bug 2 (layout jank):** Added `sixWeekMonthsEnforced: true` to `TableCalendar`. `TableCalendarBase` previously calculated row count per month (4–6 rows), causing the calendar widget to resize on month transition and produce layout shifts. All months are now 6 rows, height is constant.
* **Fix — Bug 3 (adjacent month days hidden):** Added `calendarStyle: CalendarStyle(outsideDaysVisible: true, outsideTextStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.35)))`. Leading/trailing days from adjacent months are now visible with dimmed text.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fix: calendar month jump + Omni-Picker Law audit [shipped]
* **BUG (calendar_view.dart):** `CalendarView` was a `StatelessWidget` with `focusedDay` sourced from the parent (`_focusedDay` in `app_shell.dart`). Any parent `setState` (frequent from stream events) rebuilt the widget with the same stale `focusedDay` because `TableCalendar.onPageChanged` was not wired — page navigation never updated the parent. `TableCalendar` then reset its displayed month to the parent's original value. Fix: converted to `StatefulWidget` (`_CalendarViewState`), owns `_focusedDay` locally via `initState`, wired `onPageChanged: (day) => setState(() => _focusedDay = day)` and updated `onDaySelected` to also call `setState(() => _focusedDay = focused)`. Parent `app_shell.dart` unchanged.
* **Omni-Picker Law audit (Bug 2):** Full grep across the codebase for `showDatePicker`, `showTimePicker`, `showCupertinoModalPopup`, and `CalendarDatePicker`. All remaining hits are date-only exempt: `global_app_header.dart:21` (date-only header nav, keyboard), `global_app_header.dart:40` (date-only header nav, mobile `CalendarDatePicker` in dialog — closes on select), `planning_view.dart:331` (date-only reschedule, preserves task's existing time). No new violations found after previous session's `bulk_planning_edit_sheet.dart` fix.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - Bug fixes: omni picker month reset + bulk edit legacy pickers [shipped]
* **BUG (omni_date_time_picker_dialog.dart):** Removed `ValueKey<String>` from `CalendarDatePicker` (was keyed to `'${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}'`). Key change on every day tap forced full widget rebuild, resetting the displayed month back to the newly selected day. Fix: remove key entirely so Flutter reuses the widget in-place.
* **BUG (bulk_planning_edit_sheet.dart):** Replaced `showDatePicker` + hand-rolled iOS `showCupertinoModalPopup` time picker + `showTimePicker` with `showAppDateTimePicker` in both `_pickDate` and `_pickTime`. Removed `picker_entry_modes.dart` and `cupertino.dart` imports; added `shared_widgets.dart` import. `_pickDate` extracts only the date component from the returned `DateTime`; `_pickTime` extracts only the `TimeOfDay`. State shape (`_date`, `_pickedTargetTime`) unchanged.
* **Result:** `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-30] - V5.5: extract db_core.dart from database_service.dart [shipped]
* **Extraction (lib/data/db_core.dart — new, ~418 lines):** Bootstrap and lifecycle domain moved to a `part of 'database_service.dart'` file using `extension DbCoreExtension on DatabaseService`. Contains: `ensurePocketBaseReady`, `_maybeVerifyPocketBaseReachable`, health/circuit helpers (`_registerPocketBaseUnreachable`, `_clearPocketBaseConnectivityBackoff`, `_isPbCircuitWorthyFailure`, `_maybeOpenPbCircuitFromListFailure`), realtime reconnect (`ensureRecordsRealtimeBridge`, `_scheduleRecordsRealtimeReconnectAfterFailure`, `_logRecordsRealtimeSubscribeQuiet`), `_hydrateRecordsCacheFromPrefsIfEmpty`, lifecycle observer register/unregister, `clearLocalStateOnSignOut`, `setDataRegion`, `loadInitialData`, `loadInitialDataWearLite`, `_loadInner`, `_loadInnerWearLite`.
* **Result:** `database_service.dart` 1,089 → 720 lines. `db_core.dart` 418 lines (new). God Object split complete across 5 part files. `flutter analyze` full project: 0 errors (62 info/warnings, all pre-existing).

## [2026-04-29] - V5.4: extract category_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/category_service.dart — new, ~3,158 lines):** Category domain moved to a `part of 'database_service.dart'` file using `extension CategoryServiceExtension on DatabaseService`. Contains: `fetchCategories`, `_loadRulesFromNoco`, category CRUD (`addNestedCategory`, `updateCategory`), `findCategoryByFuzzyMatch`, slug helpers, stats utilities (`statsRecordsSignature`, `recordDurationSecondsWithinDayFromTimestamps`, `startTimeFromRecord`, `endTimeFromRecord`), record-query helpers (`recordsTablePk`, `isRecordMapActuallyRunning`, `_rowInt`, `_parseDateTimeUtc`, `_isNocoRowActiveRunning`, `_isLikelyUuidOrLongPk`, `_isNocoRowSacredStopTarget`), and sacred-stale-open merge logic.
* **Qualification fixes in category_service.dart:** `_cacheCategoriesRawKey` / `_nocoSystemRowIdKey` / `_nocoEnvelopePkKey` / `_nocoCategoryRestSegmentKey` / `_sacredStaleOpenCap` / `_oneShotUntitledGhostCleanKey` qualified with `DatabaseService.` prefix (6 statics, all `replace_all`).
* **Cross-file call-site updates:** 11 statics now in `CategoryServiceExtension` re-routed from `DatabaseService.X()` → `CategoryServiceExtension.X()` across `record_service.dart`, `plan_service.dart`, `profile_service.dart`, `database_service.dart`, `stats_view.dart`, `timeline_view.dart`, `wear_timer_screen.dart`.
* **Result:** `database_service.dart` 4,238 → 1,089 lines. `category_service.dart` 3,158 lines (new). `flutter analyze` full project: 0 errors (57 info/warnings, all pre-existing).

## [2026-04-29] - V5.3: extract record_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/record_service.dart — new, ~2,407 lines):** Record domain moved to a `part of 'database_service.dart'` file using `extension RecordServiceExtension on DatabaseService`. Contains: `writeRecord`, `stopRecordByDocId`, `updateRecord`, `deleteRecordByDocId`, optimistic shadow methods (`_startAtomicTaskSequenceApplyLocalPrimary`, `_applyOptimisticStopUiSnapshot`), realtime handler (`_onPbRecordsSubscriptionEvent`), record cache mutation (`_upsertFlatRecordFromPbModel`), ID resolution (`_resolveRecordIdForStopOrDelete`), singleton/stale-open detection, and all supporting record fetch/parse helpers.
* **Qualification fixes in record_service.dart:** `_appLifecycleObserver` / `_appLifecycleObserverRegistered` / `_kMinGapRecordsNetworkFetch` / `_cacheRecordsFlatKey` / `_nocoSystemRowIdKey` / `_isNocoRowActiveRunning` — all qualified with `DatabaseService.` prefix.
* **Result:** `database_service.dart` 6,634 → 4,238 lines. `record_service.dart` 2,407 lines (new). `flutter analyze` full project: 0 errors (57 info/warnings, all pre-existing).

## [2026-04-28] - V5.2: extract plan_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/plan_service.dart — new, ~2,803 lines):** Plan domain moved to a `part of 'database_service.dart'` file using `extension PlanServiceExtension on DatabaseService`. Extracted: library-level state (`_planCreateOutboxFlushInFlight`, `_tasksController`, `_planningRefreshController`, `_planningOptimisticByDateKey`, `_tasksCache`, `_planOrderDebounce`, `_planOrderBulkChunkSize`, `_planOrderDebounceTimer`, `_pendingPlanOrderSyncList`, `_planReorderBaselineByPlanId`, `_planAlarmRescheduleDebounceTimer`, `_random`); library-level consts/getters (`_plansToTagsLinkColumnSystemId`, `_isPlansTableConfigured`); 75 methods/getters including all plan CRUD, rrule expansion, optimistic UI cache, alarm scheduling, order persistence, AI task parsing, plan prefs, and plan link scoring statics.
* **Qualification fixes in plan_service.dart:** `_log(` → `DatabaseService._log(`; `_levenshteinDistance(` / `_isLikelyPocketBaseRowId(` / `pocketRelationIdOrNull(` / `getPlanetaryNow(` / `_parseDateTimeUtc(` / `recordDurationSecondsWithinDayFromTimestamps(` / `_sanitizePkString(` / `newClientUuid(` / `_newClientRecordUuid(` / `_categoryOrderDebounce` / `_nocoEnvelopePkKey` — all qualified with `DatabaseService.` prefix (12 statics, all `replace_all`).
* **Call-site fix in planning_view.dart:1562:** `DatabaseService.planningWallEstimateSeconds` → `PlanServiceExtension.planningWallEstimateSeconds` (extension statics must be called via extension name, not type name).
* **`tool/apply_v52.dart` deleted** (22-anchor extraction script, served its purpose). `tool/transform_v52.dart` deleted (dry-run manifest only).
* **Result:** `database_service.dart` 9,415 → 6,634 lines. `plan_service.dart` 2,803 lines (new). `flutter analyze` full project: 0 errors (116 info/warnings, all pre-existing).

## [2026-04-27] - V5.1: extract profile_service.dart from database_service.dart [shipped]
* **Extraction (lib/data/profile_service.dart — new, 666 lines):** 19 block extraction via `transform_v51.dart` (deleted post-run). Profile/tag domain moved to a `part of 'database_service.dart'` file using `extension ProfileServiceExtension on DatabaseService`. Extracted: `_ProfileFetchFailedException` (top-level class); library-level state (`_profilePbRecordId`, `_dataRegion`, `_settings`, `_settingsController`, `_userTagsCatalogCache`, `_tagsCatalogRefreshController`); library-level consts (`_dataRegionKey`, `_profileTzLabelKey`, `_profileTzOffsetKey`, `_profileThemeModeKey`); top-level functions (`_normalizeTimezone`, `_fixedOffsetHoursFromLabel`, `utcRangeForDateInTimezone`, `utcRangeForWallClockDate`); extension methods: `settings`, `cachedUserTagsCatalog`, `tagsCatalogUpdated`, `notifyTagsCatalogChanged`, `dataRegion`, `reloadForDataRegionChange`, `getUserProfile`, `getCurrentUserProfileMap`, `saveSettings`, `updateTimeZone`, `updateUserTimezone`, `fetchTagsForCurrentUser` + tag CRUD, `getProjectedToday`, `applyUserOffset`, `getTimelineDeviceLocalToday`.
* **Pre-transform promotion:** `_two()` and `_dateKeyFromDate()` promoted from `static` class methods to top-level library functions in `database_service.dart` to avoid `unqualified_reference_to_static_member_of_extended_type` errors inside the extension.
* **Auth stubs deleted entirely:** `signInWithYandex`, `exchangeCodeForSession`, `signInWithOtp`, `verifyOtp` not included in profile_service.dart (already dead code — no callers).
* **Post-extract fixes:** `_log(` → `DatabaseService._log(` and `_rowInt(` → `DatabaseService._rowInt(` (replace_all in profile_service.dart — both are `static` on DatabaseService, not inherited by extension); extension renamed `_ProfileServiceExtension` → `ProfileServiceExtension` (private extension not visible to callers in other files).
* **Result:** `database_service.dart` 10,063 → 9,415 lines. `flutter analyze` full project: 0 errors (58 info/warnings, all pre-existing or isolated-scope false positives).

## [2026-04-27] - Phase 1 roadmap sync + timezone comment corrections [shipped]
* **Roadmap sync (commit a7f27d5):** Phase 1 bug `database_service.dart:3830` (mixed timezone sources in `_rowStartWallDayIsBeforeProjectedToday`) was already fixed in `393bb0f` (April 25) — `toLocal()` replaced with `_timelineDeviceLocalDayKeyFromUtc`; the ROADMAP was the stale artifact. Status updated to ✅ Fixed; Phase 1 now 3 of 5 done, 2 open: `models.dart:709` (HIGH) and category-drop on cold start (MEDIUM).
* **Doc comment corrections — `database_service.dart`:** `_rowStartWallDayIsProjectedToday` doc changed from "device-local calendar today" → "profile wall-clock today"; `_filterCachedRecordsForDate` inline comment changed from "device local Y-M-D only (no profile-offset wall)" → "profile wall-clock Y-M-D; callers must pass a profile wall-clock date". Comments had inverted the reality of the code, trapping future maintainers.
* **CLAUDE.md nav map:** Added row "Singleton / stale-open detection → `_rowStartWallDayIsBeforeProjectedToday` / `_mergeSacredStaleOpenCandidates`" to the Where things live table.

## [2026-04-27] - Round 4: avoid_print sweep [shipped]
* **Round 4a — app_shell.dart (commit e9611b0):** Converted 10 `print()` error-path calls to `debugPrint()`. Deleted 2 "Attempting to stop record" got-here traces from `_showEditRecordSheetForTimeline.onStop`; also dropped the now-dead `final ok =` capture and empty `if (!ok)` block — DatabaseService surfaces stop failures internally via `_brainSnackError` / `_snackStopHttpFailure`.
* **Round 4b — database_service.dart hot-path DELETEs (commit 1bdea90):** Deleted 16 `print()` calls: `SEARCHING PB FOR` trace (fires on every Stop/Delete ID resolution); two `ID TRANSLATION` prints inside plan/category `for` loops (tight loops); `_printAtomicCheckRunningCount` body; two `if (logSuccessLine)` blocks in `_upsertFlatRecordFromPbModel` (realtime hot path); `_logRecordsPatchDispatch` and `_logRecordsDeleteDispatch` bodies (every PATCH/DELETE); `_logIdMapTranslated` body (every successful PATCH); `[ABORT_REASON]` dead-letter PATCH skip (#31 — sync-storm risk); `[POST_PAYLOAD]` full payload dump before `records.create`; `[SMART_LINK]` category match trace (#35 — fires on every fuzzy-hit record write); `[SHADOW_EMIT]` optimistic shadow on Start; `DEBUG: Tag` in `_pbTagRecordIdsFromTags` tight loop; two `DEBUG: Sending to PB tags_link` verbose dumps.
* **Round 4c — database_service.dart debugPrint conversions (commit f724c69):** Converted 24 remaining `print()` calls to `debugPrint()` on genuine error/diagnostic paths: emergency fallback ID lookup + owner-mismatch conflict; `PB_ERROR_RESPONSE` on `fetchCategories` / `fetchAllCategories`; `ID TRANSLATION` cache-hit and server-hit in `_resolveRecordIdForStopOrDelete`; `[ABORT_REASON]` PATCH-failed catch; `PB_CREATE_ERROR_DETAILS` on records create; `[SERVER_ERROR_BODY]` + `[CATEGORY_RECOVERY]` in category creation; four `[CHILD_RECORD_PARSE]` parse-error prints (2 overloads × message + stack trace); 8 guard-clause and catch-block prints in `stopRecordByDocId`.
* **Round 4d — voice_audio_web + shared_widgets + planning_view (commit a99646b):** Added `import 'package:flutter/foundation.dart' show debugPrint;` to `voice_audio_web.dart` (only Flutter-free file in scope). Deleted 2 "Attempting to stop" got-here traces from `_stopChild` and `_stop` in `shared_widgets.dart`. Converted 5 remaining error-path prints to `debugPrint()` across `shared_widgets.dart` and `planning_view.dart` (`_toggleDone` catch).
* **Result: `flutter analyze` shows 0 `avoid_print` violations across all 6 in-scope lib files. One pre-existing violation in `tool/test_smart_parse.dart` is out of scope. Net reduction: 17 deleted, 45 converted to debugPrint, 3 left as LEAVE (already `// ignore: avoid_print` — boot-fail crash surfaces in `main.dart` and `database_service.dart`). Total prints touched: 65.**

## [2026-04-27] - Phase 1 cleanup: legacy backends + dead code [shipped]
* **Round 1+2 — Legacy backend deletion (commit 66e37e5):** Removed 11 files: `lib/data/yandex_ydb_auth_bridge.dart`, `lib/data/yandex_ydb_provider.dart`, `lib/data/ydb_api_client.dart`, top-level `lib/ydb_api_client.dart`, `lib/models/nocodb_response.dart` (+ empty `lib/models/` dir), top-level `lib/l10n.dart` (vestigial static class), and `lib/migration_data/` (5 CSVs not in pubspec assets). `auth_service.dart` and `auth_screen.dart` retained — still actively imported by `main.dart` and `profile_view.dart`; flagged for separate migration.
* **Round 3a — Trivial dead code (commit 0f49121):** Removed 3 unused imports from `lib/features/shared/shared_widgets.dart` (`category_color_palette.dart`, `category_db_display.dart`, `flutter/services.dart`); deleted dead widget class `_PlanningDatePickerDialog` (40 lines) from `lib/features/planning/planning_view.dart`; deleted unused `_uuidRe` constant from `tool/verify_migration.dart`.
* **Round 3b — NocoDB-era parsers (commit 09fff1f):** Removed `_parseNocoCategoryWrapperRowIdFromBody` and `_parseCategoryFieldsCategoryIdFromBody` from `lib/data/database_service.dart` (42 lines). Both were NocoDB response parsers with zero call sites post-PocketBase migration.
* **Round 3c — Legacy private helpers (commit 91b356b):** Removed 5 unused privates from `lib/data/database_service.dart` (47 lines): `_SignInRequiredException`, `_standardUuidRe` + `_looksLikeStandardUuid` (deleted as pair — regex orphaned without consumer), `_m2MlinkIntCount` (NocoDB M2M rollup parser), `_replaceCategoryNodeById` and `_updateCategoryTagInRules` (legacy in-memory category tree mutators by int id; pre-flight grep confirmed `_rules` mutation is alive elsewhere).
* **`flutter analyze`: 143 → 119 issues (−24, all info/warning, zero errors). Web release build clean with `--no-tree-shake-icons`.**
* **Backlog noted:** `auth_service.dart` migration (still wired alongside `AuthBridge`); icon tree-shaking failure (`category.dart:315`, `database_service.dart:5689` use non-constant `IconData`); 63× `avoid_print` sweep (Round 4); 2× `unused_field` in `database_service.dart` (`_cachedProfileUuid`, `_planOrderBulkChunkSize` — kept defensively, may be optimistic-cache plumbing).

## [2026-04-25] - Phase 1 bugs + Phase 3a/3b foundation + model split [shipped]
* **Phase 1 — Timezone (`lib/data/models/record.dart`, `lib/data/database_service.dart`):** Fixed three `toLocal()` violations: `_recordLocalCalendarDate` accepts `[int offsetHours = 0]`; `TimelineRecord.dateKey` uses new `timezoneOffsetHours` field (UTC + `Duration(hours:)`, no device TZ); `_rowStartWallDayIsBeforeProjectedToday` replaced device-local date compare with `_timelineDeviceLocalDayKeyFromUtc(stUtc).compareTo(getTimelineDeviceLocalTodayDateKey()) < 0`. Four `TimelineRecord.fromMap` callers in `database_service.dart` + one in `app_shell.dart` pass `timezoneOffsetHours: _settings.timezoneOffsetHours`.
* **Phase 1 — Category ID hash collision (`lib/data/models/category.dart`):** Replaced `rawId.hashCode` (Dart-VM-randomised, dart2js-variable) with `_stableStringHash(rawId)` — deterministic 31-bit polynomial hash, range [1, 0x7FFFFFFF], avoids sentinels -1 and 0. No migration: `CategoryRule.id` is session-local, never persisted.
* **Phase 3a — Kill `EditRecordSheet` (`lib/features/shared/shared_widgets.dart`, `lib/app_shell.dart`):** Deleted legacy NocoDB-era `EditRecordSheet`. All timeline record edit entry points now route exclusively to `_TimelineRecordSheetContent`.
* **Phase 3b — Component library (`lib/core/widgets/`):** Built 4 primitives: `AppLoading` (`app_loading.dart`), `showConfirmDialog` (`confirm_dialog.dart`), `AppButton` (`app_button.dart`), `AppErrorState` + `AppEmptyState` (`app_state_views.dart`). Migrated all 17 inline `CircularProgressIndicator` call sites to `AppLoading(size:)`.
* **Phase 4.2 — Split `lib/data/models.dart` into Dart part files (`lib/data/models/`):** `_shared.dart` (enums + JSON/ISO/ID helpers), `profile.dart`, `category.dart`, `record.dart`, `planning.dart`, `tag.dart`, `stats.dart`. Public API unchanged; import via `package:counter/data/models.dart` or barrel `package:counter/models.dart`.
* **`flutter analyze`: 143 pre-existing info/warnings, zero new issues introduced. Web release build verified locally. All committed.**

## [2026-04-20] - Strike 25: Shell layout isolation & ticker edge-scroll (victory)
* **Strike 25 (`lib/core/shell_layout_state.dart` `ShellLayoutController` / `ShellLayoutScope`, `lib/app_shell.dart`, `lib/features/planning/planning_view.dart`, `lib/features/lists/lists_view.dart`, `lib/data/database_service.dart`):** Enforced domain isolation by extracting UI layout state (`ShellLayoutController`) from the data layer. Replaced frame-dependent pointer events with a time-delta `Ticker` to guarantee hardware-agnostic, consistent velocity for timeline edge auto-scrolling.
* **Strike 25 — Lists / Backlog (`lib/features/lists/lists_view.dart`, `UserSettings.listCompletionBehavior`, `DatabaseService.persistPlanningTaskOrder`):** `CustomScrollView` + `SliverReorderableList` + `ReorderableDelayedDragStartListener` for long-press backlog reorder with optimistic `plans.order` + debounced bulk PATCH; per-card category path header; `list_completion_behavior`-driven done/archive/hide layouts; filter chip bar with horizontal manual reorder; optional tag chips on cards; mass-edit selection + bottom bar reporting FAB clearance through `ShellLayoutScope` (not the data layer).
* **Strike 25 — Planning day & tag fork (`lib/features/planning/planning_view.dart`, `lib/features/profile/tag_settings_hub.dart`, `lib/features/profile/tag_manager_page.dart`, `lib/features/shared/shared_widgets.dart` `_PlanningTaskEditSheet`):** Segmented sort surface (category / wall-time hour grid / tags / custom) with delayed-drag reorder in tag & custom buckets; hour-grid `LongPressDraggable` + slot `DragTarget` rescheduling; plan bulk-select bar wired to shell FAB reserve. `TagSettingsHub.tagCreateDomain` + `TagManagerPage.pocketTagDomain` enforce PocketBase `tags.domain` + `fetchTagsForCurrentUser(scope:)` so Ideas/backlog CRUD list-scoped tags without mixing the plan tag catalog.

## [2026-04-19] - Strike 24: UI purge & editor unification (victory)
* **Strike 24 (`lib/features/timeline/timeline_view.dart`, `lib/features/timeline/timeline_widgets.dart`, `lib/features/planning/planning_view.dart`, `lib/features/shared/shared_widgets.dart`, `lib/core/theme.dart`, `lib/l10n/dictionary.dart`):** Eliminated legacy spatial bloat by moving dates to a compact SafeArea strip. Unified the Plan and Record edit sheets into a mirrored, left-aligned Tab architecture (Start/End 50-50 row, Notes, Checklist, Parallel) and stabilized the Quill toolbar height, maintaining strict schema adherence for Record text persistence.

## [2026-04-17] - Strike 22: Idea vs Plan editor fork (rollback)
* **`_PlanningTaskEditSheet` (`lib/features/shared/shared_widgets.dart`, `_startedAsUndatedBacklog`, nullable `TabController`):** Resolved UI regression by explicitly branching `_PlanningTaskEditSheet` logic based on list-item state. Restored the optimized single-scroll layout for time-bound Plans (exposed Omni-Picker, visible Tags) while preserving the 3-tab GTD layout for Ideas, ensuring both modes safely integrate the new Quill editor schema.

## [2026-04-17] - Strike 19: Idea Editor (GTD layout + Markdown toolbar)
* **Idea Editor (`lib/features/shared/shared_widgets.dart` `_PlanningTaskEditSheet`, `lib/l10n/dictionary.dart` `notes_md_*`):** Overhauled the Idea Editor into a strict 3-tab GTD layout (Notes, Checklist, Schedule), completely purging the Tag UI for undated backlog items. Implemented a lightweight, schema-safe Markdown injection toolbar for the Notes field, avoiding heavy WYSIWYG dependencies while preserving the Optimistic UI speed.

## [2026-04-17] - Strike 17: Omni-Picker refinement
* **Platform / omni-picker (`lib/core/widgets/omni_date_time_picker_dialog.dart`, `showAppDateTimePicker` keyboard path in `shared_widgets.dart`):** Refined the Web/Desktop Omni-Picker into a hybrid UI, combining Flutter's native CalendarDatePicker for visual day selection with a custom-styled, large-format digital text input for time. Maintained the single-dialog Omni-Picker Law while drastically improving visual hierarchy and desktop input ergonomics. Replaced `InputDatePickerFormField` with `CalendarDatePicker` + `ValueKey` sync; soft rounded HH:mm fields, divider, ~350px content width; mobile/touch path unchanged (`omni_datetime_picker`).

## [2026-04-17] - Strike 16: Authentication gates
* **Auth / routing (`auth_bridge.dart`, `auth_view.dart`, `main.dart` `RootAuthWrapper`, `pb_config.dart` `PbCollections.profiles`):** Implemented secure authentication flow targeting the profiles collection with a unified AuthView UI (Sign In, Register, Password Reset, OAuth). Hardened checkSession() to strictly trust pb.authStore.isValid, removing stale local fallbacks, and wired the global routing gate to protect the AppShell. Added `loginWithPassword` / `register` / `requestPasswordReset` / `loginWithOAuth2` (`AuthBridgeException` / `AuthBridgeCancelled`); all PocketBase auth uses `profiles` only; `auth_screen.dart` re-exports `AuthView`.

## [2026-04-17] - Strike 15: Unified Omni-Picker
* **Platform / omni-picker (`ARCHITECTURE.md` §8.1, `lib/core/widgets/omni_date_time_picker_dialog.dart`, `shared_widgets.dart` `showAppDateTimePicker`, `picker_entry_modes.dart`):** Codified the Omni-Picker Law in ARCHITECTURE.md and implemented a unified, keyboard-first Date & Time AlertDialog for Web/Desktop, replacing the sequential picker flow to eliminate UX friction while preserving mobile touch flows. The `useKeyboardFriendlyMaterialPickers()` path now opens `showOmniDateTimePickerDialog` (`InputDatePickerFormField` + 24h hour/minute `TextFormField`s, single Save) instead of chained `showDatePicker`→`showTimePicker`; touch/mobile still uses `showOmniDateTimePicker` from `omni_datetime_picker`.

## [2026-04-17] - Strike 14: Inbox gating & UI polish
* **Lists / Timeline / Planning / shell (`lists_view.dart` `_filterCategoryId` gate, `timeline_view.dart` / `planning_view.dart` `kIsWeb` chevrons, `app_shell.dart`, `dictionary.dart` `input_placeholder_*`, `tag_contrast.dart` / `chip_component.dart`):** Enforced strict GTD Inbox gating with empty states. Purged redundant manual-add UI/dead code from app_shell, standardized inline placeholders, relocated 'No Tags' settings with dynamic B/W contrast, and implemented Web-only chevron date navigation.

## [2026-04-17] - Strike 13: Inbox paradigm & UI purge
* **Shell / Lists / task editor:** Purged redundant cloud sync UI. Overhauled Inbox/Lists paradigm: updated localized placeholders, implemented collapsible category tree in Lists settings, restyled cards (leading checkbox, no category pill), and added GTD 'graduate to plan' logic for dating backlog items. (`app_shell.dart` removed `_SyncStatusIcon` / connection overlay; `lists_view.dart` `ListsPage.onEditTask`, `_buildManualCategoryTreeTile` + `ExpansionTile`, underline + green inline add, `_BacklogPlanCard`; `timeline_view.dart` / `planning_view.dart` / `dictionary.dart` `input_placeholder_*`; `shared_widgets.dart` `_PlanningTaskEditSheet` `_startedAsUndatedBacklog` / `plan_graduate_*`.)

## [2026-04-17] - Strike 12: Web accelerator (keyboard-first pickers)
* **Platform / pickers:** Centralized platform-aware picker logic in picker_entry_modes.dart. Forced all showDatePicker and showTimePicker invocations across the app to default to input mode on Web/Desktop for rapid keyboard entry, while preserving calendar/dial modes for mobile. (`appDatePickerEntryMode` / `appTimePickerEntryMode`, `useKeyboardFriendlyMaterialPickers()`; `global_app_header.dart`, `shared_widgets.dart` `showAppDateTimePicker` + record date pickers, `planning_view.dart` `_changeSingleTaskDate` / `_openPlanningHeaderDatePicker`, `bulk_planning_edit_sheet.dart`.)

## [2026-04-17] - Strike 11: UI reclamation & six critical fixes
* **Lists / Planning / shell:** Standardized GlobalAppHeader (Day · Date · Time) and restored Lists inline-add UI. Enforced category colors on filter chips, implemented toggle-to-clear filtering to replace the 'All' chip, indented the Lists category settings tree, and added SharedPreferences persistence for customizable 'No Tags' visibility and color (including pure black/white). (`global_app_header.dart` removes `sectionTitle`; `lists_view.dart` `FilledButton.icon` inline add, `_ListsQuadraticChip` category tints, `_categoryTreeDepthFromPath` manual sheet; `timeline_view.dart` / `planning_view.dart` header call sites; `planning_view.dart` + `chip_component.dart` `TagQuickPickStrip.onTagLongPress` when non-reorder; prefs `no_tags_visible` / `no_tags_color`.)

## [2026-04-17] - Strike 8: Sortable pseudo-tag & UI purge
* **Planning / tags:** Purged redundant static tag filter UI. Injected a draggable, synthetic 'No Tags' pseudo-tag (ID -1) into the existing tag prioritization strip, persisting its custom sort order via SharedPreferences to dynamically route untagged tasks in the timeline view. (`planning_view.dart`, prefs key `planning_quick_bar_tag_ids_v1`, `_groupIdsInMasterBarSequence`.)

## [2026-04-17] - Strike 4: Backlog quarantine & Lists UX
* **Backlog / Lists:** Quarantined backlog data by bypassing the dateKey/startTime optimistic defaults in database_service.dart. Implemented horizontal quadratic category chips with SharedPreferences persistence and enforced leaf-node strictness for inline item creation.

## [2026-04-16] - Strike 2 & 2.5: Context-aware parser + STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex and an isBacklog bypass for dateless plans. Enforced strict EN/RU localeId binding (using en-US for Web) in the STT listener, fixing legacy locale hardcodes.

## [2026-04-16] - Strike 2: Context-aware parser & STT locale
* **Parser / STT:** Upgraded smart_input_parser.dart with a leading-hour regex (^([01]?\d|2[0-3])\s+) and an isBacklog bypass that forces startTime: null and strips scheduling junk. Enforced strict EN/RU localeId binding in the STT listener, removing legacy Web locale hardcodes.

## [2026-04-16] - Strike 1: Lists friction + optimistic tags
* **Lists / planning cache:** Fixed Optimistic UI cache for tags by removing the server-override branch in `_mergePlanningOptimistic`. Added inline quick-add with `_pendingInline` state and a delete button with confirmation dialog to the ListsView. (`database_service.dart` `applyOptimisticPlanningTask` dateKey fallback for short keys; `lists_view.dart` optimistic `optimistic-inline-*` rows + `addPlanningTask` / `deletePlanningTasksBulk`; l10n `lists_inline_add_hint` / `lists_delete_backlog_confirm`.)

## [2026-04-16] - Recurring: instance materialization (virt- complete)
* **Planning / recurrence:** Refactored virtual clone mutation in `database_service.dart`. Separated Delete (adds `exception_dates` to parent) from Complete (Instance Materialization: adds exception to parent AND creates a concrete `isDone: true` record). Added a strict rollback mechanism if the materialization POST fails. (`_parseVirtualPlanRowId`; delete path → `_patchRecurringTemplateExceptionDates` only; complete path → `_completeVirtualRecurringInstance` = parent PATCH + `_createPlanningTaskPocketStrict` / `_buildPocketPlanCreateBody`; rollback removes the exception; `updatePlanningTask` / `markPlanningTasksCompletedBulk` vs `deletePlanningTasksBulk`.)

## [2026-04-16] - Phase 4–5: Zero-Table Lists & More navigation
* **Backlog / shell:** Implemented 'Zero-Table' Lists using dateless PlanningTask rows in database_service.dart with 1-tap Play/Complete execution. Restructured App Shell navigation using IndexedStack, adding ListsView and collapsing Profile/Categories into a new MoreView. (Implementation: `fetchBacklogPlans` / `startRecordFromPlanTask` / `startTimerWithCategory` dateKey fallback; day-scoped plan fetches require `startTime`; `lists_view.dart`, `more_view.dart`, `app_shell.dart`.)

## [2026-04-16] - Phase 3: Scheduling Engine UI (recurrence + notifications)
* **Scheduling / notifications:** Wired UI bindings in _PlanningTaskEditSheet for rrule and reminderOffset. Upgraded DatabaseService PATCH payloads to correctly route recurrence edits. Added Notification OS permissions diagnostic to ProfileView. (`shared_widgets.dart` `_PlanRepeatUi` / reminder `DropdownButtonFormField`, `database_service.dart` `patchPlanAlarmRecurrence` + `_scalarPatchBodyForPlanningRow`, `app_shell.dart` `_persistPlanningEditFromSheet`, `profile_view.dart` `_ProfileNotificationsSection` + `FlutterLocalNotificationsPlugin.areNotificationsEnabled` on Android; `PlanningTask.copyWith` `clearReminderOffset` / `exceptionDates` with `clearRrule` in `models.dart`.)

## [2026-04-15] - Timeline & planning card metadata icons
* **Planning / Timeline cards:** Added synchronous boolean getters (hasNotes, hasChecklist, etc.) to Record and PlanningTask models in `models.dart`, and bound them to muted icon rows in UI cards. Strictly avoided N+1 database queries in the `build()` method; wiring uses `Record.forTimelineCard` + `_timelineRecordMetaIcons` in `timeline_view.dart` and `_planningTaskMetaIcons` in `planning_view.dart` (plus aligned getters on `TimelineRecord`).

## [2026-04-08] - Bilingual STT & Timeline Overlap Fix
* **Voice Input (STT):** Implemented strict `RU | EN` toggle on `VoiceInputSheet`. Preserves prefix on toggle. Web bypasses empty locales using explicit `ru-RU`. (DO NOT REBUILD).
* **Database (PocketBase):** Added `record.update:before` and `record.create:before` hooks to enforce the Singleton Timeline Law. Server now auto-truncates overlapping records.
* **Parser:** Implemented dependency-free Levenshtein fuzzy matching (0.9 threshold) for Category string matching in `smart_input_parser.dart`.

## [2026-04-05] - Timeline & Stats Foundation
* **UI:** Created `timeline_view.dart` and nested `stats_view.dart` inside the timeline feature module.
* **Logic:** Built initial `DatabaseService` logic for fetching records grouped by day using `timezone_offset`.

## [2026-04-03] - UI Performance & Shell Foundation
* **Architecture:** Enforced Optimistic UI and Zero-await policies. Visual updates trigger in <100ms. DB writes use `unawaited` fire-and-forget logic.
* **State Management:** Implemented strict Unidirectional Data Flow. `database_service.dart` acts as the God Object; UI modules (`features/`) are "dumb" and never mutate data directly.
* **Categories UI:** Implemented Dynamic Grid Math (3/4/5 tiles wide based on depth, 8pt gaps) and The Centering Law (Icon + Text tightly clustered in the absolute center).

## [2026-04-01] - PocketBase Setup & Realtime Sync
* **Database:** Mapped `profiles`, `categories`, `records`, `plans`, and `tags` collections adhering strictly to the Iron Laws (15-char System IDs for REST, UUIDs for metadata only).
* **Realtime:** Implemented `subscribe('*')` on the `records` collection so Web and Mobile share identical in-memory cache updates.
* **AI API Structure:** Established `POST /api/ai/parse-task` endpoint on the server for secure Groq LLM integration.
* **Time Engine:** Grouping logic fully relies on profile `timezone_offset` and `preferred_timezone`. Banned local `DateTime.now()` for persisted grid keys.

## [2026-03-29] - Anti-Spam & Network Guards
* **Circuit Breakers:** Implemented strict 15-second cooldowns for background fetches and a 3-strike/60-second block for failed requests.
* **Error Handling:** Enforced silent success logs and debounced errors (logged once) to protect VPS resources.
