# Planning Page Seam Audit — 2026-07-06

**Project:** Counter / Life OS  
**Pass type:** Report only — **no production Dart changes, no file moves, no splits.**  
**Target file:** `lib/features/planning/planning_page.dart`  
**Baseline commit:** `fab79fb` (post Stage A Category decomposition)  
**Governing law:** Structure Growth Law — `docs/ARCHITECTURE.md` §11, `docs/APP_STRUCTURE.md` §7

---

## 1. Executive verdict

### **B1 COMPLETE — B2 CONDITIONALLY UNBLOCKED**

`planning_page.dart` is **not ready for a blind line-count split**. Time View drag/cascade/layout logic is **already extracted** to `time_view/*` (~783 lines in `planning_time_view.dart` alone), but the page still **implements `PlanningTimeViewHost`**, owns **card-row rendering used by Time View**, and duplicates **day-body routing** in two methods.

**Stage B0 (2026-07-06):** Added `test/planning_page_host_contract_test.dart` and `test/planning_page_list_modes_test.dart` — `PlanningPage` mounts without network; empty-day and sort-mode shell smoke; Time View host path does not throw.

**Stage B1 (2026-07-06):** Extracted S1 → `widgets/planning_list_grouping.dart`, S5 → `widgets/planning_frozen_day_list.dart`, S6 → `widgets/planning_select_mode_header.dart`. `planning_page.dart` **2394 → ~2202 lines**. Zero behavior change; B0 tests green.

| Sub-verdict | Meaning |
| :--- | :--- |
| **Grouped list sections (B2)** | **Unblocked (conditional)** — S2/S3/S4 after B0 stays green |
| **Time View host / card row (B3+)** | **High risk** — do not move without host contract tests |
| **Brain / CRUD paths** | **No-touch** — all mutations stay via `DatabaseService.instance.*` |

**Do not split** beyond documented B2 seams until B0 tests pass; re-run `flutter test test/planning_page_*` before any B2 commit.

---

## 2. Current metrics

| Metric | Value |
| :--- | :--- |
| **`planning_page.dart` lines** | **~2202** (was 2394 pre-B1) |
| **Public entrypoints** | `PlanningPage`, `_PlanningPageState` (private) |
| **Private widget classes in file** | **0** (all logic in `_PlanningPageState` methods) |
| **Import count** | **~52** package imports |
| **Already extracted siblings** | `planning_page_shell.dart` (270), `time_view/*` (10+ files), `widgets/planning_*` (8 files), `settings/*`, `bulk_planning_edit_sheet.dart`, `smart_plan_sheet.dart` |
| **Empty comment stub block** | ~L1673–L1733 (legacy Time View extraction markers — cleanup only, not behavior) |

---

## 3. Responsibility map

### 3.1 Public surface

| Symbol | Role |
| :--- | :--- |
| `PlanningPage` | StatefulWidget — single-day Plans tab body (one page in date pager or active day strip) |
| `_PlanningPageState` | State + **`PlanningTimeViewHost` implementor** + stream/optimistic orchestration |

**Barrel:** `planning_view.dart` re-exports `planning_page.dart`, `planning_page_shell.dart`, `planning_sort_mode.dart`.

### 3.2 State fields (~L143–L218)

| Field / group | Purpose |
| :--- | :--- |
| `_textController`, `_quickAddFocus` | Inline quick-add input |
| `_selectedPlanKeys`, `_planSelectMode` | Bulk selection mode |
| `_optimisticTasks`, `_latestPlanningDayTasks` | Quick-add + stream merge |
| `_planDoneOverride`, `_planCompletionHoldKeys`, `_planCompletionHoldTimers` | Done-toggle UX hold (~250ms) |
| `_planReorderSettleKeys` | Reorder settle animation keys |
| `_planningStream`, `_planningStreamKey` | Per-day `planningStream` cache |
| `_dragOrder` | Transient list reorder |
| `_sortMode` | `PlanSortMode` (custom / time / category / tags) |
| `timeView` | `PlanningTimeViewCoordinator` — Time View state + build |
| `_planningTimeSub`, `_tagsCatalogSub`, `_settingsSub` | Running title, tag catalog, timezone refresh |
| `_quickAddAvailableTags`, `_creationSelectedTags`, prefs keys | Quick-add tag strip + SharedPreferences order |
| `_activeRecordingTitleNorm` | Highlight running record on matching plan title |

### 3.3 Method groups (approximate line ranges)

