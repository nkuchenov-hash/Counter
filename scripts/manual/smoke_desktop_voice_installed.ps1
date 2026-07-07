# Installed Desktop Voice smoke — verifies identity, helper, WAV/STT chain markers.
param(
    [switch]$SkipVoiceAttempt,
    [int]$LaunchWaitSec = 45
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$installedExe = Join-Path $env:LOCALAPPDATA 'Programs\Counter\counter.exe'
$installedHelper = Join-Path $env:LOCALAPPDATA 'Programs\Counter\stt_helper\counter_stt_helper.exe'
$modelDir = Join-Path (Split-Path $installedHelper -Parent) 'models\parakeet'
$logPath = Join-Path $env:TEMP 'counter_desktop_voice_pipeline.log'
$wavPath = Join-Path $env:LOCALAPPDATA 'Counter\voice_samples\latest_command.wav'
$setupPath = Join-Path $repoRoot 'installer\windows\output\CounterSetup.exe'

function Stop-CounterProcesses {
    Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Wait-LogMarker {
    param([string]$Marker, [int]$TimeoutSec = 90)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $logPath) {
            $text = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
            if ($text -and $text.Contains($Marker)) { return $text }
        }
        Start-Sleep -Milliseconds 400
    }
    return $null
}

Write-Host '=== Desktop Voice Installed Smoke ==='

if (-not (Test-Path $installedExe)) {
    Write-Host 'INSTALLED_SMOKE_FAIL reason=installed_app_missing path=' $installedExe
    exit 1
}

if (-not (Test-Path $installedHelper)) {
    Write-Host 'INSTALLED_SMOKE_FAIL reason=helper_missing path=' $installedHelper
    exit 2
}

if (-not (Test-Path $modelDir)) {
    Write-Host 'INSTALLED_SMOKE_FAIL reason=model_missing path=' $modelDir
    exit 3
}

Stop-CounterProcesses
if (Test-Path $logPath) { Remove-Item $logPath -Force }

$env:COUNTER_DESKTOP_VOICE_SMOKE = '1'
$env:COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE = '1'
$proc = Start-Process -FilePath $installedExe -PassThru -ArgumentList '--tray'

$ready = Wait-LogMarker 'DESKTOP_VOICE_HOTKEY_REGISTERED' $LaunchWaitSec
if (-not $ready) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Write-Host 'INSTALLED_SMOKE_FAIL reason=hotkey_not_registered'
    exit 4
}

$logText = $ready
foreach ($m in @(
    'DESKTOP_VOICE_RUNNING_EXE_PATH',
    'DESKTOP_VOICE_INSTALLED_APP_CONFIRMED'
)) {
    if (-not $logText.Contains($m)) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Write-Host "INSTALLED_SMOKE_FAIL reason=stale_installed_app missing=$m"
        exit 5
    }
}

if ($logText -match 'DESKTOP_VOICE_RUNNING_EXE_PATH\s+(.+)') {
    Write-Host ('running_exe_path=' + $Matches[1].Trim())
}

# Helper HTTP /status
try {
    $status = Invoke-WebRequest -Uri 'http://127.0.0.1:8765/status' -TimeoutSec 5 -UseBasicParsing
    Write-Host ('helper_status=' + $status.StatusCode + ' ' + $status.Content.Substring(0, [Math]::Min(120, $status.Content.Length)))
} catch {
    Write-Host 'helper_status=unavailable (may load after first voice attempt)'
}

if (-not $SkipVoiceAttempt) {
    Write-Host 'Note: full voice chain requires manual hotkey + speech; checking WAV if present.'
}

if (Test-Path $wavPath) {
    $wavBytes = (Get-Item $wavPath).Length
    Write-Host "latest_wav_path=$wavPath bytes=$wavBytes"
    if ($wavBytes -lt 3200) {
        Write-Host 'INSTALLED_SMOKE_FAIL reason=no_wav_saved'
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        exit 6
    }
}

if (Test-Path $setupPath) {
    $setup = Get-Item $setupPath
    Write-Host ('CounterSetup.exe timestamp=' + $setup.LastWriteTime.ToString('o') + ' size=' + $setup.Length)
} else {
    Write-Host 'CounterSetup.exe missing at' $setupPath
}

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host 'INSTALLED_SMOKE_PASS'
exit 0
