# Bundles GOLOS production STT helper + models beside Counter for Windows installer.

# Usage (repo root, after flutter build windows --release):

#   powershell -ExecutionPolicy Bypass -File installer\windows\prepare_stt_payload.ps1



$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'

$sttDir = Join-Path $releaseDir 'stt_helper'

$parakeetDir = Join-Path $sttDir 'models\parakeet'

$whisperDir = Join-Path $sttDir 'models\whisper-tiny'



# Production GOLOS backend (parakeet-capable). EN whisper patch optional for debug.

$enHelper = Join-Path $PSScriptRoot 'stt_helper_build\counter_stt_helper.exe'

$backendSrc = if (Test-Path $enHelper) { $enHelper } else {

    'C:\Users\nkuch\Development\Apps\_cleanup_backup_20260615_110428\Release\backend\golos-backend.exe'

}

$parakeetSrc = 'C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\parakeet'

$whisperSrc = 'C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\whisper-tiny'

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

