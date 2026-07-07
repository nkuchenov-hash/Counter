# Desktop Voice STT quality benchmark — golden phrase postprocess + parser gate.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host '=== Desktop Voice STT Benchmark (golden text) ==='
flutter test test/desktop_voice_stt_quality_test.dart --reporter expanded
if ($LASTEXITCODE -ne 0) {
    Write-Host 'DESKTOP_VOICE_STT_BENCHMARK_FAIL'
    exit 1
}
Write-Host 'DESKTOP_VOICE_STT_BENCHMARK_PASS'
exit 0
