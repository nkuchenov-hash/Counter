# Structure Decomposition — Pass 3B (2026-07-03)

**Baseline SHA:** `dd0b954` (Pass 3 accepted)  
**Pass type:** Finish planned UI module splits from Pass 3 deferred list  
**Brain split:** skipped

## Line counts (before → after)

| Target | Pass 3 after | Pass 3B after |
| :--- | ---: | ---: |
| `lists_view.dart` | 1685 | 1091 |
| `timeline_view.dart` | 713 | 624 |
| `planning_page.dart` | 2650 | 2632 |
| `plan_card_layouts.dart` | (in package) | tag widgets moved out |

## Modules created / completed

### Lists (`lib/features/lists/`)

- `lists_filters.dart` — tag/category filter chips, chip bar, settings sheet
- `lists_bulk_actions.dart` — select-mode header + bulk bottom bar
- `lists_inline_add.dart` — inline quick-add row
- `lists_empty_state.dart` — loading / filtered / no-category empty panels

### Timeline (`lib/features/timeline/`)

- `timeline_header_controls.dart` — list/stats segmented control + record input row

### Plan card package (`lib/core/widgets/plan_time_task_card/`)

- `plan_card_tags.dart` — `TimeViewTagsRow`, `TimeViewTagStack`, `TimeViewCompactTagPill`

### Planning coordinator trim

- `planning/widgets/planning_quick_add_strip.dart` — quick-add tag strip above inline field

## Ownership (unchanged product behavior)

| File | Role |
| :--- | :--- |
| `lists_view.dart` | Page coordinator / state owner |
| `timeline_view.dart` | Date pager + screen coordinator |
| `planning_page.dart` | Plans day body coordinator (Time View delegated to `time_view/`) |
| `plan_time_task_card.dart` | Public widget API barrel |

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | (see commit report) |
| `flutter analyze` | 0 errors |
| `flutter test` | (see commit report) |
| `flutter build web` | (see commit report) |
| `flutter build apk` arm64 | (see commit report) |

## Not moved (intentional)

- Brain `plan_service` / `record_service` / `category_service` / `profile_service`
- Time View gesture/drag/resize ownership in `time_view/`
- Optimistic UI / outbox / PocketBase payloads
