# Windows desktop artifact (GitHub Actions)

Use this path to test the **Desktop Price Reporter voice command MVP** without installing Visual Studio or other local Windows C++ build tools on your machine.

## You do not need Visual Studio to run the app

The downloaded artifact is a **pre-built** Flutter Windows runner. Extract the folder and run `counter.exe` (or the project executable in that folder). No compiler, ATL, MFC, or Flutter SDK is required on the PC where you test.

**Visual Studio C++ / ATL / MFC** is only needed if you want to run `flutter build windows` **locally** on your own machine. Missing headers such as `atlstr.h` or `atlbase.h` are local toolchain gaps, not requirements for running the CI artifact.

## Download the artifact

1. Open the repository on GitHub: `https://github.com/nkuchenov-hash/Counter`
2. Go to **Actions** → workflow **Windows desktop build (manual)**
3. Open a completed green run (or start one — see below)
4. Under **Artifacts**, download `counter-windows-release-<run_number>` (ZIP)

### Start a build manually

1. **Actions** → **Windows desktop build (manual)** → **Run workflow**
2. Branch: `main` (or your feature branch if the MVP is there)
3. Wait for the job to finish; download the artifact from that run

The CI build passes `--dart-define=DESKTOP_VOICE_COMMAND=true`. Normal web/mobile builds and the default local app **do not** enable this flag.

## Run the Windows app

1. Extract the ZIP to a folder (e.g. `Counter-Windows-Release`)
2. Open that folder — it must keep all sibling files (`flutter_windows.dll`, `data/`, plugin DLLs, etc.)
3. Double-click **`counter.exe`** (name matches `pubspec.yaml` `name: counter`)
4. Sign in as usual (PocketBase session required for `writeRecord`)

Do not move only the `.exe` out of the folder; Flutter Windows apps need the full **Release** directory layout.

## Manual test — desktop voice command

Prerequisites: your account has a **Price Reporter** category with child clients (e.g. **AGE SOLUTIONS**) in the live category tree.

1. Launch the artifact build (CI build has desktop voice enabled)
2. Press **Ctrl+Shift+Space** (global hotkey when the app is running, or in-app shortcut fallback)
3. Say clearly: **`Price Reporter AGE SOLUTIONS ADD MOD`**
4. Expected:
   - Floating panel shows transcript, category path, and record title
   - On an exact match, a **running Timeline record** is created via the existing `DatabaseService.writeRecord` path (optimistic UI + Brain sync)
5. Wrong or ambiguous client → panel shows error/ambiguity; **no** record is created

Mic permission: allow Windows microphone access for the app when prompted.

## Related workflow file

[`.github/workflows/windows-desktop-build.yml`](../.github/workflows/windows-desktop-build.yml)
