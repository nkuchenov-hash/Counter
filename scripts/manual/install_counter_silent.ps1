# Build, install silently, launch Counter (Desktop Voice P0 handoff).
$ErrorActionPreference = 'Stop'
$repoRoot = 'c:\Users\nkuch\Development\Apps\counter'
$setup = Join-Path $repoRoot 'installer\windows\output\CounterSetup.exe'
$installedExe = Join-Path $env:LOCALAPPDATA 'Programs\Counter\counter.exe'

Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $setup)) {
    throw "CounterSetup.exe missing: $setup"
}

DesktopVoicePipeline = $null
Write-Host 'DESKTOP_INSTALLER_SILENT_INSTALL_ATTEMPTED'
$proc = Start-Process -FilePath $setup -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Host "DESKTOP_INSTALLER_SILENT_INSTALL_FAILED exit=$($proc.ExitCode)"
    exit $proc.ExitCode
}
Write-Host 'DESKTOP_INSTALLER_SILENT_INSTALL_SUCCESS'

if (-not (Test-Path $installedExe)) {
    throw "Installed counter.exe missing: $installedExe"
}

Write-Host "DESKTOP_INSTALLER_INSTALLED_APP_LAUNCHED $installedExe"
Start-Process -FilePath $installedExe
Start-Sleep -Seconds 3
Write-Host 'INSTALLED_APP_LAUNCHED_OK'
