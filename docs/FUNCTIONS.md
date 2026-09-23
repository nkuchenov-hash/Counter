# LIFE OS Function Encyclopedia

Canonical product-behavior reference for AI developers and maintainers. Code and this document must stay synchronized. User-facing explanations live in `docs/USER_GUIDE.md`.

## planning.recurring_plans — Recurring plans

**Status:** implemented  
**Owner:** Planning / Brain  
**Persistent collection:** `plans`  
**Primary code:** `lib/data/plans/plan_recurrence_helpers.dart`, `lib/data/plans/plan_recurrence_split_helpers.dart`, `lib/data/recurrence_edit_scope.dart`, `lib/features/planning/recurrence_scope_dialog.dart`

### Storage and expansion

- One PocketBase `plans` row with `rrule` is a recurrence series.
- Ordinary occurrences are generated just-in-time for the visible window; they are not persisted as individual rows.
- Virtual IDs are `virt-{seriesPocketId}-{YYYY-MM-DD}` and must never be used as PocketBase REST IDs.
- `exception_dates` suppresses specific generated occurrences.
- A separately edited/completed occurrence is materialized as a real `plans` row linked by `parent_plan_id` + `recurrence_instance_date_key`.
- A materialized occurrence suppresses the matching virtual occurrence.

### Edit/delete scope

The product exposes exactly two scopes:

1. **This event** — one occurrence only. Edit materializes it; delete adds/keeps the occurrence exception.
2. **This and all following events** — the recurrence is split at the selected occurrence. Earlier occurrences keep the old series definition. A future edit creates a new series; a future delete ends the old series immediately before the selected occurrence.

There is no user-facing “all series” operation because it would retroactively rewrite history. The legacy `entireSeries` enum value canonicalizes to `thisAndFuture` for compatibility.

### Split invariants

- Historical series fields (title, category, notes, schedule, recurrence cadence) are never patched by a future edit; only its RRULE boundary/old exceptions are adjusted.
- The historical RRULE ends with `UNTIL` immediately before the split wall day.
- If the unchanged original RRULE used `COUNT`, the new future series receives only the remaining count.
- Existing materialized occurrences on/after the split boundary are re-parented to the new future series so their exception semantics remain valid.
- Existing materialized occurrences before the boundary remain linked to the historical series.
- Editing one occurrence never completes/deletes/renames the recurrence series.
- Completing one virtual occurrence materializes only that occurrence as done; the recurrence continues.

### Time

- Recurrence is evaluated in profile wall-clock semantics.
- Persistent timestamps remain UTC.
- Split boundaries use the selected occurrence’s profile-wall date, converted to UTC only for RFC5545 `UNTIL`.

### Documentation synchronization rule

Any change to recurrence behavior must update, in the same change set:

- `docs/FUNCTIONS.md`
- `docs/USER_GUIDE.md`
- `docs/UX_CONTRACT.md` when user-visible behavior changes
- `docs/ARCHITECTURE.md` when an invariant changes
- `docs/DATA_MAP.md` / `docs/POCKETBASE_MANIFEST.md` if persistence changes
- `docs/APP_STRUCTURE.md` / detailed structure if ownership or files change
- `CHANGELOG.md` when shipped

If code and documentation disagree, treat it as a defect and report the discrepancy rather than silently choosing one.
