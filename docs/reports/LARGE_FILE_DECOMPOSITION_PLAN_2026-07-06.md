# Large File Decomposition Plan — 2026-07-06

**Project:** Counter / Life OS  
**Pass type:** Report only — **no refactors, no file moves, no production Dart changes.**  
**Baseline:** [`FINAL_STRUCTURE_AUDIT_2026-07-06.md`](FINAL_STRUCTURE_AUDIT_2026-07-06.md) verdict **ACCEPTED WITH WATCHLIST**  
**Governing law:** Structure Growth Law — `docs/ARCHITECTURE.md` §11, `docs/APP_STRUCTURE.md` §7

---

## 1. Executive verdict

Large files are **expected after Pass 3–4D** but **must not keep growing**. The repo is structurally healthy (architecture guard **0 violations**), yet six watchlist files plus several Brain domain parts exceed safe single-file scope.

**Queue verdict:** **STAGED DECOMPOSITION RECOMMENDED** — not urgent blockers, but **`plan_service.dart` (5118 lines)** and **`planning_page.dart` (2394 lines)** should not receive major new features without a split plan.

| Priority | Action |
| :--- | :--- |
| **Now** | Use this queue before adding features to watchlist files |
| **Stage A first** | Low-risk UI extractions (calendar grids, category sheets) |
| **Stage D last** | `plan_service.dart` — high risk; needs test harness expansion first |
| **Do not split yet** | Coordinators under ~900 lines, l10n catalogs, Component Lab |

---

## 2. Threshold scan (tracked Dart)

| Threshold | Count | Notes |
| :--- | ---: | :--- |
| **≥600 lines** | 31 | Includes 2 l10n files + 1 large test |
| **≥1000 lines** | 8 | All listed in §3 |
| **≥2000 lines** | 2 | `plan_service.dart`, `planning_page.dart` |

### Top 10 largest tracked Dart files

| Rank | Lines | Path | Layer |
| ---: | ---: | :--- | :--- |
| 1 | 5118 | `lib/data/plan_service.dart` | Brain coordinator `part` |
| 2 | 2394 | `lib/features/planning/planning_page.dart` | Feature UI |
| 3 | 1727 | `lib/features/categories/category_list_view.dart` | Feature UI |
| 4 | 1718 | `lib/features/shared/planning_task_edit_sheet.dart` | Feature UI (shared sheet) |
| 5 | 1377 | `lib/data/records/record_crud.dart` | Brain domain `part` |
| 6 | 1084 | `lib/features/calendar/calendar_view.dart` | Feature UI |
| 7 | 1072 | `lib/features/shared/timeline_record_edit_sheet.dart` | Feature UI (shared sheet) |
| 8 | 1018 | `lib/features/lists/lists_view.dart` | Feature UI |
| 9 | 978 | `lib/data/plan_time_sequential_cascade.dart` | Brain helper |
| 10 | 964 | `lib/features/dev/component_lab_view.dart` | Dev/admin UI |

---

## 3. Per-file responsibility maps

