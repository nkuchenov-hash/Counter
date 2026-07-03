# Structure Decomposition — Pass 4A Plan Service (2026-07-03)

**Baseline SHA:** `1ef6c3c` (Pass 3B deployed)  
**Pass type:** Safe Brain decomposition — **`plan_service.dart` only**  
**Failed Pass 4 (full Brain regex split):** reverted; `scripts/pass4_brain_split.py` and `scripts/pass4_split_fast.py` **deleted**.

## Line counts

| File | Before | After |
| :--- | ---: | ---: |
| `lib/data/plan_service.dart` | 6457 | 5118 |
| **Moved to `lib/data/plans/`** | — | **1356** (6 part files) |
| **Net reduction in coordinator** | — | **−1339** |

### New part files (`part of '../database_service.dart'`)

| File | Lines | Extension / symbols |
| :--- | ---: | :--- |
| `plan_projection_types.dart` | 101 | `TimeModeProjectedPlan`, `PlanTimeModeProjection` |
| `plan_recurrence_helpers.dart` | 178 | `PlanRecurrenceExtension` — `expandRecurringPlans`, RRULE helpers |
| `plan_time_cascade_helpers.dart` | 196 | `PlanTimeCascadeExtension` + top-level duration consts, `planningWallEstimateSeconds` |
| `plan_tags_helpers.dart` | 30 | `PlanTagsExtension` — `_fetchPlanAndListTagCatalog`, `_syncPlanTagsPocket` |
| `plan_cache_helpers.dart` | 260 | `PlanCacheProjectionExtension` — dedupe/scrub; top-level link scoring |
| `plan_outbox_helpers.dart` | 591 | `PlanOutboxSyncExtension` — enqueue/flush/replay |

## What moved

1. **Time View projection type family** — `TimeModeProjectedPlan` + `PlanTimeModeProjection` kept together.
2. **Recurrence** — offline exception-date parse (top-level), `_collectMaterializedRecurrenceSuppressionKeys`, `_normalizeRruleStringForDecoder`, `_utcDateOnlyFromPlanDateKey`, `expandRecurringPlans`.
3. **Time cascade / duration** — `kDefaultPlanDurationMinutes`, snap/overload consts, tag duration resolution, sequential cascade (`normalizeSequentialPlanTimesForDay`, `applySequentialTimeViewCascadeIfNeeded`, collision nudge helpers).
4. **Tags** — plan/list tag catalog fetch + PocketBase `tags_link` sync helper.
5. **Cache / dedupe** — `dedupePlanningTasksForDisplay`, scrub helpers, title link scoring (`titlePlanLinkScore`, etc.).
6. **Outbox** — `flushPendingPlanMutations`, enqueue helpers, `_flushOnePlanOutboxEntry`, resolve/replay helpers.

## What intentionally stayed in `plan_service.dart`

- `extension PlanServiceExtension` — public coordinator API (CRUD, streams, optimistic overlay, wall-time reprojection, AI parse, alarms).
- Top-level Brain mutable state: `_allPlansUserCache`, `_planningOptimisticByDateKey`, stream hubs, debounce timers.
- Shared private helpers used across domains: `_planUtcInstants`, `_reprojectPlanningTaskWallTimes`, `_profileWallFromUtc`, `_findCachedPlanningTaskForEdit`, `_isJitVirtualPlanningTask`, pocket record mapping, CRUD network phases.
- Warm-window / render snapshot builders tightly coupled to cache + coordinator.

## Seams rejected (and why)

| Seam | Reason |
| :--- | :--- |
| Automated regex/line-based method split | Failed Pass 4 — broke multi-line signatures, duplicate extension members (~99 analyze errors). |
| Moving `_planUtcInstants` / reprojection cluster | Used by recurrence, Time View, CRUD, cache — single owner avoids ambiguous extension access. |
| Moving stream hub / `_PlanningDayStreamHub` | Tight coupling to top-level mutable state and notify debounce. |
| Splitting `record_service` / `category_service` / `profile_service` | Out of scope for Pass 4A. |
| UI references to `PlanServiceExtension` type | Updated `planning_page.dart` to call top-level `planningWallEstimateSeconds` instead. |

## UI / API notes

- **No public `DatabaseService` plan API removed** — methods remain on `DatabaseService.instance` via named extensions in the same library.
- **`planningWallEstimateSeconds`** — now a library top-level function in `plan_time_cascade_helpers.dart` (was `PlanServiceExtension` static).
- **Duration consts** — top-level in `plan_time_cascade_helpers.dart` for library-wide access.

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | 0 violations (after APP_STRUCTURE doc sync) |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| `flutter build web` | OK |
| `flutter build apk` arm64 | OK — `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |

## Not touched

- `record_service.dart`, `category_service.dart`, `profile_service.dart` (code)
- PocketBase schema / payloads
- Optimistic UI / outbox behavior
- Recurrence / Time View product behavior
- Desktop voice files
