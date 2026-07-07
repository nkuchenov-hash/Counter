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
$content = $content -replace 'const VAD_PAD_MS:\s*usize = 200;', 'const VAD_PAD_MS:        usize = 350;'
$content = $content -replace 'const VAD_RMS_THRESHOLD: f32   = 0.01;', @'
const VAD_TAIL_KEEP_MS:  usize = 700;
const VAD_RMS_THRESHOLD: f32   = 0.01;
'@
$trimStart = $content.IndexOf('/// Trim leading/trailing silence with 200 ms padding')
if ($trimStart -lt 0) { throw 'trim_silence block not found in main.rs.bak_counter_en' }
$whisperIdx = $content.IndexOf('fn whisper_transcribe', $trimStart)
if ($whisperIdx -lt 0) { throw 'whisper anchor not found after trim_silence' }
$trimEnd = $content.LastIndexOf("`n`n", $whisperIdx)
if ($trimEnd -lt $trimStart) { throw 'trim_silence end anchor not found' }
$golosTrimFn = @'
/// Trim leading/trailing silence - GOLOS parity (350 ms pad + 700 ms tail keep).
fn trim_silence(audio: &[f32]) -> &[f32] {
    let pad = VAD_PAD_MS * VAD_SAMPLE_RATE / 1000;
    let tail_keep = VAD_TAIL_KEEP_MS * VAD_SAMPLE_RATE / 1000;
    match vad_find_speech(audio) {
        None => audio,
        Some((start, end)) => {
            let s = start.saturating_sub(pad);
            let preserve_from = audio.len().saturating_sub(tail_keep);
            let e = (end + pad).max(preserve_from).min(audio.len());
            &audio[s..e]
        }
    }
}
'@
$content = $content.Substring(0, $trimStart) + $golosTrimFn + $content.Substring($trimEnd)
if ($content -notmatch 'VAD_TAIL_KEEP_MS \* VAD_SAMPLE_RATE') {
    throw 'GOLOS VAD trim_silence patch did not apply'
}
Write-Host 'DESKTOP_VOICE_COUNTER_PIPELINE_MATCHED_TO_GOLOS (VAD 350ms pad + 700ms tail keep)'

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