| Range | Responsibility | Layer |
| ---: | :--- | :--- |
| L222–L372 | Date keys, quick-add order, single-task date change, `_planKey`, reorder commit, stream factory | UI + Brain callbacks |
| L375–L485 | **`PlanningTimeViewHost` getters + forwards** | **Host contract (HIGH)** |
| L488–L543 | `initState`: sort mode persist, stream subs, `timeView` init | Lifecycle |
| L545–L712 | Quick-add tag load/merge/reorder prefs, tag manager navigation | UI + prefs |
| L714–L792 | Timezone refresh, lifecycle, dispose | Lifecycle |
| L793–L905 | Optimistic merge, display sort, completion holds, FAB bulk reserve | **Optimistic UI (HIGH)** |
| L908–L1100 | Select mode exit/toggle, bulk edit/delete | **Bulk UX (MEDIUM–HIGH)** |
| L1103–L1474 | Edit launcher, recurrence delete, quick-add hour, radial menu, `_addTask`, smart plan inject, `_toggleDone` | **CRUD coordination (HIGH)** |
| L1476–L1604 | `_taskSortCmp`, category/tag grouping helpers | Pure list logic (LOW) |
| L1606–L1670 | `_planningTaskCardForRow` → `PlanCard` wiring | **Host + cards (HIGH)** |
| L1735–L1855 | `_planCardRow`, `_wrapPlanCardForDisplay` — list + **Time View long-press drag** | **Host + gestures (HIGH)** |
| L1861–L2126 | Category/tag grouped views + bucket reorder | List UI (MEDIUM) |
| L2128–L2193 | `_buildFrozenPlanCardList` — offscreen frozen day | List UI (LOW) |
| L2195–L2335 | `_buildActiveDayBody`, `_buildDayContentForPageIndex` — **duplicated mode switch** | **Routing (HIGH)** |
| L2338–L2480 | `build`: StreamBuilder, error/loading, select chrome, bulk bottom bar | Orchestrator |
| L2482–L2628 | `_buildPlanningMainColumn`: sort bar, quick-add strip, day strip / active body | Orchestrator + chrome |

### 3.4 Already extracted (do not re-merge)

| Path | Owns |
| :--- | :--- |
| `planning_page_shell.dart` | `PlanningSwipeWrapper` — PageView date pager, settle gate |
| `widgets/planning_quick_add_strip.dart` | `PlanningQuickAddTagStrip` (tag chips only) |
| `widgets/planning_bulk_bar.dart` | `PlanningBulkBottomBar` |
| `widgets/planning_empty_states.dart` | `PlanningDayEmptyState`, `PlanningFrozenListEmptyState` |
| `widgets/planning_filter_controls.dart` | `PlanningSortModeBar` |
| `widgets/planning_list_helpers.dart` | `planningReorderProxyDecorator` |
| `widgets/plan_card_reorder_settle.dart` | Reorder settle wrapper |
| `time_view/planning_time_view_host.dart` | Host **interface** |
| `time_view/planning_time_view_coordinator.dart` | Coordinator **state fields** |
| `time_view/planning_time_view.dart` | Coordinator **methods** (783 lines): hour grid build, drag, cascade apply, settings |
| `time_view/time_view_*` | Canvas, card layer, drag/resize controllers, hour grid, drop preview |
| `plan_time_view_layout.dart`, `plan_time_gesture_contract.dart` | Layout math + gesture thresholds |
| `bulk_planning_edit_sheet.dart`, `smart_plan_sheet.dart`, `recurrence_scope_dialog.dart` | Modal flows launched from page |

---

## 4. Dependency / import map

### 4.1 Who imports `planning_page.dart`

| Importer | Usage |
| :--- | :--- |
| `planning_view.dart` | Barrel export |
| `planning_page_shell.dart` | Instantiates `PlanningPage` per pager day |
| `time_view/planning_time_view_host.dart` | Imports `PlanningPage` type for `pageWidget` getter |

No other feature modules import `planning_page.dart` directly.

### 4.2 `planning_page.dart` → Brain / data (must stay indirect)

| Import / call | Usage |
| :--- | :--- |
| `database_service.dart` | `planningStream`, `applyOptimisticPlanningTask`, `updatePlanningTask`, `bulkUpdatePlans`, `deletePlanningTasksBulk`, `persistPlanningTaskOrder`, tag fetch, render snapshots |
| `plan_time_sequential_cascade.dart` | Indirect via Time View coordinator (cascade on drop) |
| `time_view_fixed_time_policy.dart` | Fixed-time tag policy in Time View |
| `smart_input_parser.dart` | Smart plan sheet inject |

