# Server sleep synchronization deployment

This module makes completed sleep appear in the Life OS Timeline without opening the Life OS web, desktop, Android, or iOS client.

## Data path

`Mi Band → Mi Fitness → Health Connect → Google Health account → Google Health API → PocketBase cron → records → all Life OS clients`

The Life OS phone app is not part of this path. A Bluetooth-only wearable still needs a gateway that uploads its data. For Xiaomi wearables, Google requires the watch or tracker to sync regularly with Mi Fitness; Google Health does not communicate directly with Xiaomi devices.

## Production files

Copy these repository files beside the production PocketBase executable:

- `pb_hooks/sleep_sync.pb.js` → `<pocketbase-dir>/pb_hooks/sleep_sync.pb.js`
- `pb_migrations/1785390000_server_sleep_sync.js` → `<pocketbase-dir>/pb_migrations/1785390000_server_sleep_sync.js`

Restart PocketBase so the migration creates `sleep_sync_connections` and adds `records.sleep_source` plus `records.sleep_external_id`. PocketBase on Unix normally reloads hook changes, but the restart is required here to make migration execution explicit.

## Google Cloud setup

1. Create or select a Google Cloud project.
2. Enable **Google Health API**.
3. Configure an External OAuth consent screen.
4. Add the restricted scope:
   - `https://www.googleapis.com/auth/googlehealth.sleep.readonly`
5. Create a **Web application** OAuth client.
6. Add this exact redirect URI:
   - `https://217-114-0-201.sslip.io/api/sleep-sync/google-health/callback`
7. During private testing, add the Life OS Google account as a test user. Public use beyond the test-user limit requires Google OAuth verification.

Do not configure the retired Google Fit REST API.

## Required PocketBase process environment

Set these environment variables on the PocketBase service, not in Flutter or Git:

```text
SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_ID=<Google OAuth web client id>
SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_SECRET=<Google OAuth web client secret>
SLEEP_SYNC_TOKEN_KEY=<exactly 32 random characters>
SLEEP_SYNC_PUBLIC_BASE_URL=https://217-114-0-201.sslip.io
SLEEP_SYNC_RETURN_URL=https://nkuchenov-hash.github.io/Counter/
```

`SLEEP_SYNC_TOKEN_KEY` encrypts stored access and refresh tokens with AES-256-GCM. Back it up securely. Changing or losing it invalidates existing connected-source tokens.

Example systemd drop-in:

```ini
[Service]
Environment="SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_ID=..."
Environment="SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_SECRET=..."
Environment="SLEEP_SYNC_TOKEN_KEY=12345678901234567890123456789012"
Environment="SLEEP_SYNC_PUBLIC_BASE_URL=https://217-114-0-201.sslip.io"
Environment="SLEEP_SYNC_RETURN_URL=https://nkuchenov-hash.github.io/Counter/"
```

Then run:

```bash
sudo systemctl daemon-reload
sudo systemctl restart <pocketbase-service-name>
```

## Smoke test

1. Open Life OS web.
2. Go to Settings → Sleep synchronization → Server synchronization.
3. Select **Connect Google Health** and grant sleep read access.
4. Return to Life OS and run **Sync now**.
5. Confirm that the status reports found/imported sessions.
6. Confirm that an ordinary completed `Sleep` / `Сон` Timeline record appears in web.
7. Close all Life OS clients.
8. After the configured profile-local time, default 21:00, confirm that the PocketBase cron updates `last_sync_at` and imports any newly completed sleep.

## Operational behavior

- PocketBase checks due connections every 15 minutes.
- Each account runs at most once per profile-local calendar day after its configured time.
- Only completed sessions are imported.
- Every request rereads the latest 14 days to catch provider delays and corrections.
- `sleep_source + sleep_external_id` prevents duplicate Timeline records.
- A changed provider session updates the existing Timeline record.
- Imported sleep remains authoritative over overlapping Timeline activity, following the existing sleep policy.

## Diagnostics

Check:

- `GET /api/sleep-sync/status` while authenticated;
- PocketBase logs for `sleep sync failed`;
- `sleep_sync_connections.status` and `last_error` in PocketBase Admin;
- Google Cloud API and OAuth dashboards;
- whether Mi Fitness has recently synchronized the Xiaomi device and is connected to Google Health through Health Connect.
