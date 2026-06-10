# LIFE OS: Architecture (PocketBase)

**Runtime law:** The app’s primary backend is **PocketBase** (`pocketbase` Dart SDK). URL, collection names, auth, and **record → category** relation (`category_link` + expand) are defined in **`POCKETBASE_MANIFEST.md`**. **`lib/DATA_MAP.md`** remains the vocabulary for **field names** and business IDs (`user_id`, `record_id`, `plan_id`, `category_id`, etc.).

---

## 1. File hierarchy

| Vault | Responsibility | Rule |
| :--- | :--- | :--- |
| `lib/data/models.dart` | **Data DNA** | Pure data classes. No DB/UI imports. |
| `lib/data/database_service.dart` | **The Brain** | PocketBase SDK for profiles, categories, records, plans. Single place for server I/O. |
| `lib/data/auth_bridge.dart` | **The Gate** | PocketBase `authWithPassword`, session + secure storage. |
| `lib/app_shell.dart` | **The Navigator** | Shell / global UI. |
| `lib/main.dart` | **The ignition** | Calls `ensurePocketBaseReady()`, then restores session and loads profile. |

---

## 2. IDs

- **PocketBase row id:** string primary key on each collection (used in `update` / `delete`).
- **Business IDs:** `user_id` (UUID string), `record_id`, `plan_id`, `category_id` — carried in row data for filtering and matching.
- **Timeline PATCH/DELETE:** Prefer PB row id from cache (`_pb_record_id` / `id`); resolve business `record_id` to row id when needed.

---

## 3. Core contracts

- **ACTIVE_STATUS_LAW:** A running interval has `end_time` null and `status == running` (UI also treats any row with `end_time` as closed where noted in code).
- **SINGLETON_STOP:** Starting a new primary timer stops other open primaries for the same wall-clock rules before create.
- **OWNERSHIP:** Every query filters by current user, e.g. `user_id = "<uuid>"` in PB filter strings.
- **INSTANT_PURGE_PROTOCOL:** Optimistic UI before await where the Brain already does so; revert on failure.
- **LAW_OF_OPTIMISTIC_UI (Shadow State):** No user-driven **Start / Stop / Update** on records may block the UI on a network round-trip. The Brain applies a **local shadow** (cache + timeline/active streams) in **&lt;100 ms**, then runs PocketBase **PATCH/POST** asynchronously; on failure it **rolls back** to the last stable snapshot and surfaces a **single** sync error (see `database_service.dart`).
- **OFFLINE-FIRST / LOCAL MUTATION QUEUE LAW:** Retriable network/backoff failures enqueue local mutations and keep the optimistic UI. Do **not** roll back on normal internet loss; roll back only on non-retriable validation/schema errors. Pending mutations drain on boot, reconnect, app resume, login/session restore, and tap-to-retry. 401/403 pauses sync until valid auth/session is restored. The server remains final authority for Singleton Timeline Law and overlap cleanup. Anchors: `lib/data/local_sync/record_mutation_outbox.dart`, `lib/data/local_sync/plan_mutation_outbox.dart`, `lib/data/local_sync/offline_sync_state.dart`, `lib/data/local_sync/sync_manager.dart`, `DbCoreExtension.flushPendingLocalMutations`, `RecordServiceExtension.flushPendingRecordMutations`, `PlanServiceExtension.flushPendingPlanMutations`, `_OfflineSyncStatusBar` in `app_shell.dart`.
- **LAW_OF_THE_MAIN_THREAD (Iron Rules):**
  - **~100ms visual feedback:** User gestures must reflect in the UI within about **100ms** (optimistic/shadow first).
  - **Zero-await UI:** Do not `await` network, DB writes, or Wear sync **before** the UI updates for that action; use **`unawaited`** background sync with rollback on failure.
  - **Heavy work off the hot path:** Large JSON parsing, big list scans, and expensive filters should yield or run in a **background isolate** when they would stall frames.
  - **No blocking init on record path:** STT prewarm, ghost cleanup, plan outbox flush, and optional realtime **must not** block start/stop of a record.
  - **Wear:** Phone↔watch `MethodChannel` lives in `lib/features/wear/`; `DatabaseService` only has a **Wear-lite** bootstrap that avoids awaiting non-essential work (e.g. records realtime on watch).
