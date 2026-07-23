# LIFE OS: Architecture (PocketBase)

**Runtime law:** The app’s primary backend is **PocketBase** (`pocketbase` Dart SDK). URL, collection names, auth, and **record → category** relations (`category_id`, `category_link` + expand) are defined in **`POCKETBASE_MANIFEST.md`**. **`docs/DATA_MAP.md`** remains the vocabulary for **field names** and business IDs (`user_id`, `record_id`, `plan_id`, `categories.category_id`, etc.).

---

## 1. File hierarchy

| Vault | Responsibility | Rule |
| :--- | :--- | :--- |
| `lib/data/models.dart` | **Data DNA** | Pure data classes. No DB/UI imports. |
| `lib/data/database_service.dart` | **The Brain** | PocketBase SDK for profiles, categories, records, plans. Single place for server I/O. |
| `lib/data/auth_bridge.dart` | **The Gate** | PocketBase `authWithPassword`, session + secure storage. |
| `lib/shared/time/` | **Shared time** | UTC ↔ profile wall-clock, timezone catalog, `AppClock` / `ProfileTimezoneActions`. No feature or Brain I/O imports. |
| `lib/shared/diagnostics/` | **Shared diagnostics** | Runtime logs (`runtime_log`, `platform_log`, `startup_log`) + kill switches / metrics under `performance/` (`runtime_flags`, `shell_flags`, `rebuild_metrics`). No feature or Brain I/O imports. |
| `lib/shared/voice/` | **Shared Voice (one system)** | Commands, recognition, acceptance routing bridge, reusable UI, platform adapters (`platforms/desktop`, `platforms/mobile`), and diagnostics. Phone/desktop/web/Wear activation paths converge on the same command interpretation. Must not import `features/`, `data/voice/`, `database_service.dart`, or shell tab-state ownership. |
| `lib/shared/categories/` | **Shared Categories** | Presentation lookup, tree helpers/body, picker sheet/form/create dialog, local visibility prefs. Narrow injected contracts only — no `database_service` / `features` / shell imports. |
| `lib/data/voice/` | **Brain Voice** | Parser, domain resolution, normalize, record-submit / command execution, glossary builder, contamination/postprocess, PocketBase cloud STT backend, parser-tied benchmarks. |
| `lib/features/voice/` | **Desktop Voice UI** | Flutter overlay widget, capsule, correction sheet, command panel. |
| `lib/features/settings/voice/` | **Voice settings UI** | Microphone / hotkey / recognizer / diagnostics settings pages. |
| `lib/features/settings/categories/` | **Categories manager UI** | More → Categories band grid, editor/appearance sheets, create dialog, browse panel. |
| `lib/data/plans/diagnostics/` | **Brain plans diagnostics** | Planning-domain duplicate / stream lifecycle log (`plan_duplicate_log.dart`). Lives inside Brain; not shared diagnostics and not feature UI. |
| `lib/app_shell.dart` | **The Navigator** | Thin entry re-export; canonical shell under `lib/app/shell/`. |
| `lib/main.dart` | **The ignition** | Calls `ensurePocketBaseReady()`, then restores session and loads profile. |

---

## 2. IDs

- **PocketBase row id:** string primary key on each collection (used in `update` / `delete`).
- **Business IDs:** `user_id` (UUID string), `record_id`, `plan_id`, `categories.category_id` (business slug) — carried in row data for filtering and matching. **Record REST category payloads** use 15-char `categories.id`, not the business slug.
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
- **PERFORMANCE_KILL_SWITCH_LAW (Iron Rule — P0V):** Performance, responsiveness, and stability are **sacred**. The app must **never** become slower, crashier, less responsive, or less immediately reactive because of a preload/cache/render/design experiment. **Worst failure ≠ imperfect UI; worst failure = damaged speed, stability, instant feedback, or basic usability.**

  **Hard-stop conditions** — if any change causes any of the following, work **stops immediately** (no feature/design/preload continuation until fixed):
  - Slower startup
  - App freeze or crash
  - Swipe jank regression or broken short swipe
  - UI action not reflecting immediately (~100ms)
  - Record/plan create not appearing instantly without refresh
  - Optimistic UI broken; active stream disconnected from live data
  - Visible loader replacing already loaded content
  - Partial card render before full card render
  - Massive console/log spam
  - Massive projection/rebuild of invisible data
  - Mounted widget explosion / OOM risk or significant memory growth
  - Background work on gesture hot path
  - Network wait before local UI update

  **Required emergency response:**
  1. Disable the offending experiment **by default**.
  2. Restore last known stable behavior.
  3. Restore instant optimistic/local UI.
  4. Remove hot-path overload.
  5. Only then continue with smaller scoped fixes.

  **Preload rule:** Preloading is allowed only if it makes the app **faster** without increasing crash risk or blocking startup. A preload that slows startup, causes memory pressure, breaks optimistic UI, or creates stale screens is **worse than no preload** and must be disabled.

  **Snapshot/cache rule:** Snapshots and render DTOs are helpers only. They must **never** replace active live optimistic sources; **never** suppress active Timeline/Plans updates; **never** force refresh to see newly created data.

  **Logging rule:** Verbose diagnostics must be gated. Release web/APK must **never** flood console/logcat with per-row/per-card/per-plan spam. Batch summary logs are debug/profile only.

  **Hot path rule:** Swipe, startup, text entry, record create/start/stop, plan create/update, and tab switch are hot paths. No full-history scan, full-plan projection, full widget mount window, network wait, or heavy rebuild may run **synchronously** on these paths.

  **Code anchors:** `lib/shared/diagnostics/performance/runtime_flags.dart`, `lib/shared/diagnostics/performance/shell_flags.dart`. Experimental preload/render paths default **off** until proven stable on **web and Android**.
