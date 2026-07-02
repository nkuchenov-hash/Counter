# Large File Split Blueprint — Stage E.0 (2026-07-02)

**Pass type:** Planning only — **no production Dart changes in this pass.**  
**Purpose:** Exact, repo-specific blueprint for splitting mixed-responsibility files into clean modules without changing behavior, performance, PocketBase logic, optimistic UI, offline sync, Time View, swipe, or design.

---

## Kill-switch status (read before E1)

| Condition | Status | Notes |
| :--- | :--- | :--- |
| Uncommitted runtime/UI work mixed with structure work | **BLOCKER** | Working tree has **53+ modified Dart files** (desktop voice, timezone picker, plan card, plan/record services, tests, Windows runner). Not a clean structure-only baseline. |
| `architecture_guard.ps1 -Strict` | **BLOCKER** | **49 violations** — mostly undocumented desktop-voice + timezone modules; 2 forbidden imports (`core→features`, `core→database_service`); 1 experiment filename (`desktop_voice_diag.dart`). |
| `flutter analyze` errors | **OK** | **0 errors** (94 warnings/info). |
| `APP_STRUCTURE` vs tree | **BLOCKER** | ~40+ `lib/` files exist on disk but are not in `docs/APP_STRUCTURE.md` (desktop voice stack, timezone catalog, navigation helper, etc.). |
| Release cleanup committed | **PARTIAL** | HEAD `afea362` includes prior structure work; subsequent desktop-voice/timezone work is **uncommitted**. |
| Web build baseline | **UNKNOWN** | Not re-run in this pass (docs-only). |

**E1 implementation must not start until:** desktop-voice/timezone modules are either documented in `APP_STRUCTURE` + strict guard green, or committed on a dedicated branch with a stable baseline. This blueprint assumes the **current tree** for line counts and symbols.

---

## 1. Baseline (current working tree)

| Metric | Value |
| :--- | :--- |
| **Baseline SHA** | `afea362` |
| **Working tree** | Dirty — 53 files changed (+2707/−990 lines in diff stat) |
| **Strict guard** | **FAIL** — 49 violations |
| **flutter analyze** | 0 errors, 94 issues (warnings/info) |
| **`lib/` Dart files** | 169 |
| **Files >800 lines** | 16 |
| **Files >1200 lines** | 9 |
| **Files >1800 lines** | 8 |

### Line-count tiers (`lib/**/*.dart`)

| Tier | Count | Files |
| :--- | :--- | :--- |
| **>1800** | 8 | `planning_view.dart` (6409), `plan_service.dart` (6223), `record_service.dart` (4423), `shared_widgets.dart` (3725), `category_service.dart` (3287), `app_shell.dart` (2767), `plan_time_task_card.dart` (2629), `lists_view.dart` (2036) |
| **1200–1800** | 1 | `category_list_view.dart` (1728) |
| **800–1200** | 7 | `timeline_view.dart` (1129), `calendar_view.dart` (1084), `profile_service.dart` (1022), `component_lab_view.dart` (964), `desktop_stt_helper_service.dart` (930), `voice_command_parser.dart` (855), `profile_view.dart` (826) |
| **700–799** | 3 | `voice_input_sheet.dart` (799), `en.dart` (764), `ru.dart` (766) |

---

## 2. Classification — every file >800 lines

Legend: **K** cohesive keep · **L** local private extraction · **S** split required · **E** exception · **C** coordinator exception

