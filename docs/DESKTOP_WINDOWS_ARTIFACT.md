# Windows desktop artifact (GitHub Actions)

> **Preferred path:** use the normal installer — see **[WINDOWS_INSTALLER.md](WINDOWS_INSTALLER.md)** (`CounterSetup.exe`).

This page documents the **debug fallback** raw Flutter Release folder. End users should **not** need this path.

## You do not need Visual Studio to run Counter

Whether you use **`CounterSetup.exe`** (recommended) or the raw Release folder (debug only), you do **not** need Visual Studio, ATL, MFC, or Flutter on the PC where you run the app.

**Visual Studio C++ / ATL / MFC** is only required for **local** `flutter build windows` on a developer machine.

## Debug fallback — raw Release folder

1. Open [GitHub Actions](https://github.com/nkuchenov-hash/Counter/actions) → **Windows desktop build (manual)**
2. Download artifact **`counter-windows-release-debug-<run_number>`** (not `CounterSetup`)
3. Extract and run `counter.exe` **inside** that folder with all DLLs and `data/` present

Do not move only `counter.exe` out of the folder.

The CI build uses `--dart-define=DESKTOP_VOICE_COMMAND=true`. Default web/mobile builds do **not**.

## Manual test — desktop voice command

1. Launch Counter (from installer or debug folder)
2. **Ctrl+Shift+Space**
3. Say: **`Price Reporter AGE SOLUTIONS ADD MOD`**
4. Exact match → running Timeline record via `DatabaseService.writeRecord`
5. Ambiguous / no match → visible error, no record

## Related files

- [WINDOWS_INSTALLER.md](WINDOWS_INSTALLER.md) — primary user path
- [`.github/workflows/windows-desktop-build.yml`](../.github/workflows/windows-desktop-build.yml)
- [`installer/windows/counter.iss`](../installer/windows/counter.iss)
