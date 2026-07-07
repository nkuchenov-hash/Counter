# Builds English-language counter_stt_helper.exe from GOLOS backend-rs sources.
# Patches Whisper language ru -> en and Price Reporter initial prompt.
# Output: installer/windows/stt_helper_build/counter_stt_helper.exe

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$backendSrcRoot = 'C:\Users\nkuch\Development\Apps\_cleanup_backup_20260615_110428\backend-rs'
$outDir = Join-Path $PSScriptRoot 'stt_helper_build'
$mainRs = Join-Path $backendSrcRoot 'src\main.rs'

if (-not (Test-Path $mainRs)) {
    throw "backend-rs main.rs not found: $mainRs"
}

$backup = "$mainRs.bak_counter_en"
if (-not (Test-Path $backup)) {
    Copy-Item -Force $mainRs $backup
}

$content = Get-Content -Raw $backup
$content = $content -replace "`r`n", "`n"
$content = $content -replace 'params\.set_language\(Some\("ru"\)\);', 'params.set_language(Some("en"));'
$content = $content -replace 'params\.set_initial_prompt\([\s\S]*?\);', @'
params.set_initial_prompt(
        "Price Reporter, Planning, Southern Computer Warehouse, SCW, DEL MOD, ADD MOD, ADD SIN, Submit, BLINK, Laredo Technical Services, Laredo TS, AGE SOLUTIONS, client, task, record, timeline."
    );
'@
# Command-VAD parity: benchmark (wav_stt_replay, Handy + old Counter WAVs)
# selected NO VAD trim for command-length audio. GOLOS 350/700 tail-trim
# degraded short commands ("Del Mod" -> "Dell Mod"); light endpointing was
# worse on the old Counter WAV; no_vad matched Handy's own app output.
$trimStart = $content.IndexOf('/// Trim leading/trailing silence with 200 ms padding')
if ($trimStart -lt 0) { throw 'trim_silence block not found in main.rs.bak_counter_en' }
$whisperIdx = $content.IndexOf('fn whisper_transcribe', $trimStart)
if ($whisperIdx -lt 0) { throw 'whisper anchor not found after trim_silence' }
$trimEnd = $content.LastIndexOf("`n`n", $whisperIdx)
if ($trimEnd -lt $trimStart) { throw 'trim_silence end anchor not found' }
$noVadTrimFn = @'
/// Command-length audio: NO VAD trim (benchmark-selected, Handy parity).
/// GOLOS tail-trim degraded short commands (Del Mod -> Dell Mod); no_vad
/// matched Handy app output on the Handy WAV and preserved final words.
#[allow(dead_code)]
fn trim_silence(audio: &[f32]) -> &[f32] {
    audio
}
'@
$content = $content.Substring(0, $trimStart) + $noVadTrimFn + $content.Substring($trimEnd)
if ($content -notmatch 'NO VAD trim \(benchmark-selected') {
    throw 'no_vad trim_silence patch did not apply'
}
Write-Host 'DESKTOP_VOICE_COMMAND_VAD_SELECTED_BY_BENCHMARK (no_vad; final words preserved)'

Set-Content -Encoding UTF8 -NoNewline -Path $mainRs -Value $content

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Push-Location $backendSrcRoot
try {
    cargo build --release
    if ($LASTEXITCODE -ne 0) {
        throw "cargo build failed with exit code $LASTEXITCODE"
    }
    $built = Join-Path $backendSrcRoot 'target\release\golos-backend.exe'
    if (-not (Test-Path $built)) {
        throw "cargo build succeeded but golos-backend.exe missing"
    }
    Copy-Item -Force $built (Join-Path $outDir 'counter_stt_helper.exe')
    Write-Host "OK: EN STT helper -> $outDir\counter_stt_helper.exe"
} finally {
    Copy-Item -Force $backup $mainRs
    Pop-Location
}