- **STATE_RECONCILIATION:** 404 → purge ghost rows / revert optimistic state.

---

## 4. API shape

- **No Noco `fields` wrapper.** Requests use flat JSON maps. Checklist / long JSON fields are stringified where the schema expects strings.
- **Relations:** `records.category_id` and `records.category_link` → `categories.id` (15-char in POST/PATCH body); list with `expand: category_link` to hydrate timeline category data. Business slug (`categories.category_id`) is **not** valid in record relation fields.

---

## 5. Planetary time

- **STORAGE:** UTC ISO8601 in DB.
- **OFFSET:** `timezone_offset` + `preferred_timezone` from profile drive wall-clock grouping (see existing Brain helpers).
- **BANNED:** `DateTime.now().toLocal()` for **persisted** grid keys; use profile offset patterns already in the codebase.

---

## 6. Categories & planning

- **Record category API law:** POST/PATCH on `records` must send the **15-char** `categories.id` in **both** `category_id` and `category_link`. The Brain may hold business slugs in cache/UI but normalizes before network I/O (`_normalizeRecordCategoryFieldsForPbApi` / `_mapCategoryIdToLinkForPb`). Sending a business slug (e.g. `"life"`) causes PocketBase **400** `validation_missing_rel_records`.
- **WORD_MATCH_LAW:** Whole-word matching on `title.split` for auto-category (no substring fuzzy).
- **Planning tasks:** Loaded from PocketBase `plans` collection with expands as implemented in `database_service.dart` (not a separate Dart `Plan` model — use `PlanningTask` / record maps).
- **Recurring virtual occurrence edit:** Editing time/metadata on a virtual recurring instance materializes a one-off plan row and appends the instance date to the parent series `exception_dates` (see `plan_service.dart`).

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
| **POCKETBASE_MANIFEST.md** | PB URL, collections, `category_id` / `category_link`, auth. |
| **DATA_MAP.md** | Field naming reference (legacy Noco table UIDs are historical only). |
| **NOCODB_MANIFEST.md** | Legacy Noco contract — do not use for new work. |
| **APP_STRUCTURE.md** | Layer map, import boundaries, Structure Growth Law. |

---

## 11. Structure Growth Law

New features must integrate into the **existing** architecture — not parallel folders, duplicate Brain paths, or feature-local “mini frameworks.” Every new file must have **one clear owner layer**: Entry/Shell, Brain/Data, Core/Foundation, Feature UI, Services, l10n, Platform, Tests, Scripts, or Docs.

**Integration rules:**

- Extend the canonical screen, service, Brain module, or shared widget that already owns the domain.
- Do **not** create duplicate local components, duplicate PocketBase constants, duplicate offline/outbox paths, or duplicate timezone/date helpers when a canonical home exists (see `docs/APP_STRUCTURE.md`, `docs/DESIGN_SYSTEM.md`).
- PocketBase schema or field-name changes require **`docs/DATA_MAP.md`** and **`docs/POCKETBASE_MANIFEST.md`** updates before client behavior ships.

### File size / decomposition law

Large files must **not** grow without bound. When a file mixes responsibilities or approaches risky size, **split early** into focused modules:

| Layer | Split pattern |
| :--- | :--- |
| **Feature UI** | Screen shell · widgets · controllers/helpers · sheets |
| **Brain/Data** | Domain parts under `records/*`, `plans/*`, `categories/*`, `profile/*`, `local_sync/*`; keep coordinators thin |
| **Core widgets** | One canonical component per file; small private layout helpers only |
| **Platform** | Native/runner/config only — **never** absorb product logic |
| **Docs/scripts** | Generated or reference material may be large if clearly marked generated/reference |

**Risk thresholds (watchlist, not auto-split triggers):** Dart UI/coordinator files **>1000 lines** → plan decomposition; Brain domain parts **>1500 lines** → consider further `part` split; any file mixing unrelated domains → split regardless of line count.

### New-feature checklist (required before implementation)

Every new feature prompt must answer:

1. Which **existing layer** owns this feature?
2. Which **existing screen / service / Brain module** does it extend?
3. Which **canonical components** does it use (`AppButton`, `PlanTimeTaskCard`, Omni-Picker, offline banner, etc.)?
4. Does it need **PocketBase schema / DATA_MAP** changes?
5. Does it create a **file-size or mixed-responsibility** risk?
6. Do **docs / tests / APP_STRUCTURE_DETAILED** need updates?

Run `.\scripts\audit\architecture_guard.ps1 -Strict` after structural edits. Regenerate `docs/APP_STRUCTURE_DETAILED.md` after tree changes.
