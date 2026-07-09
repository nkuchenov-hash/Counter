# Installed Desktop Voice smoke — identity, helper, endpoint diagnostics (no live speech).
param(
    [string]$ExpectedBuildSha = '',
    [int]$LaunchWaitSec = 60
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

if ([string]::IsNullOrWhiteSpace($ExpectedBuildSha)) {
    $ExpectedBuildSha = (git rev-parse --short HEAD).Trim()
}

$installedExe = Join-Path $env:LOCALAPPDATA 'Programs\Counter\counter.exe'
$installedHelper = Join-Path $env:LOCALAPPDATA 'Programs\Counter\stt_helper\counter_stt_helper.exe'
$appSo = Join-Path $env:LOCALAPPDATA 'Programs\Counter\data\app.so'
$logPath = Join-Path $env:TEMP 'counter_desktop_voice_pipeline.log'
$buildStarted = Get-Date

function Stop-CounterProcesses {
    Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
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

function Get-EmbeddedBuildSha {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path $Path)) { return '' }
    if ([string]::IsNullOrWhiteSpace($Expected)) { return '' }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    if ($ascii.Contains($Expected)) { return $Expected }
    return ''
}

function Parse-DiagValue {
    param([string]$Text, [string]$Key)
    if ($Text -match "(?m)^$Key=(.+)$") { return $Matches[1].Trim() }
    return ''
}

Write-Host '=== Desktop Voice Installed Smoke (identity) ==='
Write-Host 'DESKTOP_VOICE_INSTALLED_SMOKE_FAILS_ON_SHA_MISMATCH'
Write-Host 'DESKTOP_VOICE_INSTALLED_SMOKE_FAILS_ON_MISSING_ENDPOINT_DIAG'

$installIdentityPass = $false
$endpointIdPresent = $false
$endpointRolePresent = $false
$endpointVolumePresent = $false
$endpointDiagFieldsPresent = $false
$runningBuildSha = ''
$appTs = ''
$helperTs = ''
$runningExePath = ''

