# Structure Decomposition Audit — 2026-07-02

**Baseline SHA:** `54b9b54` (P0 Time View bulk drag complete)  
**Pass type:** P0-SAFE overnight structure refactor — safe extractions only; no Brain semantics / gesture / recurrence behavior changes.

---

## Top 20 large Dart files (baseline, physical lines)

| Lines | File | Recommendation |
|------:|------|----------------|
| 7272 | `lib/features/planning/planning_view.dart` | **SPLIT_NOW_REQUIRED** → partial tonight |
| 6457 | `lib/data/plan_service.dart` | **DO_NOT_TOUCH_NOW** (Brain optimistic + PB) |
| 4423 | `lib/data/record_service.dart` | **DO_NOT_TOUCH_NOW** |
| 3916 | `lib/features/shared/shared_widgets.dart` | **SPLIT_NOW_REQUIRED** → barrel + modules tonight |
| 3287 | `lib/data/category_service.dart` | **SPLIT_LATER** (Brain fuzzy match + PB) |
| 2767 | `lib/app_shell.dart` | **SPLIT_SAFE** (offline banner only tonight) |
| 2826 | `lib/core/widgets/plan_time_task_card.dart` | **SPLIT_SAFE** (metrics/density tonight) |
| 2036 | `lib/features/lists/lists_view.dart` | **SPLIT_LATER** (list CRUD + filters intertwined) |
| 1728 | `lib/features/categories/category_list_view.dart` | **SPLIT_LATER** |
| 1129 | `lib/features/timeline/timeline_view.dart` | **KEEP** (acceptable; date pager coupling) |
| 1084 | `lib/features/calendar/calendar_view.dart` | **SPLIT_LATER** |
| 1022 | `lib/data/profile_service.dart` | **DO_NOT_TOUCH_NOW** |
| 978 | `lib/data/plan_time_sequential_cascade.dart` | **KEEP** (already focused Brain math) |
| 964 | `lib/features/dev/component_lab_view.dart` | **KEEP** (admin-only lab) |
| 930 | `lib/core/services/desktop_stt_helper_service.dart` | **DO_NOT_TOUCH_NOW** (Desktop Voice) |
| 855 | `lib/data/voice_command_parser.dart` | **KEEP** |
| 870 | `lib/features/profile/profile_view.dart` | **SPLIT_SAFE** (settings sections tonight) |
| 799 | `lib/features/shared/voice_input_sheet.dart` | **SPLIT_LATER** |
| 778 | `lib/l10n/langs/ru.dart` | **KEEP** |
| 776 | `lib/l10n/langs/en.dart` | **KEEP** |

Also audited: `lib/data/database_service.dart` (843 lines) — **KEEP** (singleton root only).

---

## Target file map (post-refactor)

| Before | After primary modules |
|--------|-------------------------|
| `planning_view.dart` (7272) | `planning_view.dart` (~6022) + `planning/time_view/*`, `planning/settings/*`, `planning/widgets/*` |
| `shared_widgets.dart` (3916) | `shared_widgets.dart` (16-line barrel) + `activity_detail_sheet.dart`, `planning_task_edit_sheet.dart`, `timeline_record_edit_sheet.dart`, `edit_sheet/*`, `empty_state_placeholder.dart` |
| `plan_time_task_card.dart` (2826) | `plan_time_task_card.dart` (~2729) + `plan_card/plan_card_metrics.dart`, `plan_card/plan_time_card_density.dart` |
| `profile_view.dart` (870) | `profile_view.dart` (~542) + `profile/settings/*` |
| `app_shell.dart` (2767) | `app_shell.dart` (~2782) + `features/shared/offline_sync_status_bar.dart` |

---

## Safe splits performed tonight

| Item | Extracted | Commit stage |
|------|-----------|--------------|
| Time View interaction block + drag enums | `time_view/time_view_interaction_block.dart`, `time_view/time_view_drag_state.dart` | C |
| Fixed-time tags settings | `time_view/time_view_fixed_time_settings.dart` | C |
| Timeline bounds sheet | `settings/planning_timeline_bounds_sheet.dart` | C |
| Record-link / no-tags / default category+TZ search | `settings/plan_record_link_settings.dart`, `planning_no_tags_settings.dart`, `default_plan_*_search.dart` | C |
| Planning menu overlay, keep-alive, reorder settle | `widgets/planning_menu_overlay.dart`, `planning_day_card_list_keep_alive.dart`, `plan_card_reorder_settle.dart` | C |
| Edit sheet barrel + modules | `shared_widgets.dart` barrel + 11 modules | D |
| Plan card metrics/density | `plan_card/plan_card_metrics.dart`, `plan_time_card_density.dart` | E |
| Profile notification/security/account | `profile/settings/*.dart` | F |
| Offline sync banner | `features/shared/offline_sync_status_bar.dart` | H |

