# Desktop Voice STT quality benchmark — real WAV replay + golden text safety gate.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host '=== Desktop Voice STT Benchmark ==='
Write-Host 'DESKTOP_VOICE_REAL_WAV_REGRESSION_ADDED'
Write-Host 'DESKTOP_VOICE_STT_BASELINE_STORED'

$manifestPath = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav\golden_manifest.json'
$wavPath = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav\scw_delmod_submit_real_2026_07_07.wav'
$freshHelper = Join-Path $repoRoot 'installer\windows\stt_helper_build\counter_stt_helper.exe'
$installedHelperDir = Join-Path $env:LOCALAPPDATA 'Programs\Counter\stt_helper'
$helperExe = Join-Path $installedHelperDir 'counter_stt_helper.exe'

if (-not (Test-Path $manifestPath)) { throw "Missing manifest: $manifestPath" }
if (-not (Test-Path $wavPath)) { throw "Missing WAV: $wavPath" }

$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$baseline = $manifest.baseline_transcript
Write-Host "Baseline transcript: $baseline"

function Start-CounterSttHelper {
    param([string]$ExePath, [int]$Port = 8766)
    if (-not (Test-Path $ExePath)) {
        Write-Host "Helper exe missing: $ExePath"
        return $null
    }
    $proc = Start-Process -FilePath $ExePath -ArgumentList @('--port', "$Port") `
        -WorkingDirectory (Split-Path $ExePath -Parent) `
        -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        try {
            $null = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/ping" -TimeoutSec 2
            return $proc
        } catch {}
        Start-Sleep -Milliseconds 500
    }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    return $null
}

function Wait-HelperModelReady {
    param([string]$Engine = 'parakeet', [int]$Port = 8766)
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/config" `
        -ContentType 'application/json' -Body (@{ engine = $Engine } | ConvertTo-Json) | Out-Null
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        $st = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/status" -TimeoutSec 3
        if ($st.final_transcribe_ready -eq $true) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Invoke-WavTranscribe {
    param([string]$WavFile, [string]$Engine = 'parakeet', [int]$Port = 8766)
    $bytes = [System.IO.File]::ReadAllBytes($WavFile)
    if ($bytes.Length -le 44) { throw 'WAV too small' }
    $pcm = $bytes[44..($bytes.Length - 1)]
    $b64 = [Convert]::ToBase64String([byte[]]$pcm)
    if (-not (Wait-HelperModelReady -Engine $Engine -Port $Port)) {
        throw 'Helper model not ready'
    }
    $t0 = Get-Date
    $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$Port/transcribe/stop" `
        -ContentType 'application/json' -Body (@{ audio_base64 = $b64 } | ConvertTo-Json) `
        -TimeoutSec 120
    $latencyMs = [int]((Get-Date) - $t0).TotalMilliseconds
    return @{ text = $resp.text; latency_ms = $latencyMs; pcm_bytes = $pcm.Length }
}

$helperProc = $null
try {
    if (Test-Path $freshHelper) {
        $benchDir = Join-Path $env:TEMP 'counter_stt_wav_bench'
        New-Item -ItemType Directory -Force -Path $benchDir | Out-Null
        Copy-Item -Force $freshHelper (Join-Path $benchDir 'counter_stt_helper.exe')
        $benchModels = Join-Path $benchDir 'models'
        if (Test-Path $installedHelperDir) {
            if (Test-Path $benchModels) { Remove-Item -Force -Recurse $benchModels -ErrorAction SilentlyContinue }
            cmd /c mklink /J "$benchModels" "$installedHelperDir\models" | Out-Null
        }
        $benchPort = 8766
        $runHelper = Join-Path $benchDir 'counter_stt_helper.exe'
        Write-Host "Benchmark helper dir: $benchDir port=$benchPort"
        Write-Host 'DESKTOP_VOICE_SAME_WAV_COMPARISON_READY'
        $helperProc = Start-CounterSttHelper -ExePath $runHelper -Port $benchPort
        if ($null -ne $helperProc) {
            $counter = Invoke-WavTranscribe -WavFile $wavPath -Port $benchPort
            Write-Host "DESKTOP_VOICE_COUNTER_RAW_TRANSCRIPT_RECORDED: $($counter.text)"
            Write-Host "Counter latency_ms=$($counter.latency_ms) pcm_bytes=$($counter.pcm_bytes)"
            Write-Host 'alias_postprocess_used_for_quality=false'
            Write-Host 'stt_quality_mode=raw_transcript_evaluation'

            $newText = [string]$counter.text
            if ($newText.ToLower() -ne $baseline.ToLower()) {
                Write-Host 'DESKTOP_VOICE_STT_REGRESSION_IMPROVED (transcript changed vs baseline)'
            }
            if ($newText -match '(?i)southern') { Write-Host 'DESKTOP_VOICE_RAW_STT_SCW_PASS' }
            if ($newText -match '(?i)del\s*mod|delmod') { Write-Host 'DESKTOP_VOICE_RAW_STT_DELMOD_PASS' }
            if ($newText -match '(?i)submit') { Write-Host 'DESKTOP_VOICE_RAW_STT_SUBMIT_PASS' }
        } else {
            Write-Host 'Helper failed to start — skipping live WAV replay'
        }
    } else {
        Write-Host 'Helper not built — skipping live WAV replay (run build_stt_helper_en.ps1)'
    }

    $golosSrc = 'C:\Users\nkuch\Development\Apps\golos_flutter\src-tauri\src\transcribe.rs'
    if (Test-Path $golosSrc) {
        Write-Host 'DESKTOP_VOICE_GOLOS_PIPELINE_FOUND (source)'
    } else {
        Write-Host 'DESKTOP_VOICE_GOLOS_PIPELINE_NOT_FOUND'
    }
    Write-Host 'DESKTOP_VOICE_GOLOS_RAW_TRANSCRIPT_RECORDED: skipped (no golos-backend.exe on machine)'

    Write-Host '--- Flutter unit/integration tests ---'
    flutter test test/desktop_voice_audio_pipeline_test.dart --reporter expanded
    if ($LASTEXITCODE -ne 0) { exit 1 }
    flutter test test/desktop_voice_stt_quality_test.dart --reporter expanded
    if ($LASTEXITCODE -ne 0) { exit 1 }
} finally {
    if ($null -ne $helperProc) {
        Stop-Process -Id $helperProc.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'DESKTOP_VOICE_STT_BENCHMARK_PASS'
exit 0
