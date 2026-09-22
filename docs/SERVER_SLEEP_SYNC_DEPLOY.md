# Server sleep synchronization deployment

This document is the governing production contract for completed sleep ingestion into the LIFE OS Timeline. It must stay aligned with `pb_hooks/sleep_sync.pb.js`, `pb_hooks/xiaomi_sleep_runtime.js`, `pb_hooks/xiaomi_sleep_bridge.py`, the sleep migrations, and the deployment verifier.

## Canonical data path

**Primary production path:**

`Mi Band / Xiaomi wearable → Mi Fitness → Xiaomi Health cloud → server Xiaomi bridge → PocketBase sleep runtime → records → all LIFE OS clients`

The LIFE OS phone/web/desktop client is **not required** for this path to run. Xiaomi Cloud is the primary server source.

**Recovery only:** an already-authorized Google Health connection may be used as stale-data recovery when recent Xiaomi sleep is absent. Google Fit / Google Health are not the active primary pipeline while Xiaomi is configured.

## Production ownership

- `pb_hooks/xiaomi_sleep_bridge.py` owns Xiaomi Cloud retrieval and normalization.
- `pb_hooks/xiaomi_sleep_runtime.js` owns Xiaomi connection state, import/upsert, maintenance cadence, and source metadata.
- `pb_hooks/sleep_sync.pb.js` owns authenticated sleep routes, the 15-minute missing-day scheduler, startup self-healing, duplicate cleanup, prior-record boundary repair, and Google Health stale-source recovery.
- `pb_hooks/01_sleep_sync_runtime_bootcheck.pb.js` fails PocketBase hook loading early if the active Xiaomi runtime cannot be required.
- `lib/data/health/cloud_sleep_sync_service.dart` is only the authenticated client for server status/connect/run operations; it is not the source of truth for scheduling.
- `lib/data/health/sleep_foreground_reconcile_service.dart` refreshes client state on startup/resume, but correctness must not depend on the client being open.

## Xiaomi API contract

The current Xiaomi Health API family is the `relatives` API used by the pinned `mi-fitness` runtime:

- `/app/v1/relatives/get_aggregated_data`
- `/app/v1/relatives/get_fitness_data`
- `/app/v1/relatives/get_latest_data`

The historical `/app/v1/data/...` endpoints are **compatibility fallback only**. They must never become the primary path again merely because they still return HTTP success: they can return stale history while Mi Fitness already contains newer sleep.

The bridge must reconcile aggregate + latest + raw sleep data on each current-API pass. If the primary regional backend is stale, it probes the known Xiaomi Health regions and keeps the freshest successful result.

## Missing-day synchronization law

`lifeos_xiaomi_sleep_sync` runs every **15 minutes**.

For each enabled Xiaomi connection:

1. Determine the current profile-local day.
2. If a Xiaomi sleep record already ends inside that local day, no missing-day force is needed.
3. If the current local day has no Xiaomi sleep, clear the runtime throttle marker and run Xiaomi sync immediately.
4. **Do not wait for a configured morning clock time.** If Xiaomi has already published the completed night, LIFE OS must import it on the next 15-minute pass regardless of hour.
5. PocketBase startup performs the same missing-day force so a deploy/restart self-heals instead of waiting for the next quarter-hour tick.

The runtime may still perform low-frequency maintenance/history repair, but the missing-current-day path above has priority until the sleep appears.

## Import and duplicate law

Imported completed sleep is stored as an ordinary completed `Sleep` / `Сон` record with Xiaomi source metadata.

Primary identity fields:

- `external_source = xiaomi`
- `external_kind = sleep`
- `sleep_source = xiaomi`
- `external_id` / `sleep_external_id` carry the provider-derived interval identity.

Exact source IDs are idempotent. In addition, Xiaomi may later revise bedtime/wake boundaries for the same night, producing a different interval-based source ID. Therefore source ID alone is **not sufficient** to prevent duplicate nights.

The server dedupe rule is:

- inspect recent Xiaomi sleep rows;
- if two intervals overlap by at least **60% of the shorter interval**, treat them as revised versions of the same sleep and keep the longer interval;
- do **not** collapse separate non-overlapping naps;
- run this cleanup after scheduled sync and on PocketBase startup.

## Timeline boundary law

Completed imported sleep is authoritative for the primary Timeline interval.

If the immediately preceding root non-sleep record has no end or extends through the imported sleep start, the server closes it exactly at `sleep.start_time` and marks it completed. Child/subrecords and other imported sleep records are not rewritten by this repair.

## History reconciliation

- Normal Xiaomi reads cover recent history on every pass.
- The runtime periodically performs a wider reconciliation window so delayed provider corrections can update earlier nights.
- Current Xiaomi API results are preferred; legacy endpoint results exist only as fallback.
- Duplicate cleanup covers the recent history window, not only the newest night.

## Connection and fallback rules

- One Xiaomi connection is the primary active sleep source for a user.
- Legacy Google providers are disabled while Xiaomi is configured.
- Google Health recovery may temporarily run only when recent sleep is absent and an existing refresh authorization is available.
- A fallback failure must not replace or delete valid Xiaomi records.

## Deployment contract

PocketBase deployment must include `pb_hooks/**` and `pb_migrations/**`, validate JavaScript syntax, restart the PocketBase service when the server bundle changes, and run the sanitized production verifier.

The Xiaomi runtime provisioning workflow pins the server-side `mi-fitness` dependency and verifies that the bridge can read the production account without exposing credentials.

The deployment verifier must report at least:

- Xiaomi connection enabled/status/error class;
- source session count;
- latest Xiaomi sleep day / recent-36h presence;
- Xiaomi record count;
- whether legacy sleep providers are active.

## Anti-regression requirements

Architecture Guard / deployment contract must fail if any of these invariants regress:

- current Xiaomi `relatives` aggregate endpoint is missing;
- current Xiaomi latest-data endpoint is missing;
- current Xiaomi raw fitness endpoint is missing;
- the active sleep cron is no longer `*/15 * * * *`;
- a morning-time gate is reintroduced before missing-day sync;
- Xiaomi revised-night overlap dedupe disappears;
- this document reverts to describing Google Fit as the primary production path.

A green compile alone is not sufficient proof of sleep correctness. Changes to the sleep bridge/runtime/hooks must be verified against source freshness and PocketBase record freshness in production.

## Diagnostics

For an authenticated client use `GET /api/sleep-sync/status`. Operationally verify both sides of the pipeline:

1. **Source freshness:** Xiaomi bridge latest session end/day.
2. **Database freshness:** latest Xiaomi `records.end_time` / local day.

If the bridge is fresh but PocketBase is stale, investigate scheduler/import logic. If both are stale while Mi Fitness visibly has newer sleep, investigate the Xiaomi API family/region before touching Timeline UI.

Never expose Xiaomi credentials, token files, user ids, server secrets, or raw authorization payloads in logs or user-facing diagnostics.
