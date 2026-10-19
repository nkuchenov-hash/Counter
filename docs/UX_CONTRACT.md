# UX Contract

This document defines how Life OS behaves when people interact with it. It is the behavioral source of truth that sits beside `ARCHITECTURE.md`; app code and feature screens must follow it before adding new UI patterns.

## Core Rules

**P0 — Optimistic UI first:** Every valid user action immediately changes the active visible UI; PocketBase, outbox persistence, refresh, and animations are secondary operations. Visual feedback target is **≤100 ms**, including create, edit, delete, start/stop, toggle, reorder, and bulk actions in Records, Plans, and Lists. A visible local acknowledgment must never be confused with confirmed remote synchronization. See `ARCHITECTURE.md` § `OPTIMISTIC_UI_FIRST`.

- Every user action must produce visible feedback within ~100ms.
- User intent updates local UI first, then syncs in the background when the action writes data.
- Errors are visible, specific enough to act on, and never spammed.
- Loading, empty, disabled, and offline states are first-class states, not afterthought text.
- Feature screens compose canonical components from `lib/core/widgets/` and approved shared feature widgets.

## Morning Start prompt (Timeline)

- The existing "Start the day" sleep check-in is enabled by default. Settings → Preferences → Start of day provides an explicit on/off switch (also available on mobile Settings).
- The switch is stored in device-local SharedPreferences under the signed-in profile's ID and survives application restarts. It is not synchronized to other devices.
- When disabled, Timeline's morning gate must never open the check-in automatically. Enabling it restores the existing one-per-day, wake-window and done/dismissed rules.
- This visibility preference does not disable sleep synchronization, delete sleep records, or alter the existing first-activity start flow.

## Tap Feedback

- Tappable controls must have an obvious pressed/selected/disabled state.
- Icon-only actions require tooltips where practical.
- A tap that opens a sheet, menu, route, picker, or mode must respond immediately.
- Debounce repeated destructive or sync-heavy actions at the handler boundary.

## Lossless record capture

- Web record create/update/stop/delete mutations persist to a transactional IndexedDB journal, not the small browser settings localStorage; migrate legacy queued writes atomically, then release old storage.
- Retry of one capture must reuse the same business UUID and original start time; a stale retry cannot submit a title once the input changed.
- A new recording must not stop a running recording until the new capture is durably accepted.
- Browser web tests must prove migration, persistence after reinitialization, draft recovery, and retry deduplication.


- A record's title, requested category and start-time intent must enter durable
  device storage before the entry field is cleared or a server request is made.
- A temporarily missing category catalog must **never** reject a new record
  before local outbox staging. Keep the explicit category identity for replay;
  do not silently remap it to an unrelated category.
- Network downtime, auth refresh and PocketBase validation delay delivery, not
  local acceptance. Pending records remain visible and survive reload.
- Keep the draft recoverable if even the local write-ahead handoff fails. Never
  display a false success if device storage cannot persist the input.
- Corrupt record outbox bytes must be surfaced and preserved; never interpret
  an unreadable queue as empty and overwrite its pending user data.

## Save Behavior

- Saves that affect records, plans, lists, Paths, categories, tags, or profile settings update the active local state before remote sync. Where a feature lacks a safe optimistic mutation path, implement the path rather than waiting for PocketBase; never bypass required validation, authorization, or local lossless-capture safeguards.
- Retriable network failures keep the optimistic state and enqueue where an outbox exists.
- For records, successful local staging means the input is accepted even when PocketBase is slow/offline; rapid consecutive creates are distinct and never rejected because an earlier request is in flight.
- A staged record remains visible across a full refresh or app restart until confirmed on the server; an uncertain POST retries against the same business ID without duplicating it.
- Failed record create validation retains the original queued payload and shows a sync error rather than falsely showing server success. If device storage cannot persist the input, do not report it as accepted.
- Other non-retriable validation/schema failures roll back and show one concise error.
- Silent success is preferred; no success log spam for background sync.

## Edit Behavior

