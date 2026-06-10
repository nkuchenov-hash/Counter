# Life OS — Roadmap

**Single canonical plan.** Drawn from the April 2026 audit (`docs/reports/AUDIT_NOTES.md`). Updated 2026-06-09.

> Other docs (`CLAUDE.md`, `docs/AI_CONTEXT.md`) link here — do not maintain a second roadmap copy.

---

## The goal

Build the best time tracker possible. Every UI component lives in one place and changes everywhere when you touch it once. Designed to last.

---

## Priority rule

Two parallel tracks. Always work the **🔴 Correctness track** first when one is open — bugs that hurt users beat everything. Otherwise drop into the **🟢 Velocity track**, ordered by *token-savings-per-iteration*: do the things first that make every future AI session cheaper and faster.

The velocity rule exists because Nick is a UX designer working with AI assistants on a split codebase. Every minute the AI wastes hunting through code is a minute Nick pays for and waits for. Tidiness for tidiness' sake is not a goal — tidiness *that compounds* is.

---

## Execution order

```
~~C1~~ ✅ → ~~O1~~ ✅ (Offline-first) → ~~V1~~ ✅ (CLAUDE.md nav map) → ~~F1~~ ✅ (Lists completion) → F2 (Plans completion) → F3 (Auto-save) → V3 (UX_CONTRACT) → V7 (Design Language)
```

**F1 is unblocked** after O1.4 audit (2026-06-09). Start with V1 if `CLAUDE.md` nav map still lags the God Object split.

---

## 🔴 Correctness Track

### ~~O1 — Offline-first core reliability~~ ✅ (shipped 2026-06-09)

**Goal:** The app must remain usable without internet. User actions must update UI immediately, save locally, queue failed network mutations, and sync to PocketBase when connection returns.

| Sub-phase | Scope | Status |
| :--- | :--- | :--- |
| **O1.1** | Record Start / Stop offline | ✅ |
| **O1.2** | Record Edit / Delete offline | ✅ |
| **O1.3** | Planning + Lists CRUD + done-toggle offline | ✅ |
| **O1.4** | Audit, restart/auth/banner polish, ordering docs | ✅ |

**Scope — Timeline records:**
- Start works offline
- Stop works offline
- Edit/update works offline
- Delete works offline

**Scope — Planning and Lists:**
- Create works offline
- Update works offline
- Delete works offline
- Done-toggle works offline

**Local mutation queue (target schema):**
- `operation_id`
- `collection` name
- `operation_type`: create / update / delete
- `business_id`: `record_id` / `plan_id` / `category_id` / `tag_id`
- PocketBase system id if known
- `payload`
- `created_at`
- `retry_count`
- `last_error`
- `sync_status`

**Sync behavior:**
- If network is unavailable, do not lose the action
- Store the mutation locally
- Replay pending mutations when connection returns
- Merge PocketBase response back into local cache after sync
- 401/403 pauses sync and surfaces session/sign-in error
- 404 reconciles or purges ghost state using existing architecture

**UI (`app_shell.dart`):**
- Subtle global sync/offline indicator
- Online and synced: no noisy UI
- Offline with pending changes: show “Offline · X pending”
- Syncing: show “Syncing…”
- Sync error: show subtle warning

**Rules:**
- Respect Optimistic UI / Zero-await laws
- Do not await network before visual update
- Server remains final authority for Singleton Timeline Law and overlap cleanup
- Do not rewrite unrelated features

**O1.4 audit summary (2026-06-09):**
- **Restart hydration:** `record_mutation_outbox_v1` + `plan_mutation_outbox_v1` persist in SharedPreferences — pending mutations survive app restart. `loadInitialData` → `flushPendingLocalMutations()` + `refreshPendingCount()` on boot; app resume also triggers flush.
- **Optimistic UI after restart:** in-memory overlays (`_planningOptimisticByDateKey`, `_optimisticDeletedKeys`, `_optimisticEndByKey`) are **not** persisted. After restart the UI reflects server/cache fetch until outbox flush merges server truth. User may briefly see stale server rows until pending ops replay (banner shows pending count).
- **Ordering:** coalescing documented in outbox `coalesceQueue` (records + plans). FIFO across entities; per-id merge/delete rules enforced on enqueue.
- **Auth:** 401/403 sets `offlineSync.authPaused` + enqueue `paused_auth`; flush skipped until valid session. Login / tap-to-retry calls `resumeAfterAuthIfNeeded()` then flush. Auth-specific banner string + existing `_brainSnackError` on mutation paths.
- **Banner:** quiet only when fully synced; online-with-pending shows “%s pending sync”; offline shows “Offline · %s pending”.
- **Retry:** `SyncManager` + tap-to-retry → `flushPendingLocalMutations()`; retriable errors enqueue; non-retriable (400/404 validation) drop on flush.

