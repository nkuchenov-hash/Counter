# Deploy (GitHub Pages)

Run release commands from the **git repository root** (the directory containing `pubspec.yaml` and `.github/workflows/`).

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

A push to `main` starts [`.github/workflows/deploy-pocketbase.yml`](../.github/workflows/deploy-pocketbase.yml) first. That workflow validates the architecture/schema/deployment contracts and either deploys changed PocketBase hooks/migrations or completes as a validated no-op. Only after that workflow succeeds does [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) run via `workflow_run` for the **same validated `head_sha`**.

The Web workflow then:

- checks out `github.event.workflow_run.head_sha` rather than an arbitrary newer `main`;
- runs `flutter build web --release --base-href="/Counter/" --no-tree-shake-icons`;
- uses [JamesIves/github-pages-deploy-action](https://github.com/JamesIves/github-pages-deploy-action) to publish `build/web` to the **`gh-pages`** branch.

This ordering is deliberate: a schema-dependent Web client must never become live before the matching PocketBase migration/hook release is validated and applied. UI-only pushes are not forced through SSH deployment; the PocketBase workflow detects no server-bundle change and acts as a validation-only gate.

**Live URL:** https://nkuchenov-hash.github.io/Counter/

The deploy scripts do **not** push to `gh-pages` directly; Actions owns that step.

## Architecture Guard (structure CI)

Executable policy sources live under `scripts/audit/`; workflow YAML invokes them rather than duplicating their rules.

| Trigger | Workflow | What runs |
| :--- | :--- | :--- |
| Pull request targeting `main`, push to `main`, or manual guard run | [`.github/workflows/architecture-guard.yml`](../.github/workflows/architecture-guard.yml) (`Architecture Guard` / `strict-structure`) | Strict architecture guard, structure-growth ratchet, documentation parity, repository hygiene, PocketBase schema/deployment contracts, PocketBase JS syntax, whitespace check |
| Push to `main` | [`.github/workflows/deploy-pocketbase.yml`](../.github/workflows/deploy-pocketbase.yml) | Revalidates release-critical contracts, deploys server bundle only when changed, then completes the Web release gate |
| Successful PocketBase workflow from a `main` push | [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) | Checks out the exact validated `head_sha`, builds Web, publishes `gh-pages` |
| Manual Windows installer | [`.github/workflows/windows-desktop-build.yml`](../.github/workflows/windows-desktop-build.yml) | Windows build/release checks before packaging |

Making `Architecture Guard / strict-structure` a **required** branch-protection check is a repository settings step (not configured by the workflow file alone). The release chain still reruns critical validation before production publication, so deployment correctness does not rely solely on branch protection.

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
6. If any in-app record/plan mutation receives 401/403, the mutation stays queued with `paused_auth`, pending sync is paused, and `RootAuthWrapper` routes to `AuthView`. A successful login returns through the same post-auth bootstrap and resumes pending sync.

PocketBase Admin requirements for production:

- `profiles` is an Auth collection with identity/password enabled.
- Google OAuth provider is enabled on `profiles`; Client ID and Client Secret are configured in PocketBase Admin.
- Yandex OAuth provider is enabled on `profiles`; Client ID and Client Secret are configured in PocketBase Admin.
- The Flutter auth screen discovers configured OAuth providers from PocketBase via `profiles.listAuthMethods()` and only renders Google/Yandex buttons when those provider names are returned by the server.
- Do not put OAuth secrets in Flutter code.
- OAuth redirect URL is the PocketBase redirect endpoint:
  - Production: `https://217-114-0-201.sslip.io/api/oauth2-redirect`
  - Local PocketBase: `http://127.0.0.1:8090/api/oauth2-redirect`
- The deployed web origin must be allowed wherever the OAuth provider requires app origins: `https://nkuchenov-hash.github.io/Counter/`.
- Android no longer declares Supabase-era callback schemes (`io.supabase.flutter://login-callback` or `mycounter://auth`). The current PocketBase Dart SDK all-in-one OAuth flow uses the PocketBase `/api/oauth2-redirect` endpoint; no app-owned Android deep link is active yet.
- Real-device Android Google/Yandex OAuth still must be verified after provider admin setup is complete. If the all-in-one flow cannot survive Android browser/app lifecycle behavior, add a deliberate `authWithOAuth2Code` exchange with a new app-owned redirect scheme instead of reusing Supabase callbacks.
- Deploy `pb_hooks/auth.request_password_reset.pb.js` to the production PocketBase `pb_hooks/` directory and reload/restart PocketBase. Flutter calls `POST /api/auth/request-password-reset` so the server can check `profiles.email` without exposing broad public profile search rules.
- The reset route returns only structured booleans (`exists`, `sent`) and never profile data. If the route is missing, Flutter falls back to PocketBase's native `profiles.requestPasswordReset(email)` endpoint, but that fallback cannot reliably distinguish unknown emails from successful sends.
- Settings → Mail settings:
  - SMTP enabled.
  - Correct SMTP host.
  - Correct port.
  - Correct encryption mode.
  - Correct username/password or app password.
  - Correct sender address.
  - PocketBase Admin “Send test email” succeeds.
- Collections → `profiles` → Options:
  - Identity/password enabled.
  - Password reset email template configured.
  - Password reset Action URL configured correctly for the production reset flow.
  - Application URL configured if the PocketBase version/templates use it for email action links.
  - Email verification template/action URL configured if verification is enabled.
- Password reset failure debugging:
  - Watch PocketBase logs while clicking Forgot password.
  - If SMTP/send fails, `pb_hooks/auth.request_password_reset.pb.js` logs the server-side reason as `auth.request_password_reset mail send failed`.
  - Do not expose raw SMTP/server internals to Flutter users; the app shows the generic mail-service unavailable message.
- OTP/code login is not implemented in Flutter. Enable OTP only if the app intentionally adds an OTP UI and server flow.

OAuth implementation note: Flutter currently uses the PocketBase Dart SDK all-in-one `authWithOAuth2` flow for Google and Yandex on web/mobile. Android provider/admin setup must be verified on real devices; if Android lifecycle/backgrounding breaks the all-in-one flow, add a deliberate `authWithOAuth2Code` deep-link exchange instead of inventing a parallel auth path.

## Redeploy without code changes

If there is nothing to commit, `git push` is a no-op and Actions will not run. To force a full gated redeploy, create an empty commit on `main`; the PocketBase workflow validates/no-ops as appropriate, then the Web workflow publishes that exact SHA:

```bash
git commit --allow-empty -m "Redeploy"
git push origin main
```

Do not add a direct/manual Web deployment bypass around the server-before-client gate.

## Windows desktop release

**Normal user path:** one installer — **`CounterSetup.exe`**. No Visual Studio, Flutter SDK, or manual Release-folder copying on the target PC.

### Build installer (developer machine)

1. `flutter pub get`
2. `flutter test test/voice_command_parser_test.dart`
3. `flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true`
4. *(Only when rebuilding the helper)* `powershell -ExecutionPolicy Bypass -File installer\windows\build_stt_helper_en.ps1 -BackendSourceRoot <path-to-http-sidecar-source>` (or set `COUNTER_STT_BACKEND_ROOT`)
5. `powershell -ExecutionPolicy Bypass -File installer\windows\prepare_stt_payload.ps1 -ModelsSourceRoot <path-to-models>` (or set `COUNTER_STT_MODELS_ROOT`)
6. Compile Inno Setup (`installer/windows/counter.iss`)
7. Output: **`installer/windows/output/CounterSetup.exe`**

**Visual Studio C++ / ATL / MFC** is only required for local `flutter build windows`, not for running the installed app.

### CI path

1. GitHub Actions → **Windows desktop build (manual)** ([`.github/workflows/windows-desktop-build.yml`](../.github/workflows/windows-desktop-build.yml))
2. Download **`CounterSetup`** artifact
3. The clean-runner workflow does **not** provision the external offline STT model directories yet; treat the artifact as voice-complete only when the release payload has been prepared with the model source contract above.
4. Run **`CounterSetup.exe`**

### After installation

- **Start Menu:** Counter
- **Install folder:** `%LOCALAPPDATA%\Programs\Counter`
- **STT helper:** `%LOCALAPPDATA%\Programs\Counter\stt_helper\counter_stt_helper.exe` + bundled `whisper-tiny` model (local offline engine)
- **Tray:** closing the main window hides Counter to the system tray (hotkey stays alive)
- **Uninstall:** Windows Settings → Apps

### Desktop voice (Windows)

| Piece | Role |
| :--- | :--- |
| Global hotkey (default **Ctrl+Shift+Space**) | Opens voice widget without restoring main window |
| `counter_stt_helper.exe` | Local GOLOS HTTP sidecar on `127.0.0.1:8765` |
| `voice_command_parser.dart` | Deterministic Price Reporter command parse |
| `DatabaseService.writeRecord` | Optimistic Highlander record start (unchanged Brain path) |

Settings → **Desktop Voice** tab (wide layout ≥900px). Stored in local SharedPreferences per device, not PocketBase profile.

**Smoke test:** hotkey → say **`Price Reporter AGE SOLUTIONS ADD MOD`** → running Timeline record with correct category path.

Unsigned builds may trigger SmartScreen — **More info → Run anyway** for trusted local/CI builds.

### Debug fallback (engineers only)

Download artifact **`counter-windows-release-debug-<run_number>`** (not `CounterSetup`), extract, run `counter.exe` **inside** the folder with all DLLs and `data/`. Do not move only `counter.exe` out of the folder.

## PocketBase schema migrations

`pb_migrations/` is version-controlled server schema/data history. `.github/workflows/deploy-pocketbase.yml` syntax-checks **every** tracked `pb_hooks/**/*.js` and `pb_migrations/**/*.js` on pull requests. On push to `main` it validates the server bundle and, when the bundle changed, uploads the complete hooks+migrations package and restarts PocketBase; PocketBase applies unapplied migrations during startup before the new client release uses the schema.

For durable Paths, `1787076000_durable_paths.js` creates/imports the server schema. The PR validates it; merging the migration to `main` triggers the existing production PocketBase deployment before normal client use of `PbCollections.paths` / `PbCollections.pathRevisions`.

### Production release ordering law

Every `main` push starts `.github/workflows/deploy-pocketbase.yml`. It validates the complete tracked PocketBase JS bundle; if `pb_hooks/`, `pb_migrations/`, or the server workflow changed, it deploys/restarts PocketBase and lets unapplied migrations finish. `.github/workflows/deploy.yml` has **no direct/manual production entry**: it is triggered only by the successful server `workflow_run`, requires that run to be a `main` push, and checks out that exact `head_sha` before publishing LIFE OS Web. Therefore a schema-dependent Web client cannot be published ahead of its server migration.

A `main` push with no PocketBase bundle change still completes the server validation workflow but skips SSH/restart; Web remains downstream of the successful gate. To repeat a release, create an empty `main` commit and let the same gated chain run again rather than bypassing the server gate.

**Main integrity gate:** Architecture Guard runs on PRs and on every `main` push. Independently, the PocketBase release workflow reruns strict architecture, documentation parity, repository hygiene, PocketBase schema, and deployment-order contracts before its server stage. Web publication is downstream of that successful workflow, so a structurally invalid direct push cannot be released even when repository branch-protection settings are unavailable.
