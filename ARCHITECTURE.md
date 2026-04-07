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

- Speech and biometrics: guard with `kIsWeb` and platform capabilities as in `app_shell` / services.
- **Records realtime:** After a valid session, the Brain subscribes to `records` (`subscribe('*', …)`) so **Web and mobile** share the same in-memory cache updates from server pushes; login flows must re-arm this subscription if init ran before auth.

---

## 9. Cross-references

| Document | Role |
| :--- | :--- |
| **POCKETBASE_MANIFEST.md** | PB URL, collections, `category_link`, auth. |
| **DATA_MAP.md** | Field naming reference (legacy Noco table UIDs are historical only). |
| **NOCODB_MANIFEST.md** | Legacy Noco contract — do not use for new work. |