**Direction rule:** UI → Brain only. No new Brain imports in extracted UI files.

### 4.3 `planning_page.dart` → planning feature subgraph

Heavy coupling to `time_view/*` (10 files), `widgets/*` (6 files), `settings/*` (4 files), `plan_time_*`, `bulk_planning_edit_sheet`, `smart_plan_sheet`, `recurrence_scope_dialog`.

---

## 5. Seam table

| ID | Source (class / method) | Lines (approx.) | Proposed file | Owner | Type | Needs from orchestrator | Risk | Mechanical? | Tests first? |
| :--- | :--- | ---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| S1 | `_taskSortCmp`, `_groupTasksByCategoryPath`, `_groupTasksByMasterBar`, `_tagSortMasterBarOrder`, `_groupIdsInMasterBarSequence`, `_masterBarIndexForTag` | 1476–1604 | `widgets/planning_list_grouping.dart` | Feature UI | Pure helpers | None (inputs → outputs) | **Low** | Yes | No (unit-test helpers in B0) |
| S2 | `_buildCategoryGroupedView` | 1861–1948 | `widgets/planning_category_grouped_list.dart` | Feature UI | UI + callbacks | `planCardRow` builder, select mode flags, reorder callbacks | **Medium** | Mostly | **Yes** (widget smoke) |
| S3 | `_buildTagGroupedListView` | 1950–2020 | `widgets/planning_tag_grouped_list.dart` | Feature UI | UI + callbacks | Same as S2 | **Medium** | Mostly | **Yes** |
| S4 | `_onCategoryBucketReorder`, `_onTagBucketReorder`, `_onReorder` | 2022–2126 | `widgets/planning_list_reorder_handlers.dart` or co-locate with S2/S3 | Feature UI | Behavior | `_commitPlanningReorder`, `_planCanReorderTask`, `_sortMode` | **Medium** | Partial | **Yes** |
| S5 | `_buildFrozenPlanCardList` | 2128–2193 | `widgets/planning_frozen_day_list.dart` | Feature UI | UI read-only | `wallDay`, scheme, render snapshot | **Low** | Yes | Optional |
| S6 | Select-mode header in `build` | 2419–2463 | `widgets/planning_select_mode_header.dart` | Feature UI | Pure UI | Exit/select-all callbacks | **Low** | Yes | Optional |
| S7 | `_mergeQuickBarTagsFromServer`, `_reloadQuickAddTags`, `_persistQuickBarTagIdOrderPrefs`, `_onPlanningQuickBarReorder`, `_toggleCreationTag` | 545–712 | `planning_quick_add_tags_controller.dart` (mixin or class) | Feature UI | UI+state | `setState`, prefs, `DatabaseService.fetchTagsForCurrentUser` | **Medium** | No | **Yes** |
| S8 | Quick-add TextField + buttons in `_buildPlanningMainColumn` | 2536–2575 | Extend `widgets/planning_quick_add_strip.dart` or `planning_quick_add_field.dart` | Feature UI | UI | `_addTask`, `_openSmartPlanSheet`, controllers | **Medium** | Yes | **Yes** |
| S9 | `_exitSelectMode`, `_toggleKeySelection`, `_clearSelection`, bulk edit/delete | 908–1100 | `planning_selection_controller.dart` | Feature UI | UI+state+Brain | Stream task list, `_planKey`, optimistic patches | **High** | No | **Required** |
| S10 | `_planningTaskCardForRow` | 1606–1670 | **Stay on host** or `planning_plan_card_factory.dart` | Feature UI | **Host contract** | All toggle/play/select callbacks | **High** | No | **Required** |
| S11 | `_planCardRow` + `_wrapPlanCardForDisplay` | 1735–1855 | **Stay on host** | Feature UI | **Time View drag** | Long-press drag, hour-grid scroll callbacks | **High** | No | **Required** |
| S12 | `_buildActiveDayBody` + `_buildDayContentForPageIndex` | 2203–2335 | `planning_day_list_body.dart` | Feature UI | **Routing** | `timeView`, `_sortMode`, all list builders | **High** | No | **Required** |
| S13 | `PlanningTimeViewHost` implementation block | 375–485 | **Do not extract** | Feature UI | **Interface** | Entire state | **High** | No | **Required** |
| S14 | Optimistic merge / display / stream builder | 793–905, 2358–2396 | **Stay in orchestrator** | Feature UI | **Optimistic** | — | **High** | No | **Required** |
| S15 | `_addTask`, `_injectSmartPlanTasks`, `_toggleDone` | 1216–1474 | **Stay until B2+** | Feature UI | CRUD | Brain writes | **High** | No | **Required** |