**O1 remaining limitations (defer):**
- Outbox queues are **device-global**, not scoped per PocketBase user — sign-out does not clear them (single-user-per-device assumption). Multi-account on one device needs user-scoped prefs keys.
- Virtual recurring plan rows (`virt-…`) still require network for exception/materialize flows.
- `bulkUpdatePlans` / `markPlanningTasksCompletedBulk` / plan order debounce are not fully offline-queued.
- Optimistic timeline/plan overlays lost on process death until outbox replay completes.

---

### Phase 1 bugs — 2 remaining

| Priority | Where | What breaks | Status |
| :--- | :--- | :--- | :--- |
| 🔴 Critical | `models/category.dart` | Category ID hash collision → category tree silently corrupts | ✅ Fixed (`_stableStringHash`, FNV polynomial) |
| 🔴 Critical | `models/record.dart` | Timeline records bucketed on wrong day for travelers | ✅ Fixed (`timezoneOffsetHours` on `TimelineRecord`) |
| 🟡 High | `database_service.dart` | Mixed timezone sources in stale-row detection (`_rowStartWallDayIsBeforeProjectedToday`) | ✅ Fixed in `393bb0f` |
| 🟡 High | `models/record.dart` | Same timezone bug in date parsing (`_parseFlexDateOnly`) | ✅ Already fixed — `_parseFlexDateOnly` not present in production code post-split |
| 🟠 Medium | `category_service.dart` | Category silently drops from saved records during cold start — no error thrown | ✅ Fixed in C1 — `_mapCategoryIdToLinkForPb` now logs `[CAT_MAP]` debugPrint on drop |

Low severity (defer): `auth_service.dart:134, 163` — non-deterministic UID fallbacks.

---

### ~~C1 — Sync & Reactivity~~ ✅ (shipped 2026-05-01)