---

## Risky splits postponed (exact blockers)

| Target | Blocker |
|--------|---------|
| `plan_service.dart` / `record_service.dart` | Brain `part` files: optimistic cache, offline outbox, PB payloads, streams — any move risks P0 regressions |
| `planning_view.dart` main state (~5.7k lines) | Time View gesture state machine, bulk drag, cascade commit path — must not move until covered by isolated widget tests |
| `plan_time_task_card.dart` private `_PlanCard*` widgets | Tight layout geometry; extraction requires visual regression pass |
| `lists_view.dart` | Plan/list CRUD + filter state + optimistic toggles mixed in one `State` |
| `app_shell.dart` voice/desktop routing | Desktop Voice explicitly out of scope |
| `category_service.dart` | Fuzzy match + PB relation mapping in single extension |

---

## Stage order (executed)

1. **Preflight** — clean tree @ `54b9b54`; Time View tests green  
2. **Stage A** — this audit  
3. **Stage C** — Planning tail widgets  
4. **Stage D** — Shared edit sheets  
5. **Stage E** — Plan card metrics/density  
6. **Stage F** — Profile settings sections  
7. **Stage G** — **skipped** (Brain helpers)  
8. **Stage H** — Offline sync banner  
9. **Stage I** — APP_STRUCTURE / CLAUDE / CHANGELOG sync  
10. **Stage J** — analyze, test, web, APK, deploy  

---

## Behavior invariants preserved

- Time View tap/drag/resize/bulk gesture contract unchanged (extracted widgets only).  
- Duration fidelity (`scheduledSlotHeightPx`, min 38px / 10m) unchanged.  
- Cascade + fixed-time tag barriers unchanged.  
- Edit sheet autosave / explicit Save / recurrence scope unchanged.  
- Optimistic UI paths unchanged; no new direct PB writes from UI.  
- Desktop Voice files untouched.  
- PocketBase schema unchanged.

---

## Test coverage map

| Area | Tests |
|------|-------|
| Time View layout/density | `test/plan_time_view_layout_test.dart` |
| Target drop / cascade | `test/plan_time_target_drop_test.dart`, `test/plan_time_sequential_cascade_test.dart` |
| Gestures | `test/plan_time_drag_gesture_contract_test.dart` |
| Bulk drag | `test/plan_time_bulk_drag_test.dart` |
| Duration fidelity | `test/plan_time_duration_fidelity_test.dart` |
| Fixed-time tags | `test/plan_time_fixed_time_policy_test.dart` |
| Recurrence | `test/plan_recurrence_scope_test.dart` |
| Plan dup guard | `test/planning_duplicate_plan_guard_test.dart` |
| Edit autosave | `test/edit_sheet_autosave_test.dart` |
| Full suite | `flutter test` (248 tests) |

---

## Remaining oversized files (post-pass)

| Lines (approx) | File | Safe next split |
|---------------:|------|-----------------|
| 6022 | `planning_view.dart` | Header/controls/day-list clusters (no gesture state) |
| 2729 | `plan_time_task_card.dart` | Private layout widgets → `plan_card/plan_card_sections.dart` (needs golden/visual pass) |
| 2782 | `app_shell.dart` | More menu sheet only (avoid voice tab routing) |
| 6457 | `plan_service.dart` | Pure sort/scoring helpers only, with dedicated unit tests first |

---

## Verification (Stage J)

- `flutter analyze --no-fatal-infos --no-fatal-warnings`: green  
- Targeted Time View + edit tests: green  
- `flutter test`: 248/248  
- `architecture_guard.ps1`: warnings only (undocumented until APP_STRUCTURE sync)  
- `architecture_guard.ps1 -Strict`: green after APP_STRUCTURE documents new modules  

---

## Pass 2 (2026-07-02) — baseline `c200d77`

See extractions: `planning_page.dart`, `planning_page_shell.dart`, plan-card geometry/controls/sections, shell side-nav/settings/hydration bar. Brain services untouched. `planning_page.dart` remains ~5543 lines (Time View state machine stays monolithic by design).
