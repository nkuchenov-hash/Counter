# Structure Decomposition — Pass 4C Category Service (2026-07-03)

**Baseline SHA:** `cdf277e` (Pass 4B deployed)  
**Pass type:** Safe Brain decomposition — **`category_service.dart` only**

## Line counts

| File | Before | After |
| :--- | ---: | ---: |
| `lib/data/category_service.dart` | 3287 | 466 |
| **Moved to `lib/data/categories/`** | — | **2864** (7 part files) |
| **Net reduction in coordinator** | — | **−2821** |

### New part files (`part of '../database_service.dart'`)

| File | Lines | Extension / symbols |
| :--- | ---: | :--- |
| `category_cache_helpers.dart` | 177 | `CategoryCacheExtension` — `fetchCategories`, `_loadRulesFromNoco`, slug reservation |
| `category_tree.dart` | 356 | `CategoryTreeExtension` — `_buildCategoryTreeFromFlat`, parent/child, `getRecordIdsInSubtree` |
| `category_lookup.dart` | 498 | `CategoryLookupExtension` — fuzzy/smart match, `findCategoryByFuzzyMatch`, path resolution |
| `category_crud.dart` | 914 | `CategoryCrudExtension` — `addNestedCategory`, `updateCategory`, archive/delete, PB payloads |
| `category_stats.dart` | 147 | `CategoryStatsExtension` — `getAggregatedStats`, category duration rollups |
| `category_record_bridge.dart` | 626 | `CategoryRecordBridgeExtension` — record REST id resolution, category_link bridge, ghost purge |
| `category_default_time.dart` | 146 | `CategoryDefaultTimeExtension` — `default_plan_time` read/write, inherited schedule |

## What moved

1. **Cache / hydration** — category fetch, all-rows slug reservation, `_loadRulesFromNoco`, dialog universe rebuild.
2. **Tree** — flat→hierarchy build, sibling sort, parent/child getters, subtree record id collection.
3. **Lookup** — fuzzy match integration, smart plan label resolution, `getCategoryPath`, `categoryExists`, display path helpers.
4. **CRUD** — create/update/archive, PB PATCH payloads, slug collision recovery, nested category helpers.
5. **Stats** — per-category duration aggregation, `getAggregatedStats` tree builder.
6. **Record bridge** — REST id resolution for stop/delete, category field normalization, Highlander row probes, `_purgeGhostRecordById`.
7. **Default plan time** — sanitize/inherit/update `default_plan_time` schedule helpers.

## What intentionally stayed in `category_service.dart`

- `extension CategoryServiceExtension` — coordinator name preserved for external static references (`CategoryServiceExtension.recordsTablePk`, `_parseDateTimeUtc`, `_rowInt`, `statsRecordsSignature`, duration statics).
- `_flattenNocoRecord` — shared Noco envelope flatten used by cache + records domain.
- Static record-running probes (`isRecordMapActuallyRunning`, `_isNocoRowSacredStopTarget`, etc.) — cross-domain bridge statics referenced from record parts.
- `_timelineDeviceLocalDayKeyFromUtc` — shared wall-day bucketing used by plan/record coordinators.
- `setRulesAndSave`, `updateCategoryKeywords`, legacy task helpers (`loadTasksForDate`, `getCleanTitleAndTags`).
- `persistRules()` no-op coordinator stub.

## Seams rejected (and why)

| Seam | Reason |
| :--- | :--- |
| Duplicate `getCategoryPath` / `categoryExists` in tree + lookup | `ambiguous_extension_member_access` — kept only in `CategoryLookupExtension`. |
| Duplicate `getRecordIdsInSubtree` in crud + tree | Same — kept only in `CategoryTreeExtension`. |
| Moving `CategoryServiceExtension` static bridge statics to part files without prefix | Record/profile parts call `CategoryServiceExtension._rowInt` / `recordsTablePk` by extension name — kept in coordinator. |
| Truncated `getRecordIdsInSubtree` in first extraction batch | Script cut mid-method — restored full body in tree file. |
| Splitting `plan_service` / `record_service` / `profile_service` | Out of scope for Pass 4C. |

## Cross-extension static access

Part files call coordinator statics via explicit prefix where needed, e.g. `CategoryServiceExtension._flattenNocoRecord`, `CategoryServiceExtension.recordsTablePk`, `CategoryTreeExtension._rowInt` from CRUD helpers.

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | 0 violations (after APP_STRUCTURE doc sync) |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| `flutter build web` | OK |
| `flutter build apk` arm64 | OK — `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |

## Not touched

- `plan_service.dart`, `plans/*`, `record_service.dart`, `records/*`, `profile_service.dart` (code)
- PocketBase schema / payloads
- Optimistic UI / outbox behavior
- Category_id / category_link mapping behavior
- Desktop voice files