| File | Lines | Class | Role today | Mixed responsibilities | Importers (direct) | Imports (high level) | Boundary | Perf | UI risk | APP_STRUCTURE |
| :--- | ---: | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `features/planning/planning_view.dart` | 6409 | **S** | Plans screen + date PageView + list modes + **Time View canvas** + drag/resize/drop + settings sheets | UI shell, stream wiring, sort/group, hour grid, interaction physics, prefs, semicircle menus, category default-time UI | `app_shell.dart` | `data/`, `core/`, `shared_widgets`, `plan_time_task_card`, `plan_time_view_layout` | Low (feature) | **High** (swipe, warm window) | **Critical** (Time View, swipe) | Yes — new `features/planning/time_view/` subtree |
| `data/plan_service.dart` | 6223 | **S** | Brain plans domain (`part of database_service`) | Outbox flush, stream hub, cache/dedupe, recurrence, wall-time projection, CRUD, tags sync, alarms, AI parse, auto-schedule/cascade, stats hooks | *(via `DatabaseService` only)* | `models`, `core/time`, `cache`, outbox, `pb_config` | **High** (Brain) | **High** (streams, warm cache) | Medium (plan/list UI via streams) | Yes — `plan_*` part files under `data/plans/` |
| `data/record_service.dart` | 4423 | **S** | Brain records domain (`part of`) | Highlander start/stop, optimistic UI, realtime, timeline index/VM/cache, warm snapshots, ghost cleanup, outbox, CRUD | *(via `DatabaseService`)* | `cache`, outbox, `core/performance` | **High** | **Critical** (timeline boot, swipe) | High (timeline cards) | Yes — `data/records/` parts |
| `features/shared/shared_widgets.dart` | 3725 | **S** | Edit sheets + Omni-Picker bridge + checklist helpers | Router (`ActivityDetailSheet`), planning edit sheet (~1700 lines), timeline record sheet (~1100 lines), parallel/child bars, URL launch | `app_shell`, `planning_view`, `timeline_view`, `category_list_view`, `bulk_planning_edit_sheet` | `data/`, `core/widgets`, `l10n`, planning parsers | Medium | Low | **High** (all edit flows) | Yes — `features/shared/sheets/` |
| `data/category_service.dart` | 3287 | **S** | Categories CRUD + **record ghost/highlander helpers** + fuzzy match + stats paths | Category tree, PB ID map, record PATCH/DELETE resolution, ghost cleanup, default plan time | *(via `DatabaseService`)* | `category_fuzzy_match`, `core/time` | **High** | Medium | Medium | Yes — split category vs record-id bridge |
| `app_shell.dart` | 2767 | **C** | Shell coordinator: nav, voice, offline banner, edit hosts, desktop voice wiring | Auth gate, tab hosts, date header, FAB, speech, settings page, side nav, desktop hotkeys | `main.dart` | All major `features/*`, `data/`, `core/` | Medium | Medium | **High** (navigation, voice) | Partial — extract sub-widgets only |
| `core/widgets/plan_time_task_card.dart` | 2629 | **S** | Canonical plan card (list + Time View densities) | Tokens/constants, density math, 15+ private layout shells, controls, tags, progress | `plan_card.dart`, `planning_view`, `calendar_view`, `plan_time_view_layout`, `component_lab` | `models`, `core/tag`, `chip_component`, `plan_category_lookup` | Low | Low | **Critical** (Time View card visuals) | Yes — `plan_time_task_card/` package |
| `features/lists/lists_view.dart` | 2036 | **S** | Lists/backlog screen | Filters, cards, bulk actions, export, inline add, semicircle menu | `app_shell.dart` | `data/`, `core/widgets`, `shared_widgets` | Low | Low | Medium | Yes — `lists_*` modules |
| `features/categories/category_list_view.dart` | 1728 | **L** | Category manager screen | Editor sheets, tree, visibility, appearance — single feature but long | `app_shell.dart` | `data/`, `shared_widgets`, `category_recursive_tree` | Low | Low | Medium | Optional — extract editor sheets |
| `features/timeline/timeline_view.dart` | 1129 | **L** | Timeline screen + date PageView | Swipe wrapper, day body, record list, header strip (inlined) | `app_shell.dart` | `data/`, `core/widgets`, `shared_widgets` | Low | **High** (swipe, cache) | **High** | Optional — extract `timeline_day_body.dart` |
| `features/calendar/calendar_view.dart` | 1084 | **L** | Calendar month + plan dots | Month grid, plan fetch, navigation to planning | `app_shell.dart` | `data/`, `plan_time_task_card` | Low | Low | Medium | Optional — extract month grid widget |
| `data/profile_service.dart` | 1022 | **S** | Profile + tags catalog (`part of`) | Settings, timezone, tag CRUD, streams, admin flag | *(via `DatabaseService`)* | `models`, `core/time` | **High** | Low | Low (settings) | Yes — `profile_service.dart` + `tag_catalog_service.dart` |
| `features/dev/component_lab_view.dart` | 964 | **E** | Admin design lab | Demos only | `app_shell.dart` (admin) | `core/widgets` | Low | None | None (admin) | Defer until V7; optional split demos |
| `core/services/desktop_stt_helper_service.dart` | 930 | **E** | Desktop voice STT helper | New desktop track — document first | `app_shell`, voice stack | platform IO | **Violates** guard today | Medium | Low | **Blocker** — APP_STRUCTURE + guard first |
| `features/shared/voice_command_parser.dart` | 855 | **L** | Desktop/mobile voice command parse | Parser only — could stay if cohesive | voice widgets, `app_shell` | `data/smart_input_parser`? | Medium | Low | Low | Document; split only if parser + grammar diverge |
| `features/profile/profile_view.dart` | 826 | **L** | Profile settings screen | Timezone, notifications, desktop voice settings sections | `app_shell.dart` | `data/`, `core/widgets`, new desktop voice UI | Low | Low | Medium | Optional — extract desktop voice settings section (already partial files exist) |

