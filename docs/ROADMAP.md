# Life OS — Roadmap (April 2026)

Drawn from the April 2026 full-codebase audit. Updated 2026-04-27.

---

## The goal

Build the best time tracker possible. Every UI component lives in one place and changes everywhere when you touch it once. Designed to last.

---

## Priority rule

Two parallel tracks. Always work the **🔴 Correctness track** first when one is open — bugs that hurt users beat everything. Otherwise drop into the **🟢 Velocity track**, ordered by *token-savings-per-iteration*: do the things first that make every future AI session cheaper and faster.

The velocity rule exists because Nick is a UX designer working with AI assistants on a 10k-line file. Every minute the AI wastes hunting through code is a minute Nick pays for and waits for. Tidiness for tidiness' sake is not a goal — tidiness *that compounds* is.

---

## 🔴 Correctness Track — Phase 1 bugs

**Status: 3 of 5 fixed. 2 remaining.**

| Priority | Where | What breaks | Status |
| :--- | :--- | :--- | :--- |
| 🔴 Critical | `models/category.dart` | Category ID hash collision → category tree silently corrupts | ✅ Fixed (`_stableStringHash`, FNV polynomial) |
| 🔴 Critical | `models/record.dart` | Timeline records bucketed on wrong day for travelers | ✅ Fixed (`timezoneOffsetHours` on `TimelineRecord`) |
| 🟡 High | `database_service.dart` | Mixed timezone sources in stale-row detection (`_rowStartWallDayIsBeforeProjectedToday`) | ✅ Fixed in `393bb0f` — `toLocal()` replaced with `_timelineDeviceLocalDayKeyFromUtc`; two misleading doc comments corrected 2026-04-27 |
| 🟡 High | `models.dart:709` | Same timezone bug in date parsing (`_parseFlexDateOnly`) | ⏳ Open — locate by symbol, line number is pre-split |
| 🟠 Medium | `database_service.dart` | Category silently drops from saved records during cold start — no error thrown | ⏳ Open — locate by symbol near `loadInitialData` cold-start path |

Low severity (defer): `auth_service.dart:134, 163` — non-deterministic UID fallbacks.

---

## 🟢 Velocity Track — ordered by token-savings-per-iteration

### V1. Sharpen `CLAUDE.md` into a navigation map
**Effort: small. Savings: every session, forever. Highest ROI on the board.**

`CLAUDE.md` is solid as a rules document but weak as a routing document. Right now an AI reading it learns the laws but not where things live. Add a "Where things live" section so the AI opens the right file on first try without scanning the 10k God Object.

Concretely, add a table like:
- Stop logic → `database_service.dart` → `stopRecordByDocId`
- Start logic → `database_service.dart` → `writeRecord`
- Optimistic UI shadow → `database_service.dart` → `_upsertFlatRecordFromPbModel`
- Realtime subscribe → `database_service.dart` → [symbol]
- Category resolution → `database_service.dart` → `_resolveRecordIdForStopOrDelete` + smart-link helpers
- Timeline render → `app_shell.dart` → [symbol]
- Inline edit widget → `shared_widgets.dart` → [symbol]
- Planning task done-toggle → `planning_view.dart` → `_toggleDone`

Goal: any AI session can answer *"where do I open first?"* from `CLAUDE.md` alone, without grepping. This single change makes the 10k-line file dramatically less expensive to work with — without splitting it.

### V2. Skills docs for repeated task patterns
**Effort: small per skill, write as you encounter the pattern. Compounds with every repeat task.**

Short reference docs for tasks the AI re-derives every time. Each one replaces ~5–15 minutes of code-reading with a 30-second doc read. Candidates from observed work:
- "How to add a field to a record" (touches model, DB write, DB read, PB collection, UI)
- "How to add a new PB error-path debugPrint correctly"
- "Optimistic UI checklist for a new user-action button"
- "How to safely delete dead code without breaking imports" (Round 1–3 lessons)

Don't write all of these now — write each one the first time you notice the AI re-deriving the pattern.

### V3. Phase 3c — Write `UX_CONTRACT.md`
**Effort: medium. Savings: high — once written, every UI question gets a one-doc answer.**

A single written spec for how the UI responds to every user action — tap, save, edit, delete, drag, swipe, error, offline, loading, empty state. Same authority as the Iron Laws.

Without it, every new feature reinvents its own behavior and the AI has to ask. With it, the AI applies the contract and ships.

