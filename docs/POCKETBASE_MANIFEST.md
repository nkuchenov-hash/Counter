# PocketBase manifest (project law)

This file is the **single source of truth** for how this app talks to **PocketBase**: URL, collection names, auth, **relation fields**, **expand** paths, and **API rule intent** (what the server should enforce). Semantic field names stay aligned with **`docs/DATA_MAP.md`**.

**Code anchors:** `lib/data/pb_config.dart` (`kPocketBaseUrl`, `PbCollections`, `PbAppApiRoutes`, `kPbRecordCategoryExpand`, `kPbPlanTagsExpand`, `kPbRecordTagsExpand`), `lib/data/database_service.dart`, `lib/data/auth_bridge.dart`.

**App-owned HTTP (same host):**

- `POST /api/ai/parse-task` — optional structured parsing for voice/plan text; implemented behind the reverse proxy. Client calls `DatabaseService.parseTaskViaAiBackend` only (no vendor-specific SDKs).
- `POST /api/ai/transcribe-command` — authenticated audio transcription. `command_mode: true` serves Desktop Voice; `command_mode: false` serves freeform Notes audio and returns `raw_transcript` or `transcript`. Audio remains stored/playable if transcription fails.
- `POST /api/auth/request-password-reset` — safe password-reset lookup/send route implemented in `pb_hooks/auth.request_password_reset.pb.js`. Body: `{ "email": "..." }`. Response exposes only `{ "exists": false }` or `{ "exists": true, "sent": true }`; SMTP failure returns a generic mail-unavailable error. The route must never return profile ids, user ids, or private fields.

---

## 1. Instance

- **Base URL:** no trailing slash; see `kPocketBaseUrl` in `pb_config.dart`.
- **Transport:** PocketBase REST via the official Dart SDK (`pocketbase` package).

---

## 2. Auth & identification

- **`profiles`** is the **Auth** collection. The authenticated user’s primary key is the **15-char** system **`id`** on that auth record.
- **Child collections** (`records`, `categories`, `plans`, `tags`, …) store **`user_id` as a Relation** to **`profiles.id`** (same 15-char value), not arbitrary UUIDs in new rows.
- **Client source of truth for mutating `user_id`:** on every **POST/PATCH** for owned rows, the Brain sets **`user_id`** from **`pb.authStore.record.id`** (SDK 0.21+: alias of deprecated `model.id`). Session invalid → no writes; **401/403** must surface in UI (snackbar), not “silent null”.
- **Legacy:** Text field **`profiles.user_id`** (UUID) may still exist for historical NocoDB mapping; filters may OR legacy and auth id — see `DatabaseService` — but **new writes** target the **relation id**.

---

## 3. Relational data model (app architecture)

| Collection | Relation | Target | Role | App usage |
| :--- | :--- | :--- | :--- | :--- |
| **records** | `user_id` | `profiles.id` | **Owner** | Mandatory on create; must equal current auth id for rules. |
| **records** | `category_id` / `category_link` | `categories.id` | **Category** | Both relation fields; payload uses **15-char** `categories.id` in **each** (never business slug). Expand `category_link` for UI. |
| **records** | `source_plan_id` | `plans.id` | **Plan vs fact** | Optional. **Many records** may point to **one plan** (iterations). Omit/clear (`null`) for legacy or unlinked rows. |
| **records** | `tags_link` (optional) | `tags` | Tags | Expand `tags_link` when present; string **`tags`** may still hold CSV. |
| **plans** | `user_id` | `profiles.id` | **Owner** | Plan rows are tenant-scoped the same way as records. |
| **plans** | `tags_link` | `tags` | Tags | Expand per `kPbPlanTagsExpand`. |
| **categories** | `user_id` | `profiles.id` | **Owner** | Same ownership pattern. |

**Cross-rule intent:** A **record** is always owned via **`records.user_id`**. If **`source_plan_id`** is set, the linked **plan must belong to the same user** so analytics and security stay consistent (enforce in PocketBase rules or hooks).

---

## 4. Collections (minimal schemas)

### 4.1 `profiles` (auth)

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | **15-char primary key** for Auth; value used as **`user_id`** target on child relations. |
| `email` | email | Auth identity. |
| `user_id` | text | Legacy UUID on profile row (optional/historical). |
| `is_admin` | bool | Admin-only app flag; default false; used to gate internal tools such as Component Lab. Managed manually in PocketBase Admin UI and read-only in client UI. |
| `tag_display_mode` | text or select | App: **`text_chip`**, **`chip`**, **`dot`**, **`icon`**, **`icon_circle`**. |

Password reset is app-owned through `POST /api/auth/request-password-reset`; do not make `profiles` publicly listable/searchable just so Flutter can check whether an email exists. Deploy `pb_hooks/auth.request_password_reset.pb.js` next to the PocketBase executable and configure SMTP + password reset template/action URL in PocketBase Admin.

