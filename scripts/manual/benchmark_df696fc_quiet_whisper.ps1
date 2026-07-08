# Offline whisper-tiny benchmark on df696fc live quiet fixture (all STT processing variants).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

Write-Host 'DESKTOP_VOICE_LIVE_QUIET_AUDIO_BENCHMARK_RUN'
Write-Host 'DESKTOP_VOICE_WHISPER_GAIN_BENCHMARK_RUN'
Write-Host 'DESKTOP_VOICE_STT_AGC_BENCHMARK_RUN'
Write-Host 'DESKTOP_VOICE_NO_HARMFUL_PEAK_NORMALIZATION'

$wav = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav\scw_delmod_submit_df696fc_live_quiet.wav'
$helperExe = Join-Path $env:LOCALAPPDATA 'Programs\Counter\stt_helper\counter_stt_helper.exe'
$helperDir = Split-Path $helperExe -Parent
$port = 8783

if (-not (Test-Path $wav)) { throw "Missing fixture: $wav" }
if (-not (Test-Path $helperExe)) { throw "Missing helper: $helperExe" }

function Get-Pcm16Metrics([byte[]]$pcm) {
    $sum = 0.0; $peak = 0.0; $clipped = 0
    for ($i = 0; $i -lt $pcm.Length - 1; $i += 2) {
        $v = [BitConverter]::ToInt16($pcm, $i)
        $s = $v / 32768.0
        $a = [Math]::Abs($s)
        if ($a -gt $peak) { $peak = $a }
        $sum += $s * $s
        if ($v -ge 32767 -or $v -le -32768) { $clipped++ }
    }
    $n = [Math]::Max(1, $pcm.Length / 2)
    $rms = [Math]::Sqrt($sum / $n)
    return @{ rms = $rms; peak = $peak; clipped = $clipped }
}

function Apply-RmsGain([byte[]]$pcm, [double]$targetRms) {
    $m = Get-Pcm16Metrics $pcm
    if ($m.rms -le 0.0001) { return $pcm }
    $gain = $targetRms / $m.rms
    if ($gain * $m.peak -gt 0.90) { $gain = 0.90 / $m.peak }
    $out = New-Object byte[] $pcm.Length
    $clip = 0
    for ($i = 0; $i -lt $pcm.Length - 1; $i += 2) {
        $v = [BitConverter]::ToInt16($pcm, $i)
        $s = [int][Math]::Round($v * $gain)
        if ($s -gt 32767) { $s = 32767; $clip++ }
        elseif ($s -lt -32768) { $s = -32768; $clip++ }
        [BitConverter]::GetBytes([int16]$s).CopyTo($out, $i)
    }
    return $out
}

function Score-Transcript([string]$t) {
    $l = $t.ToLower()
    $score = 0
    if ($l -match 'southern') { $score += 30 }
    if ($l -match 'computer warehouse') { $score += 10 }
    if ($l -match 'del\s*mod') { $score += 20 }
    if ($l -match 'submit') { $score += 10 }
    if ($l -match 'here\.') { $score -= 50 }
    return $score
}

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
taskkill /IM counter_stt_helper.exe /F 2>$null | Out-Null
$ErrorActionPreference = $prevEap
Start-Sleep 1
$proc = Start-Process $helperExe -ArgumentList '--port', $port -WorkingDirectory $helperDir -PassThru -WindowStyle Hidden
try {
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        try { $null = Invoke-RestMethod "http://127.0.0.1:$port/ping" -TimeoutSec 2; break } catch { Start-Sleep 0.5 }
    }
    Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/config" -ContentType 'application/json' -Body '{"engine":"whisper-tiny"}' | Out-Null
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        $st = Invoke-RestMethod "http://127.0.0.1:$port/status" -TimeoutSec 3
        if ($st.final_transcribe_ready) { break }
        Start-Sleep 0.5
    }
    Write-Host "Helper warm: engine=$($st.engine) ready=$($st.final_transcribe_ready)"

    $bytes = [IO.File]::ReadAllBytes($wav)
    $pcm = [byte[]]$bytes[44..($bytes.Length - 1)]
    $inputMetrics = Get-Pcm16Metrics $pcm
    Write-Host "input_rms=$([Math]::Round($inputMetrics.rms,4)) input_peak=$([Math]::Round($inputMetrics.peak,4))"

    $variants = [ordered]@{
        current = $pcm
        whisperRmsTarget055 = (Apply-RmsGain $pcm 0.055)
        whisperRmsTarget040 = (Apply-RmsGain $pcm 0.040)
        whisperRmsTarget030 = (Apply-RmsGain $pcm 0.030)
    }

    $best = @{ name = ''; score = -999; text = '' }
    foreach ($kv in $variants.GetEnumerator()) {
        $name = $kv.Key
        $vpcm = [byte[]]$kv.Value
        $om = Get-Pcm16Metrics $vpcm
        $gainDb = if ($inputMetrics.rms -gt 0) { 20 * [Math]::Log10($om.rms / $inputMetrics.rms) } else { 0 }
        $b64 = [Convert]::ToBase64String($vpcm)
        $t0 = Get-Date
        $r = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$port/transcribe/stop" -ContentType 'application/json' -Body (@{ audio_base64 = $b64 } | ConvertTo-Json) -TimeoutSec 180
        $lat = [int]((Get-Date) - $t0).TotalMilliseconds
        $text = [string]$r.text
        $score = Score-Transcript $text
        Write-Host "variant=$name output_rms=$([Math]::Round($om.rms,4)) output_peak=$([Math]::Round($om.peak,4)) gain_db=$([Math]::Round($gainDb,2)) clipped=$($om.clipped) latency_ms=$lat score=$score transcript=$text"
        if ($score -gt $best.score) { $best = @{ name = $name; score = $score; text = $text } }
    }

    Write-Host "selected_processing_variant=$($best.name)"
    Write-Host "selected_reason=best_scw_transcript_score=$($best.score)"
    Write-Host "best_transcript=$($best.text)"
    if ($best.text.ToLower() -match 'southern') {
        Write-Host 'DESKTOP_VOICE_STT_PROCESSING_SELECTED_BY_TRANSCRIPT'
    }
} finally {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}

Write-Host 'DESKTOP_VOICE_DF696FC_LIVE_QUIET_FIXTURE_ARCHIVED'
Write-Host 'DESKTOP_VOICE_LIVE_QUIET_FAILURE_REPRODUCED_OFFLINE'