### Files 700–799 (not mandatory but noted)

| File | Lines | Class | Notes |
| :--- | ---: | :--- | :--- |
| `l10n/langs/en.dart` | 764 | **E** | Canonical EN SSOT — **do not split**; folder rule in APP_STRUCTURE |
| `l10n/langs/ru.dart` | 766 | **E** | Canonical RU SSOT — **do not split** |
| `l10n/dictionary.dart` | 36 | **K** | Assembler only — **keep** |
| `voice_input_sheet.dart` | 799 | **L** | Extract mic UI vs submit bridge if voice stack grows |

---

## 3. Mandatory target — proposed final structure

### 3.1 `planning_view.dart` → coordinator + time modules

**Keep public entry points stable:** `PlanningSwipeWrapper`, `PlanningPage`.

```
lib/features/planning/
├── planning_view.dart              # Coordinator only (~800–1200 lines): PageView, tab mode, stream subscription, delegates
├── planning_day_body.dart          # Per-day list body + stream binding (_buildActiveDayBody, _buildDayContentForPageIndex)
├── planning_list_modes.dart        # Category/tag/custom/time grouped views + reorder
├── planning_quick_add.dart         # Inline add, tag strip, quick-bar prefs
├── planning_time_view_canvas.dart  # Hour grid, proportional canvas, stack layer (NO behavior change)
├── planning_time_drag.dart         # Drag, resize, drop preview, edge scroll (_TimelinePlanInteractionBlock, handles)
├── planning_time_prefs.dart        # Timeline bounds sheet, semicircle menu (move from bottom of file)
├── planning_sort_filter.dart       # _PlanSortMode, grouping, done-toggle moment
├── plan_time_view_layout.dart      # (existing) layout math
├── planning_day_start_prefs.dart   # (existing)
├── bulk_planning_edit_sheet.dart   # (existing)
└── smart_plan_sheet.dart           # (existing)
```

**Rules:** Date `PageView` ownership stays in `planning_view.dart`. Time View math unchanged — move code only. No changes to `kUseMountedDayStrip`, warm window calls, or `planningStream` lifecycle.

**Tests:** `plan_time_target_drop_test.dart`, `perf_shell_date_settle_test.dart`, manual Time View drag/resize/drop.

---

### 3.2 `plan_service.dart` → `data/plans/` parts

**Keep:** `extension PlanServiceExtension on DatabaseService` as the public Brain API surface (re-exported via `database_service.dart`).

