# LIFE OS — Collaboration foundation (2026-10-28, candidate)

**Status:** Implementation branch only. Not released or installed on production PocketBase. Default UI gate `kSharedPlansEnabled` is **false**; staging build uses `--dart-define=LIFEOS_SHARED_PLANS=true`. This is the first vertical slice, **not** full two-way Planner synchronization.

## Existing People is the source of contacts

The canonical **Settings → People** domain already owns contacts, Circles, imported address books, birthdays and relationship statuses. Do not create a second contacts collection or UI. `people.id` is a personal contact and is **not** a verified LIFE OS identity. Server-side invitation uses the owner's explicit People contact, its primary email, and a **verified** `profiles` account. The invitee must accept. The owner must never obtain another profile's private People/Category/Record data.

## First slice implemented

1. Planning visible-day tag/quick-entry toolbar has a Share action. User explicitly selects up to 40 persisted plans from that day, excluding `virt-*` and `optimistic-*` placeholders.
2. `POST /api/shares` reads selected plans **on the server** under the authenticated owner; only title, start/end, order and original system plan id enter the shared projection. Notes, tags, category tree, private records and actual time **do not** leave the owner.
3. Shared Detail allows owner to invite an existing People contact with a verified LIFE OS email. The existing People header's **Shared plans** action lists incoming invitations, accepted shared objects and owned objects.
4. Accepted members can comment and propose task-title or time changes in profile timezone against a specific object revision. Only the owner can accept/reject; acceptance updates the shared projection atomically with the proposal decision. A stale proposal yields HTTP 409.
5. An owner or accepted member sees the canonical shared-day projection in the visible Planning day and focused Calendar day. The active Planning subview polls every 12 seconds; Calendar loads on focus. Preview tasks are visible to both owners and accepted members, with independent optimistic completion checkboxes. The shared preview only updates `shared_personal_state` via the authorized route; private native plan cards are not altered.
6. Owner can revoke a member and invite again; an accepted member can leave. Server denies subsequent reads and proposals.

## Not yet implemented; do not claim completed

- Agreed edits **do not yet modify** any participant's personal `plans` rows or reminders; accepted shared drafts are displayed separately in Planning and the Calendar focused-day panel, not native Time View blocks. This first slice is a **shared projection**. The UI explicitly says so.
- Full multi-task alternatives, per-task comments, multi-user realtime subscriptions, offline collaboration outbox, iOS/Android deep links and push notifications. Collaboration currently uses on-demand HTTP and active Planning polling; it does not promise instant realtime.
- Generic sharing for Notes, Lists, Paths (schema `kind` reserves types, but API currently accepts only `plan_day`).
- Final People-contact linkage as a permanent verified profile relation, shared-tag mapping and participant-specific timezone projection.
- Two-real-account Web/Android E2E + schema deployment verification and production release.

## Participant-local completion

- `pb_migrations/1793193000_shared_personal_state.js` adds a closed `shared_personal_state` collection, unique per object, participant, and source plan ID.
- `POST /api/shares/{id}/completion` validates accepted membership and source plan inclusion; owners can separately track their own shared-task completion. `GET /api/shares/{id}` and `POST /api/shares/day` return **only the requesting account's** `my_completed` map, never other members' progress.
- Flutter Shared Detail and Planning/Calendar shared-day previews expose immediate local checkbox feedback, then save asynchronously. A failed/unauthorized write restores the prior status and reports one error; stale polling responses do not overwrite pending optimistic feedback. **Offline durability is not claimed** and remains a planned separate outbox step.
- Shared Detail fences concurrent poll responses, keeps acknowledged checkboxes visible until server confirmation even if a follow-up read fails, and clears previously loaded shared content if access is revoked (401/403/404). This avoids displaying a withdrawn share indefinitely.
- Neither person’s private `plans.is_done` changes.

## Server schema

Migration `pb_migrations/1793188800_shared_collaboration.js` creates:

- `shared_objects`: `owner_id` → profiles, kind, title, wall_day, JSON content, monotonic revision, archived.
- `shared_members`: unique (object_id,user_id), invited_by, invited/accepted/declined/revoked, role.
- `shared_messages`: author_id, kind=comment/proposal, body, allowlisted patch, base_revision, status.

**All five direct REST rules are `null` on all four sharing collections, including `shared_personal_state`.** App-owned routes in `pb_hooks/shares.pb.js` are the only authorization path. The server checks the authenticated account on **every** route, owner for invites/decisions and accepted membership for discussions. No raw email/profile ID invite API.

API: `POST /api/shares/{id}/completion`, `POST /api/shares`, `GET /api/shares`, `POST /api/shares/day`, `GET /api/shares/{id}`, `POST /api/shares/{id}/invite`, `POST /api/shares/{id}/respond`, `POST /api/shares/{id}/messages`, `POST /api/shares/{id}/proposals/{messageId}/decide`, `POST /api/shares/{id}/members/{userId}/revoke`, `POST /api/shares/{id}/leave`.

## Acceptance / rollout gates

1. Run `node test/shares_hook_test.cjs` (also enforced in `.github/workflows/deploy-pocketbase.yml`) (authorization, over-sharing prevention, consent, replay, 409 conflicts).
2. Run `flutter analyze --no-fatal-infos --no-fatal-warnings` and Flutter widget smoke on both form factors; run project architecture guard and regenerate `docs/APP_STRUCTURE_DETAILED.md` from a checked-out repository.
3. On a **staging** PocketBase matching production version, apply migration and load hooks; verify direct REST returns denied even if authenticated, while signed-in app routes work.
4. Test two independent verified accounts, invitation accepted/declined, unregistered email, blocked People contact, no access for unrelated account, concurrent proposals and delayed/offline network.
5. Check startup responsiveness, date swipe, plan create/stop, Notes, recurrence, timezone, Personal Records, web and ARM64 APK. Apply Performance Kill Switch to disable sharing on regression.
6. Only after passing the above, deploy hooks + migration **before** exposing the UI. No silent fallback that exposes profiles or owner-owned plan data.

## Next implementation pass

Adopt a single canonical shared-plan projection visible to each participant in **Planning and Calendar**, with participant-local completion, categories, reminders and actual records. Reconcile accepted revision changes with the owning plan through a conflict-aware bridge and separate participant bindings, rather than copying the same plan row across owners or loosening `plans.user_id` rules.