**Note:** Proposed names follow existing `widgets/planning_*` convention. Do **not** create `planning_time_view_host.dart` duplicate — host interface already exists.

---

## 6. Time View contract risk table

Product rules from `docs/UX_CONTRACT.md` / Time View modules. Column **Controlled by `planning_page.dart`?**

| Rule | Primary owner today | `planning_page.dart` involvement | Risk if split page first |
| :--- | :--- | :--- | :--- |
| Sequential single-column layout | `plan_time_view_layout.dart`, `time_view_canvas.dart` | Delegates via `timeView.buildHourGridView` only | **Low** if host stable |
| Drag midpoint insert before/after | `time_view_drag_controller.dart`, coordinator state | Host supplies `planCardRow`; no midpoint logic in page | **High** if S11 moved wrong |
| Cascade scheduling on drop | `plan_time_sequential_cascade.dart` (Brain), `planning_time_view.dart` | None direct | **Low** |
| No parallel / side-by-side cards | `plan_time_view_layout.dart` | None direct | **Low** |
| Time range on cards | `plan_time_labels.dart`, `_planningTaskCardForRow` | Sets `timelineTimeLabel` via host callback | **High** (S10) |
| Category stripe on Time View cards | `time_view_card_layer.dart` | Via `PlanCard` / render DTO | **Medium** |
| Compact / medium / expanded density | `plan_time_task_card.dart`, `plan_card.dart` | `_planningTaskCardForRow` passes task to `PlanCard` | **Medium** (S10) |
| Mobile long-press drag | `plan_time_gesture_contract.dart`, `_planCardRow` LongPressDraggable | **Implements** long-press drag wrapper L1792–L1837 | **High** (S11) |
| Resize zones | `time_view_resize_controller.dart` | None in page body | **Low** |
| Profile TZ projection | `DatabaseService.reprojectAllPlansForProfileTimezone`, `_settingsSub` L522–536 | **Triggers** reproject on settings stream | **High** (lifecycle) |
| Visible window / hour bounds | `planning_time_view.dart`, `planning_timeline_bounds_sheet.dart` | `timeView.timelineHourStart/End`; quick-add uses bounds L1209, L1258 | **Medium** |
| Date pager lock during drag | `PlanningTimeViewHost.onDatePagerLockChanged` | Host forward L418–421 | **High** (S13) |
| Bulk drag in Time View | `time_view_drag_controller.dart`, `plan_time_bulk_drag_test.dart` | Selection keys via host | **High** |

**Conclusion:** Time View **rendering/gesture core is already out** of `planning_page.dart`. Remaining page risk is the **`PlanningTimeViewHost` adapter** and **`_planCardRow` drag shell** — treat as **frozen boundary** until host tests exist.

---

## 7. Test coverage matrix

### 7.1 Existing tests (Planning-adjacent)

| Test file | Covers | Touches `planning_page.dart`? |
| :--- | :--- | :---: |
| `plan_time_drag_gesture_contract_test.dart` | Drag movement thresholds | No |
| `plan_time_sequential_cascade_test.dart` | Cascade normalization | No |
| `plan_time_view_layout_test.dart` | Block layout math | No |
| `plan_time_visible_window_test.dart` | Visible hour window | No |
| `plan_time_timezone_projection_test.dart` | TZ projection helpers | No |
| `plan_time_target_drop_test.dart` | Drop target intent | No |
| `plan_time_bulk_drag_test.dart` | Bulk drag offsets | No |
| `plan_time_duration_fidelity_test.dart` | Duration → px | No |
| `plan_time_fixed_time_policy_test.dart` | Fixed-time tags | No |
| `plan_recurrence_scope_test.dart` | Recurrence scope dialog / Brain | No |
| `planning_duplicate_plan_guard_test.dart` | Duplicate plan guard (Brain) | No |
| `planning_realtime_stream_lifecycle_test.dart` | Offline sync + stream stub | No |
| `widget_test.dart` | App smoke | Indirect (shell only) |

**Gap (partially closed B0):** `PlanningPage` now has widget smoke tests; selection/quick-add/host-fake tests still missing (§7.3 items 3–4).