```
lib/data/plans/
├── plan_service.dart               # part coordinator — imports + extension shell
├── plan_outbox.dart                # flush, enqueue, replay (~L423–1200)
├── plan_cache.dart                 # user cache, day cache, dedupe, scrub (~L32–1700)
├── plan_streams.dart               # _PlanningDayStreamHub, planningStream, notifyPlanningRefresh
├── plan_crud.dart                  # add/update/delete/bulk (~L4554–6300)
├── plan_recurrence.dart            # expandRecurringPlans, virt rows, exception_dates
├── plan_wall_time.dart             # wall projection, TZ logs, schedule keys (~L1744–2100)
├── plan_time_cascade.dart          # auto-schedule, overlap nudge (uses plan_time_sequential_cascade.dart)
├── plan_tags_alarms.dart           # tag sync, alarm reschedule
├── plan_ai_parse.dart              # parseTaskViaAiBackend, voice add
└── plan_stats_links.dart           # title similarity, plan-vs-fact hooks, calendar warm
```

**`database_service.dart` change:** `part 'plans/plan_service.dart';` (single part entry; inner files are `part of` plan_service.dart **or** nested parts — prefer one `part` file per concern all `part of '../database_service.dart'` to avoid breaking singleton access).

**Do not touch:** PocketBase payloads, `plan_id` vs system `id` resolution, optimistic `applyOptimisticPlanningTask`, outbox coalesce keys.

**Tests:** `planning_realtime_stream_lifecycle_test.dart`, plan duplicate tests, offline plan outbox manual.

---

### 3.3 `record_service.dart` → `data/records/` parts

```
lib/data/records/
├── record_service.dart             # extension shell
├── record_optimistic.dart          # highlander start/stop, shadow snapshots, rollback tokens
├── record_crud.dart                # writeRecord, updateRecord, delete, stop
├── record_realtime.dart            # PB subscription, reconnect
├── record_timeline_index.dart      # day index, recordsStream, getRecordsForDate
├── record_timeline_cache.dart      # warm window, rendered bodies, row VMs, prefetch
├── record_outbox.dart              # flushPendingRecordMutations
└── record_ghost.dart               # ghost cleanup, stale-open merge (if not moved to category)
```

**Do not touch:** Singleton running record, `_startAtomicTaskSequenceApplyLocalPrimary`, timeline boot path, `dateKey` / profile TZ bucketing.

**Tests:** timeline perf tests, record mutation outbox, manual start/stop/edit.

---

### 3.4 `category_service.dart` → category + record bridge split

```
lib/data/categories/
├── category_service.dart           # CRUD, tree, fuzzy match, default plan time
├── category_pb_mapping.dart        # slug ↔ PB row id, link payloads
└── category_record_bridge.dart     # _resolveRecordIdForStopOrDelete, ghost cleanup, highlander helpers
```

**Rationale:** ~40% of file is record-ID resolution and ghost logic mixed with category CRUD. Split reduces Brain cross-domain risk.

**Do not touch:** `category_id` int slugs, PB 15-char relation fields, fuzzy word-match law.

---

### 3.5 `shared_widgets.dart` → sheet modules

```
lib/features/shared/
├── activity_detail_sheet.dart      # Router only: ActivityDetailSheet, ActivityDetailKind, showAppDateTimePicker
├── sheets/
│   ├── planning_task_edit_sheet.dart    # _PlanningTaskEditSheet + checklist partition helpers
│   ├── timeline_record_sheet.dart     # _TimelineRecordSheetContent
│   ├── backlog_sub_items_panel.dart     # _BacklogSubItemsPanel
│   └── parallel_child_edit.dart         # _ParallelActivitiesTab, _ChildParallelEditBar
├── shared_widgets.dart             # Thin barrel export OR delete after import migration
├── omni_date_time_picker_dialog.dart    # (already in core — bridge stays in activity_detail_sheet)
└── voice_input_sheet.dart
```

**Public API unchanged:** `ActivityDetailSheet`, `showAppDateTimePicker`, `EditSheetAutosaveGate`.

**Tests:** widget tests for sheet open/save; manual edit record + edit plan + parallel child.

---

