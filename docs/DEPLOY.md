# Deploy (GitHub Pages)

One command from the **git repository root**:

`C:\Users\nkuch\Development\Apps\counter` — contains `.github/workflows/deploy.yml` and `pubspec.yaml`.

## Commands

| Shell | Command |
| :--- | :--- |
| **PowerShell (normal)** | `.\update.ps1` |
| PowerShell (direct) | `.\scripts\manual\td.ps1` |
| macOS / Linux / Git Bash | `./scripts/manual/td` |

`update.ps1` is a one-line wrapper that calls `scripts/manual/td.ps1`.

First time on Unix, if needed: `chmod +x scripts/manual/td`

## What it does

1. Ensures `lib/core/env/env.dart` exists (copies from `env.dart.example` if missing; file is gitignored).
2. `flutter analyze --no-fatal-infos --no-fatal-warnings` (errors still block; infos/warnings do not)
3. `flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run` (local sanity check; not committed)
4. If the working tree has changes: `git add -A` and commit `Deploy: <timestamp>`
5. `git push` to the current branch (usually `main`)

## What deploys the live site

Push to `main` triggers [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml):

- CI runs `flutter build web --release --base-href="/Counter/" --no-tree-shake-icons`
- [JamesIves/github-pages-deploy-action](https://github.com/JamesIves/github-pages-deploy-action) publishes `build/web` to the **`gh-pages`** branch

**Live URL:** https://nkuchenov-hash.github.io/Counter/

The deploy scripts do **not** push to `gh-pages` directly; Actions owns that step.

## Why `--no-tree-shake-icons`

Category icons use dynamic `IconData` from stored `icon_code_point` values. Until the [fixed icon registry](ROADMAP.md#v6-tooling-cleanup--technical-debt) task is done (see `docs/ROADMAP.md` V6), web builds must keep this flag.

## Prerequisites

- Flutter stable on `PATH`
- Git remote `origin` → `https://github.com/nkuchenov-hash/Counter.git`
- Permission to push to `main`

## Auth Flow And PocketBase Admin Setup

The app uses the PocketBase `profiles` auth collection as the only server login source. Startup follows one gate:

1. Initialize PocketBase and restore the SDK auth store.
2. If there is no valid PocketBase auth token/record, show `AuthView`.
3. If a token exists, load the current `profiles` auth row and then run the shared post-auth bootstrap (`loadInitialData`, realtime re-arm, pending-sync resume/flush).
4. If profile verification returns 401/403/404/422, clear unsafe local auth state, pause auth-blocked sync, and show login/session repair.
5. If PocketBase is temporarily unreachable but a prior valid session exists, the app may enter offline mode with cached state and the existing sync/offline banner.

PocketBase Admin requirements for production:

- `profiles` is an Auth collection with identity/password enabled.
- Google OAuth provider is enabled on `profiles`; Client ID and Client Secret are configured in PocketBase Admin.
- Yandex OAuth provider is enabled on `profiles`; Client ID and Client Secret are configured in PocketBase Admin.
- Do not put OAuth secrets in Flutter code.
- OAuth redirect URL is the PocketBase redirect endpoint:
  - Production: `https://YOUR_POCKETBASE_DOMAIN/api/oauth2-redirect`
  - Local PocketBase: `http://127.0.0.1:8090/api/oauth2-redirect`
- The deployed web origin must be allowed by the OAuth providers: `https://nkuchenov-hash.github.io/Counter/`.
- SMTP/mail settings are configured in PocketBase Admin.
- Password reset email template/action URL is configured. The Flutter app sends the reset email; PocketBase's default email flow may open a browser confirmation page unless a custom deep link/action URL is configured.
- Email verification template/action URL is configured if verification is enabled. The app requests verification best-effort after email/password registration.
- OTP/code login is not implemented in Flutter. Enable OTP only if the app intentionally adds an OTP UI and server flow.

OAuth implementation note: Flutter currently uses the PocketBase Dart SDK all-in-one `authWithOAuth2` flow for Google and Yandex on web/mobile. Android provider/admin setup must be verified on real devices; if Android lifecycle/backgrounding breaks the all-in-one flow, add a deliberate `authWithOAuth2Code` deep-link exchange instead of inventing a parallel auth path.

## Redeploy without code changes

If there is nothing to commit, `git push` is a no-op and Actions will not run. To force a redeploy:

```bash
git commit --allow-empty -m "Redeploy"
git push origin main
```

## Legacy scripts

- `Archive/root_cleanup_backup/f.ps1` — commit + push only (no analyze/build)
- `lib/deploy.ps1` — Firebase hosting (not used for GitHub Pages)
