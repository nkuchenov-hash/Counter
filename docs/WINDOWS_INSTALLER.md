# Windows installer — CounterSetup.exe

Install Counter on Windows like a normal desktop app. **No Visual Studio, no Flutter SDK, no command line, and no manual copying of Release folders.**

The normal download path is one installer file: **`CounterSetup.exe`**.

## Install Counter (simple path)

1. Open GitHub Actions for the repo: [Counter Actions](https://github.com/nkuchenov-hash/Counter/actions)
2. Open workflow **Windows desktop build (manual)**
3. Run the workflow on `main` (or wait for the latest successful run)
4. Download the **`CounterSetup`** artifact (GitHub may deliver it as a ZIP — extract it)
5. Run **`CounterSetup.exe`**
6. Follow the installer wizard
7. Counter is installed under your user profile, added to **Start Menu**, optional **Desktop** shortcut, and set to **start with Windows**
8. At the end of setup, launch Counter from the installed location (not from a temp build folder)

### After installation

- **Start Menu:** Counter  
- **Install folder:** `%LOCALAPPDATA%\Programs\Counter`  
- **Autostart:** `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` → `Counter`  
- **Uninstall:** Windows **Settings → Apps → Installed apps** (or **Apps & Features**)

### Test desktop voice command

This installer is built with `--dart-define=DESKTOP_VOICE_COMMAND=true`. Normal web/mobile builds do **not** enable that flag.

1. Sign in to Counter (PocketBase session required)
2. Press **Ctrl+Shift+Space**
3. Say: **`Price Reporter AGE SOLUTIONS ADD MOD`**
4. Expected: running Timeline record via the existing `writeRecord` path when client/title match exactly

Allow microphone access when Windows prompts.

## What you do **not** need

| Tool | Needed to install/run Counter? |
|------|--------------------------------|
| Visual Studio / C++ / ATL / MFC | **No** — only for local `flutter build windows` |
| Flutter SDK | **No** |
| Command line / BAT scripts | **No** |
| Copying DLLs or `data/` by hand | **No** — the installer bundles the full Release tree |

## SmartScreen / code signing

The installer is **unsigned** during early testing. Windows SmartScreen may show a warning (“Windows protected your PC”). Choose **More info → Run anyway** if you trust this build from your own GitHub Actions run.

Code signing can be added later without changing Counter app logic.

## Debug fallback artifact

CI also uploads **`counter-windows-release-debug-<run_number>`** — the raw Flutter `Release` folder for engineers only. **Do not** use this as the normal user path; use **`CounterSetup.exe`** instead.

See also: [DESKTOP_WINDOWS_ARTIFACT.md](DESKTOP_WINDOWS_ARTIFACT.md) (raw-folder debug notes).

## Build / packaging files

| File | Purpose |
|------|---------|
| [installer/windows/counter.iss](../installer/windows/counter.iss) | Inno Setup script |
| [.github/workflows/windows-desktop-build.yml](../.github/workflows/windows-desktop-build.yml) | Manual CI: Flutter build + ISCC + artifact upload |
