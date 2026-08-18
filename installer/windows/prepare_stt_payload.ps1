# Bundles GOLOS production STT helper + models beside Counter for Windows installer.

# Usage (repo root, after flutter build windows --release):

#   powershell -ExecutionPolicy Bypass -File installer\windows\prepare_stt_payload.ps1



param(
    [string]$ModelsSourceRoot = $env:COUNTER_STT_MODELS_ROOT,
    [string]$HelperSource = ''
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'

$sttDir = Join-Path $releaseDir 'stt_helper'

$parakeetDir = Join-Path $sttDir 'models\parakeet'

$whisperDir = Join-Path $sttDir 'models\whisper-tiny'



# Production GOLOS helper is currently retained in-repo because the old HTTP-sidecar
# source is not yet reproducibly built by Counter CI. Models stay external build inputs.
$trackedHelper = Join-Path $PSScriptRoot 'stt_helper_build\counter_stt_helper.exe'
$backendSrc = if (-not [string]::IsNullOrWhiteSpace($HelperSource)) {
    [System.IO.Path]::GetFullPath($HelperSource)
} else {
    $trackedHelper
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

    throw "golos-backend.exe not found at $backendSrc"

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



Write-Host "OK: STT payload (parakeet + whisper-tiny debug) -> $sttDir"