- Edit sheets must show the current value immediately and keep unsaved user input stable while network work runs.
- Field controls must not reset on rebuild unless the source record changed.
- Expensive parsing or list refreshes must not block text entry, tap response, or sheet opening.

## Delete Behavior

- Destructive actions require either an explicit confirmation or a clearly reversible affordance.
- After confirmation, the deleted item disappears from the active UI immediately (≤100 ms), and deletion acknowledgment reflects local acceptance rather than delayed PocketBase success. If persistence or a non-retriable error prevents deletion, restore/reconcile the item and explain the failure once.
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

- Category pickers opened from edit sheets or category-selection controls must expose **visible create actions immediately** when the picker opens — not only at the end of a long scrollable list.
- Layout: sheet header → search (optional) → **always-visible top “+ Add root category” row** → scrollable tree → **sticky bottom “+ Add root category” row** (root level only in nested tree pickers).
- Every category row in the picker tree must show a trailing **“+”** (`add_subcategory`) that creates a **child under that exact row**; row tap still selects the category; the trailing **“+”** must be a separate tap target outside the row selection hit area.
- Each **expanded folder** must show a folder-scoped **“Add category inside <folder>”** row after its visible children.
- Create actions must pass an **explicit parent** to the Brain create path — never infer parent from selected category, expanded folder, search UI, or global name lookup.
- When search/filter text does not match an existing category, show a contextual **Create “<name>”** action near the empty-result area.
- Category creation requires network connection; do not invent client-only temporary categories or fake ids.
- After successful creation, refresh the in-memory category cache via the Brain path, close only the create dialog, auto-select the new category through the **same selection callback** as tapping an existing row (`CategoryTreeSheetPicked` → edit-sheet draft → autosave), then close the picker and return to the edit sheet. The parent edit sheet must stay open; category field and entity draft must update immediately without reopening the picker.

## Paths

- **One destination:** desktop side navigation and phone/tablet More → Paths open the same shell-owned Paths destination. Do not push a second shell or a separate desktop frame.
- **Opening is read-only:** entering Paths may load category/Path data, but must not create, migrate, retire, canonicalize, publish, generate Planner tasks, or apply AI proposals.
- **Project-independent structure:** generic Path UI and validation operate from stored Path data. Do not hard-code KADR, GOLOS, Igropoisk, Price Reporter, or any other project’s required topics into the feature.
- **Local-first explicit edits:** goal/stage/action completion edits reflect immediately. A rejected save restores the prior local state once and shows one concise error.
- **Duplicate roots are not silently deleted:** when transition storage contains more than one active root for a project, surface the condition and repair it only through an explicit idempotent repair/migration action.
- **Draft/review/active separation:** future AI or user restructuring happens on a draft/review revision. Planner consumes only the explicitly active/published Path revision.
- **AI proposal safety:** AI suggestions remain proposals until validated/applied through app-owned tools. Publish, delete, and bulk schedule changes must remain auditable and reversible.

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

- **Priority 1:** Records and Planning/Lists CRUD follow the Iron Laws: visible local shadow and immediate local acknowledgment first, durable outbox handoff second, PocketBase sync third. No success toast waits for a forced refetch or remote acknowledgment; a server-confirmed claim requires real server acknowledgment.
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

## Notes library folder tabs

- Notes categories appear as color-filled physical folder-edge tabs on both desktop and mobile, not translucent pill chips or mobile drawer-only navigation. Labels use at least 16px.
- The + action remains fixed beside the horizontal scrolling tabs and explicitly separates selecting existing categories from creating a new category with the canonical Brain-backed dialog; created categories are pinned immediately.
- Pinned category order is stable: selecting an existing tab must never move it to slot 0, persist reordered IDs, or forcibly scroll the tab rail. An externally selected unpinned category may be appended after pinned tabs without disturbing them. Manual pinned categories persist across navigation/restart. No duplicate category store.
- The active folder tab connects seamlessly to a single, borderless folder-paper surface with exactly the same color, changing with a 260ms smooth animation on category selection (including dark theme). The first note card is inset at least 18px below the tab/paper seam. Do not introduce nested frames around the Notes grid. Use the approved October 5 physical folder-tab shape as reference.

