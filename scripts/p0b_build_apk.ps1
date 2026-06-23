# P0G Android APK with git sha + build time (verify in More → P0G build marker).
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\..

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  $adb = 'C:\Users\nkuch\AppData\Local\Android\Sdk\platform-tools\adb.exe'
}

$gitCommit = (git rev-parse --short HEAD).Trim()
$buildTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Write-Host "==> P0J APK git=$gitCommit built=$buildTime"

flutter build apk --release `
  --target-platform android-arm64 `
  --split-per-abi `
  --no-tree-shake-icons `
  --dart-define=GIT_COMMIT=$gitCommit `
  --dart-define=BUILD_TIME="$buildTime"

$apk = 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk'
Write-Host "==> APK: $((Resolve-Path $apk).Path)"

if (Test-Path $adb) {
  $devices = & $adb devices | Select-String 'device$'
  if ($devices) {
    Write-Host '==> Installing on connected device...'
    & $adb install -r $apk
    Write-Host '==> Launch logcat filter: adb logcat -s flutter'
  } else {
    Write-Host '==> No Android device connected. Install APK manually and verify P0J build marker on More screen.'
  }
}