| Test file | Status |
| :--- | :--- |
| `test/planning_page_host_contract_test.dart` | **Added B0** — mount, empty state, Time View host path, barrel exports |
| `test/planning_page_list_modes_test.dart` | **Added B0** — sort-mode shell, empty + seeded task, `PlanSortMode` indices |
| `test/planning_page_selection_test.dart` | **Deferred** |
| `test/planning_page_quick_add_test.dart` | **Deferred** |

### 7.2 Seam → test mapping

| Seam | Existing tests | Missing tests | Extract before tests? |
| :--- | :--- | :--- | :--- |
| S1 grouping helpers | None | Unit tests for sort/group maps | Optional |
| S2/S3 grouped lists | None | Widget test: category/tag buckets render | **No** |
| S4 reorder | None | Integration: reorder persists order | **No** |
| S5 frozen list | None | Golden/snapshot optional | Yes (low) |
| S6 select header | None | Widget tap exit/select-all | Optional |
| S7/S8 quick-add | None | Widget: add task optimistic + tag strip | **No** |
| S9 bulk | None | Bulk edit/delete selection contract | **No** |
| S10/S11 host cards | Time View unit tests partial | **Host fake implementing `PlanningTimeViewHost`** | **No** |
| S12 day body router | None | Mode switch renders correct child | **No** |
| S13 host interface | None | Contract test: coordinator calls host methods | **No** |

### 7.3 Recommended B0 tests (minimum)

1. **`test/planning_page_host_contract_test.dart`** — ✅ **Shipped B0** — `ShellLayoutScope` + `PlanningPage` mount; empty `PlanningDayEmptyState`; Time sort + optimistic task → scroll surface; barrel exports. *(Full fake `PlanningTimeViewHost` coordinator contract deferred.)*
2. **`test/planning_page_list_modes_test.dart`** — ✅ **Shipped B0** — empty day + sort taps; seeded optimistic task per `PlanSortMode`; persistence index unit check.
3. **`test/planning_page_selection_test.dart`** — **Deferred** — long-press enters select mode; bulk bar visible; FAB reserve callback (mock `ShellLayoutScope` if needed).
4. **`test/planning_page_quick_add_test.dart`** — **Deferred** — `_addTask` optimistic path (may require Brain test doubles).

### 7.4 Manual smoke checks (any extraction)

1. Plans tab → custom sort → reorder card → relaunch app → order persisted.
2. Category / Tags sort modes → buckets + reorder within bucket.
3. Time View → drag card → cascade → no overlap; midpoint insert before/after.
4. Quick-add with tags → task appears <100ms; offline queues if airplane mode.
5. Select mode → bulk edit date → bulk delete → exit select mode.
6. Date pager swipe while not dragging; pager locked during Time View drag.
7. Timezone change in Profile → Plans times reproject same day.

---

## 8. Staged decomposition plan

### Stage B0 — Tests only (required before non-trivial split) ✅ **Complete 2026-07-06**

| Item | Detail |
| :--- | :--- |
| **Target** | `test/planning_page_host_contract_test.dart`, `test/planning_page_list_modes_test.dart` (§7.3 items 1–2) |
| **Line reduction** | 0 |
| **Risk** | Low (test-only) |
| **Run** | `flutter test test/planning_page_*` + full suite — **255 passed** at B0 ship |
| **Rollback** | Revert test files |
| **B1 gate** | Low-risk split (S1/S5/S6) allowed **only if** B0 tests stay green; items 3–4 still recommended before B4/B3 |

### Stage B1 — Low-risk pure UI extraction ✅ **Complete 2026-07-06**

| Item | Detail |
| :--- | :--- |
| **Targets** | S1 → `widgets/planning_list_grouping.dart`; S6 → `widgets/planning_select_mode_header.dart`; S5 → `widgets/planning_frozen_day_list.dart` |
| **Est. reduction** | ~192 lines (`planning_page.dart` 2394 → ~2202) |
| **Risk** | **Low–medium** |
| **Run** | B0 tests + full suite green at ship |
| **Rollback** | Revert sibling files; restore methods inline |

### Stage B2 — Grouped list sections

| Item | Detail |
| :--- | :--- |
| **Targets** | S2, S3, S4 → `widgets/planning_category_grouped_list.dart`, `widgets/planning_tag_grouped_list.dart` (+ shared reorder callbacks) |
| **Est. reduction** | ~350–400 lines |
| **Risk** | **Medium** |
| **Prerequisite** | B0 list mode widget tests |
| **Run** | Full suite + manual §7.4 (1–2) |
| **Rollback** | Single revert commit |