## Calendar navigation and view modes

- Calendar period navigation is gesture-first: horizontal swipe moves to the previous/next year, month, week, day-focus date, or Events month. Do not add persistent previous/next arrow buttons to the calendar header.
- The calendar header mode button opens one menu with exactly four primary views: **Year, Month, Week, Events**.
- Year view shows all 12 months; month header enters the selected month and clicking a day cell starts new-plan creation. Month day cells and empty Week time slots start new-plan creation with the chosen wall date/time; tapping an existing task opens editing, and tapping a grouped week block opens full interactive task cards. Events is an agenda-style upcoming list beginning at the selected day.
- Calendar browsing and cell taps never change the global header date or Timeline/Plans day selection. Calendar owns its own focused day. New plans use the standard shared editor and the existing local-first plan pipeline.
- Month cells show grey dates from adjacent months and their actual scheduled plans rather than missing cells. Tapping a plan edits that plan; tapping an empty cell creates a plan for that date. Neither affects the shared top-header date.
- Start time remains visible on compact Week cards and grouped blocks. Calendar Week uses the exact Time View `TimelinePlanInteractionBlock` pointer/hold gesture contract: immediate pointer drag on wide screens, hold to drag on touch, and frozen vertical scrolling/horizontal paging while dragging. Drop targets use Time View's 5-minute wall-time snap and shared `computeTimeViewInsertionCascade` (before/after target card or empty slot). Category group member gaps/durations remain intact; fixed-time barriers and persistence use the existing Brain planning path. Month day drops retain original wall clock.
- Week view collapses consecutive/overlapping plans under their shared category branch into a visual-only block. Different branches and gaps above 10 minutes do not merge. Independent plan records, exact times, and collision lanes remain intact; hover previews details, click opens canonical task cards.
- Calendar mode changes and swipes are local UI actions and must respond immediately; data refresh stays in the existing planning cache/stream path and must not block the gesture.

## Multi-select bulk plan scheduling

- Selecting several plans and setting a destination date + start time means
  that time is the **first plan's** start, not the start for every plan.
- Place plans consecutively, in visible source order, with each plan retaining
  its original duration (or its tag/default duration when no end exists).
- Date-only bulk moves retain the original separate clock times.
- Preserve the original audit anchor and postponed flag, persist each target
  date and end-date correctly, and optimistically move the batch as one unit.
- Never overlap destination plans. Cascade affected pre-existing destination
  plans forward; leave unrelated plans outside the insertion unchanged.
- Abort the batch before any optimistic change when a collision would require
  a patch to an unsaved or virtual recurring instance.

## Automatic plan workday rollover

- Automatically placed (no user-specified clock time) dated plans must fit their **full duration** into the selected working window, never be persisted past visible hours and silently disappear from Time View.
- If the requested day is full, search subsequent days using Brain cache and optimistic overlays. A category's inherited default start is the working-day start; the existing 8-hour category limit defines its auto-placement day unless a narrower Time View bound applies.
- Preserve existing task positions, task duration, category, tags and original `initial_date_key`. Persist the actual destination wall date with the new start/end, and set `is_postponed` when moved later.
- Explicit user clock-time input is not automatically moved to a different day. If no fitting auto-placement slot exists in the 14-day search horizon, display a specific error rather than creating a hidden plan.
- An automatic move shows the destination date/time. No PocketBase reads or heavy full-history scans on the tap hot path.

## Planning Time Mode

