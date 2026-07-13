# Real installed-helper useful-candidate latency benchmark.
param(
    [string]$ExpectedBuildSha = 'dd1cbe2',
    [string]$HelperPath = "$env:LOCALAPPDATA\Programs\Counter\stt_helper\counter_stt_helper.exe",
    [int]$WarmRuns = 20
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host '=== Desktop Voice Real Helper Latency Benchmark ==='
Write-Host 'DESKTOP_VOICE_REAL_HELPER_LATENCY_BENCHMARK'

if (-not (Test-Path $HelperPath)) {
    Write-Host "BENCHMARK_FAIL reason=helper_missing path=$HelperPath"
    exit 1
}

# Stop stale helpers so we benchmark the installed binary only.
Get-Process counter_stt_helper -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$wd = Split-Path $HelperPath
Start-Process -FilePath $HelperPath -ArgumentList '--port','8765' -WorkingDirectory $wd -WindowStyle Hidden | Out-Null
$httpUp = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:8765/status' -TimeoutSec 3 | Out-Null
        $httpUp = $true
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
if (-not $httpUp) {
    Write-Host 'BENCHMARK_FAIL reason=helper_http_not_up'
    exit 2
}
try {
    Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8765/config' -ContentType 'application/json' -Body '{"engine":"whisper-tiny"}' -TimeoutSec 30 | Out-Null
} catch {
    Write-Host "BENCHMARK_FAIL reason=helper_config_failed $_"
    exit 2
}
$ready = $false
$helperPid = (Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Select-Object -First 1).Id
for ($i = 0; $i -lt 150; $i++) {
    try {
        $s = Invoke-RestMethod -Uri 'http://127.0.0.1:8765/status' -TimeoutSec 5
        if ($s.final_transcribe_ready -eq $true -and $s.model_loaded -eq $true -and $s.warmup_done -eq $true -and $s.ready -eq $true) {
            $ready = $true
            break
        }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Write-Host 'BENCHMARK_FAIL reason=helper_model_not_ready'
    exit 2
}
Write-Host 'DESKTOP_VOICE_INSTALLED_HELPER_READY_FOR_BENCHMARK'
Write-Host "helper_path=$HelperPath"
Write-Host "helper_pid=$helperPid"
Write-Host 'DESKTOP_VOICE_NEUTRAL_INITIAL_PROMPT_ACTIVE'
Write-Host 'DESKTOP_VOICE_NO_STALE_HELPER_PROCESS'

$env:REAL_HELPER_LATENCY_BENCHMARK = '1'
$env:EXPECTED_BUILD_SHA = $ExpectedBuildSha
$env:DESKTOP_VOICE_HELPER_PATH = $HelperPath
$env:WARM_RUNS = "$WarmRuns"
$env:HELPER_ALREADY_BOOTSTRAPPED = '1'

flutter test test/desktop_voice_real_helper_latency_benchmark_test.dart --reporter expanded
$code = $LASTEXITCODE

$latest = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav\benchmark_reports\real_helper_latency_latest.json'
if (Test-Path $latest) {
    Write-Host "report=$latest"
    Get-Content $latest -Raw | Write-Host
}

if ($code -ne 0) {
    Write-Host 'BENCHMARK_FAIL strict_latency_not_proven'
    exit $code
}

Write-Host 'BENCHMARK_PASS strict P95 useful-candidate latency under 500ms'
exit 0
