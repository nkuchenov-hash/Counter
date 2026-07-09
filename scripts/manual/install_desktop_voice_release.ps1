# Install Counter Desktop Voice release to %LOCALAPPDATA%\Programs\Counter.
# Stops stale processes, builds with GIT_COMMIT/BUILD_TIME, copies app + helper together.
param(
    [switch]$SkipFlutterBuild,
    [switch]$SkipHelperBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$installDir = Join-Path $env:LOCALAPPDATA 'Programs\Counter'
$installedExe = Join-Path $installDir 'counter.exe'
$installedHelper = Join-Path $installDir 'stt_helper\counter_stt_helper.exe'
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$appSo = Join-Path $installDir 'data\app.so'
$buildStarted = Get-Date

function Stop-CounterProcessesVerified {
    for ($i = 0; $i -lt 12; $i++) {
        Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        $left = @(Get-Process counter, counter_stt_helper -ErrorAction SilentlyContinue)
        if ($left.Count -eq 0) {
            Write-Host 'DESKTOP_VOICE_NO_OLD_COUNTER_PROCESS'
            return $true
        }
    }
    return $false
}

function Get-EmbeddedBuildSha {
    param([string]$Path, [string]$Expected)
    if (-not (Test-Path $Path)) { return '' }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $ascii = [Text.Encoding]::ASCII.GetString($bytes)
    if ($Expected -and $ascii.Contains($Expected)) { return $Expected }
    if ($ascii.Contains('df696fc')) { return 'df696fc' }
    if ($ascii.Contains('dev')) { return 'dev' }
    return ''
}

Write-Host '=== Desktop Voice Release Install ==='
$expectedSha = (git rev-parse --short HEAD).Trim()
$buildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Write-Host "expected_build_sha=$expectedSha"
Write-Host "build_time=$buildTime"

if (-not (Stop-CounterProcessesVerified)) {
    Write-Host 'INSTALL_FAIL reason=stale_counter_process_survived'
    exit 10
}

if (-not $SkipHelperBuild) {
    & (Join-Path $repoRoot 'installer\windows\build_stt_helper_en.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not $SkipFlutterBuild) {
    flutter build windows --release `
        --dart-define=DESKTOP_VOICE_COMMAND=true `
        --dart-define=GIT_COMMIT="$expectedSha" `
        --dart-define=BUILD_TIME="$buildTime"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    $buildStarted = (Get-Item (Join-Path $releaseDir 'counter.exe')).LastWriteTime
}

& (Join-Path $repoRoot 'installer\windows\prepare_stt_payload.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path $releaseDir)) {
    throw "Release folder missing: $releaseDir"
}
if (-not (Test-Path (Join-Path $releaseDir 'counter.exe'))) {
    throw 'counter.exe missing in Release folder'
}
if (-not (Test-Path (Join-Path $releaseDir 'stt_helper\counter_stt_helper.exe'))) {
    throw 'counter_stt_helper.exe missing in Release stt_helper folder'
}

New-Item -ItemType Directory -Force -Path $installDir | Out-Null

foreach ($rel in @('counter.exe', 'stt_helper\counter_stt_helper.exe')) {
    $target = Join-Path $installDir $rel
    if (Test-Path $target) {
        Remove-Item -Force $target -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        if (Test-Path $target) {
            Write-Host "INSTALL_FAIL reason=file_locked path=$target"
            exit 13
        }
    }
}

$robocopy = Start-Process -FilePath 'robocopy.exe' -ArgumentList @(
    $releaseDir, $installDir, '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/nc', '/ns', '/np'
) -Wait -PassThru -NoNewWindow
if ($robocopy.ExitCode -ge 8) {
    throw "robocopy failed exit=$($robocopy.ExitCode)"
}
Write-Host 'DESKTOP_VOICE_COUNTER_EXE_REPLACED'
Write-Host 'DESKTOP_VOICE_HELPER_EXE_REPLACED'

$appItem = Get-Item $installedExe
$helperItem = Get-Item $installedHelper
Write-Host "app_file_timestamp=$($appItem.LastWriteTime.ToString('o'))"
Write-Host "helper_file_timestamp=$($helperItem.LastWriteTime.ToString('o'))"

$releaseExe = Get-Item (Join-Path $releaseDir 'counter.exe')
if ($appItem.Length -ne $releaseExe.Length -or $appItem.LastWriteTime -lt $releaseExe.LastWriteTime.AddSeconds(-2)) {
    Write-Host 'INSTALL_FAIL reason=app_not_replaced_from_release'
    exit 11
}

$embedded = Get-EmbeddedBuildSha -Path $appSo -Expected $expectedSha
Write-Host "embedded_build_sha=$embedded"
if ($embedded -ne $expectedSha) {
    Write-Host 'INSTALL_FAIL reason=app_so_sha_mismatch'
    exit 12
}

Write-Host 'DESKTOP_VOICE_INSTALL_IDENTITY_VERIFIED'
Write-Host 'DESKTOP_VOICE_NO_MIXED_APP_HELPER_INSTALL'
Write-Host "INSTALLED_OK path=$installDir sha=$expectedSha"
exit 0