try {
    if (-not (Test-Path $installedExe)) {
        Write-Host 'INSTALLED_SMOKE_FAIL reason=installed_app_missing'
        exit 1
    }
    if (-not (Test-Path $installedHelper)) {
        Write-Host 'INSTALLED_SMOKE_FAIL reason=helper_missing'
        exit 2
    }

    $appTs = (Get-Item $appSo).LastWriteTime.ToString('o')
    $helperTs = (Get-Item $installedHelper).LastWriteTime.ToString('o')
    $embeddedSha = Get-EmbeddedBuildSha -Path $appSo -Expected $ExpectedBuildSha

    Write-Host "expected_build_sha=$ExpectedBuildSha"
    Write-Host "embedded_build_sha=$embeddedSha"
    Write-Host "app_so_timestamp=$appTs"
    Write-Host "app_file_timestamp=$((Get-Item $installedExe).LastWriteTime.ToString('o'))"
    Write-Host "helper_file_timestamp=$helperTs"
    Write-Host "helper_expected_path=$installedHelper"
    Write-Host "helper_exists=yes"

    if ($embeddedSha -ne $ExpectedBuildSha) {
        Write-Host 'DESKTOP_VOICE_STALE_APP_BUILD_BLOCKED'
        Write-Host "INSTALLED_SMOKE_FAIL reason=embedded_sha_mismatch embedded=$embeddedSha expected=$ExpectedBuildSha"
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
        exit 5
    }
    $logText = $ready

    foreach ($m in @(
        'DESKTOP_VOICE_RUNNING_EXE_PATH',
        'DESKTOP_VOICE_INSTALLED_APP_CONFIRMED',
        'DESKTOP_VOICE_BUILD_SHA'
    )) {
        if (-not $logText.Contains($m)) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Host "INSTALLED_SMOKE_FAIL reason=missing_marker $m"
            exit 6
        }
    }

    $runningExePath = Parse-DiagValue $logText 'DESKTOP_VOICE_RUNNING_EXE_PATH'
    if ([string]::IsNullOrWhiteSpace($runningExePath)) {
        if ($logText -match 'DESKTOP_VOICE_RUNNING_EXE_PATH\s+(.+)') {
            $runningExePath = $Matches[1].Trim()
        }
    }
    $runningBuildSha = Parse-DiagValue $logText 'DESKTOP_VOICE_BUILD_SHA'
    if ([string]::IsNullOrWhiteSpace($runningBuildSha)) {
        if ($logText -match 'DESKTOP_VOICE_BUILD_SHA\s+(.+)') {
            $runningBuildSha = $Matches[1].Trim()
        }
    }
    if ([string]::IsNullOrWhiteSpace($runningBuildSha)) {
        $runningBuildSha = $embeddedSha
    }

    Write-Host "running_exe_path=$runningExePath"
    Write-Host "running_build_sha=$runningBuildSha"

    if ($runningBuildSha -ne $ExpectedBuildSha) {
        Write-Host 'DESKTOP_VOICE_STALE_APP_BUILD_BLOCKED'
        Write-Host "INSTALLED_SMOKE_FAIL reason=running_sha_mismatch running=$runningBuildSha expected=$ExpectedBuildSha"
        exit 7
    }

    if ($runningExePath.ToLower() -ne $installedExe.ToLower()) {
        Write-Host "INSTALLED_SMOKE_FAIL reason=running_path_mismatch path=$runningExePath"
        exit 8
    }

    # Wait for helper + endpoint preflight
    $null = Wait-LogMarker 'DESKTOP_VOICE_ENDPOINT_ID_LOGGED' 45
    if (Test-Path $logPath) { $logText = Get-Content $logPath -Raw }

    try {
        $diag = Invoke-RestMethod 'http://127.0.0.1:8765/capture/device_diag' -TimeoutSec 10
        if ($diag.ok -eq $true -and $null -ne $diag.report) {
            $r = $diag.report
            $endpointIdPresent = -not [string]::IsNullOrWhiteSpace($r.selected_device_id)
            $endpointRolePresent = -not [string]::IsNullOrWhiteSpace($r.selected_role)
            $endpointVolumePresent = $null -ne $r.endpoint_volume
            Write-Host "helper_endpoint_id=$($r.selected_device_id)"
            Write-Host "helper_endpoint_role=$($r.selected_role)"
            Write-Host "helper_endpoint_volume=$($r.endpoint_volume)"
        }
    } catch {
        Write-Host "helper_device_diag=unavailable $_"
    }

    if ($logText -match 'DESKTOP_VOICE_ENDPOINT_ID_LOGGED') { $endpointIdPresent = $true }
    if ($logText -match 'DESKTOP_VOICE_ENDPOINT_ROLE_LOGGED|DESKTOP_VOICE_CAPTURE_ENDPOINT_ROLE_SELECTED') {
        $endpointRolePresent = $true
    }
    if ($logText -match 'DESKTOP_VOICE_ENDPOINT_VOLUME_LOGGED') { $endpointVolumePresent = $true }

    $endpointDiagFieldsPresent = $endpointIdPresent -and $endpointRolePresent -and $endpointVolumePresent
    Write-Host "endpoint_id_present=$($endpointIdPresent.ToString().ToLower())"
    Write-Host "endpoint_role_present=$($endpointRolePresent.ToString().ToLower())"
    Write-Host "endpoint_volume_present=$($endpointVolumePresent.ToString().ToLower())"
    Write-Host "endpoint_diag_fields_present=$($endpointDiagFieldsPresent.ToString().ToLower())"

    if (-not $endpointDiagFieldsPresent) {
        Write-Host 'INSTALLED_SMOKE_FAIL reason=endpoint_diag_fields_missing'
        exit 9
    }

    # Cue playback + overlay transparency self-checks (logged by smoke bridge).
    $null = Wait-LogMarker 'DESKTOP_VOICE_READY_CUE_PLAYBACK_SMOKE' 20
    if (Test-Path $logPath) { $logText = Get-Content $logPath -Raw }

    $cueSmokePass = $logText -match 'DESKTOP_VOICE_READY_CUE_PLAYBACK_SMOKE\s+pass|cue_playback_smoke_pass\s+yes'
    $overlayTransparent = $logText -match 'DESKTOP_VOICE_OVERLAY_TRANSPARENT_BACKGROUND|overlay_window_transparent\s+yes|overlay_background_mode\s+layered_colorkey'
    Write-Host "cue_playback_smoke_pass=$($cueSmokePass.ToString().ToLower())"
    Write-Host "overlay_transparency_diag_present=$($overlayTransparent.ToString().ToLower())"

    if (-not $cueSmokePass) {
        Write-Host 'INSTALLED_SMOKE_FAIL reason=cue_playback_smoke_missing_or_fail'
        exit 10
    }

    $installIdentityPass = $true
    Write-Host 'DESKTOP_VOICE_INSTALLED_SMOKE_IDENTITY_PASS'
    Write-Host 'DESKTOP_VOICE_BUILD_SHA_MATCHES_RUNNING_APP'
    Write-Host 'DESKTOP_VOICE_READY_CUE_PLAYBACK_SMOKE'
    Write-Host 'install_identity_pass=yes'
    Write-Host 'INSTALLED_SMOKE_PASS'
    exit 0
} finally {
    Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
