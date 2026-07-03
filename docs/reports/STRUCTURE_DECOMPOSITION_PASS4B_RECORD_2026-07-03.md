# Structure Decomposition — Pass 4B Record Service (2026-07-03)

**Baseline SHA:** `5a8ba87` (Pass 4A deployed)  
**Pass type:** Safe Brain decomposition — **`record_service.dart` only**  
**Prior pass:** Pass 4A split `plan_service.dart` into `lib/data/plans/*`.

## Line counts

| File | Before | After |
| :--- | ---: | ---: |
| `lib/data/record_service.dart` | 4423 (guard) / 4593 (raw) | **901** |
| **Moved to `lib/data/records/`** | — | **3719** (8 part files) |
| **Net reduction in coordinator** | — | **−3522** |

### New part files (`part of '../database_service.dart'`)

| File | Lines | Extension / role |
| :--- | ---: | :--- |
| `record_crud.dart` | 1401 | `RecordCrudExtension` — `writeRecord`, `updateRecord`, `stopRecordByDocId`, delete, network PATCH phases |
| `record_timeline_vm.dart` | 953 | `RecordTimelineVmExtension` — day index, warm window, row VM builders, adjacent warmup |
| `record_outbox_helpers.dart` | 555 | `RecordOutboxSyncExtension` — enqueue/flush/replay, Highlander server phase |
| `record_overlap_helpers.dart` | 437 | `RecordOverlapExtension` — Highlander local apply, singleton reconcile, overlap probes, `stopAllRunningRecords` |
| `record_cache_helpers.dart` | 120 | `RecordCacheProjectionExtension` — per-day filter, `recordsStream`, display times |
| `record_optimistic.dart` | 129 | `RecordOptimisticExtension` — optimistic stop overlay, sacred handoff |
| `record_realtime.dart` | 103 | `RecordRealtimeExtension` — PB records realtime subscribe/unsubscribe |
| `record_ghost_cleanup.dart` | 21 | `RecordGhostCleanupExtension` — `_pruneRecord404DeadletterUsingCache` |

Top-level library helpers moved with timeline VM: `_kTimelineAdjVmWarmChunkSize`, `_kTimelineAdjVmWarmMaxRecords`.

## What moved

1. **CRUD** — `writeRecord`, `updateRecord`/`patchRecord`, `deleteRecordByDocId`, stop wrappers, PATCH/DELETE network phases.
2. **Optimistic UI** — merge/stop snapshots, `clearOptimisticTimelineUi`, sacred handoff for new start.
3. **Realtime** — subscription event handler, subscribe/cancel/reconnect body.
4. **Timeline VM** — day index, warm snapshots, body prebuild, row VM cache, adjacent warmup.
5. **Cache/stream** — `_recordsForDate`, `recordsStream`, display-time projection for stream payloads.
6. **Outbox** — Highlander/stop/update/delete enqueue, `flushPendingRecordMutations`, outbox replay, server Highlander phase.
7. **Overlap / Highlander** — local atomic apply, canonical running row, duplicate reconcile, overlap identity/range helpers, `stopAllRunningRecords`, `writeCompletedRecord`.
8. **Ghost cleanup** — 404 deadletter prune when live rows reappear in cache.

## What intentionally stayed in `record_service.dart`

- `extension RecordServiceExtension` — coordinator entry points: `fetchRecords`, `_upsertFlatRecordFromPbModel`, `_rowToRecordMap`, category resolution from rows.
- Top-level Brain state: `_recordMutationOutboxFlushInFlight`, `_timelineAdjVmWarmGeneration`, `_recordMutationRetriableHttpCode`.
- Highlander rollback token restore, `_flatTimelineVisuallyEquivalent`, batched timeline notify, start timer wrappers (`startTimerWithCategory`, `startRecordFromPlanTask`).
- `activeRecordStream`, child/parallel record streams, overlap check entry that delegates to moved helpers.
- Shared cache index helpers (`_collectRecordKeysFromCache`, `_indexOfCachedRecordRow`) used across CRUD + optimistic paths.

## Seams rejected (and why)

| Seam | Reason |
| :--- | :--- |
| Moving `_upsertFlatRecordFromPbModel` / fetch cache core | Shared by realtime, fetch, CRUD, coordinator — single owner avoids duplicate private methods. |
| Moving `_purgeGhostRecordById` | Defined on `CategoryServiceExtension`; shared across record + category paths. |
| Moving `_tryResolveRecordIdFromCacheOnly` | Lives on `CategoryServiceExtension`; used from record CRUD/outbox. |
| Splitting `plan_service` / `category_service` / `profile_service` | Out of scope for Pass 4B. |
| Regex/line-based automated split | Same kill-switch as failed Pass 4 — symbol-balanced batch extraction only. |

## UI / API notes

- **No public `DatabaseService` record API removed** — methods remain on `DatabaseService.instance` via named extensions in the same library.
- **`RecordServiceExtension` name preserved** on coordinator; no UI referenced the extension type name directly.

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | 0 violations (after APP_STRUCTURE doc sync) |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| `flutter build web` | OK |
| `flutter build apk` arm64 | OK — `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |

## Not touched

- `plan_service.dart`, `plans/*`, `category_service.dart`, `profile_service.dart` (code)
- PocketBase schema / payloads
- Optimistic UI / outbox / realtime / timeline bucketing product behavior
- Desktop voice files
