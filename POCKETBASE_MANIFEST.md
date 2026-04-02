# PocketBase manifest (project law)

This file is the **single source of truth** for how this app talks to **PocketBase**: URL, collection names, auth, and **relation fields** used for expands. Semantic field names stay aligned with **`lib/DATA_MAP.md`** (business columns such as `user_id`, `record_id`, `category_id`, `plan_id`).

**Code anchors:** `lib/data/pb_config.dart` (`kPocketBaseUrl`, `PbCollections`, `kPbRecordCategoryExpand`), `lib/data/database_service.dart`, `lib/data/auth_bridge.dart`.

---

## 1. Instance

- **Base URL:** no trailing slash, see `kPocketBaseUrl` in `pb_config.dart`.
- **Transport:** PocketBase JS/REST API via official Dart SDK (`pocketbase` package). 

---

## 2. Auth & Identification

- **`profiles`** is the **Auth** collection. 
- **Primary Keys:** The app uses the 15-char systemic **`id`** (e.g., `xhjy54...`) for all active relations and API rules.
- **Rules:** Access is governed by `@request.auth.id`.
- **Legacy:** `user_id` (UUID) is kept only for historical mapping of NocoDB data.

---

## 3. Collections (minimal schemas)

### 3.1 `profiles` (auth)

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | **Primary 15-char identifier.** Used for all `Relation` mapping. |
| `email` | email | Auth identity (e.g., `Kuchenov@yandex.ru`). |
| `user_id` | text | Legacy UUID string (historical mapping). |
| `tag_display_mode` | text or select | Optional. App sends **`text_chip`**, **`chip`**, **`dot`**, **`icon`**, **`icon_circle`** (case-sensitive). If using **Select**, add these five values exactly. Legacy rows may still use `letter_chip` / `round` — the app parses those too. |

### 3.2 `categories`

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | **15-char ID used for links.** |
| `user_id` | relation | Points to `profiles.id` (15-char). |
| `category_id` | text | Business slug (e.g., "life"). |
| `name`, `normalized_id` | text | Display and search. |

### 3.3 `records` (The Timeline)

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`user_id`** | **relation** | **Must be 15-char `profiles.id`.** Rule: `user_id = @request.auth.id`. |
| **`category_id`**| **relation** | **Relation to `categories.id`.** Payload must send 15-char ID, NOT the slug. |
| **`category_link`**| **relation** | **Required for `expand: category_link`.** Used to fetch category metadata. |
| `status` | text | `running` / `stopped`. |
| `start_time` | text | ISO string. Filtering uses **Local Time** comparison (Y-M-D). |

---

## 4. UI & Performance Laws

- **Anti-Blink Policy:** - Full `fetchRecords()` is **forbidden** after `create/patch` actions.
    - Local cache (`_cachedRecords`) must be updated **atomically** using the server response to ensure smooth UI.
- **Event-Based Debugging:**
    - Debug logs are allowed **only** on user-initiated actions (Start/Stop/Error).
    - Background/Static mapping loops must remain silent.
- **Relation Translation:**
    - The `DatabaseService` must translate business slugs ("life") to systemic IDs ("c56i...") before sending payloads to avoid `400 Bad Request`.

---

## 5. Cross-references

| Document | Role |
| :--- | :--- |
| **DATA_MAP.md** | Business logic names and slug definitions. |
| **ARCHITECTURE.md** | Core Brain/Gate logic and data flow. |