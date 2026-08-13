# Google Fit server sleep sync correction — 2026-08-13

Production Google Health API testing returned `ACCOUNT_NOT_LINKED` with a Fitbit signup redirect. That API is not the source for the user's Mi Fitness data already visible in Google Fit.

LIFE OS sleep sync therefore uses the Google Fit REST Sessions endpoint server-side while retaining the PocketBase-owned OAuth/refresh-token architecture.

- OAuth scope: `https://www.googleapis.com/auth/fitness.sleep.read`
- Sessions endpoint: `GET /fitness/v1/users/me/sessions`
- Sleep activity type: `72`
- First successful authorization: full available history from 2000-01-01
- Later synchronization: 7-day correction lookback
- Storage: ordinary `records` with `external_source = google_fit` and stable session identity
- Automatic sync: PocketBase cron; no Android process required
- Manual/non-provider records are never deleted or trimmed

The previous Google Health runtime was removed. Existing OAuth web-client credentials remain server-side; the runtime accepts the existing transitional environment names while preferring Google Fit-specific names when present.
