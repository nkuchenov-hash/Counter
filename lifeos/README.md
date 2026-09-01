# LIFE OS public website

Static public landing/download/release hub for LIFE OS.

## Public route

After merge to `main` and a successful normal LIFE OS web deploy:

- Marketing site: `https://nkuchenov-hash.github.io/Counter/lifeos/`
- Flutter web app: `https://nkuchenov-hash.github.io/Counter/`

The marketing site is copied into `build/web/lifeos/` by `.github/workflows/deploy.yml`. It does not replace or change the Flutter entrypoint.

## Dynamic content

- Release history is read client-side from public LIFE OS GitHub Releases.
- Native download buttons read public assets from GitHub Releases.
- The rolling public release tag is `life-os-latest`.
- Android workflow publishes `LIFE-OS-Android-arm64.apk`.
- Windows workflow publishes `CounterSetup.exe`.
- macOS automatically appears when a `.dmg`, `.pkg`, or macOS-named `.zip` is published to any public release.

## Safety

Do not put backend URLs, OAuth secrets, PocketBase admin data, real user screenshots, Price Reporter-specific voice UI, or Component Lab content on this site.