- **STATE_RECONCILIATION:** 404 → purge ghost rows / revert optimistic state.

---

## 4. API shape

- **No Noco `fields` wrapper.** Requests use flat JSON maps. Checklist / long JSON fields are stringified where the schema expects strings.
- **Relations:** e.g. `records.category_link` → categories id; list with `expand` to hydrate timeline category data.

---

## 5. Planetary time

- **STORAGE:** UTC ISO8601 in DB.
- **OFFSET:** `timezone_offset` + `preferred_timezone` from profile drive wall-clock grouping (see existing Brain helpers).
- **BANNED:** `DateTime.now().toLocal()` for **persisted** grid keys; use profile offset patterns already in the codebase.

---

## 6. Categories & planning

- **WORD_MATCH_LAW:** Whole-word matching on `title.split` for auto-category (no substring fuzzy).
- **Planning tasks:** Loaded from PocketBase `plans` collection with expands as implemented in `database_service.dart` (not a separate Dart `Plan` model — use `PlanningTask` / record maps).

---

## 7. Tags & many-to-many

- Implemented via PocketBase relations / junction as in the Brain (`tags_link`, etc.). Follow `POCKETBASE_MANIFEST.md` and `database_service.dart` for the live schema.

---

## 8. Web / hardware

- **Voice / STT:** Immutable rules in **§9 Voice Input Protocol** — do not “clean up” without preserving bilingual toggle, session persistence, and web BCP-47 bypass semantics.
- **Biometrics and other capabilities:** guard with `kIsWeb` and platform capabilities as in `app_shell` / services.
- **Records realtime:** After a valid session, the Brain subscribes to `records` (`subscribe('*', …)`) so **Web and mobile** share the same in-memory cache updates from server pushes; login flows must re-arm this subscription if init ran before auth.

### 8.1 Omni-Picker (UI Iron Rule)

- **Omni-Picker Law:** Date and Time selection must always happen simultaneously within a single unified dialog or sheet. Never chain `showDatePicker` and `showTimePicker` consecutively.
- **Implementation:** `lib/core/widgets/omni_date_time_picker_dialog.dart` (keyboard / desktop text-first path); entry point `showAppDateTimePicker` in `lib/features/shared/shared_widgets.dart`; keyboard vs touch modes in `lib/core/picker_entry_modes.dart` (`useKeyboardFriendlyMaterialPickers`, `appDatePickerEntryMode` / `appTimePickerEntryMode`, retained for any future Material surfaces). **Date-only** navigation (e.g. changing the timeline day) may use a single `showDatePicker` with no time component.

---

## 9. Voice Input Protocol (Immutable)

Voice Input Protocol (Immutable):

Bilingual Toggle: STT operates on a strict [App Primary Language] <-> English toggle.

Session Persistence: Switching languages mid-dictation MUST preserve the existing transcript, restart the session with the new localeId, and append new text.

Web vs. Mobile STT: Web (kIsWeb) MUST use strict BCP-47 tags (e.g., ru-RU) bypassing the plugin's empty locale list. The UI toggle visibility depends ONLY on the app's currentLocale state, never on the STT plugin's initialized locales.

---

## 10. Cross-references

| Document | Role |
| :--- | :--- |
| **POCKETBASE_MANIFEST.md** | PB URL, collections, `category_link`, auth. |
| **DATA_MAP.md** | Field naming reference (legacy Noco table UIDs are historical only). |
| **NOCODB_MANIFEST.md** | Legacy Noco contract — do not use for new work. |
