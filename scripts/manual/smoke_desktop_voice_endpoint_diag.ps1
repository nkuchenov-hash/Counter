# Smoke: STT helper endpoint diagnostics (non-stub volume/id).
$ErrorActionPreference = 'Stop'
$helperExe = Join-Path $env:LOCALAPPDATA 'Programs\Counter\stt_helper\counter_stt_helper.exe'
$helperDir = Split-Path $helperExe -Parent
$port = 8765

Write-Host 'DESKTOP_VOICE_CORE_AUDIO_DEVICE_DIAGNOSTICS_SMOKE'

if (-not (Test-Path $helperExe)) {
    Write-Host "FAIL helper_missing=$helperExe"
    exit 1
}

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
taskkill /IM counter_stt_helper.exe /F 2>$null | Out-Null
$ErrorActionPreference = $prevEap
Start-Sleep 1

$proc = Start-Process $helperExe -ArgumentList '--port', $port -WorkingDirectory $helperDir -PassThru -WindowStyle Hidden
try {
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        try { $null = Invoke-RestMethod "http://127.0.0.1:$port/ping" -TimeoutSec 2; break } catch { Start-Sleep 0.5 }
    }
    $diag = Invoke-RestMethod "http://127.0.0.1:$port/capture/device_diag" -TimeoutSec 10
    if ($diag.ok -ne $true) { throw 'device_diag not ok' }
    $r = $diag.report
    Write-Host "endpoint_role=$($r.selected_role)"
    Write-Host "endpoint_id=$($r.selected_device_id)"
    Write-Host "endpoint_volume=$($r.endpoint_volume)"
    Write-Host "console=$($r.console_default.friendly_name)"
    Write-Host "communications=$($r.communications_default.friendly_name)"
    if ($null -eq $r.endpoint_volume) {
        Write-Host 'FAIL endpoint_volume_still_stub'
        exit 2
    }
    if ([string]::IsNullOrWhiteSpace($r.selected_device_id)) {
        Write-Host 'FAIL endpoint_id_missing'
        exit 3
    }
    Write-Host 'PASS endpoint_diagnostics_populated'
} finally {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}
