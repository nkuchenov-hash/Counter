# P0 desktop voice self-acceptance — deterministic command → production submit → writeRecord seam.
# No microphone. No user interaction.

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host "=== Desktop Voice Self-Acceptance ==="
Write-Host "Repo: $repoRoot"

function Invoke-FlutterTest {
    param([string]$TestPath)
    Write-Host ""
    Write-Host ">> flutter test $TestPath"
    flutter test $TestPath
    if ($LASTEXITCODE -ne 0) {
        throw "FAILED: $TestPath (exit $LASTEXITCODE)"
    }
}

Invoke-FlutterTest "test/voice_command_parser_test.dart"
Invoke-FlutterTest "test/desktop_voice_command_acceptance_test.dart"
Invoke-FlutterTest "test/desktop_voice_production_submit_test.dart"
Invoke-FlutterTest "test/desktop_voice_hotkey_self_acceptance_test.dart"
Invoke-FlutterTest "test/desktop_voice_hotkey_state_machine_test.dart"
Invoke-FlutterTest "test/app_hotkey_keycaps_test.dart"

Write-Host ""
Write-Host "SELF_ACCEPTANCE_PASS"
Write-Host "  Case A: Price Reporter Planning - pass"
Write-Host "  Case B: Price Reporter AGE SOLUTIONS ADD MOD - pass"
Write-Host "  Low-confidence blocked - pass"
Write-Host "  Confirmation copy - pass"
Write-Host "  Simulated hotkey handler - pass"

exit 0
