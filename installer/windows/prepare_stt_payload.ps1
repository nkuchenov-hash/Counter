# Bundles the pinned Counter STT helper + externally supplied models beside the Windows release.
#
# Usage (repo root, after flutter build windows --release):
#   powershell -ExecutionPolicy Bypass -File installer\windows\prepare_stt_payload.ps1
#
# Production default: download the immutable GitHub Release asset declared by
# stt_helper_artifact.json and verify SHA-256 + byte size before use.
# For an explicitly supplied local helper, pass -HelperSource <path>.

param(
    [string]$ModelsSourceRoot = $env:COUNTER_STT_MODELS_ROOT,
    [string]$HelperSource = '',
    [string]$ArtifactCacheRoot = $env:COUNTER_STT_ARTIFACT_CACHE
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
$sttDir = Join-Path $releaseDir 'stt_helper'
$parakeetDir = Join-Path $sttDir 'models\parakeet'
$whisperDir = Join-Path $sttDir 'models\whisper-tiny'
$manifestPath = Join-Path $PSScriptRoot 'stt_helper_artifact.json'

function Assert-PinnedHelper {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Manifest
    )

    if (-not (Test-Path $Path)) {
        throw "Pinned STT helper missing: $Path"
    }

    $actualSize = (Get-Item $Path).Length
    $expectedSize = [int64]$Manifest.size_bytes
    if ($actualSize -ne $expectedSize) {
        throw "Pinned STT helper size mismatch: expected=$expectedSize actual=$actualSize path=$Path"
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
    $expectedHash = ([string]$Manifest.sha256).ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "Pinned STT helper SHA-256 mismatch: expected=$expectedHash actual=$actualHash path=$Path"
    }
}

if (-not [string]::IsNullOrWhiteSpace($HelperSource)) {
    $backendSrc = [System.IO.Path]::GetFullPath($HelperSource)
    if (-not (Test-Path $backendSrc)) {
        throw "Explicit STT helper not found: $backendSrc"
    }
    Write-Host "Using explicit STT helper override: $backendSrc"
} else {
    if (-not (Test-Path $manifestPath)) {
        throw "STT helper artifact manifest missing: $manifestPath"
    }

    $manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
    if ($manifest.schema_version -ne 1) {
        throw "Unsupported STT helper artifact manifest schema: $($manifest.schema_version)"
    }
    if ([string]::IsNullOrWhiteSpace([string]$manifest.release_tag) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.asset_name) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.sha256) -or
        [int64]$manifest.size_bytes -le 0) {
        throw 'STT helper artifact manifest is incomplete.'
    }

    if ([string]::IsNullOrWhiteSpace($ArtifactCacheRoot)) {
        $ArtifactCacheRoot = Join-Path $repoRoot 'build\stt_artifacts'
    }
    $cacheRoot = [System.IO.Path]::GetFullPath($ArtifactCacheRoot)
    $cacheDir = Join-Path $cacheRoot ([string]$manifest.release_tag)
    $backendSrc = Join-Path $cacheDir ([string]$manifest.asset_name)

    $needDownload = $true
    if (Test-Path $backendSrc) {
        try {
            Assert-PinnedHelper -Path $backendSrc -Manifest $manifest
            $needDownload = $false
            Write-Host "Using verified cached STT helper: $backendSrc"
        } catch {
            Write-Warning "Discarding invalid cached STT helper: $($_.Exception.Message)"
            Remove-Item -Force $backendSrc
        }
    }

    if ($needDownload) {
        New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
        $artifactUrl = "https://github.com/nkuchenov-hash/Counter/releases/download/$($manifest.release_tag)/$($manifest.asset_name)"
        $tempPath = "$backendSrc.download"
        if (Test-Path $tempPath) { Remove-Item -Force $tempPath }
        Write-Host "Downloading pinned STT helper: $artifactUrl"
        try {
            Invoke-WebRequest -Uri $artifactUrl -OutFile $tempPath
            Assert-PinnedHelper -Path $tempPath -Manifest $manifest
            Move-Item -Force $tempPath $backendSrc
        } finally {
            if (Test-Path $tempPath) { Remove-Item -Force $tempPath }
        }
        Assert-PinnedHelper -Path $backendSrc -Manifest $manifest
        Write-Host "Verified STT helper artifact: tag=$($manifest.release_tag) sha256=$($manifest.sha256)"
    }
}

if ([string]::IsNullOrWhiteSpace($ModelsSourceRoot)) {
    throw 'STT models source is required. Pass -ModelsSourceRoot <path> or set COUNTER_STT_MODELS_ROOT.'
}
$modelsRoot = [System.IO.Path]::GetFullPath($ModelsSourceRoot)
$parakeetSrc = Join-Path $modelsRoot 'parakeet'
$whisperSrc = Join-Path $modelsRoot 'whisper-tiny'
$winSpeechScript = Join-Path $PSScriptRoot 'scripts\win_speech_wav.ps1'

if (-not (Test-Path $releaseDir)) {
    throw "Flutter Release folder missing: $releaseDir (run flutter build windows first)"
}
if (-not (Test-Path $backendSrc)) {
    throw "STT helper not found at $backendSrc"
}
if (-not (Test-Path $parakeetSrc)) {
    throw "parakeet model not found at $parakeetSrc"
}
if (-not (Test-Path $whisperSrc)) {
    throw "whisper-tiny model not found at $whisperSrc"
}

New-Item -ItemType Directory -Force -Path $sttDir | Out-Null
New-Item -ItemType Directory -Force -Path $parakeetDir | Out-Null
New-Item -ItemType Directory -Force -Path $whisperDir | Out-Null

Copy-Item -Force $backendSrc (Join-Path $sttDir 'counter_stt_helper.exe')
Copy-Item -Recurse -Force (Join-Path $parakeetSrc '*') $parakeetDir
Copy-Item -Recurse -Force (Join-Path $whisperSrc '*') $whisperDir
if (Test-Path $winSpeechScript) {
    Copy-Item -Force $winSpeechScript (Join-Path $sttDir 'win_speech_wav.ps1')
}

$settingsPath = Join-Path $sttDir 'settings.json'
@{ active_model = 'parakeet' } | ConvertTo-Json | Set-Content -Encoding UTF8 $settingsPath

Write-Host "OK: STT payload (pinned helper + parakeet + whisper-tiny debug) -> $sttDir"