### 3.6 `plan_time_task_card.dart` → card package

**Public stable:** `PlanTimeTaskCard`, `PlanTimeTaskCardDensity`, `PlanCardSurface`, density helpers used by `plan_time_view_layout.dart`.

```
lib/core/widgets/plan_time_task_card/
├── plan_time_task_card.dart        # Public widget + state orchestration (~400 lines)
├── plan_time_tokens.dart           # kPlanTime* constants, PlanTimeCardVisualDensity enums
├── plan_time_density.dart          # planTimeCardVisualDensityForRenderedHeight, etc.
├── plan_time_layouts.dart          # _TimeViewVerySmall/Small/Medium/Large layouts
├── plan_time_controls.dart         # checkbox, play, menu painters
├── plan_time_tags_footer.dart      # tags row, footer, progress, watermark
└── plan_time_list_body.dart        # list-mode / _PlanCardInvariantBody
```

**Do not change:** pixel geometry, Figma tokens, density breakpoints, `PlanCategoryLookup` usage.

**Tests:** `component_lab_cards_demo`, visual snapshot manual on Time View + Lists.

---

### 3.7 `lists_view.dart`

```
lib/features/lists/
├── lists_view.dart                 # ListsPage coordinator
├── lists_filters.dart              # category/tag chips, active-first scroll
├── lists_cards.dart                # _BacklogPlanCard, _ListsQuadraticChip
├── lists_bulk_actions.dart         # export, bulk delete, selection mode
└── lists_inline_add.dart           # inline add + voice hook
```

---

### 3.8 `app_shell.dart` — coordinator exception

**Keep as shell** unless extractions are pure UI with no lifecycle risk:

| Extract candidate | Target | Risk |
| :--- | :--- | :--- |
| `_OfflineSyncStatusBar` | `features/shell/offline_sync_banner.dart` | Low |
| `_ProfileHydrationStatusBar` | `features/shell/profile_hydration_banner.dart` | Low |
| Voice dispatch (`_startVoiceInput`, submit helpers) | `features/shell/voice_dispatch.dart` | Medium |
| Desktop voice wiring | `features/shell/desktop_voice_shell.dart` | Medium — **after** APP_STRUCTURE documents desktop stack |
| `SettingsPage` | `features/profile/settings_page.dart` | Low |

**Never split in E-phase without explicit task:** auth gate, `IndexedStack` tab ownership, date header wiring, `PlanCategoryLookup` / `TagDisplayModeScope` hosts.

---

### 3.9 `timeline_view.dart` / `calendar_view.dart`

**Timeline** (1129 lines): extract `timeline_day_body.dart` (list + warm cache bind), keep `TimelineSwipeWrapper` + PageView in `timeline_view.dart`.

**Calendar** (1084 lines): extract `calendar_month_grid.dart`; keep month navigation in view.

---

### 3.10 `profile_service.dart`

```
lib/data/profile/
├── profile_service.dart            # settings, timezone, getProjectedToday, saveSettings
└── tag_catalog_service.dart        # fetch/create/patch/delete tags, streams
```

Both remain `part of database_service.dart`.

---

## 4. Split order (E1 → E3+)

### Prerequisites (E0.5 — before E1 code)

1. Commit or branch-isolate desktop-voice/timezone work.
2. Update `APP_STRUCTURE.md` for all `lib/core/services/desktop_voice_*`, `desktop_stt_*`, `profile_timezone_catalog.dart`, `timezone_quick_picker.dart`, etc.
3. Fix forbidden imports (`desktop_voice_record_submit`, `timezone_quick_picker`).
4. Rename `desktop_voice_diag.dart` → `desktop_voice_log.dart` (or move under `diagnostics/` with non-experiment name).
5. Re-run `architecture_guard.ps1 -Strict` → **exit 0**.

### E1 — **First implementation split (lowest risk)**

**Target:** `lib/data/profile_service.dart` → `profile_service.dart` + `tag_catalog_service.dart` (parts)