- **Selected-time stability:** typing or editing a task title, notes, checklist, category, or tags must not change a start time selected on the Time View grid. Start/end changes require an explicit time control or drag/resize gesture.
- **Create anti-overlap:** a newly created scheduled task that intersects another task moves forward to the first free slot, preserves duration, treats touching boundaries as valid, and shows one concise adjustment notice. Existing tasks are not moved by this create correction.
- **Editor hot-path:** text and rich-note typing must not rebuild the full Planning surface or emit global planning refreshes per keystroke; expensive draft merge/sync work is debounced.
- **Timezone / storage:** Plan and record instants are stored as **UTC ISO**. Time mode projects them into the **profile timezone** for day filter, block placement, labels, and drag/resize math. User-entered wall time at create/edit belongs to the **current profile timezone**.
- **Current-time line:** Uses profile-projected “now”; renders **above** plan cards (`IgnorePointer`); must not sit behind blocks.
- **Visible range:** No “outside visible range” / out-of-hours fallback bucket. Scheduled cards outside the selected wall day or visible hour range are **not shown**.
- **Snap / duration:** Time mode supports **10-minute** minimum duration and **5-minute** snap for move and top/bottom resize (`timelineSnapMinutes`, `kPlanScheduleSnapMinutes`, `kPlanTimeMinDurationMinutes`). Card top positions are exact wall-time projections on the same Y scale as the timeline grid: an hour-boundary start aligns exactly with that hour line, and no post-layout packing may shift the card top.
- **Dense hour cap:** One wall-clock hour visually stretches to at most **248 px** (six 10-minute cards at 38 px + 4 px gaps). Card heights use piecewise anchors (10→38, 30→75, 60→120 px), not unbounded proportional stretch.
- **Card density:** Short blocks use **micro** / **compact** layouts (essential controls only). **Medium** / **large** blocks show progress separator + category breadcrumb + planned time footer (`PlanTimeTaskCard`).
- **Interactions:** Checkbox, play, menu, body tap, drag, and resize keep independent hit zones; Time View body drag/tap overlays must not cover trailing Play/Menu controls; optimistic schedule updates follow the Iron Laws.

## Planning edit-sheet geometry

- Dated-plan edit sheets on desktop/web and mobile use one stable hierarchy: title → category → start/end times → tag strip → three tabs (**Notes**, **Repeat**, **Parallel plans**) → active tab content → fixed Delete/Cancel/Save footer. Do not place schedule controls below the Notes editor or divide the sheet into permanently competing Notes/schedule flex panes.
- **Notes is the initial first tab**, rendered using the canonical `NoteEditorPage(inlineBodyOnly: true)` with its existing block canvas, floating Notes toolbar, and single scroll owner. Do not replace it with a text box or create a second toolbar. Repeat owns reminder/recurrence controls, Parallel plans owns linked plans.
- Content area uses the remaining height; the footer stays visible without overlapping tabs or the editor. When the mobile keyboard is open, preserve the existing notes-focused compact mode. Keep the accepted category/time/tags ordering on both desktop and phone.

## Edit sheet Save (local-first)

- **Save is a local commit button**, not a network gate. Valid Save applies optimistic Brain/cache/UI **immediately**, shows **Changes saved** (or a specific validation error), and closes the sheet without waiting for PocketBase.
- **Explicit Save beats autosave:** `EditSheetAutosaveGate.flush(force: true)` always runs the latest draft sync and cancels pending debounce; autosave debounce must read the latest controller state at fire time, not a stale captured draft.
- **Network is background:** PocketBase PATCH runs after local apply; retriable failures keep optimistic UI and enqueue outbox; non-retriable failures roll back once with one error snack.
- **Validation feedback:** Empty title or missing required times show an immediate localized warning — never a silent no-op tap.

## Recurring plan edit/delete scope

- **One stored row per series:** Client expands `plans.rrule` into virtual `virt-{seriesPb}-{YYYY-MM-DD}` rows for the visible window; `exception_dates` omits instances; materialized one-offs link to the series via `parent_plan_id` + `recurrence_instance_date_key`.
- **Historical immutability:** A recurring edit/delete must never rewrite earlier occurrences. Past recurrence history remains attached to the old series definition.
- **Scope dialog (EN/RU):** Editing a recurring/virtual/materialized occurrence stays as an in-sheet draft while fields change; the two-choice scope dialog opens only after explicit **Save**, never from autosave while typing/changing fields. Deleting opens the same scope dialog only after the explicit delete action. Choices:
  - **This event** — single occurrence only (`exception_dates` + materialized one-off on edit; exception only on delete for virtual rows).
  - **This and all following events** — split at the selected occurrence. The historical series gets an `UNTIL` boundary immediately before that day; edits create a new future series from the selected occurrence, while delete stops the series at that boundary. Existing materialized future exceptions move with the future series.
