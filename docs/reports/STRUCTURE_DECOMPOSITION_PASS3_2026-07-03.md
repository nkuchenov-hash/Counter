# Structure Decomposition — Pass 3 (2026-07-03)

**Baseline SHA:** `858708b`  
**Pass type:** UI large-file splits (behavior-preserving)  
**Brain split:** skipped (separate pass)

## Line counts (before → after)

| Target | Before | After |
| :--- | ---: | ---: |
| `planning_page.dart` | 5287 | 2650 |
| `plan_time_task_card.dart` (widget) | 2003 | 433 (+ package modules) |
| `app_shell.dart` | 2335 | 2 (+ `shell/life_os_dashboard.dart` 555) |
| `lists_view.dart` | 2036 | 1685 |
| `timeline_view.dart` | 1129 | 713 |

## Modules created

### Planning Time View (`lib/features/planning/time_view/`)

- `planning_time_view_host.dart`, `planning_time_view_coordinator.dart`
- `planning_time_view.dart`, `time_view_canvas.dart`, `time_view_hour_grid.dart`
- `time_view_card_layer.dart`, `time_view_drag_controller.dart`, `time_view_resize_controller.dart`
- `time_view_drop_preview.dart`, `time_view_settings_sheet.dart`, `time_view_search_delegate.dart`

### Shell (`lib/shell/`)

- `life_os_dashboard.dart`, `shell_core.dart`, `shell_tab_host.dart`, `shell_edit_hosts.dart`
- `shell_more_menu.dart`, `shell_voice_routing.dart`, `shell_offline_banner.dart`, `shell_shared.dart`
- `shell_side_navigation.dart`, `profile_hydration_status_bar.dart`, `settings_page.dart`

### Plan card package (`lib/core/widgets/plan_time_task_card/`)

- `plan_time_task_card.dart`, `plan_card_layouts.dart`, `plan_card_progress.dart`, `plan_card_density.dart`
- Moved helpers from `plan_card/` with re-export stubs

### Timeline / Lists

- `timeline_day_page.dart`, `timeline_record_card.dart`, `timeline_helpers.dart`
- `lists_card.dart`, `lists_export.dart`

## Deferred to follow-up (low risk, not blocking)

- `lists_filters.dart`, `lists_bulk_actions.dart`, `lists_inline_add.dart`, `lists_empty_state.dart` — filter/bulk/inline logic remains in `lists_view.dart` coordinator
- `timeline_header_controls.dart` — list/stats header row remains in `timeline_view.dart`
- `plan_card_tags.dart` — tag row widgets remain in `plan_card_layouts.dart`

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | pass (0 violations) |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| `flutter build web` | green |
| `flutter build apk` arm64 | green |

## Kill-switch items checked

- Time View drag/drop/resize: unchanged (plan_time_* tests green)
- Brain services: not split
- Desktop voice files: moved only (part mixins); behavior unchanged
- Optimistic/outbox: untouched
