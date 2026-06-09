# Hybrid Cloud: Supabase (Global) + YDB (Russia)

## CLOUD_AGNOSTICISM
The UI does not know which cloud holds the data. The Brain selects the provider from **data region** (profile, SharedPreferences, or system language).

## Dynamic routing
- **data_region = 'global'** → Supabase (categories, records, plans, profiles) + Supabase Auth.
- **data_region = 'russia'** → Yandex YDB (same schema, YQL-optimized backend) + AuthService (Yandex/Google); session can be stored in `app_sessions` in Yandex Cloud by the backend.

## How to switch to YDB for testing (Russian version)

### Option A: System language
1. Set the device/emulator language to **Russian** (e.g. **Settings → System → Language → Русский**).
2. Clear app data or uninstall and reinstall so there is no saved `data_region` in SharedPreferences.
3. Open the app and sign in (Supabase or AuthService).
4. On first load, the Brain uses `PlatformDispatcher.instance.locale`; if it starts with `ru`, it sets **data_region = 'russia'** and uses **YandexYdbProvider** + **YandexYdbAuthBridge**.

### Option B: Programmatic switch (for testing)
1. From code (e.g. a debug button or Settings screen), call:
   ```dart
   await DatabaseService.instance.setDataRegion('russia');
   await DatabaseService.instance.loadInitialData(DatabaseService.instance.currentUid);
   ```
2. Ensure the user is already signed in (so `currentUid` is valid).
3. The next data operations will use YDB. Restart the app or re-run `loadInitialData(uid)` so the whole Brain uses the new provider.

### Option C: SharedPreferences (developer)
1. Clear app data, or from a debug screen write to SharedPreferences:
   - Key: `data_region`
   - Value: `russia`
2. Restart the app and sign in. On `loadInitialData(uid)` the Brain reads `data_region` and uses YDB.

### What to check when testing YDB
- Categories, records, and plans load from your YDB backend (HTTP API with IAM token).
- Auth uses **AuthService** (Google / Yandex native); no Supabase OAuth redirect.
- All IDs remain UUID/Text; timestamps remain UTC (PLANETARY_TIME).
- **checkAndSeedCategories(uid)** runs on both clouds (no category seeds; YDB can ensure `app_sessions` row in the backend).

## Switching back to Supabase (Global)
- Set system language to non-Russian (e.g. English), clear `data_region` from SharedPreferences, and restart; or
- Call `DatabaseService.instance.setDataRegion('global')` and then `loadInitialData(currentUid)` (or restart).

## Backend requirements for YDB
- REST API that implements the same contract as [BaseDatabase] (see `lib/data/base_database.dart`).
- Queries **MANDATORY** optimized for YQL (indexes on `user_id`, `start_time`, `end_time`, `parent_id`, etc.).
- Optional: store session in `app_sessions` after AuthService sign-in for server-side session checks.
