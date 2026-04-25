# Life OS — Audit Notes (April 2026)

Findings from a full-codebase audit. Use these to write ROADMAP.md and update CLAUDE.md.

---

## Owner's goals (Nick)

- Build the best time tracker possible. Long-term success.
- I'm a UX designer, not a developer. Code so far is functionality-only — no UX/UI design pass yet.
- I want the app "tidy as shit": every reusable thing lives in one place, change it once → changes everywhere.
- "Worst case I learn how to build apps like a god."

---

## Audit 1 — God Object

**File:** `lib/data/database_service.dart`
- 10,222 lines, ~130 public methods. 5–10x larger than healthy.

**Proposed 5-file split (facade pattern, zero caller changes):**
1. `db_core.dart` (~900 lines) — bootstrap, streams, lifecycle
2. `record_service.dart` (~2,500 lines) — timeline records
3. `plan_service.dart` (~2,500 lines) — planning, rrule, AI parsing
4. `category_service.dart` (~3,500 lines) — biggest domain
5. `profile_service.dart` (~800 lines) — user, settings, tags, auth

**Order if/when split:** profile → tags → plans → records → categories.

**Verdict:** NOT urgent. App works. Defer until pain demands it.

---

## Audit 2 — Iron Law violations (real bugs)

3 of 5 laws clean. 4 bugs found:

| # | Severity | File:line | Bug |
|---|---|---|---|
| 1 | CRITICAL | `models.dart:1157` | `hashCode` fallback for category ID can collide → silent category tree corruption |
| 2 | CRITICAL | `models.dart:1220` | `TimelineRecord.dateKey` uses device timezone, not profile timezone → records bucketed on wrong day for travelers |
| 3 | HIGH | `models.dart:709` | Same `.toLocal()` issue in `_parseFlexDateOnly` |
| 4 | HIGH | `database_service.dart:3830` | Mixed timezone sources in stale-row detection |

LOW severity (defer): `auth_service.dart:134, 163` — non-deterministic UID fallbacks.

---

## Audit 3 — Drift risk (category_id vs category_link)

Two columns store category info. `category_id` is used; `category_link` is actively stripped from every save. No drift (one is unused).

**One new bug found:**

| # | Severity | File:line | Bug |
|---|---|---|---|
| 5 | MEDIUM | `database_service.dart:3517` | `_mapCategoryIdToLinkForPb` silently drops `category_id` from save payload if any of 5 conditions fail (e.g., during cold start). Records save with no category, no error. |

**Long-term:** drop the unused `category_link` column entirely. Not urgent.

---

## Audit 4 — Component inventory

29 custom UI components. Distribution:
- 2 in `core/widgets/` (only true primitives)
- 8 in `features/shared/`
- 19 scattered across feature folders

**Gaps:** 0 custom buttons, 0 error states, 0 skeleton loaders, 1 empty state, 17 inline `CircularProgressIndicator` with drifting strokeWidth.

### Consolidation priorities

**🔴 CRITICAL — fix soon:**
- **Two timeline edit sheets coexist.** `EditRecordSheet` (older, NocoDB-era, raw Map) and `_TimelineRecordSheetContent` (newer, typed) both edit the same record. Behavior diverges by entry point. Kill the older one.

**🟡 IMPORTANT — design system phase:**
- 8 inline AlertDialog confirms → consolidate into `showConfirmDialog(title, body) → bool?`
- Build `AppLoading(size)` to replace 17 inline `CircularProgressIndicator` calls
- Build error-state widget (currently zero exists)

**🟢 JUDGMENT CALLS — not urgent:**
- `_PlanningTaskCard` vs `_BacklogPlanCard` — same card with different optional features (progress bar, date tap). Mergeable with parameters.
- `_ListsQuadraticChip` — could become a 6th `CategoryChip` mode (filter). Forked because filter bar lacks category data, making CategoryChip's call site verbose.

**⚪ KEEP SEPARATE (intentional differences):**
- Web vs mobile date picker — legitimate platform difference
- `RecordCategoryHeader` — it's a breadcrumb, not a chip. Rename someday.
- `TagQuickPickStrip` — a container of chips, not a chip
- `CategoryFolderTile` — a folder, not an activity card

---

## Design philosophy (bake into roadmap as principles)

1. **Single Source of UI Truth.** Every reusable component lives in `core/widgets/`. Feature folders COMPOSE primitives, never reimplement. Variations are parameters, not copies.
2. **Edit sheets:** shared shell (header, save/delete/cancel, dismiss, error states) + per-feature content slots. Merge scaffolding, not field content.
3. **Need `UX_CONTRACT.md`** — written document defining how UI ALWAYS responds to user actions: tap, save, edit, delete, drag, swipe, error, offline, loading, empty. Universal across every screen. Treated like the Iron Laws. This is the "biblical" piece for a consistent design-system-driven app.

---

## Roadmap phases (to detail tomorrow)

- **Phase 1 — Stop the bleeding:** Fix the 5 real bugs (above)
- **Phase 2 — Audit:** ✅ Done (this document)
- **Phase 3 — Foundation:**
  - Component consolidation (build primitive library)
  - Write `UX_CONTRACT.md`
  - God Object split (defer until painful)
- **Phase 4 — Design language:** typography, color tokens, spacing, motion
- **Phase 5 — Per-screen polish + accessibility**
- **Phase 6 — Growth / market differentiation**

---

## Snapshot

- Live at: `nkuchenov-hash.github.io/Counter/`
- Backend: PocketBase, self-hosted
- Targets: Android, iOS, Web, Windows, macOS, Linux, Wear OS
- Architecture: disciplined, Iron Laws documented and mostly honored
- Git: main branch, ahead of origin by checkpoint commits
- Stack: Flutter