- `profile_service.dart`: tag mutations (`createTagForCurrentUser`, `deleteTagByPocketRecordId`, `patchTagForCurrentUser`) now update `_userTagsCatalogCache` and call `notifyTagsCatalogChanged()` — tags push to UI without manual refresh (#16)
- `category_service.dart`: `_mapCategoryIdToLinkForPb` silent drop replaced with `debugPrint('[CAT_MAP]')` including rawCat/bid/ruleName/ruleId (#9)
- `lists_view.dart`: `_onListToggleDone` is now truly optimistic — updates `_flat` in `setState` immediately, rolls back on PATCH failure, adds `TextDecoration.lineThrough` for completed items; removed non-optimistic `notifyPlanningRefresh()` call (#11)
- `_parseFlexDateOnly` timezone bug: confirmed not present in production code post-split (already resolved via God Object split)
- PocketBase realtime re-arm: confirmed existing `ensureRecordsRealtimeBridge()` calls in all login paths handle this correctly

---

## 🟢 Velocity Track

### ~~V1. Sharpen `CLAUDE.md` into a navigation map~~ ✅ (shipped 2026-06-10)

`CLAUDE.md` updated for O1 local sync (`lib/data/local_sync/`), flush/resume symbols, offline banner, F1 unblocked. Goal: any AI session answers "where do I open first?" from `CLAUDE.md` alone — **keep this table current when symbols move.**

---

### ~~F1 — Lists: Feature Completion~~ ✅ (shipped 2026-06-10)
**Completed after O1 + V1.**

Audit-first pass found the Lists UI mostly implemented already; final F1 work tightened active-chip ordering and list-tag hydration in Brain/cache paths.

User items in scope: #3, #4, #8, #20, and partial #2.

**Completed:**
- ✅ **Tags in Lists (#3):** `domain: list` tags are loaded via `fetchTagsForCurrentUser(scope: TagCatalogScope.list)`, shown in the Lists filter bar and card strip, available in the backlog edit sheet, reactive through `tagsCatalogUpdated`, and hydrated through combined plan/list tag catalogs for plain `tags_link` cache/replay paths.
- ✅ **Card text/checkbox alignment (#4):** `_BacklogPlanCard` centers the compact checkbox/status control against the title column for one-line and two-line titles.
- ✅ **Active chip always-first (#8):** Active category/list-tag chips move to index 0 and the bar scrolls to start on tap; manual category chip mode uses the same scroll controller.
- ✅ **Export list as text (#20):** Visible filtered list items copy to clipboard as a numbered text list with a snackbar; no file/share sheet.
- ✅ **Remove play button from list card (#2):** `_BacklogPlanCard` / `_ListsSemicircleMenuOverlay` have no start/play action; Planning cards remain separate.

---

### F2 — Plans: Feature Completion
**Do after F1. One focused session.**

Plans has several UX gaps that make it feel unfinished. All are contained to `planning_view.dart` and `shared_widgets.dart` plus a new settings field.

User items in scope: #6, #7, #12, #13, #15, and #1.

**What to build / fix:**
- **Shrink plan tabs (#6):** The tab bar in Plans (`TabBar`) is too large and looks unorganized. Reduce tab height, font size, and padding to match a compact, tidy style. Tabs must still be tap-friendly (min 44px touch target).
- **Category default time setting (#7):** Add a per-category setting: "Default start time for new plans in this category." Stored as `default_plan_time` (HH:mm string) on the `categories` collection (new field — add to PocketBase and `DATA_MAP.md`). When a new plan is created and no time is parsed from input, apply the category's default time if set. UI: in the category edit sheet, a time picker field labeled "Default plan time". If not set, behavior unchanged (no time assigned).
- **Move play button in Plans (#12):** In `_PlanningTaskCard`, the play button is on the far right. Move it below the leading action button (the checkbox/circle area on the left side) to save horizontal space and reduce card width pressure. Layout: left column = [status circle, play button stacked], right = title + meta.
- **Recurring plan icon + edit scope dialog (#13):** Plans with a non-null `rrule` must show a recurring icon (e.g. `Icons.repeat`) on their card. When the user opens the edit sheet for a recurring plan instance, show a dialog before opening: "Edit this occurrence only" / "Edit all future occurrences". This is the standard calendar app pattern. "This only" adds an exception date and creates a materialized copy (existing `_completeVirtualRecurringInstance` pattern). "All future" patches the template row's `rrule` / times.
- **Plan filter config (#15):** Add a small settings icon button at the end of the Plans sort/filter bar. Tapping opens a bottom sheet: a checklist of categories the user can toggle on/off to show/hide from the current plan view. Persisted to `SharedPreferences` key `plans_hidden_category_ids`. Filtered categories are hidden from the plan list but not deleted. The icon shows a badge if any categories are currently hidden.
- **Remove black app header (#1):** Remove the dark/black app header bar from the Plans (and any other) screen where it appears. The `GlobalAppHeader` (date/time strip) stays. Only the opaque black navigation-style bar goes.

---

### F3 — Auto-save
**Do after F2. Touches shared_widgets.dart deeply — do in isolation.**

User item: #14. Also resolves the "notes deleted on close" complaint.

**What to build:**
- In `ActivityDetailSheet` and `_PlanningTaskEditSheet`: replace the explicit Save button with debounced auto-save. On any field change, wait 800ms of inactivity, then fire the PATCH optimistically (update local cache first, sync async, rollback on failure per Iron Law).
- Notes field (`notes_delta` / `notes_plain`) must auto-save on every Quill change event with the same debounce. This is the most important one — notes are currently lost on sheet close without Save.
- The sheet close button (X) triggers an immediate flush of any pending debounce before dismissing.
- Remove the Save button from both sheets. Keep Delete.
- If PATCH fails during auto-save, surface one snackbar error (existing `_brainSnackError` pattern) and re-enable a manual "Retry" button in the sheet header only while the error state is active.

---

### V2. Skills docs for repeated task patterns
**Write as you encounter the pattern — do not batch upfront.**

Short reference docs for tasks Claude Code re-derives every time. Candidates: "How to add a field end-to-end", "Optimistic UI checklist for a new action", "How to add a new PB error-path debugPrint".

---

### V3. Phase 3c — Write `UX_CONTRACT.md`
**Effort: medium. Savings: high — once written, every UI question gets a one-doc answer.**

A single written spec for how the UI responds to every user action — tap, save, edit, delete, drag, swipe, error, offline, loading, empty state. Same authority as the Iron Laws. Unblocks V7 and V8.

---

### V4. Phase 3b leftovers — judgment-call merges
**Only when the file is already open for another reason.**

- Merge `_PlanningTaskCard` and `_BacklogPlanCard` — same card, different optional features. (F1 and F2 will make this more obviously right.)
- Promote `_ListsQuadraticChip` to a filter mode of `CategoryChip`.

Keep separate: web vs mobile date picker, `RecordCategoryHeader` (breadcrumb), `TagQuickPickStrip` (container), `CategoryFolderTile` (folder).

---

### V5. Split `database_service.dart`
**Already done (V5.1–V5.5). God Object split complete.**

Status: `database_service.dart` ~720 lines. All domains extracted to part files. ✅

---

### V6. Tooling cleanup & technical debt
**Not urgent. Later cleanup — not F1/F2.**

- **`Archive/tool/test_smart_parse.dart`** — dev-only smart-parse probe; `avoid_print` suppressed. Former repo-root `tool/` lives under `Archive/tool/` after June 2026 cleanup.
- **Replace dynamic IconData with fixed icon registry** — Flutter web release builds need `--no-tree-shake-icons` because category icons are created dynamically from stored `icon_code_point` values (`CategoryRule.iconCodePoint` → `IconData(...)`). **Current workaround:** `update.ps1` / `scripts/manual/td.ps1` and GitHub Actions CI pass `--no-tree-shake-icons`. **Proper fix:** persist stable icon keys/names (e.g. `'work'`, `'home'`) instead of arbitrary code points; resolve through a const registry, e.g. `const Map<String, IconData> appIcons = { 'work': Icons.work, 'home': Icons.home, ... }`. **Scope:** category model, category create/edit UI, `category_service.dart`, migration/backward compatibility for existing `icon_code_point` rows, `docs/DATA_MAP.md` / `docs/POCKETBASE_MANIFEST.md` if field meaning changes.

---

### V7. Phase 4 — Design Language
Typography scale, color tokens, spacing system, motion principles. Unblocked by V3.

---

### V8. Phase 5 — Per-Screen Polish + Accessibility
Apply design language and UX contract screen by screen.

---

### V9. Phase 6 — Growth / Market Differentiation
Defined once foundation is solid.

---

## 🚫 Out of scope / separate projects

- **Image & file attachments (#17):** Requires PocketBase file storage config, upload flow, CDN/storage decisions, and model changes. Scope as a separate project spec before any code is written. Do not fold into any session above.
- **Calendar adjacent-month overflow (#19):** Show leading/trailing days from adjacent months in the monthly calendar view. Low priority, purely cosmetic. Do when `calendar_view.dart` is already open for another reason.

---

## ✅ Completed

### ~~Phase 0 — Cleanup (Rounds 1–4, April 2026)~~
- ~~**Round 1+2** — Deleted 11 legacy backend files.~~
- ~~**Round 3a** — Removed dead imports, unused widget classes, dead constants.~~
- ~~**Round 3b/3c** — Further dead code removal across 4 files.~~
- ~~**Round 4a–4d** — `avoid_print` sweep: 17 deleted, 45 converted to `debugPrint`, 3 kept. Zero violations.~~

### ~~Phase 2 — Audit~~
~~Full audit documented in `docs/reports/AUDIT_NOTES.md`.~~

### ~~Phase 3a — Kill the duplicate edit sheet~~
~~`EditRecordSheet` deleted. All entry points route to `_TimelineRecordSheetContent`.~~

### ~~Phase 3b — Component library (core pieces)~~
- ~~`AppLoading(size)`, `showConfirmDialog()`, `AppButton`, `AppErrorState`, `AppEmptyState` — all built in `core/widgets/`.~~

### ~~Phase 1 bugs (3 of 5)~~
- ~~Category ID hash collision — fixed.~~
- ~~Timeline timezone bucketing — fixed.~~
- ~~Mixed timezone in stale-row detection — fixed.~~

### ~~V5 — God Object split (V5.1–V5.5, April 2026)~~
- ~~`profile_service.dart` (~666 lines) extracted.~~
- ~~`plan_service.dart` (~2,803 lines) extracted.~~
- ~~`record_service.dart` (~2,407 lines) extracted.~~
- ~~`category_service.dart` (~3,158 lines) extracted.~~
- ~~`db_core.dart` (~418 lines) extracted.~~
- ~~`database_service.dart` reduced to ~720 lines.~~

---

## Snapshot (June 2026)

- **Repo root:** `C:\Users\nkuch\Development\Apps\counter` (flattened from nested `counter/counter/`; outer skeleton in `counter_WRAPPER_BACKUP`)
- **Live at:** `nkuchenov-hash.github.io/Counter/`
- **Update website:** `.\update.ps1` from repo root — see `docs/DEPLOY.md`
- **Backend:** PocketBase, self-hosted
- **Targets:** Android, iOS, Web, Windows, macOS, Linux, Wear OS
- **Stack:** Flutter
- **Analyzer:** 11 info-only issues (0 errors, 0 warnings) after June 2026 hygiene pass
- **Architecture:** Iron Laws honored. God Object split complete. **O1 offline-first ✅** (records + plans/lists). Velocity track: V1 → F1/F2.
