# LIFE OS disaster recovery — Beget outage, 2026-11-03

Status: **staging only**. This procedure must not be treated as a completed
restoration. The original PocketBase endpoint is still the build default.

## Scope

Restore the existing Flutter **Web + Android** application without a UI rewrite.
Windows is explicitly out of scope. User data integrity, original PocketBase
record IDs, and safe upgrade of the installed Android package take priority over
quickly publishing an empty database.

## Verified repository facts

- App: `lib/data/pb_config.dart` selects the backend; release builds may now
  provide `--dart-define=POCKETBASE_URL=https://your-backend.example`.
- The existing production origin remains
  `https://217-114-0-201.sslip.io` **until the repository variable is set**.
- Build workflows use repository variable `LIFEOS_POCKETBASE_URL` for both
  Android APK and web. Do not set it before the replacement backend passes
  recovery acceptance.
- `pb_hooks/` contains application-specific server logic.
- `pb_migrations/` has **incremental**, not complete from-scratch, schema
  migrations. Its first migration assumes `profiles` and `records` exist.
  Later migrations likewise expect `categories`, `plans` and `tags`.
  There is **no committed base schema migration for these five collections**.
  Therefore a clean PocketBase install is **not** a verified replacement.
- The Android workflow currently retrieves
  `~/.lifeos/android-signing/life-os-release.jks` and `signing.env` from
  the original VPS. Without the identical signing key, a new APK cannot safely
  update the existing Android installation in place. The private signing key
  is not derivable from a published APK.
- `/etc/lifeos/viktor-vault.env` contains the separate, non-recreatable
  server-only encryption key for saved Viktor connections. Losing it means
  reauthorization/reset of those connections, not using a new key to pretend
  old ciphertext is decryptable.
- OAuth provider setup, SMTP and external integration secrets are not all
  stored in Git and require separate verification.
- Local clients cache categories, Records and warm Plans. Web has IndexedDB
  durable Records/Plans outboxes. Avoid clearing browser site data, app storage,
  logging out or uninstalling Android before attempting recovery.

## Stage 1 — preparation (this branch)

1. Keep the existing server origin as the default.
2. Allow a **build-time backend origin** for Web and release Android;
   exercise both the default and overridden origins in CI.
3. Hold changes in a draft PR. **Do not merge** this PR or set the backend
   variable until the new server and data reconciliation plan are ready.
4. Identify an independent provider / server account. Never share root
   passwords or private keys in issue comments or chat.

## Stage 2 — recover a valid server data source

1. Request Beget's last consistent `pb_data/data.db` and
   `pb_data/storage/` backups, plus any VPS file backups.
2. If copied from a running SQLite server, use a consistent SQLite/PocketBase
   backup, rather than copying only `data.db` while a WAL is active.
3. Obtain, if available, the original Android signing keystore and separate
   Viktor vault key. Store these in independent encrypted backup locations.
4. Inspect and preserve recoverable Android/Web client data, existing
   PocketBase auth record IDs and outbox state **before** exposing a replacement.
5. If the database is unavailable, reconstruct and test a complete
   `profiles`, `categories`, `records`, `plans`, `tags` base schema first,
   then replay all incremental migrations in a disposable test environment.
   Use the source manifest, DATA_MAP, client writes and hooks to verify
   every field, rule, relation and index. **Do not assume the documents are
   a drop-in authoritative database export.**

## Stage 3 — launch replacement PocketBase (not yet done)

1. Configure a new independent VPS, persistent encrypted backups and a
   stable HTTPS domain (not a provider IP / sslip.io alias).
2. Install the compatible PocketBase binary, the validated base schema,
   incremental migrations and `pb_hooks/`.
3. Restore the consistent owned data/IDs where possible. Validate auth,
   field types, relations, API rules, files and server-specific hooks.
4. Configure Google/Yandex OAuth redirect URLs, email service and any
   external integrations. Missing encrypted credentials require reauthorization.
5. Run production-like Web and Android regression/smoke tests in isolation:
   sign in, list/create category under Price Reporter, tag create/list,
   Records start/stop/history, Plans create/read/move, Notes, Paths,
   account ownership, reconnect, offline outboxes and duplicate prevention.
6. If the new environment starts empty, keep it **isolated** from old accounts
   and browser outboxes until an explicit identity/ID reconciliation and
   old-vs-new data merge strategy is tested.
7. Only after readiness: set repository variable
   `LIFEOS_POCKETBASE_URL=https://api.your-domain.example`, merge the
   reviewed change, and verify Web deployment and signed Android upgrade.
   CI Android release requires the **original release signing keystore**;
   migrate it off the lost VPS first, securely.
8. Establish continuous off-provider backups and conduct a restoration drill.

## Explicit go/no-go

- No production switchover on health-only evidence: check authenticated data
  reads/writes and client end-to-end behavior.
- Never write to old and new PocketBase instances independently without a
  tested reconciliation plan.
- Never initialize a replacement using an empty dataset and then overwrite
  old locally queued changes.
- Never create a new Android signing key as if it could upgrade an installed
  package signed by the old key.
- Do not claim complete old history, account access or integrations without
  recovered data and actual tests.

## Original service

- Outage tracking: https://github.com/nkuchenov-hash/Counter/issues/409
- Current source deployment pipeline:
  `.github/workflows/deploy-pocketbase.yml` then
  `.github/workflows/deploy.yml`. The existing PocketBase deploy still
  targets the old VPS via SSH secrets; this must be updated and verified
  separately before any production server push.