### V4. Phase 3b leftovers — judgment-call merges
**Effort: small. Savings: small but recurring (less "which one is canonical?" confusion).**

Do these only when the file is already open for another reason:
- Merge `_PlanningTaskCard` and `_BacklogPlanCard` — same card, different optional features.
- Promote `_ListsQuadraticChip` to a filter mode of `CategoryChip`.

Keep separate (intentional, do not merge): web vs mobile date picker, `RecordCategoryHeader` (it's a breadcrumb), `TagQuickPickStrip` (container of chips), `CategoryFolderTile` (folder, not card).

### V5. Split `database_service.dart` (the 10k God Object)
**Effort: large. Savings: large but one-time. Hard prerequisite: V1 must be done first.**

Promoted from "defer indefinitely" to *next big lift after V1–V4* — under the new priority rule, this file taxes every AI session. Splitting it is a one-time cost that pays back forever.

**Why V1 must come first:** if you split before `CLAUDE.md` is a proper map, the AI loses its mental model of where things live mid-surgery and writes worse code, not better. Sharpened map first, then split.

**Split plan already exists in `AUDIT_NOTES.md` (5-file split).** When you start, load that first.

**Hard rules for the split:**
- One PR per extracted file.
- `flutter analyze` must show zero new warnings after each PR.
- Update `CLAUDE.md` "Where things live" table in the same PR — never lag behind.
- Iron Laws (optimistic UI, no-await-before-UI, UTC storage, user_id filter) must be preserved verbatim — they're contracts, not implementation details.

### V6. Tooling cleanup leftovers
- `tool/test_smart_parse.dart:13` — last `avoid_print` violation, out of Round 4 scope. Quick fix.

### V7. Phase 4 — Design Language
Typography scale, color tokens, spacing system, motion principles. Unblocked by V3 and V4.

### V8. Phase 5 — Per-Screen Polish + Accessibility
Apply design language and UX contract screen by screen.

### V9. Phase 6 — Growth / Market Differentiation
Defined once foundation is solid.

---

## ✅ Completed (struck through, kept for history)

### ~~Phase 0 — Cleanup (Rounds 1–4, April 2026)~~
- ~~**Round 1+2** — Deleted 11 legacy backend files (Yandex YDB, NocoDB stubs, vestigial l10n, migration CSVs).~~
- ~~**Round 3a** — Removed dead imports, unused widget classes, dead constants.~~
- ~~**Round 3b/3c** — Further dead code removal across 4 files.~~
- ~~**Round 4a–4d** — `avoid_print` sweep across 6 files: 17 deleted (hot-path traces), 45 converted to `debugPrint`, 3 left as intentional boot-fail crash surfaces. Net: 65 prints touched, 0 violations remaining in scope.~~

### ~~Phase 2 — Audit~~
~~Full audit documented in `AUDIT_NOTES.md`.~~

### ~~Phase 3a — Kill the duplicate edit sheet~~
~~`EditRecordSheet` deleted. All entry points route to `_TimelineRecordSheetContent`.~~

### ~~Phase 3b — Component library (core pieces)~~
- ~~`AppLoading(size)` — built, 17 `CircularProgressIndicator` sites migrated.~~
- ~~`showConfirmDialog(title, body)` — built, replaces 8+ inline `AlertDialog` patterns.~~
- ~~`AppErrorState` — built (`app_state_views.dart`).~~
- ~~`AppEmptyState` — built (`app_state_views.dart`).~~
- ~~`AppButton` — built (`app_button.dart`).~~

### ~~Phase 1 bugs (3 of 5)~~
- ~~Category ID hash collision — fixed with `_stableStringHash`.~~
- ~~Timeline timezone bucketing — fixed with `timezoneOffsetHours` parameter.~~
- ~~Mixed timezone in stale-row detection — fixed in `393bb0f` (`_rowStartWallDayIsBeforeProjectedToday`); doc comments corrected 2026-04-27.~~

---

## Snapshot (April 2026)

- **Live at:** `nkuchenov-hash.github.io/Counter/`
- **Backend:** PocketBase, self-hosted
- **Targets:** Android, iOS, Web, Windows, macOS, Linux, Wear OS
- **Stack:** Flutter
- **Architecture:** Iron Laws documented and honored. `database_service.dart` still monolithic (10k+ lines) — split is V5 on the velocity track, gated on V1.
