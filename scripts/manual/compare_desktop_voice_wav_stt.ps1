# Same-WAV STT parity — Counter helper vs GOLOS-equivalent replay runner.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$wav = Join-Path $repoRoot 'test\fixtures\desktop_voice_wav\scw_delmod_submit_real_2026_07_07.wav'
$replayExe = Join-Path $repoRoot 'installer\windows\wav_stt_replay\target\release\wav_stt_replay.exe'
$freshHelper = Join-Path $repoRoot 'installer\windows\stt_helper_build\counter_stt_helper.exe'
$modelDir = 'C:\Users\nkuch\Development\Apps\golos_flutter\Release\models\parakeet'
$benchPort = 8766

if (-not (Test-Path $wav)) { throw "Missing WAV: $wav" }

Write-Host 'DESKTOP_VOICE_GOLOS_EQUIVALENT_SAME_WAV_RUNNER_READY'

if (-not (Test-Path $replayExe)) {
    Write-Host 'Building wav_stt_replay...'
    Push-Location (Join-Path $repoRoot 'installer\windows\wav_stt_replay')
    cargo build --release
    Pop-Location
}

Write-Host '=== GOLOS-equivalent pipelines (direct Parakeet, no glossary) ==='
$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$golosOut = & $replayExe --wav $wav --model-dir $modelDir 2>&1
$ErrorActionPreference = $prevEap
$golosOut | ForEach-Object { Write-Host $_ }

function Start-Helper {
    param([string]$Exe, [int]$Port)
    $proc = Start-Process -FilePath $Exe -ArgumentList @('--port', "$Port") `
        -WorkingDirectory (Split-Path $Exe -Parent) -PassThru -WindowStyle Hidden
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        try { $null = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/ping" -TimeoutSec 2; return $proc } catch {}
        Start-Sleep -Milliseconds 400
    }
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    return $null
}

$helperProc = $null
try {
    if (Test-Path $freshHelper) {
        $benchDir = Join-Path $env:TEMP 'counter_stt_wav_bench'
        New-Item -ItemType Directory -Force -Path $benchDir | Out-Null
        Copy-Item -Force $freshHelper (Join-Path $benchDir 'counter_stt_helper.exe')
        $benchModels = Join-Path $benchDir 'models'
        if (Test-Path $benchModels) { cmd /c "rmdir `"$benchModels`"" 2>$null }
        cmd /c mklink /J "$benchModels" (Split-Path $modelDir -Parent) | Out-Null
        $helperExe = Join-Path $benchDir 'counter_stt_helper.exe'
        Write-Host '=== Counter HTTP helper (current build) ==='
        $helperProc = Start-Helper -Exe $helperExe -Port $benchPort
        if ($null -ne $helperProc) {
            Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$benchPort/config" `
                -ContentType 'application/json' -Body '{"engine":"parakeet"}' | Out-Null
            $deadline = (Get-Date).AddSeconds(120)
            while ((Get-Date) -lt $deadline) {
                $st = Invoke-RestMethod -Uri "http://127.0.0.1:$benchPort/status" -TimeoutSec 3
                if ($st.final_transcribe_ready -eq $true) { break }
                Start-Sleep -Milliseconds 400
            }
            $bytes = [IO.File]::ReadAllBytes($wav)
            $pcm = $bytes[44..($bytes.Length - 1)]
            $b64 = [Convert]::ToBase64String([byte[]]$pcm)
            $resp = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$benchPort/transcribe/stop" `
                -ContentType 'application/json' -Body (@{ audio_base64 = $b64 } | ConvertTo-Json) -TimeoutSec 120
            Write-Host "DESKTOP_VOICE_COUNTER_RAW_TRANSCRIPT_RECORDED: $($resp.text)"
        }
    }
} finally {
    if ($null -ne $helperProc) {
        Stop-Process -Id $helperProc.Id -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'DESKTOP_VOICE_SAME_WAV_COMPARISON_COMPLETE'
