# Supabase-only refactor (v3.0.0) — Summary & Manual Test

## Summary of Changes (alignment with ARCHITECTURE.md v3.0.0)

### 1. Shell (lib/main.dart)
- **SUPABASE_AUTH_GATE**: Replaced Firebase Auth with `Supabase.instance.client.auth.onAuthStateChange`. No `firebase_auth` or `cloud_firestore` imports.
- **INITIALIZATION_GUARD**: Loading screen until auth state is ready; then `_InitGuard` shows loading until `DatabaseService.loadInitialData(uid)` returns `true`; only then is the LifeOS dashboard shown.
- Root: no session → `AuthScreen`; session → `_InitGuard(uid)` → dashboard.

### 2. Brain (lib/database_service.dart)
- **Firebase removed**: All `cloud_firestore`, `firebase_auth`, `Timestamp`, `FieldValue`, `_userRecords`, `_userDoc`, `_userPlanning` removed. Data layer is Supabase-only.
- **OWNERSHIP_FILTER**: All queries filter by `user_id` (from `_uid()` = Supabase auth current user).
- **ACTIVE_STATUS_LAW**: “Active” record = row where `end_time IS NULL`. Uses `.filter('end_time', 'is', null)` for Supabase.
- **POINTER_HANDOVER**: Before inserting a new running record, batch-update all rows with `end_time IS NULL` for that user (and `parent_id` when applicable), then insert the new row with `end_time: null`.
- **Categories**: Load/save from Supabase `categories`; seed default LifeOS when empty.
- **Settings**: Load/save from Supabase `profiles` (snake_case: `primary_language`, `preferred_timezone`, etc.).
- **Records**: All CRUD via Supabase `records` (snake_case, ISO8601 timestamps). `runningChildrenStream` / `completedChildrenStream` / `activeRecordStream` / `recordsStream` implemented with Supabase + polling.
- **Planning**: `planningStream`, `addPlanningTask`, `updatePlanningTask`, `deletePlanningTask` use Supabase `plans` table (snake_case).
- **Scaffolding removed**: No migration or Firestore-related APIs. `forceRefreshFromServer` reloads settings and categories from Supabase. `stopAnyRunningRecordsForDate` closes running records for a date.
- All data operations wrapped in try/catch.

### 3. DNA (lib/models.dart)
- **Snake_case serialization**: `TimelineRecord` and `PlanningTask`:
  - `fromMap` / `fromJson`: Accept both camelCase and snake_case (Brain in-memory vs Supabase row).
  - `toMap` / `toJson`: Output snake_case for PostgreSQL (e.g. `start_time`, `end_time`, `date_key`, `category_id`, `is_manual`, `created_at`, `sub_record_ids`, `parent_id`; plans: `category_id`, `is_done`, `date_key`, `scheduled_time`, `end_time`, `end_date_key`, `sub_record_ids`).
- No Firebase types; DateTime from ISO8601 strings where needed.

### 4. Auth UI (lib/auth_screen.dart)
- New screen: Email/Password sign-in and sign-up using `supabase.auth.signInWithPassword` and `supabase.auth.signUp`.
- Try/catch with user-visible error messages.

### Banned / Mandatory
- **Banned**: No `firebase_auth`, `cloud_firestore`, no `DateTime.now().toLocal()`, no raw user-facing strings for DB lookups (normalization used).
- **Mandatory**: Try/catch around data operations; OWNERSHIP_FILTER on all queries; INITIALIZATION_GUARD until session + `loadInitialData()`.

---

## Manual Test (emulator)

1. **Auth gate**
   - Cold start: app shows loading, then either Auth screen (signed out) or loading then dashboard (signed in).
   - Sign out (if implemented): you are taken to Auth screen.
   - On Auth screen: enter email + password, tap Sign in (or Sign up). After success you should land on the main dashboard (or see “Check your email” for sign-up).

2. **Supabase writes**
   - Start a timer (e.g. from timeline or “Start” flow). Confirm one row in Supabase `records` with `end_time IS NULL` for your `user_id`.
   - Stop the timer. Confirm that row now has `end_time` set (no more `end_time IS NULL` for that record).
   - Add a manual/completed record (if UI exists). Confirm a new row in `records` with both `start_time` and `end_time` set and your `user_id`.

3. **Categories & settings**
   - Change a category or settings (e.g. timezone). Reload app; confirm categories/settings persist (loaded from Supabase).

If any step fails, check the Debug Console for errors and ensure Supabase URL/anon key, RLS, and tables (`records`, `categories`, `plans`, `profiles`) match the schema expected by the Brain.
