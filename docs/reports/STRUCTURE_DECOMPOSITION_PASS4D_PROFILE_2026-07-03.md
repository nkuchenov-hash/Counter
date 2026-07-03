# Structure Decomposition — Pass 4D Profile Service (2026-07-03)

**Baseline SHA:** `8cee50b` (Pass 4C deployed)  
**Pass type:** Safe Brain decomposition — **`profile_service.dart` only**

## Line counts

| File | Before | After |
| :--- | ---: | ---: |
| `lib/data/profile_service.dart` | 1022 | 75 |
| **Moved to `lib/data/profile/`** | — | **969** (8 part files) |
| **Net reduction in coordinator** | — | **−947** |

### New part files (`part of '../database_service.dart'`)

| File | Lines | Extension / symbols |
| :--- | ---: | :--- |
| `profile_hydration.dart` | 299 | `ProfileHydrationExtension` — fetch/hydrate/retry, PB map apply, diag logs |
| `profile_settings.dart` | 111 | `ProfileSettingsExtension` — `saveSettings`, PATCH diff, locale sync |
| `profile_timezone.dart` | 120 | `ProfileTimezoneExtension` + top-level TZ helpers — `getProjectedToday`, `updateTimeZone` |
| `tag_catalog.dart` | 350 | `TagCatalogExtension` — tag CRUD, sort order, `_pbTagRecordIdsFromTags` |
| `profile_cache_helpers.dart` | 52 | `ProfileCacheExtension` — device prefs mirror/hydrate |
| `tag_display_settings.dart` | 15 | `TagDisplaySettingsExtension` — list tag strip visibility prefs |
| `profile_admin.dart` | 13 | top-level `_profileBool` admin parse helper |
| `profile_preferences.dart` | 9 | `ProfilePreferencesExtension` — data region reload hook |

## What moved

1. **Hydration** — `getUserProfile`, `_loadSettingsFromNoco`, `_applyProfileFromPbMap`, retry, boot diag logging.
2. **Settings** — `saveSettings`, `_diffProfilePatchFields`, `_syncMaterialAppLocaleFromSettings`.
3. **Timezone** — `_normalizeTimezone`, `_fixedOffsetHoursFromLabel`, `utcRangeForWallClockDate`, projected today helpers, TZ PATCH wrappers.
4. **Cache** — device prefs mirror/hydrate for theme/tz/lang.
5. **Preferences** — `reloadForDataRegionChange`, `dataRegion` getter.
6. **Admin** — `_profileBool` parse helper (hydration-owned).
7. **Tag catalog** — full tag fetch/CRUD, sort persist, default duration PATCH, `_pbTagRecordIdsFromTags`.
8. **Tag display** — `persistShowListTagsOnCards`, prefs key helper.

## What intentionally stayed in `profile_service.dart`

- `_ProfileFetchFailedException` and all top-level mutable Brain state (`_settings`, `_settingsController`, tag catalog cache/stream, hydration flags, prefs keys).
- `_maskEmailForLog`, `_authRecordEmail` (used by display label resolver).
- `extension ProfileServiceExtension` — `settings` getters, `resolveProfileDisplayLabelFor` static (referenced from UI).

## Seams rejected (and why)

| Seam | Reason |
| :--- | :--- |
| Duplicate `part of` in timezone/hydration files | Script emitted two directives — merged to single directive per file. |
| Duplicate `_profileBool` in timezone + admin | Kept only in `profile_admin.dart`. |
| `_prefsKeyShowListTagsOnCards` static on tag display extension | Cache/hydration call via `TagDisplaySettingsExtension._prefsKeyShowListTagsOnCards` prefix. |
| Separate empty `profile_admin` extension | Admin gate is hydration-owned; only `_profileBool` helper extracted. |
| Splitting `plan_service` / `record_service` / `category_service` | Out of scope for Pass 4D. |

## Verification

| Gate | Result |
| :--- | :--- |
| `architecture_guard.ps1 -Strict` | 0 violations (after APP_STRUCTURE doc sync) |
| `flutter analyze` | 0 errors |
| `flutter test` | 248/248 |
| `flutter build web` | OK |
| `flutter build apk` arm64 | OK — `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` |

## Not touched

- `plan_service.dart`, `plans/*`, `record_service.dart`, `records/*`, `category_service.dart`, `categories/*` (code)
- PocketBase schema / payloads
- Profile hydration / tag catalog product behavior
- Desktop voice files
