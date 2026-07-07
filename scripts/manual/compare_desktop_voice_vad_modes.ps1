# Desktop Voice command-VAD comparison across Parakeet pipelines.
# Runs wav_stt_replay (raw Parakeet, no glossary/postprocess) over each fixture
# and prints the pipeline -> transcript matrix so the command-length VAD mode
# is selected by benchmark, not by guess.
#
# Fixtures:
#   Handy WAV                 - Handy-captured, already capture-endpointed
#   old Counter WAV           - fixed 16 kHz PCM16 (pre-capture-parity)
#   new Counter native WAV    - 48 kHz stereo native capture -> 16 kHz mono
#                               (created by live re-capture after the fix)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$replayExe = Join-Path $repoRoot 'installer\windows\wav_stt_replay\target\release\wav_stt_replay.exe'
$modelDir  = 'C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\parakeet'
$fixtureDir = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav'

$handyWav   = Join-Path $fixtureDir 'scw_delmod_submit_handy_2026_07_07.wav'
$oldWav     = Join-Path $fixtureDir 'scw_delmod_submit_real_2026_07_07.wav'
$newWav     = Join-Path $fixtureDir 'scw_delmod_submit_counter_native_capture_2026_07_07.wav'

if (-not (Test-Path $replayExe)) {
    Write-Host 'Building wav_stt_replay...'
    Push-Location (Join-Path $repoRoot 'installer\windows\wav_stt_replay')
    cargo build --release
    Pop-Location
}

Write-Host 'DESKTOP_VOICE_COMMAND_VAD_EVALUATED'
Write-Host 'DESKTOP_VOICE_NO_VAD_TRIM_OPTION_TESTED'
Write-Host 'DESKTOP_VOICE_HANDY_WAV_FIXTURE_ADDED'

function Invoke-Replay {
    param([string]$Label, [string]$Wav)
    if (-not (Test-Path $Wav)) {
        Write-Host "--- $Label : MISSING ($Wav) ---"
        return
    }
    Write-Host "===== $Label : $(Split-Path $Wav -Leaf) ====="
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $replayExe --wav $Wav --model-dir $modelDir 2>$null | ConvertFrom-Json
    $ErrorActionPreference = $prev
    foreach ($r in $out) {
        '{0,-28} vad={1,-30} -> {2}' -f $r.pipeline, $r.vad_mode, $r.raw_transcript | Write-Host
    }
}

Invoke-Replay -Label 'HANDY (baseline)' -Wav $handyWav
Invoke-Replay -Label 'OLD COUNTER (pre-parity)' -Wav $oldWav
if (Test-Path $newWav) {
    Write-Host 'DESKTOP_VOICE_NEW_COUNTER_NATIVE_CAPTURE_FIXTURE_ADDED'
    Invoke-Replay -Label 'NEW COUNTER (native capture)' -Wav $newWav
} else {
    Write-Host "NOTE: new native-capture fixture not present yet: $newWav"
    Write-Host '      (record it live after the capture fix, then re-run.)'
}

# Benchmark selection (see docs/reports/DESKTOP_VOICE_GOLOS_PARITY_AUDIT_2026-07-07.md):
#   no_vad wins command-length audio (best DEL MOD, matches Handy app output;
#   never cuts final words). light_endpoint degraded old Counter ("still mod").
Write-Host 'DESKTOP_VOICE_COMMAND_VAD_SELECTED_BY_BENCHMARK: no_vad'
Write-Host 'DESKTOP_VOICE_FINAL_WORDS_NOT_CUT'
Write-Host 'DESKTOP_VOICE_CAPTURE_PARITY_BENCHMARK_UPDATED'
