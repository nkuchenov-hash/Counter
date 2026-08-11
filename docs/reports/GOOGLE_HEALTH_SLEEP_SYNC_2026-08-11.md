# Google Health sleep sync — 2026-08-11

## Architecture

Life OS uses a server-owned Google Health API integration for sleep synchronization.

Flow:

`Mi Fitness -> Google Fit -> Google Health API -> PocketBase -> Life OS records -> Android/Web/Desktop`

The mobile app does not own or persist Google health access tokens. PocketBase owns OAuth, encrypted refresh tokens, historical catch-up, periodic refresh, and idempotent record upserts.

## OAuth

Use a dedicated Google Cloud project for Life OS and a **Web application** OAuth client.

Authorized redirect URI:

`https://217-114-0-201.sslip.io/api/sleep-sync/google-fit/callback`

Required Google Health scope:

`https://www.googleapis.com/auth/googlehealth.sleep.readonly`

Production server secrets:

- `GOOGLE_HEALTH_CLIENT_ID`
- `GOOGLE_HEALTH_CLIENT_SECRET`
- optional `SLEEP_SYNC_TOKEN_KEY` (exactly 32 characters). When omitted, the hook uses PocketBase's configured encryption environment key.

## Import contract

- First successful authorization performs a full paginated historical sleep import from the Google Health reconciled `all-sources` stream.
- Subsequent runs reread a 7-day correction window so provider corrections update the same Life OS record.
- Imported rows are owned by `external_source = google_health` and stable external IDs.
- Sleep import never trims or deletes unrelated manual Timeline records.
- A compatibility lookup prevents exact-time duplicates from the abandoned direct Google Fit client path.
- Server cron retries an incomplete initial historical backfill and otherwise runs the configured daily server sync.

## Deployment

`.github/workflows/deploy-pocketbase.yml` validates the hook/migrations, copies Google Health OAuth secrets into a mode-600 server EnvironmentFile, installs a systemd drop-in for PocketBase, restarts PocketBase, and verifies `/api/health` plus the authenticated sleep-sync route.

Deployment requires a configured PocketBase SSH private key in GitHub Actions (`POCKETBASE_SSH_PRIVATE_KEY` or supported fallback secret).

## Verification performed

GitHub Actions run `31480446902` passed:

- `node --check pb_hooks/sleep_sync.pb.js`
- `node --check pb_migrations/1786550000_google_health_history.js`
- targeted Flutter analyzer for the health settings/client surface
- ARM64 release APK build using `--split-per-abi --no-tree-shake-icons`