### 3.1 `lib/data/plan_service.dart` — **5118 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Brain — `part of database_service.dart`; `PlanServiceExtension` |
| **Public surface** | `planningStream`, `addPlanningTask`, `updatePlanningTask`, `deletePlanningTask*`, `bulkUpdatePlans`, `fetchBacklogPlans`, `getBasicDayStats`, `planningDayTasksSnapshot`, warm-window boot APIs, AI parse entry points, recurrence-scope mutations |
| **Private state** | `_allPlansUserCache`, `_planningOptimisticByDateKey`, `_PlanningDayStreamHub` map, reorder debounce, realtime subscribe handles, warm snapshot caches |
| **Domain sections (approx.)** | (1) Stream hub ~L44–178 · (2) Optimistic merge + user cache ~L178–1360 · (3) Wall-time TZ projection ~L1057–1260 · (4) Warm window / boot perf ~L1260–2260 · (5) Fetch/group/stats ~L2350–2700 · (6) AI parse ~L2778–2984 · (7) CRUD + voice add ~L3001–3640 · (8) Order sync ~L3641–3808 · (9) Update/delete/bulk ~L4417–5228 · (10) Realtime ~L5253–5418 |
| **Imports** | Via `database_service.dart` barrel — models, pb_config, local_sync, plans/* parts, notifications |
| **Imported by** | Only `database_service.dart` (`part`); UI via `DatabaseService.instance.*` |
| **Tests** | Indirect: `planning_realtime_stream_lifecycle_test.dart`, `planning_duplicate_plan_guard_test.dart`, `plan_recurrence_scope_test.dart`, `plan_time_*` tests — **no dedicated CRUD integration suite** |
| **User-visible** | Plans tab, Lists, Calendar indicators, Time View data, plan alarms, offline plan queue |
| **Why it grew** | Single coordinator retained post–Pass 4B; warm-window perf, recurrence, backlog, AI parse, realtime added without further `part` split |
| **Must not change in split** | Optimistic UI ordering, offline outbox coalescing, singleton plan stream hub keys, wall-day projection semantics, Highlander-adjacent plan→record category resolution |
| **Classification** | **risky split, needs dedicated test coverage first** (borderline **blocker** for blind line-count splits) |

**Existing `lib/data/plans/` parts (already extracted):**  
`plan_cache_helpers.dart`, `plan_outbox_helpers.dart`, `plan_projection_types.dart`, `plan_recurrence_helpers.dart`, `plan_tags_helpers.dart`, `plan_time_cascade_helpers.dart`

**Proposed target splits (justify by seams):**

| New `part` file | Move from coordinator | Rationale |
| :--- | :--- | :--- |
| `plans/plan_stream_helpers.dart` | `_PlanningDayStreamHub`, `planningStream`, hub ref-count, `_tasksController` wiring | Isolated stream lifecycle; test exists (`planning_realtime_stream_lifecycle_test`) |
| `plans/plan_warm_window_helpers.dart` | `preparePlansMountedWindowBoot`, `restorePlansWarmSnapshotsFromDiskAtBoot`, `persistPlansWarmSnapshotsToDisk`, body prebuild | P0 perf island; failures = boot jank only |
| `plans/plan_crud_network.dart` | `_patchPlanUpdateNetworkPhase`, `_deletePlanNetworkPhase`, `_resolvePlanRestId` | Pure network phases; pairs with outbox |
| `plans/plan_bulk_helpers.dart` | `bulkUpdatePlans`, `deletePlanningTasksBulk` | Bulk UX path; separate from single-row CRUD |
| `plans/plan_materialization_helpers.dart` | Recurrence scope update/delete wrappers ~L5006+, JIT merge helpers tied to `expandRecurringPlans` | Coupled to `plan_recurrence_helpers.dart` |
| `plans/plan_alarm_helpers.dart` | `_requestPlanAlarmReschedule`, `_reschedulePlanAlarmsWork` | Device notification bridge |
| `plans/plan_realtime_helpers.dart` | § Plans realtime ~L5253+ | Mirrors `record_realtime.dart` pattern |
| `plans/plan_list_mode_helpers.dart` | Backlog snapshot, `_filterBacklogFromAll`, list/backlog optimistic merge | Shared Plans + Lists Brain path |

**Keep in coordinator (~800–1200 lines target):** public CRUD entry (`addPlanningTask`, `updatePlanningTask`), cache orchestration calling moved helpers, `applyOptimisticPlanningTask`, order-sync debounce entry points.

---

### 3.2 `lib/features/planning/planning_page.dart` — **2394 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Feature UI — Plans tab day body |
| **Public symbols** | `PlanningPage`, `_PlanningPageState` (implements `PlanningTimeViewHost`) |
| **UI sections** | Quick-add + tag bar · bulk selection mode · list vs Time View mode switch · category/tag grouped list layouts · card reorder · done-toggle holds · smart plan inject · day PageView body · `PlanningTimeViewHost` delegation |
| **Imports** | 40+ planning/time_view/widgets + Brain + core widgets |
| **Imported by** | `planning_page_shell.dart`, `planning_view.dart` (export), `planning_time_view_host.dart` |
| **Tests** | Gesture/layout tests hit extracted modules (`plan_time_*`, `planning_time_view`) — **no widget test on `PlanningPage` directly** |
| **User-visible** | Entire Plans tab task list, quick-add, bulk edit entry, play→record |
| **Why it grew** | Time View extracted to `time_view/*` but list-mode + selection + quick-add stayed |
| **Must not change** | `PlanningTimeViewHost` contract, optimistic merge with stream, 100ms tap feedback, bulk bar shell reserve |
| **Classification** | **split on next feature touch** (medium risk) |

**Already extracted (do not re-merge):** `planning_page_shell.dart`, `time_view/*`, `widgets/planning_*`, settings sheets.

**Proposed target files:**

| File | Responsibilities | Est. lines |
| :--- | :--- | ---: |
| `planning_selection_controller.dart` | `_selectedPlanKeys`, select-all, bulk bar sync, `_exitSelectMode` | ~200 |
| `planning_task_list_section.dart` | `_buildFrozenPlanCardList`, category/tag grouped views, reorder handlers | ~450 |
| `planning_quick_add_controller.dart` | Quick-add strip state, tag merge, smart plan, `_addTask` | ~350 |
| `planning_day_list_body.dart` | `_buildActiveDayBody`, `_buildDayContentForPageIndex`, stream subscription glue | ~400 |
| `planning_page.dart` (slim) | `build`, mode switch, `PlanningTimeViewHost` forwards, lifecycle | ~900 |

---

### 3.3 `lib/features/categories/category_list_view.dart` — **1727 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Feature UI — Categories (More tab) |
| **Public symbols** | `CategoriesPage`, `CategoryRowWidget`, `CategoryEditorSheet`, `TagInputField`, `_CategoryAppearanceSheet` |
| **Sections** | Tree row rendering · depth layout math · appearance sheet · full editor sheet · page state/orchestration |
| **Imported by** | `life_os_dashboard.dart`, `category_recursive_tree.dart` |
| **Tests** | None dedicated |
| **User-visible** | Category tree, create/edit/archive, default plan time |
| **Why it grew** | Multiple sheets co-located with list page |
| **Must not change** | Category save paths through Brain, breadcrumb layout, archive semantics |
| **Classification** | **safe to split now** (Stage A) for sheet widgets |

**Proposed splits:**

| File | Move |
| :--- | :--- |
| `category_row_widget.dart` | `CategoryRowWidget`, `_CategoryDepthLayout`, `CategoryBandLayout` |
| `category_editor_sheet.dart` | `CategoryEditorSheet` + state (note: separate from `create_category_dialog.dart`) |
| `category_appearance_sheet.dart` | `_CategoryAppearanceSheet` |
| `category_tag_input_field.dart` | `TagInputField` |
| `category_list_view.dart` | `CategoriesPage` orchestration only (~600–800 lines) |

---

### 3.4 `lib/features/shared/planning_task_edit_sheet.dart` — **1718 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Feature UI — shared edit sheet (Plans/Lists via `ActivityDetailSheet`) |
| **Public** | `PlanningTaskEditSheet`, `PlanningTaskEditSheetState` |
| **Sections** | Quill notes · checklist · schedule/recurrence tabs · tag strip · autosave gate · parallel record panels hook |
| **Imports** | Already uses `edit_sheet/*` helpers (partial Pass 3) |
| **Imported by** | `activity_detail_sheet.dart`, `shared_widgets.dart` export |
| **Tests** | None on sheet; UX contract in `docs/UX_CONTRACT.md` |
| **User-visible** | Plan/list edit sheet — save, recurrence scope, Omni-Picker |
| **Must not change** | Optimistic save order, recurrence scope dialog flow, no auto-save law for notes |
| **Classification** | **risky split, needs dedicated test coverage first** |

**Proposed splits (after tests):**

| File | Move |
| :--- | :--- |
| `edit_sheet/planning_task_schedule_tab.dart` | Date/time, recurrence UI |
| `edit_sheet/planning_task_notes_tab.dart` | Quill + toolbar |
| `edit_sheet/planning_task_checklist_tab.dart` | Checklist controllers |
| `planning_task_edit_sheet.dart` | Tab host + save/delete orchestration |

---

### 3.5 `lib/features/lists/lists_view.dart` — **1018 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Feature UI — Lists tab |
| **Public** | `ListsPage` |
| **Sections** | Chip bar (category/tag) · backlog stream · inline add · bulk actions · export |
| **Already split** | `lists_card.dart`, `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart`, `lists_export.dart` |
| **Imported by** | `life_os_dashboard.dart` |
| **Tests** | None dedicated |
| **Classification** | **monitor only** — split only if Lists feature work adds >150 lines |

**Optional on-touch split:** `lists_chip_bar.dart` (~200 lines) for category/tag chip persistence.

---

### 3.6 `lib/features/calendar/calendar_view.dart` — **1084 lines**

| Field | Detail |
| :--- | :--- |
| **Owner layer** | Feature UI — Calendar tab |
| **Public** | `CalendarView` |
| **Private widgets** | `_CalendarChromeHeader`, `_MonthGrid`, `_WeekPlannerGrid`, `_DayEventList`, `_SelectedDayTaskPanel`, … |
| **Imported by** | `life_os_dashboard.dart` |
| **Tests** | None |
| **Classification** | **safe to split now** (Stage A) — private widgets are self-contained |

**Proposed splits:**

| File | Move |
| :--- | :--- |
| `calendar_month_grid.dart` | `_MonthGrid`, `_MonthDayCell` |
| `calendar_week_grid.dart` | `_WeekPlannerGrid`, `_WeekCompactStrip` |
| `calendar_day_panel.dart` | `_SelectedDayTaskPanel`, `_DayEventList`, `_CalendarEventPill` |
| `calendar_chrome_header.dart` | `_CalendarChromeHeader` |
| `calendar_view.dart` | State + mode switch + stream wiring (~350 lines) |

---

### 3.7 Other ≥600-line files (summary)

| Lines | Path | Classification | Notes |
| ---: | :--- | :--- | :--- |
| 1377 | `lib/data/records/record_crud.dart` | **risky split** | Record start/stop/update network; mirror plan split after record tests expanded |
| 1072 | `timeline_record_edit_sheet.dart` | **split on next feature touch** | Parallel to planning edit sheet |
| 978 | `plan_time_sequential_cascade.dart` | **monitor only** | Domain-heavy; has `plan_time_sequential_cascade_test.dart` |
| 964 | `component_lab_view.dart` | **OK large reference** | Admin-only; intentional demo surface |
| 930 | `desktop_stt_helper_service.dart` | **monitor only** | Platform voice bridge |
| 914 | `category_crud.dart` | **watchlist** | Brain; split with category feature work |
| 901 | `record_timeline_vm.dart` | **watchlist** | Timeline perf; tightly coupled to cache |
| 855 | `plan_card_layouts.dart` | **OK large reference** | Canonical card layouts — parameter variations |
| 855 | `voice_command_parser.dart` | **monitor only** | Parser tables |
| 854 | `record_service.dart` | **OK large coordinator** | Post–Pass 4 thin coordinator |
| 799 | `voice_input_sheet.dart` | **split on next feature touch** | Voice UX |
| 783 | `planning_time_view.dart` | **monitor only** | Already extracted from planning_page |
| 778/776 | `l10n/langs/*.dart` | **OK large reference** | Translation catalogs — never split by feature |
| 771 | `desktop_voice_widget.dart` | **monitor only** | Has `desktop_voice_widget_e2e_test.dart` |
| 754 | `database_service.dart` | **OK large coordinator** | Singleton host — **do not split** per APP_STRUCTURE §8 |
| 705 | `models/category.dart` | **monitor only** | Model + tree helpers |
| 703 | `shell_voice_routing.dart` | **monitor only** | Shell voice dispatch |
| 697 | `main.dart` | **monitor only** | Boot wiring |
| 626 | `category_record_bridge.dart` | **monitor only** | Brain bridge |
| 623 | `plan_vs_fact_tab.dart` | **split on next feature touch** | Stats UI |
| 621 | `db_core.dart` | **OK** | Bootstrap `part` |
| 615 | `smart_plan_sheet.dart` | **monitor only** | Already separate sheet |
| 942 | `test/plan_time_target_drop_test.dart` | **OK** | Large test file |

---

## 4. No-touch / risky areas

| Area | Why risky |
| :--- | :--- |
| `plan_service.dart` optimistic + outbox interleaving | Wrong order → duplicate plans or lost offline mutations |
| `planning_page.dart` `PlanningTimeViewHost` | Time View coordinator assumes host methods stable |
| Edit sheets (plan + timeline) | UX_CONTRACT save/recurrence/autosave rules |
| `record_crud.dart` start/stop atomic sequence | Highlander + optimistic shadow |
| `database_service.dart` root | Singleton field declarations must stay with parts |
| Warm-window plan boot flags | Performance kill-switch law — test on web + Android |

---

## 5. Risk and test matrix (proposed splits)

| Split | Risk | Tests before | Tests after | Manual smoke | Failure modes | Rollback |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Calendar grid extract | **Low** | — | `flutter test`; open Calendar month/week | Calendar tab: select day, play plan, indicators | Missing import, layout overflow | Revert single PR |
| Category sheets extract | **Low** | — | `flutter test`; Categories CRUD | Create/edit category, appearance, archive | Sheet route breaks | Revert |
| Planning selection/list extract | **Medium** | Add widget test for bulk select | `plan_time_*` + planning tests | Plans: select, bulk move, reorder | Bulk bar overlap FAB | Revert; keep host interface |
| Planning quick-add extract | **Medium** | — | planning tests | Quick-add, tags, smart plan | Order index wrong | Revert |
| `plan_service` stream part | **High** | Extend realtime lifecycle test | Full `flutter test` + offline banner | Plans swipe days, Lists backlog, offline toggle | Duplicate stream events, stale cache | Feature flag or revert; flush outboxes |
| `plan_service` CRUD parts | **High** | New Brain integration tests for add/update/delete queue | Same + manual offline | Start plan, edit, delete, recurrence | Outbox coalesce break | Revert entire Stage D |
| Edit sheet tab split | **High** | Sheet golden or widget tests | UX manual script | Edit plan: notes, recurrence, save | Autosave regression | Revert |

---

## 6. Staged execution queue

### Stage A — Low-risk UI splits (independently shippable)

1. `calendar_view.dart` → grid/header/part files (§3.6)  
2. `category_list_view.dart` → row + editor + appearance files (§3.3)  

**Exit criteria:** `architecture_guard -Strict` green; Calendar + Categories manual smoke; no behavior change.

### Stage B — Medium-risk Planning UI splits

3. `planning_selection_controller.dart` + `planning_task_list_section.dart`  
4. `planning_quick_add_controller.dart` + slim `planning_page.dart`  

**Exit criteria:** Stage A + Plans tab smoke (list mode, bulk, quick-add, play); run existing `plan_time_*` tests.

### Stage C — Brain/Data split prep (no production moves yet)

5. Document extension method → part file map for `plan_service.dart`  
6. Add Brain tests: `addPlanningTask` offline enqueue, `updatePlanningTask` optimistic rollback, `planningStream` hub refcount  
7. Add optional widget test: `PlanningPage` bulk select (minimal)  

**Exit criteria:** New tests green; team sign-off on part boundaries table (§3.1).

### Stage D — Brain/Data actual split

8. Extract `plans/plan_stream_helpers.dart` + `plans/plan_realtime_helpers.dart`  
9. Extract `plans/plan_warm_window_helpers.dart` (perf-sensitive — ship alone)  
10. Extract CRUD network + bulk + materialization parts incrementally (one PR per part)  

**Exit criteria:** Full test suite; offline plan queue manual; web + Android boot timing unchanged.

### Stage E — RAW_UI / V7 (orthogonal but related)

11. Migrate raw `FilledButton`/`IconButton` in feature files per `DESIGN_SYSTEM_INVENTORY.md`  
12. Touch large files only when migrating that screen’s buttons  

**Exit criteria:** Component Lab acceptance; guard RAW_UI warnings trend down.

---

## 7. Files — split policy summary

| Policy | Files |
| :--- | :--- |
| **Do not split yet** | `database_service.dart`, `record_service.dart`, `db_core.dart`, `l10n/langs/*`, `component_lab_view.dart`, `plan_card_layouts.dart` |
| **Split only when touched by product work** | `lists_view.dart`, `planning_time_view.dart`, `smart_plan_sheet.dart`, `voice_input_sheet.dart`, `plan_vs_fact_tab.dart` |
| **Safe to split first (Stage A)** | `calendar_view.dart`, `category_list_view.dart` (sheet widgets) |
| **Split on next Plans feature** | `planning_page.dart` |
| **Split after test prep (Stage C→D)** | `plan_service.dart`, `record_crud.dart` |
| **Split after edit-sheet tests** | `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart` |

---

## 8. Recommended first implementation prompt

Use this when starting Stage A:

> **Stage A — Calendar grid decomposition**  
> Extract `_MonthGrid`, `_WeekPlannerGrid`, and `_CalendarChromeHeader` from `lib/features/calendar/calendar_view.dart` into `lib/features/calendar/calendar_month_grid.dart`, `calendar_week_grid.dart`, and `calendar_chrome_header.dart`. No behavior changes. Keep `CalendarView` public API unchanged. Run `flutter test`, `architecture_guard.ps1 -Strict`, manual Calendar tab smoke (month/week toggle, day select, play plan).

Alternative first prompt (Categories):

> **Stage A — Category sheet decomposition**  
> Move `CategoryEditorSheet` and `_CategoryAppearanceSheet` from `category_list_view.dart` into dedicated files under `lib/features/categories/`. Export symbols used by `category_recursive_tree.dart` if any. No Brain changes.

---

## 9. Verification (this report pass)

Recorded at commit time:

- `flutter analyze --no-fatal-infos --no-fatal-warnings`
- `flutter test`
- `architecture_guard.ps1 -Strict`

No production Dart modified. `APP_STRUCTURE_DETAILED.md` not regenerated (no tree change).

---

## 10. Cross-references

- Structure audit: [`FINAL_STRUCTURE_AUDIT_2026-07-06.md`](FINAL_STRUCTURE_AUDIT_2026-07-06.md)  
- Growth law: `docs/ARCHITECTURE.md` §11  
- Do-not-split table: `docs/APP_STRUCTURE.md` §8  
- Planning tests map: `test/plan_time_*`, `test/planning_*`