| Why lowest risk | Details |
| :--- | :--- |
| Brain-only | No widget tree, no swipe, no Time View |
| Clear domain seam | Tags catalog vs user profile settings already logically separate |
| Small blast radius | 1022 lines → two ~500-line parts |
| Easy verification | Tag manager, profile settings, tag chips on plans/lists |

**Must NOT touch in E1:** `plan_service`, `record_service`, `planning_view`, `plan_time_task_card`, offline outboxes, PocketBase payloads.

**Commit:** `refactor(data): split profile_service and tag_catalog_service parts`

---

### E2 — **Second split**

**Target:** `lib/features/shared/shared_widgets.dart` → `activity_detail_sheet.dart` + `sheets/*`

| Why second | Reduces largest feature-layer context file (3725 lines); classes already isolated |
| Risk | Edit-sheet regressions — mitigated by keeping router API identical |

**Must NOT touch:** Omni-Picker behavior, optimistic save paths, PocketBase field names.

**Commit:** `refactor(shared): extract edit sheets from shared_widgets`

---

### E3 — **Third split**

**Target:** `lib/core/widgets/plan_time_task_card/` private extraction

| Why third | High visual regression risk — needs Component Lab + Time View manual after E1/E2 stable |
| Risk | **Critical** for Time View card visuals — file-only moves, zero layout constant changes |

**Commit:** `refactor(core): split plan_time_task_card layout modules`

---

### E4–E8 (ordered — one per pass)

| Phase | Target | Defer if |
| :--- | :--- | :--- |
| **E4** | `lists_view.dart` modules | — |
| **E5** | `category_service.dart` → categories/ parts | Until record bridge semantics documented in DATA_MAP |
| **E6** | `record_service.dart` → records/ parts | Until E1–E3 green; highest timeline perf risk |
| **E7** | `plan_service.dart` → plans/ parts | Until record split proven; stream hub is fragile |
| **E8** | `planning_view.dart` time modules | **Last** — only after plan_service + plan_time_task_card splits; requires full swipe/Time View regression |

### Defer indefinitely (unless product changes)

| File | Reason |
| :--- | :--- |
| `l10n/langs/en.dart`, `ru.dart` | SSOT string tables — folder-level rule |
| `dictionary.dart` | 36-line assembler |
| `database_service.dart` root | Coordinator — only grows `part` list |
| `component_lab_view.dart` | Admin-only demos |
| `desktop_stt_helper_service.dart` | Document first; split after desktop voice ships |
| `main.dart` | Boot coordinator |

### Never split by line count alone

`app_shell.dart` stays coordinator unless extraction is a **named widget with zero behavior change**.

---

## 5. Risk matrix

| Split | Behavior | Perf | PB/optimistic | UI/visual | Reversibility |
| :--- | :--- | :--- | :--- | :--- | :--- |
| profile_service | Low | Low | Low | Low | Easy |
| shared_widgets sheets | Medium | Low | Medium | High | Easy (file moves) |
| plan_time_task_card | Low | Low | None | **Critical** | Easy |
| lists_view | Low | Low | Low | Medium | Easy |
| category_service | Medium | Medium | Medium | Low | Medium |
| record_service | Medium | **Critical** | **Critical** | High | Hard |
| plan_service | Medium | **Critical** | **Critical** | High | Hard |
| planning_view | Medium | **Critical** | Medium | **Critical** | Hard |
| app_shell partial | Medium | Medium | Low | High | Medium |

---

## 6. Tests required per split

| Phase | Automated | Manual smoke |
| :--- | :--- | :--- |
| **E0.5** | `architecture_guard -Strict`, `flutter analyze` | — |
| **E1 profile** | `profile_timezone_catalog_test.dart`, tag-related tests | Profile save TZ; tag manager CRUD; plan tag chips |
| **E2 sheets** | `widget_test.dart` (if stabilized), sheet unit tests if added | Edit plan; edit timeline record; checklist; parallel child |
| **E3 plan card** | `plan_time_target_drop_test.dart` | Time View densities; list card; calendar card; Component Lab cards |
| **E4 lists** | lists export tests if any | Filter chips; done toggle; inline add |
| **E5 category** | category fuzzy tests | Category create/edit; record category link |
| **E6 record** | `perf_*` timeline tests, record outbox | Start/stop; timeline swipe; running record singleton |
| **E7 plan** | `planning_realtime_stream_lifecycle_test.dart` | Planning day swipe; offline plan queue; recurring virtual edit |
| **E8 planning_view** | All perf swipe tests | Full Plans tab: all sort modes, Time View drag/resize/drop, date swipe |

