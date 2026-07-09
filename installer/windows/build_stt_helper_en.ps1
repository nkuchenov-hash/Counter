# Builds English-language counter_stt_helper.exe from GOLOS backend-rs sources.
# Patches Whisper language ru -> en, Price Reporter prompt, no_vad trim, and
# injects CPAL/WASAPI mic capture module (Handy-parity F32 native capture).
# Output: installer/windows/stt_helper_build/counter_stt_helper.exe

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$backendSrcRoot = 'C:\Users\nkuch\Development\Apps\_cleanup_backup_20260615_110428\backend-rs'
$outDir = Join-Path $PSScriptRoot 'stt_helper_build'
$mainRs = Join-Path $backendSrcRoot 'src\main.rs'
$captureSrc = Join-Path $PSScriptRoot 'stt_helper_src\capture.rs'
$captureDst = Join-Path $backendSrcRoot 'src\capture.rs'
$winAudioSrc = Join-Path $PSScriptRoot 'stt_helper_src\win_audio_endpoint.rs'
$winAudioDst = Join-Path $backendSrcRoot 'src\win_audio_endpoint.rs'
$cargoToml = Join-Path $backendSrcRoot 'Cargo.toml'
$cargoBak = Join-Path $backendSrcRoot 'Cargo.toml.bak_counter_capture'

if (-not (Test-Path $mainRs)) {
    throw "backend-rs main.rs not found: $mainRs"
}
if (-not (Test-Path $captureSrc)) {
    throw "capture.rs module missing: $captureSrc"
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
# Command-VAD parity: benchmark selected NO VAD trim for command-length audio.
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

# Inject CPAL capture module + routes.
if ($content -notmatch '(?m)^mod capture;') {
    $content = $content -replace '(?m)^(use actix_web::\{web, App, HttpResponse, HttpServer\};)', "`$1`nmod capture;"
}
if ($content -notmatch 'capture::configure') {
    $needle = '.route("/debug/download-test",    web::get().to(debug_download_test))'
    $insert = @'
.route("/debug/download-test",    web::get().to(debug_download_test))
            .configure(capture::configure)
'@
    if ($content.IndexOf($needle) -lt 0) { throw 'route anchor for capture::configure not found' }
    $content = $content.Replace($needle, $insert)
}
# Expose last mid-listen partial for Dart first-candidate (<500ms) path.
if ($content -notmatch 'async fn transcribe_last_partial') {
    $partialFn = @'

/// GET last mid-listen partial cache (first-candidate fast path).
async fn transcribe_last_partial(state: web::Data<Arc<AppState>>) -> HttpResponse {
    let g = state.last_partial.lock().unwrap();
    match g.as_ref() {
        Some((text, at)) => HttpResponse::Ok().json(serde_json::json!({
            "ok": true,
            "text": text,
            "age_ms": at.elapsed().as_millis() as u64,
        })),
        None => HttpResponse::Ok().json(serde_json::json!({
            "ok": true,
            "text": "",
            "age_ms": null,
        })),
    }
}
'@
    $anchor = 'async fn transcribe_partial_audio('
    $idx = $content.IndexOf($anchor)
    if ($idx -lt 0) { throw 'transcribe_partial_audio anchor not found for last_partial inject' }
    $content = $content.Insert($idx, $partialFn)
}
if ($content -notmatch 'web::get\(\)\.to\(transcribe_last_partial\)') {
    $needle2 = '.route("/transcribe/partial_audio",    web::post().to(transcribe_partial_audio))'
    $insert2 = @'
.route("/transcribe/partial_audio",    web::post().to(transcribe_partial_audio))
            .route("/transcribe/last_partial",       web::get().to(transcribe_last_partial))
'@
    if ($content.IndexOf($needle2) -lt 0) { throw 'partial_audio route anchor not found' }
    $content = $content.Replace($needle2, $insert2)
}
Write-Host 'DESKTOP_VOICE_CPAL_WASAPI_CAPTURE_INJECTED'
Write-Host 'DESKTOP_VOICE_LAST_PARTIAL_ROUTE_INJECTED'

Set-Content -Encoding UTF8 -NoNewline -Path $mainRs -Value $content
Copy-Item -Force $captureSrc $captureDst
if (Test-Path $winAudioSrc) {
    Copy-Item -Force $winAudioSrc $winAudioDst
    Write-Host 'DESKTOP_VOICE_WIN_AUDIO_ENDPOINT_MODULE_COPIED'
}

# Ensure cpal dependency (restore Cargo.toml from backup after build).
if (-not (Test-Path $cargoBak)) {
    Copy-Item -Force $cargoToml $cargoBak
}
$cargo = Get-Content -Raw $cargoBak
$depsToInject = @()
if ($cargo -notmatch '(?m)^cpal\s*=') {
    $depsToInject += 'cpal = "0.15"'
}
if ($cargo -notmatch '(?m)^windows\s*=') {
    $depsToInject += @'
windows = { version = "0.58", features = [
  "Win32_Foundation",
  "Win32_Media_Audio",
  "Win32_Media_Audio_Endpoints",
  "Win32_System_Com",
  "Win32_System_Com_StructuredStorage",
  "Win32_System_Variant",
  "Win32_UI_Shell_PropertiesSystem",
  "Win32_Devices_FunctionDiscovery",
  "Win32_Devices_Properties",
] }
'@
}
if ($depsToInject.Count -gt 0) {
    $cargo = $cargo.TrimEnd() + "`n" + ($depsToInject -join "`n") + "`n"
    Set-Content -Encoding UTF8 -NoNewline -Path $cargoToml -Value $cargo
    Write-Host 'DESKTOP_VOICE_HELPER_DEPS_INJECTED'
} else {
    Copy-Item -Force $cargoBak $cargoToml
}

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
    Write-Host "OK: EN STT helper (cpal capture) -> $outDir\counter_stt_helper.exe"
} finally {
    Copy-Item -Force $backup $mainRs
    if (Test-Path $cargoBak) { Copy-Item -Force $cargoBak $cargoToml }
    if (Test-Path $captureDst) { Remove-Item -Force $captureDst }
    if (Test-Path $winAudioDst) { Remove-Item -Force $winAudioDst }
    Pop-Location
}