### 4.2 `categories`

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | **15-char**; used in record payloads. |
| `user_id` | relation | → `profiles.id`. |
| `category_id` | text | Business slug / UUID (`life`, …). |
| `name`, `normalized_id` | text | Display / search. |
| `default_plan_time` | text | Optional `HH:mm` 24-hour default start time for new scheduled plans in this category; empty = inherit nearest parent / no default. |
| `default_plan_timezone` | text | Optional IANA id for `default_plan_time` wall clock (`America/New_York`, `Europe/Moscow`, …). Empty/null/`profile` = active profile timezone at plan creation. |

### 4.3 `plans`

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | **15-char**; **only** this id may appear in **`records.source_plan_id`** and in REST URLs for plans. |
| `user_id` | relation | → `profiles.id`. |
| `plan_id` | text | Business UUID / metadata; **not** a REST path segment. |
| `title`, `is_done`, `order`, times, `checklist`, `notes_delta`, `notes_plain`, `tags` | — | See **`docs/DATA_MAP.md`**. |
| `initial_date_key` | text | Wall day `YYYY-MM-DD` of original plan commitment; **does not change** when the task is postponed to a future day. |
| `is_postponed` | bool | `true` when the scheduled wall day is after `initial_date_key` (bulk/single move ahead). |
| `tags_link` | relation(s) | Expand: `kPbPlanTagsExpand`. |

### 4.4 `records` (timeline)

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`user_id`** | relation | → **`profiles.id`** (**15-char**). **Create/Update rules:** must match `@request.auth.id` for standard tenants. |
| **`category_id`** | relation | → `categories.id` (15-char in API body). **Not** the business slug. |
| **`category_link`** | relation | → `categories.id` (same 15-char id as `category_id`). Required for **`expand: category_link`** (see `kPbRecordCategoryExpand`). |
| **`source_plan_id`** | relation | Optional → **`plans.id`**. Set only when linking “fact” to an owned plan; **clear** with `null` on unlink. |
| `status` | select | `running` / `stopped` / `completed` (app contract). |
| `start_time`, `end_time` | date | ISO strings; timeline buckets use **wall-clock** (see DATA_MAP). |
| `record_id` | text | Business UUID (passive); never used as REST path **id**. |
| `tags_link` | relation(s) | Optional expand `kPbRecordTagsExpand`. |

### 4.5 `tags` (if used)

| Field | Type | Notes |
| :--- | :--- | :--- |
| **`id`** | **system** | 15-char. |
| `user_id` | relation | → `profiles.id`. |
| `default_plan_duration_minutes` | number | Optional minutes for auto-scheduled plan blocks when this tag is on the task. PB may return `10.0` (double); client accepts `num` / `int` / `double`. |

---

## 5. API rules (server contract)

PocketBase Admin should enforce **multi-tenant isolation** and **plan integrity**. Exact syntax depends on PB version; patterns below describe **required intent**.

### 5.1 Global

- **Authenticated-only** mutations: **Create / Update / Delete** on `records`, `plans`, `categories`, `tags` require **`@request.auth.id != ""`** (or stricter).
- **List / View** on those collections: restrict rows to the current user (e.g. **`user_id = @request.auth.id`** on the row’s relation).

### 5.2 `records`

- **Owner column:** Every create/update must keep **`user_id = @request.auth.id`** (for single-profile auth; adjust if you use team rules).
- **`source_plan_id`:** When present, the referenced plan must be readable/owned by the same user. Recommended approaches:
  - **Rule:** Allow `source_plan_id` only if empty **or** the linked **`plans.user_id`** equals **`@request.auth.id`** (implement via PB rule subquery / `~` filter on relation, or a **collection hook** that rejects mismatches), **or**
  - **Hook:** On create/update, verify plan ownership server-side.
- **Reject** cross-tenant links with **403**; the app treats **401/ 403** on record create/update as user-visible errors.

### 5.3 `plans`

- **Create / Update / Delete:** **`plans.user_id = @request.auth.id`** (same isolation as records).

---

## 6. Client (Brain) obligations

- **Never** send legacy UUIDs as **`source_plan_id`** or **`user_id`** relation targets; only **15-char** PocketBase ids from cache or known-good fields.
- **POST `records`:** Body always includes **`user_id`** from **`authStore.record.id`**; optional **`source_plan_id`** when starting from a plan or after user confirmation / manual dropdown.
- **PATCH `records`:** Optional **`source_plan_id`** updates only when the user changes link; **`null`** clears the relation.
- **Errors:** **401** (session) and **403** (forbidden / wrong plan owner) → snackbar + log; no silent failure.

---

## 7. UI & performance laws

- **Anti-blink:** A full `fetchRecords()` **fan-out** right after every small create/patch is **discouraged**; prefer atomic cache merge from the response (see `DatabaseService`).
- **Event-based debugging:** Logs on user actions (Start / Stop / Error); background loops stay quiet (project anti-spam rules).
- **Relation translation:** Resolve category **business slugs** (`categories.category_id`) to **15-char `categories.id`** before POST/PATCH on **records** (`category_id` **and** `category_link`) to avoid **400** (`validation_missing_rel_records`).

---

## 8. Cross-references

| Document | Role |
| :--- | :--- |
| **`docs/DATA_MAP.md`** | Field names, business keys, operational laws. |
| **`ARCHITECTURE.md`** | Brain / gate / data flow. |
