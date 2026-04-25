# Life OS — Roadmap (April 2026)

Drawn from the April 2026 full-codebase audit. Phases are ordered by dependency, not timeline.

---

## The goal

Build the best time tracker possible. Every UI component lives in one place and changes everywhere when you touch it once. Designed to last.

---

## Phase 1 — Stop the Bleeding
**Fix real bugs before anything else.**

Five confirmed bugs. Two are silent data corruptors that affect travelers and multi-device users today.

| Priority | Where | What breaks |
| :--- | :--- | :--- |
| 🔴 Critical | `models.dart:1157` | Category ID hash collision → category tree silently corrupts |
| 🔴 Critical | `models.dart:1220` | Timeline records bucketed on wrong day for travelers (uses device timezone, not profile timezone) |
| 🟡 High | `models.dart:709` | Same timezone bug in date parsing |
| 🟡 High | `database_service.dart:3830` | Mixed timezone sources in stale-row detection |
| 🟠 Medium | `database_service.dart:3517` | Category silently drops from saved records during cold start — no error thrown |

Low severity (non-urgent): `auth_service.dart:134, 163` — non-deterministic UID fallbacks. Defer.

---

## Phase 2 — Audit
**Status: ✅ Complete.**

Full audit documented in `AUDIT_NOTES.md`.

---

## Phase 3 — Foundation
**Build the base that everything else sits on.**

Three parallel workstreams. Do them roughly in order — they each unblock the next phase.

### 3a. Kill the duplicate edit sheet
One thing to fix before any design work starts.

Two sheets currently edit the same timeline record from different entry points:
- `EditRecordSheet` — older, NocoDB-era, works with raw data maps
- `_TimelineRecordSheetContent` — newer, typed, should be the only one

**Action:** Delete `EditRecordSheet`. Route all entry points to `_TimelineRecordSheetContent`. Until this is done, fixing a bug in one means the other still has it.

### 3b. Build the component library
**Target: every reusable UI element lives in `core/widgets/`. Zero duplicates.**

Current state of the 29 existing components:
- 2 in `core/widgets/` — the only true shared primitives
- 8 in `features/shared/` — shared but not in core
- 19 scattered across feature folders — not reusable without copying

**Missing pieces to build (in order):**

| What | Why it's needed |
| :--- | :--- |
| `AppLoading(size)` widget | 17 inline `CircularProgressIndicator` calls exist with inconsistent `strokeWidth`. One component fixes all 17. |
| `showConfirmDialog(title, body)` | 8 inline `AlertDialog` confirms are scattered. One function, consistent behavior. |
| Error-state widget | Currently zero exist. Every screen handles errors differently (or not at all). |
| Empty-state widget | One exists. May need variants. |
| Button component | Currently zero custom buttons. |

Lower priority consolidations (judgment calls, do when the area is already open):
- Merge `_PlanningTaskCard` and `_BacklogPlanCard` — same card, different optional features
- Promote `_ListsQuadraticChip` to a filter mode of `CategoryChip`

**Keep separate (intentional differences, don't merge):**
- Web vs mobile date picker — platform difference is correct
- `RecordCategoryHeader` — it's a breadcrumb, not a chip (rename it someday)
- `TagQuickPickStrip` — a container of chips, not a chip
- `CategoryFolderTile` — a folder tile, not an activity card

### 3c. Write UX_CONTRACT.md
**The most important design document this app doesn't have yet.**

A single written spec defining exactly how the UI responds to every user action — universally, across every screen. Covers: tap, save, edit, delete, drag, swipe, error, offline, loading, empty state. Treated with the same authority as the Iron Laws in `ARCHITECTURE.md`.

Once written, every new screen and component is built against it. Without it, each feature invents its own behavior.

### 3d. God Object — defer
`database_service.dart` is 10,222 lines and could be split into 5 focused files. The app works fine today. **Don't split it until the pain of working in it makes it unavoidable.** When that day comes, the split plan is already designed in `AUDIT_NOTES.md`.

---

## Phase 4 — Design Language
**Make it look like a deliberate product, not assembled code.**

- Typography scale
- Color tokens
- Spacing system
- Motion / animation principles

This phase is unblocked once the component library exists (Phase 3b), because tokens only work when there's one place to apply them.

---

## Phase 5 — Per-Screen Polish + Accessibility
**With the foundation in place, go screen by screen.**

Apply the design language and UX contract to every surface. Fix accessibility gaps.

---

## Phase 6 — Growth / Market Differentiation
**What makes this the best time tracker.**

TBD — defined once the foundation is solid.

---

## Snapshot (April 2026)

- **Live at:** `nkuchenov-hash.github.io/Counter/`
- **Backend:** PocketBase, self-hosted
- **Targets:** Android, iOS, Web, Windows, macOS, Linux, Wear OS
- **Stack:** Flutter
- **Architecture:** disciplined, Iron Laws documented and mostly honored