**After each pass:** `architecture_guard -Strict` · `flutter analyze` · targeted tests · `flutter build web --release --base-href="/Counter/"` · manual smoke row for that phase.

---

## 7. APP_STRUCTURE changes required

| When | Changes |
| :--- | :--- |
| **E0.5 (blocker)** | Add entire desktop voice + timezone module tree to §3.3 `core/services/`, `core/widgets/timezone_quick_picker.dart`, `core/time/profile_timezone_catalog.dart`, `features/shared/desktop_voice_*`, `features/profile/desktop_voice_*` |
| **E1** | Add `data/profile/tag_catalog_service.dart` as `part` under Brain |
| **E2** | Add `features/shared/sheets/` table; demote `shared_widgets.dart` to barrel or remove |
| **E3** | Replace single `plan_time_task_card.dart` entry with `plan_time_task_card/` folder table |
| **E4–E8** | Matching folders per §3 |

**Do not add** debt/legacy/quarantine wording.

---

## 8. architecture_guard changes

| When | Change |
| :--- | :--- |
| **E0.5** | No rule changes — bring tree into compliance |
| **E1+** | Optional: allow `part` files in `data/plans/` via folder-level rule: `data/plans/*.dart` documented as `part of database_service` without listing every part filename |
| **E3** | Add folder rule for `core/widgets/plan_time_task_card/` |

---

## 9. Rollback plan

1. Each split lands as **one revertible commit** on a feature branch.
2. If post-split: analyze errors, strict guard fail, swipe jank, optimistic rollback, missing cards, or log storm → **revert that commit only**.
3. Restore last green: `architecture_guard -Strict` + targeted tests + manual smoke for previous phase.
4. Document failure in `CHANGELOG.md` `[rollback]` entry with file list and symptom.
5. Do not combine splits in one commit.

---

## 10. Top 10 split candidates (by value / risk ratio)

| Rank | File | Lines | Priority |
| :---: | :--- | ---: | :--- |
| 1 | `profile_service.dart` | 1022 | **E1** — lowest risk |
| 2 | `shared_widgets.dart` | 3725 | **E2** — highest context win |
| 3 | `plan_time_task_card.dart` | 2629 | **E3** — canonical card |
| 4 | `lists_view.dart` | 2036 | E4 |
| 5 | `category_list_view.dart` | 1728 | Optional local extraction |
| 6 | `category_service.dart` | 3287 | E5 |
| 7 | `record_service.dart` | 4423 | E6 |
| 8 | `plan_service.dart` | 6223 | E7 |
| 9 | `planning_view.dart` | 6409 | E8 — last |
| 10 | `app_shell.dart` | 2767 | Partial extractions only after desktop voice documented |

---

## 11. Summary for implementers

- **Blueprint path:** `docs/reports/LARGE_FILE_SPLIT_BLUEPRINT_2026-07-02.md`
- **Recommended first code split (E1):** `profile_service.dart` / `tag_catalog_service.dart`
- **Why E1 is lowest risk:** Brain-only, no UI/swipe/Time View, clear tag vs profile seam, small file, easy smoke tests
- **Do not touch in E1:** All UI screens, `plan_service`, `record_service`, `planning_view`, `plan_time_task_card`, PocketBase schema, outboxes, optimistic paths
- **Block E1 until:** Strict guard green + APP_STRUCTURE documents current desktop-voice/timezone tree

---

*Generated: 2026-07-02 · Stage E.0 planning pass · No production Dart changes.*
