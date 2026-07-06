# UX Contract

This document defines how Life OS behaves when people interact with it. It is the behavioral source of truth that sits beside `ARCHITECTURE.md`; app code and feature screens must follow it before adding new UI patterns.

## Core Rules

- Every user action must produce visible feedback within ~100ms.
- User intent updates local UI first, then syncs in the background when the action writes data.
- Errors are visible, specific enough to act on, and never spammed.
- Loading, empty, disabled, and offline states are first-class states, not afterthought text.
- Feature screens compose canonical components from `lib/core/widgets/` and approved shared feature widgets.

## Tap Feedback

- Tappable controls must have an obvious pressed/selected/disabled state.
- Icon-only actions require tooltips where practical.
- A tap that opens a sheet, menu, route, picker, or mode must respond immediately.
- Debounce repeated destructive or sync-heavy actions at the handler boundary.

## Save Behavior

- Saves that affect records, plans, lists, categories, tags, or profile settings must update local state before network sync when the current architecture supports it.
- Retriable network failures keep the optimistic state and enqueue where an outbox exists.
- Non-retriable validation/schema failures roll back and show one concise error.
- Silent success is preferred; no success log spam for background sync.

## Edit Behavior

- Edit sheets must show the current value immediately and keep unsaved user input stable while network work runs.
- Field controls must not reset on rebuild unless the source record changed.
- Expensive parsing or list refreshes must not block text entry, tap response, or sheet opening.

## Delete Behavior

- Destructive actions require either an explicit confirmation or a clearly reversible affordance.
- Delete UI should disappear optimistically after confirmation.
- Failed non-retriable deletes restore the item or show a clear recovery path.
- Background delete retries must not produce repeated identical errors.

## Loading States

- Use `AppLoading` for canonical loading indicators.
- Full-page loading should center the indicator with enough padding.
- Inline loading should preserve layout size where possible.
- Do not replace already loaded content with a full blank loader for a small background refresh.

## Empty States

- Use `AppEmptyState` when a surface loads successfully but has no items.
- Empty states must explain what is empty and, when useful, offer the next safe action.
- Do not show empty states while data is still loading.

## Error States

- Use `AppErrorState` for blocking surface-level failures.
- Use snackbars for action failures where the existing surface can stay rendered.
- Error messages must avoid exposing backend internals unless they are needed for debugging.
- Repeated background errors must be debounced.

## Offline / Pending Sync States

- Offline actions should remain usable when the relevant outbox supports them.
- Pending sync should be visible through the global sync/offline banner, not per-row noise.
- Auth-paused sync must clearly indicate that sign-in/session repair is needed.
- Manual retry should call the existing outbox flush path.

## Disabled States

- Disabled controls must remain visible when they explain unavailable capability.
- Use disabled state for missing prerequisites, not hidden UI, unless the feature is admin-only or permission-only.
- Disabled controls should preserve layout to avoid jumpy screens.

## Sheet Close Behavior

- Closing a sheet must not discard committed state.
- If a sheet contains unsaved local edits, it must either autosave/flush pending edits or ask for confirmation.
- Sheets that perform background writes must remain closeable unless closing would corrupt state.

## Picker / Taxonomy Creation

- Category pickers opened from edit sheets or category-selection controls must offer **New category** without closing the parent edit flow.
- When search/filter text does not match an existing category, show a contextual **Create “&lt;name&gt;”** action when online.
- Category creation requires network connection; do not invent client-only temporary categories or fake ids.
- After successful creation, refresh the in-memory category cache via the Brain path, close only the create dialog, keep the parent picker/sheet open, and auto-select the new category with the same save/autosave behavior as picking an existing row.

## Selection / Bulk Mode

- Bulk mode must have a clear entry and exit.
- Selected rows/cards must have a persistent selected state.
- Bulk action bars must not cover critical row controls without providing enough bottom padding.
- Exiting bulk mode should clear selection predictably.

## Drag / Reorder Behavior

- Drag handles or long-press affordances must be discoverable.
- Reorder should update local order immediately.
- Persisted order sync should be batched or debounced and must not block drag motion.
- Failed reorder sync should restore or reconcile order without duplicating rows.

## Optimistic UI Expectations

- Records and Planning/Lists CRUD follow the Iron Laws: local shadow first, network later.
- The UI must not wait for PocketBase writes before reflecting a user action.
- Rollback is reserved for non-retriable failures; ordinary offline/network failures use queues where available.
- Do not introduce full refetch fan-out after a small mutation unless unavoidable.

## Performance & Responsiveness Contract

Performance, responsiveness, and stability are **P0 correctness**, not polish. See `docs/ARCHITECTURE.md` § **PERFORMANCE_KILL_SWITCH_LAW**.