### Stage B3 — Quick-add extraction

| Item | Detail |
| :--- | :--- |
| **Targets** | S7, S8 → extend `planning_quick_add_strip.dart` + optional `planning_quick_add_controller.dart` |
| **Est. reduction** | ~250–320 lines |
| **Risk** | **Medium** |
| **Prerequisite** | B0 quick-add test |
| **Run** | Manual §7.4 (4) |
| **Rollback** | Revert; prefs keys unchanged |

### Stage B4 — Selection / bulk extraction

| Item | Detail |
| :--- | :--- |
| **Targets** | S9 → `planning_selection_controller.dart` (mixin on state or composed helper) |
| **Est. reduction** | ~180–220 lines |
| **Risk** | **High** |
| **Prerequisite** | B0 selection tests + bulk sheet integration smoke |
| **Run** | Manual §7.4 (5) |
| **Rollback** | Revert immediately if bulk optimistic diverges |

### Stage B5 — Day body deduplication (not Time View core)

| Item | Detail |
| :--- | :--- |
| **Targets** | S12 → `planning_day_list_body.dart` — **single** mode switch shared by `_buildActiveDayBody` and `_buildDayContentForPageIndex` |
| **Est. reduction** | ~120–180 lines (dedupe) |
| **Risk** | **High** |
| **Prerequisite** | B0 mode router tests; **do not** move S10/S11/S13 |
| **Run** | Full §7.4 |
| **Rollback** | Revert; watch offscreen frozen vs active paths |

### Stage B6 — Docs + audit update

| Item | Detail |
| :--- | :--- |
| **Targets** | `docs/APP_STRUCTURE.md`, regenerate `APP_STRUCTURE_DETAILED.md`, `CHANGELOG.md` |
| **Risk** | None |

### Explicitly deferred (DO NOT SPLIT in Stage B)

| Area | Reason |
| :--- | :--- |
| `PlanningTimeViewHost` implementation (S13) | Coordinator coupling |
| `_planCardRow` / `_planningTaskCardForRow` (S10, S11) | Time View + list shared render path |
| Optimistic stream merge (S14) | 100ms UX law |
| `_addTask` / `_toggleDone` / recurrence delete (S15) | Brain write ordering |
| `plan_service.dart` | Stage D — separate queue |
| `planning_task_edit_sheet.dart` | Needs sheet test harness first |

### Stop conditions

1. Any `flutter test` regression in `plan_time_*` or new `planning_page_*` tests.
2. Time View drag/cascade manual check fails.
3. Optimistic quick-add or done-toggle exceeds ~100ms visible feedback.
4. Extraction requires changing `PlanningTimeViewHost` method signatures.
5. Offscreen frozen day list shows interactive controls or wrong sort mode.

---

## 9. Recommended first implementation prompt

> **Stage B0:** ✅ Complete — host + list-mode widget tests shipped.
> **Stage B1:** ✅ Complete — S1/S5/S6 extracted; B0 tests green.

Next split prompt (B2 — only if B0 green):

> **Stage B2:** Extract `_buildCategoryGroupedView` to `widgets/planning_category_grouped_list.dart` and tag grouped list (S3/S4) to `widgets/planning_tag_grouped_list.dart`. Zero behavior change. Run B0 tests + architecture guard + manual §7.4 items 1–2.

---

## 10. No-touch areas

- `lib/data/plan_service.dart`, `lib/data/plans/*`
- `lib/features/planning/time_view/*` gesture/layout/drag implementations (except host consumer tests)
- `lib/features/shared/planning_task_edit_sheet.dart`
- `plan_time_sequential_cascade.dart` semantics
- PocketBase schema / field names
- RAW_UI migration (`FilledButton`/`IconButton` in page — Stage E)

---

## 11. Related documents

| Doc | Link |
| :--- | :--- |
| Large-file queue | [`LARGE_FILE_DECOMPOSITION_PLAN_2026-07-06.md`](LARGE_FILE_DECOMPOSITION_PLAN_2026-07-06.md) §3.2 |
| Final audit | [`FINAL_STRUCTURE_AUDIT_2026-07-06.md`](FINAL_STRUCTURE_AUDIT_2026-07-06.md) |
| UX contract | `docs/UX_CONTRACT.md` |
| App structure | `docs/APP_STRUCTURE.md` §3.4 `planning/` |

---

*Report generated 2026-07-06. Production Dart unchanged.*
