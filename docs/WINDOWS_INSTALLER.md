# Windows installer — CounterSetup.exe

Install Counter on Windows like a normal desktop app. **No Visual Studio, no Flutter SDK, no command line, and no manual copying of Release folders.**

The normal download path is one installer file: **`CounterSetup.exe`**.

## Install Counter (simple path)

### Local build (developer machine)

1. `flutter pub get`
2. `flutter test test/voice_command_parser_test.dart`
3. `flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true`
4. *(Recommended)* `powershell -ExecutionPolicy Bypass -File installer\windows\build_stt_helper_en.ps1` — English Whisper helper (`language=en`, Price Reporter prompt)
5. `powershell -ExecutionPolicy Bypass -File installer\windows\prepare_stt_payload.ps1` — prefers `installer/windows/stt_helper_build/counter_stt_helper.exe` when present
6. Compile Inno Setup (see `installer/windows/counter.iss`)
7. Output: **`installer/windows/output/CounterSetup.exe`**

### CI path

1. Open GitHub Actions → **Windows desktop build (manual)**
2. Download **`CounterSetup`** artifact
3. Run **`CounterSetup.exe`**

## After installation

- **Start Menu:** Counter  
- **Install folder:** `%LOCALAPPDATA%\Programs\Counter`  
- **STT helper:** `%LOCALAPPDATA%\Programs\Counter\stt_helper\counter_stt_helper.exe` + `models\whisper-tiny\` (offline GOLOS-style local engine)  
- **Tray:** closing the main window hides Counter to the system tray (process stays alive for hotkey)  
- **Autostart (optional installer task):** `HKCU\...\Run` → `counter.exe --tray` (hidden to tray)  
- **Uninstall:** Windows Settings → Apps

## Desktop voice architecture

| Piece | Role |
|-------|------|
| Global hotkey (default **Ctrl+Shift+Space**) | Opens small voice widget without restoring main window |
| `record` package | Captures PCM16 mono 16 kHz microphone audio |
| `counter_stt_helper.exe` | Bundled GOLOS `golos-backend` HTTP sidecar on `127.0.0.1:8765` |
| `whisper-tiny` model | Local offline STT (no cloud) |
| `voice_command_parser.dart` | Deterministic Price Reporter command parse |
| `DatabaseService.writeRecord` | Optimistic Highlander record start (unchanged Brain path) |

**Not used for desktop voice:** Flutter `speech_to_text` / `VoiceInputSheet` (mobile/web FAB path unchanged).

## Hotkey & tray settings

**Settings** (Profile tab) — **desktop wide layout** (side nav ≥900px):

| Tab | Contents |
|-----|----------|
| Account | signed-in identity, password reset, biometric lock |
| Preferences | language + timezone |
| Desktop Voice | Windows card grid — enable, hotkey keycaps, behavior, widget options, mic monitor, tip, STT diag |
| Notifications | Android/iOS permission (hidden on web) |
| Appearance | theme + display name |
| About | build stamp |

**Mobile / narrow:** single-column section cards (no horizontal tab row); Desktop Voice shows one “Windows only” row on Android/iOS.

- Enable/disable desktop voice widget  
- View / change / reset hotkey (capture dialog — modifiers required, no `Control Right` labels)  
- Autostart at login  
- Launch hidden to tray  
- Test voice command  
- Last command diagnostic steps (no log spam)

**Hotkey editor:** title *Change hotkey*, instruction *Press the new shortcut*, live preview, validation message, Cancel / Save (Save disabled until valid combo). Registration failure keeps previous hotkey and shows error.

**Tray menu (localized):** Show Counter · Start voice command · Stop current record · Settings · Exit Counter. Only **Exit Counter** quits the process.

Settings are stored in **local SharedPreferences** (per Windows device), not PocketBase profile.

## Installed app verification checklist

1. Install `CounterSetup.exe`
2. Launch → sign in
3. Close main window → confirm Counter stays in tray / hidden icons
4. Tray → **Show Counter** restores window
5. Press hotkey (default Ctrl+Shift+Space) → voice widget opens (main window not required)
6. Say: **`Price Reporter AGE SOLUTIONS ADD MOD`**
7. Tap **Finish speaking**
8. Verify transcript, category path `Price Reporter > AGE SOLUTIONS`, title `ADD MOD`
9. Tap **Start record** on preview (or confirm auto-flow) → running Timeline record; no new category/client created
10. Wrong client phrase → no record, visible reason + retry
11. Profile → change hotkey → new combo works
12. Enable autostart + launch hidden → reboot → Counter in tray without main window

Allow microphone access when Windows prompts.

## STT payload sources (build machine only)

`prepare_stt_payload.ps1` copies from:

- `golos-backend.exe` → `C:\Users\nkuch\Development\Apps\_cleanup_backup_20260615_110428\Release\backend\`
- `whisper-tiny` → `C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\whisper-tiny\`

If either path is missing on the build machine, stop and install/copy GOLOS assets before packaging.

## SmartScreen / code signing

Unsigned builds may trigger SmartScreen. **More info → Run anyway** for trusted local/CI builds.

## Debug fallback

Raw `build/windows/x64/runner/Release/` folder is for engineers only. Normal users use **`CounterSetup.exe`**.

See also: [DESKTOP_WINDOWS_ARTIFACT.md](DESKTOP_WINDOWS_ARTIFACT.md).
