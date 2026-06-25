# Requires: Run as Administrator (UAC).
# Adds MSVC ATL/MFC headers required by flutter_secure_storage_windows and
# flutter_local_notifications_windows native plugins.
#
# Usage (Admin PowerShell):
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   & "C:\Users\nkuch\Development\Apps\counter\installer\windows\install-cpp-atl.ps1"

$ErrorActionPreference = 'Stop'
$setup = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe"
$installPath = 'C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools'

if (-not (Test-Path $setup)) {
    throw "Visual Studio Installer not found at $setup"
}

Write-Host "Installing Microsoft.VisualStudio.Component.VC.ATLMFC on:"
Write-Host "  $installPath"
Write-Host ""

& $setup modify `
  --installPath $installPath `
  --add Microsoft.VisualStudio.Component.VC.ATLMFC `
  --passive `
  --norestart `
  --force

if ($LASTEXITCODE -ne 0) {
    throw "setup.exe modify failed with exit code $LASTEXITCODE"
}

$atl = Get-ChildItem -Path "$installPath\VC\Tools\MSVC" -Recurse -Filter 'atlbase.h' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $atl) {
    throw 'ATL headers still missing after install (atlbase.h not found).'
}

Write-Host "OK: $($atl.FullName)"
