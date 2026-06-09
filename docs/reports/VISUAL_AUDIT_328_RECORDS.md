# Visual Audit: 328 Records and Plans as Active Source of Truth

## INITIALIZATION_GUARD (§2)

The Loading screen remains visible until:

1. **Categories** are loaded (`_loadRulesFromProvider()`).
2. **Records** fetch has been executed (`getRecords(uid: uidStr, ...)`).
3. **Plans** fetch has been executed (`getPlans(uid: uidStr)`).

Only then does `loadInitialData()` return `true` and the app show the main UI.

## Visual Audit Confirmation (328 Records in Timeline)

After signing in (Supabase: **auth.currentUser.id**; YDB: AuthService uid):

1. **Loading screen** appears until all three fetches complete.
2. **Debug console** shows one of:
   - `DEBUG loadInitialData: auth.uid()=<id>, categoriesLoaded=N, recordsVisible=true`  
     → Records and plans are the active source of truth; Timeline and Planning use them.
   - If records are empty: `records list empty for auth.uid()=<id> (...)` → investigate RLS/network.
3. **Timeline** (or equivalent list of records) shows the full set of records (expect **328** for this user). Scroll or use date range to confirm count.
4. **Plans** screen shows all plans for this user. Count matches `plansLoaded` in the log.
5. **No 400 error** from Supabase; all fetches use auth.uid() via _authUid.

## Summary of Changes (328 Records and Plans = Active Source of Truth)

- **Fetch methods** (`getRecords`, `getCategories`, `getPlans`) in `lib/data/supabase_provider.dart` use **_authUid** (Supabase: `auth.currentUser.id`) for all `.eq('user_id', ...)`.
- **loadInitialData()** in `lib/database_service.dart`:
  - Resolves uid from **auth before requests**: `authUid = _authBridge?.getCurrentUid()?.toString().trim() ?? uidStr` (Supabase = currentUser.id); sets `_currentUid = authUid`.
  - **Awaits all three** data loads (categories, records sample, plans) before clearing the Loading screen (INITIALIZATION_GUARD §2).
  - Wrapped in **try/catch** with `debugPrint` on error and `return false` so the guard keeps showing Loading on failure (cursor.rules §4).
- **BANNED** in codebase: no `id::uuid` casting in Dart; no use of `DateTime.now()` for data (only `getPlanetaryNow()`).
- **Records and plans** in Supabase (owner `user_id` = auth.uid()) are the **active source of truth**: Timeline and Planning read from the provider’s getRecords/getPlans.
