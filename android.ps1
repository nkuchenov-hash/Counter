# Android release APK shortcut (split per CPU ABI - smaller than universal APK).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

Write-Host 'Fetching Flutter packages...' -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Building compact Android APKs split per CPU...' -ForegroundColor Cyan
$gitCommit = (git rev-parse --short HEAD).Trim()
$buildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$dartDefines = @(
  "--dart-define=GIT_COMMIT=$gitCommit",
  "--dart-define=BUILD_TIME=$buildTime"
)
flutter build apk --release --split-per-abi @dartDefines
if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'Release APK build failed with icon tree-shaking enabled.' -ForegroundColor Yellow
    Write-Host 'Retrying with --no-tree-shake-icons because this project has non-constant IconData.' -ForegroundColor Yellow
    flutter build apk --release --split-per-abi --no-tree-shake-icons @dartDefines
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$outputFolder = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk'
$modernPhoneApk = Join-Path $outputFolder 'app-arm64-v8a-release.apk'

Write-Host ''
Write-Host 'Done. Compact APKs are here:' -ForegroundColor Green
Write-Host 'build\app\outputs\flutter-apk\'
Write-Host ''
Write-Host 'APK sizes:' -ForegroundColor Green
Get-ChildItem -Path $outputFolder -Filter '*.apk' |
    Sort-Object Name |
    ForEach-Object {
        $sizeMb = [math]::Round($_.Length / 1MB, 2)
        Write-Host ("{0} - {1} MB" -f $_.Name, $sizeMb)
    }
Write-Host ''
Write-Host 'For most modern Android phones, use:' -ForegroundColor Yellow
Write-Host $modernPhoneApk
