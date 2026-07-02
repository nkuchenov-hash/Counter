@echo off
REM ============================================================================
REM  run_desktop_voice_test.bat
REM  No PowerShell, no terminal commands for the user. Double-click to launch
REM  a freshly built Counter with Desktop Voice enabled.
REM
REM  Pre-req: build once with
REM    flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true
REM  (this script will detect that and remind you if the exe is missing)
REM
REM  After launch:
REM    1. Press Ctrl+Shift+Space (default hotkey) once to start listening.
REM    2. Speak, e.g. "Price Reporter Planning" or "Laredo TSscene".
REM    3. Press Ctrl+Shift+Space again to finish and submit.
REM    4. Inside the app open More (•••) menu -> Voice command to see what
REM       happened, and press the Copy button if you need to share it.
REM ============================================================================

setlocal

set "REPO_ROOT=%~dp0"
pushd "%REPO_ROOT%" >nul

set "EXE=%REPO_ROOT%build\windows\x64\runner\Release\counter.exe"

REM Kill any stale helper / previous instance silently
taskkill /F /IM counter_stt_helper.exe >nul 2>&1
taskkill /F /IM counter.exe           >nul 2>&1

if not exist "%EXE%" (
  echo.
  echo counter.exe not found at:
  echo   %EXE%
  echo.
  echo Build it once with:
  echo   flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true
  echo.
  pause
  popd
  exit /b 1
)

echo Launching Counter with Desktop Voice enabled...
echo.
echo Hotkey: Ctrl+Shift+Space
echo   Press once = start listening
echo   Press again = finish + create task
echo.
echo After each attempt open the in-app More (circled dots) menu,
echo then choose "Voice command" to inspect or copy diagnostics.
echo.

start "" "%EXE%"

popd
endlocal
