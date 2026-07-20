# Captures GLM Notes editor + library parity PNGs at 1156x821.
# Requires a Windows desktop target (toImage hangs in widget tests on this host).

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..\..
flutter run -d windows -t scripts/manual/capture_notes_glm_main.dart --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Screenshots:"
Write-Host "  test/fixtures/notes_glm_parity_capture.png"
Write-Host "  test/fixtures/notes_glm_library_parity_capture.png"
