# Calendar integrations

Server-owned read-only synchronization for Microsoft 365 / Teams and Google Calendar.

## Product behavior

- Connected provider events are materialized into the existing PocketBase `plans` collection.
- Existing Planning, Planning Time View, and Calendar streams therefore show external meetings together with normal Life OS plans.
- Normal title/category matching runs before the integration fallback category.
- The fallback is configured per provider calendar in Profile → Account → Calendar integrations.
- No provider-to-category rule is hardcoded. A title such as `Price Reporter LAREDO TS Call` is matched against the current user category tree; `call`, `meeting`, provider names, and similar words are treated as noise.
- External rows are marked `external_read_only = true` and are refreshed from the provider. Disconnecting an integration removes only its imported external plans.

## PocketBase schema

Migration: `pb_migrations/1785960000_calendar_integrations.js`.

### `calendar_integrations`

Closed server-owned collection. One row per user/provider.

- `user_id` → `profiles.id`
- `provider`: `microsoft` or `google`
- account identity and status
- selected calendars plus fallback category settings in `calendars_json`
- bounded sync window
- encrypted access/refresh tokens
- OAuth state and expiration
- last sync/error fields

### Added `plans` fields

- `external_provider`
- `external_account_id`
- `external_calendar_id`
- `external_event_id`
- `external_occurrence_key`
- `external_web_url`
- `external_join_url`
- `external_read_only`
- `external_cancelled`
- `external_updated_at`
- `external_auto_category_id` → `categories.id`

A partial unique index prevents duplicate provider occurrences.

## Routes

All non-callback routes require authenticated `profiles` auth.

- `GET /api/calendar-integrations/status`
- `POST /api/calendar-integrations/microsoft/connect`
- `GET /api/calendar-integrations/microsoft/callback`
- `POST /api/calendar-integrations/microsoft/sync`
- `DELETE /api/calendar-integrations/microsoft`
- `POST /api/calendar-integrations/google/connect`
- `GET /api/calendar-integrations/google/callback`
- `POST /api/calendar-integrations/google/sync`
- `DELETE /api/calendar-integrations/google`
- `POST /api/calendar-integrations/settings`

PocketBase cron `lifeos_calendar_integrations` runs every 15 minutes for connected enabled integrations.

## Required server environment

Shared:

```text
CALENDAR_PUBLIC_BASE_URL=https://217-114-0-201.sslip.io
CALENDAR_RETURN_URL=https://nkuchenov-hash.github.io/Counter/
CALENDAR_TOKEN_KEY=<exactly 32 characters>
```

`CALENDAR_TOKEN_KEY` may be omitted only when the PocketBase encryption environment already resolves to a 32-character key, matching the existing sleep-sync convention.

Microsoft:

```text
CALENDAR_MICROSOFT_CLIENT_ID=...
CALENDAR_MICROSOFT_CLIENT_SECRET=...
CALENDAR_MICROSOFT_TENANT=common
```

Redirect URI:

```text
https://217-114-0-201.sslip.io/api/calendar-integrations/microsoft/callback
```

Required delegated permissions:

- `openid`
- `profile`
- `offline_access`
- `User.Read`
- `Calendars.Read`

Google:

```text
CALENDAR_GOOGLE_CLIENT_ID=...
CALENDAR_GOOGLE_CLIENT_SECRET=...
```

If these variables are absent, the hook may reuse the PocketBase `profiles` Google OAuth client only when it is configured with the calendar callback URI.

Redirect URI:

```text
https://217-114-0-201.sslip.io/api/calendar-integrations/google/callback
```

Scopes:

- `openid`
- `email`
- `profile`
- `https://www.googleapis.com/auth/calendar.readonly`

## Deploy

1. Back up PocketBase data.
2. Deploy `pb_migrations/1785960000_calendar_integrations.js`.
3. Deploy `pb_hooks/calendar_integrations.pb.js`.
4. Configure environment variables.
5. Restart PocketBase so migration, routes, and cron are loaded.
6. Open Life OS → Settings → Account → Calendar integrations.
7. Connect a provider, choose calendars, optionally select a per-calendar fallback, and run Sync now.

## Acceptance check

- Teams/Google meeting appears among ordinary plans and in Calendar.
- Existing category matching wins over fallback.
- Repeated sync does not create duplicates.
- Provider update changes the imported plan.
- Provider deletion/cancellation removes it on the next full-window sync.
- Disabling a calendar removes only plans imported from that provider calendar.
- Disconnecting does not remove normal Life OS plans or Timeline records.