- **No “all series” mutation:** There is no user action that retroactively changes/deletes earlier occurrences. Legacy `entireSeries` callers canonicalize to the future-safe split behavior.
- **Dedupe:** Materialized occurrence for `{seriesPb, instanceDate}` suppresses the matching virtual card. Virtual rows must never enter persistent caches or REST PATCH/DELETE paths.

## Gesture Ownership / Date Swipe Law

- **Horizontal swipe inside Timeline and Planning changes the calendar day** (previous/next date). This is **required** product behavior — do not remove it, disable it globally, or replace it with tap-only navigation.
- **This is not main-tab navigation.** Bottom/side nav switches app sections; horizontal swipe within Timeline/Planning is **date** navigation.
- **Code:** `TimelineSwipeWrapper` (`lib/features/timeline/timeline_view.dart`), `PlanningSwipeWrapper` (`lib/features/planning/planning_view.dart`) — infinite day `PageView.builder`.
- **During Planning Time-mode card drag/resize only:** horizontal date paging may be temporarily locked while the card owns the gesture; restore date swipe when the interaction ends.
- **Vertical scroll** stays vertical; tap opens edit; long press starts drag where supported. Gesture conflicts are P0 bugs.
- **Performance work** must not stack experiments on a regressing build. If swipe/startup/optimistic UI regresses, **stop** and apply the Performance Kill Switch Law (`ARCHITECTURE.md` § PERFORMANCE_KILL_SWITCH_LAW) — disable the risky path, restore stable paging, restore live optimistic sources, then re-measure. Profile-mode/DevTools proof is required **before** re-enabling any experimental preload layer; “the cache exists” / “snapshot is ready” / “body cache exists” is **not** sufficient if the user sees lag, loading, or crash.

## People / source hygiene contract

- Entry point: Settings → Account → People; People is not a primary app tab.
- Sections: People, Circles, Sources.
- Person supports photo, email, phone, relationship, optional-year birthday, reminders, multiple Circles and notes.
- Sources are a hidden review index, never the visible People list.
- Explicit source actions: Add, Link, Ignore, Block. Ignore/Block survives later source syncs.
- Device contacts sync only after user action and OS permission; no startup address-book scan.
- Plan reminder reconciliation must not cancel People birthday reminders.


## Browser extension companion

- The browser extension is a compact LIFE OS companion, not a second backend client.
- Popup order is fixed: **Current record** → **New record** → **Open LIFE OS**.
- **Current record** shows the canonical primary running record, its category path, category-color accent, and a locally ticking elapsed timer derived from the Brain-owned start time. If nothing is running, show an explicit empty state.
- **Stop** ends the current primary record through the existing Brain stop path.
- **New record** starts an actual running Timeline record through the existing Brain `startTimer` / Highlander path. Category inference, singleton-running enforcement, optimistic state, offline behavior, timezone rules, and PocketBase ownership remain canonical.
- **Open LIFE OS** is always a visible one-click action.
- The popup follows LIFE OS design tokens and canonical geometry: app/card surfaces from `AppColors`, 18px card radius, 12px control radius, monochrome primary actions, semantic error color for Stop, and data-driven category color only as the running-card accent.
- The extension never stores PocketBase credentials and never calls PocketBase directly. When needed it opens an inactive authenticated LIFE OS web bridge tab; the web shell executes the command after normal auth/profile bootstrap and publishes only a bounded running-record snapshot back to browser-local storage.
- Browser requests carry unique IDs and successful requests are deduped. A temporary bridge tab must stay alive until the canonical primary-record network chain has completed and the resulting running state is confirmed.
- Browser-local snapshots are **render-only cache**. Opening the popup must always trigger a fresh `bridge_sync` through the authenticated web app; an open LIFE OS tab's stored snapshot must never suppress that canonical refresh. While the popup remains open, it refreshes the canonical current-record state periodically and applies pushed snapshots without blocking the local elapsed timer.
- Bridge setup and request consumption run after the first frame and must not block normal LIFE OS startup.