- Every user action must produce **visible feedback within ~100ms**.
- Local/optimistic UI must update **before** network I/O for record/plan mutations.
- Already loaded content must **not** be replaced by blank/loading state for a background refresh.
- UI must **never** show partial/incomplete card states as an intentional loading phase.
- If content is not ready, do not reveal broken/partial UI — but readiness gates must **not** break live updates or freeze navigation.
- Any perceived performance regression (lag, freeze, missing instant update, “impossible to work”) is a **P0 correctness bug** and outranks feature/design/preload work.
- No feature, design, preload, cache, animation, or architecture idea may remain active if it hurts app speed or stability.

## Planning Time Mode

- **Timezone / storage:** Plan and record instants are stored as **UTC ISO**. Time mode projects them into the **profile timezone** for day filter, block placement, labels, and drag/resize math. User-entered wall time at create/edit belongs to the **current profile timezone**.
- **Current-time line:** Uses profile-projected “now”; renders **above** plan cards (`IgnorePointer`); must not sit behind blocks.
- **Visible range:** No “outside visible range” / out-of-hours fallback bucket. Scheduled cards outside the selected wall day or visible hour range are **not shown**.
- **Snap / duration:** Time mode supports **10-minute** minimum duration and **10-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`).
- **Dense hour cap:** One wall-clock hour visually stretches to at most **248 px** (six 10-minute cards at 38 px + 4 px gaps). Card heights use piecewise anchors (10→38, 30→75, 60→120 px), not unbounded proportional stretch.
- **Card density:** Short blocks use **micro** / **compact** layouts (essential controls only). **Medium** / **large** blocks show progress separator + category breadcrumb + planned time footer (`PlanTimeTaskCard`).
- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; optimistic schedule updates follow the Iron Laws.

## Edit sheet Save (local-first)

- **Save is a local commit button**, not a network gate. Valid Save applies optimistic Brain/cache/UI **immediately**, shows **Changes saved** (or a specific validation error), and closes the sheet without waiting for PocketBase.
- **Explicit Save beats autosave:** `EditSheetAutosaveGate.flush(force: true)` always runs the latest draft sync and cancels pending debounce; autosave debounce must read the latest controller state at fire time, not a stale captured draft.
- **Network is background:** PocketBase PATCH runs after local apply; retriable failures keep optimistic UI and enqueue outbox; non-retriable failures roll back once with one error snack.
- **Validation feedback:** Empty title or missing required times show an immediate localized warning — never a silent no-op tap.

## Recurring plan edit/delete scope

- **One stored row per series:** Client expands `plans.rrule` into virtual `virt-{seriesPb}-{YYYY-MM-DD}` rows for the visible window; `exception_dates` omits instances; materialized one-offs link to the series via `parent_plan_id` + `recurrence_instance_date_key`.
- **Scope dialog (EN/RU):** Editing or deleting a recurring/virtual/materialized occurrence prompts:
  - **This event** — single occurrence only (`exception_dates` + materialized one-off on edit; exception only on delete for virtual rows).
  - **This and following events** — disabled until safe RRULE split-series (UNTIL boundary) ships.
  - **All events in the series** — PATCH/DELETE the stored series row only (15-char PocketBase `id`; never `virt-*`).
- **Dedupe:** Materialized occurrence for `{seriesPb, instanceDate}` suppresses the matching virtual card. Virtual rows must never enter persistent caches or REST PATCH/DELETE paths.

## Gesture Ownership / Date Swipe Law

- **Horizontal swipe inside Timeline and Planning changes the calendar day** (previous/next date). This is **required** product behavior — do not remove it, disable it globally, or replace it with tap-only navigation.
- **This is not main-tab navigation.** Bottom/side nav switches app sections; horizontal swipe within Timeline/Planning is **date** navigation.
- **Code:** `TimelineSwipeWrapper` (`lib/features/timeline/timeline_view.dart`), `PlanningSwipeWrapper` (`lib/features/planning/planning_view.dart`) — infinite day `PageView.builder`.
- **During Planning Time-mode card drag/resize only:** horizontal date paging may be temporarily locked while the card owns the gesture; restore date swipe when the interaction ends.
- **Vertical scroll** stays vertical; tap opens edit; long press starts drag where supported. Gesture conflicts are P0 bugs.
- **Performance work** must not stack experiments on a regressing build. If swipe/startup/optimistic UI regresses, **stop** and apply the Performance Kill Switch Law (`ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW) — disable the risky path, restore stable paging, restore live optimistic sources, then re-measure. Profile-mode/DevTools proof is required **before** re-enabling any experimental preload layer; “the cache exists” / “snapshot is ready” / “body cache exists” is **not** sufficient if the user sees lag, loading, or crash.
