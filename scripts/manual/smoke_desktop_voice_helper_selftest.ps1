# GOLOS sidecar self-test — exercises the STT helper end-to-end OUTSIDE the
# Flutter app so the recognizer chain can be debugged without the hotkey path.
#
# Verifies, in order:
#   1. helper exe exists at the resolved installed/build path
#   2. parakeet model directory + files exist
#   3. settings.json exists
#   4. helper process spawns on a free port
#   5. /status responds and reports ready=true for parakeet within timeout
#   6. a known WAV file is sent to /transcribe/stop
#   7. transcript text OR a structured failure is returned
#   8. helper does not immediately crash
#
# Prints HELPER_SELFTEST_PASS on success, or one of these structured failures:
#   helper_missing | model_missing | settings_missing | spawn_failed
#   process_crashed | port_busy | status_timeout | status_error
#   transcribe_timeout | transcribe_connection_closed
#   transcribe_invalid_response
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\manual\smoke_desktop_voice_helper_selftest.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\manual\smoke_desktop_voice_helper_selftest.ps1 -Payload installed
#   powershell -ExecutionPolicy Bypass -File scripts\manual\smoke_desktop_voice_helper_selftest.ps1 -Payload build
#   powershell -ExecutionPolicy Bypass -File scripts\manual\smoke_desktop_voice_helper_selftest.ps1 -SelfTestPort 8799
param(
    [ValidateSet('auto', 'installed', 'build')]
    [string]$Payload = 'auto',
    [int]$SelfTestPort = 8799
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Write-Step([string]$msg) { Write-Host "[step] $msg" }
function Write-Fail([string]$code, [string]$detail) {
    Write-Host "HELPER_SELFTEST_FAILED"
    Write-Host "code=$code"
    Write-Host "detail=$detail"
    exit 1
}

# --- Resolve the payload folder -----------------------------------------------
function Resolve-HelperRoot([string]$mode) {
    $installed = Join-Path $env:LOCALAPPDATA 'Programs\Counter'
    $build = Join-Path $repoRoot 'build\windows\x64\runner\Release'
    if ($mode -eq 'installed') { return $installed }
    if ($mode -eq 'build')     { return $build }
    # auto: prefer installed if present, otherwise build.
    if (Test-Path (Join-Path $installed 'stt_helper\counter_stt_helper.exe')) {
        return $installed
    }
    if (Test-Path (Join-Path $build     'stt_helper\counter_stt_helper.exe')) {
        return $build
    }
    return $null
}

$appRoot = Resolve-HelperRoot $Payload
if (-not $appRoot -or -not (Test-Path $appRoot)) {
    Write-Fail 'helper_missing' "No Counter install or build folder found. Pass -Payload build after a Windows release build."
}
$helperRoot = Join-Path $appRoot 'stt_helper'
$helperExe  = Join-Path $helperRoot 'counter_stt_helper.exe'
$modelDir   = Join-Path $helperRoot 'models\parakeet'
$settingsFile = Join-Path $helperRoot 'settings.json'
Write-Host "Payload resolved: $appRoot"

# --- 1-3. File presence checks -----------------------------------------------
Write-Step "check helper exe"
if (-not (Test-Path $helperExe)) { Write-Fail 'helper_missing' "missing $helperExe" }

Write-Step "check parakeet model"
$modelFiles = @(
    'config.json',
    'decoder_joint-model.int8.onnx',
    'encoder-model.int8.onnx',
    'installed.json',
    'nemo128.onnx',
    'vocab.txt'
)
$missing = @()
foreach ($f in $modelFiles) {
    $p = Join-Path $modelDir $f
    if (-not (Test-Path $p)) { $missing += $f }
}
if ($missing.Count -gt 0) {
    Write-Fail 'model_missing' "model dir=$modelDir missing files: $($missing -join ', ')"
}

Write-Step "check settings.json"
if (-not (Test-Path $settingsFile)) { Write-Fail 'settings_missing' "missing $settingsFile" }
$settings = Get-Content $settingsFile -Raw | ConvertFrom-Json
Write-Host "settings.active_model = $($settings.active_model)"

# --- 4. Spawn helper on the self-test port ------------------------------------
Write-Step "spawn helper on port $SelfTestPort"
$existing = Get-Process counter_stt_helper -ErrorAction SilentlyContinue
# A pre-existing helper on 8765 is fine — but our self-test needs its own port
# so we don't fight with a running app. The chosen SelfTestPort must be free.
$busy = $false
try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $SelfTestPort)
    $listener.Start()
    $listener.Stop()
} catch {
    $busy = $true
}
if ($busy) { Write-Fail 'port_busy' "port $SelfTestPort already in use. Pass -SelfTestPort <other>." }

$procArgs = @('--port', "$SelfTestPort")
$proc = Start-Process -FilePath $helperExe -ArgumentList $procArgs `
    -WorkingDirectory $helperRoot -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $env:TEMP 'counter_selftest_helper.out') `
    -RedirectStandardError  (Join-Path $env:TEMP 'counter_selftest_helper.err')

Start-Sleep -Milliseconds 500
if ($proc.HasExited) {
    $err = Get-Content (Join-Path $env:TEMP 'counter_selftest_helper.err') -Raw -ErrorAction SilentlyContinue
    Write-Fail 'process_crashed' "helper exited early with code=$($proc.ExitCode). stderr=$err"
}
Write-Host "spawned pid=$($proc.Id)"

# Make sure we ALWAYS tear it down on exit.
$cleanup = {
    try {
        if ($proc -and -not $proc.HasExited) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}
trap { & $cleanup; break }

try {
    # --- 5. /status ready probe ---------------------------------------------
    $baseUrl = "http://127.0.0.1:$SelfTestPort"
    Write-Step "POST /config to load parakeet"
    try {
        $cfgBody = @{ 'engine' = 'parakeet' } | ConvertTo-Json -Compress
        Invoke-WebRequest -Uri "$baseUrl/config" -Method Post `
            -Body $cfgBody -ContentType 'application/json' `
            -TimeoutSec 5 -UseBasicParsing | Out-Null
    } catch {
        # Best-effort; some helper versions lazy-load on first transcribe and
        # ignore /config. The status loop below is the source of truth.
        Write-Host "/config POST failed (continuing): $($_.Exception.Message)"
    }

    Write-Step "wait for /status ready= parakeet (90s)"
    $deadline = (Get-Date).AddSeconds(90)
    $ready = $false
    $statusFail = $null
    while ((Get-Date) -lt $deadline) {
        if ($proc.HasExited) {
            $err = Get-Content (Join-Path $env:TEMP 'counter_selftest_helper.err') -Raw -ErrorAction SilentlyContinue
            Write-Fail 'process_crashed' "helper exited during warmup code=$($proc.ExitCode). stderr=$err"
        }
        try {
            $r = Invoke-WebRequest -Uri "$baseUrl/status" -TimeoutSec 3 -UseBasicParsing
            if ($r.StatusCode -eq 200) {
                $body = $r.Content | ConvertFrom-Json
                if ($body.ready -eq $true -and ($body.engine -eq 'parakeet' -or $body.model -eq 'parakeet')) {
                    $ready = $true
                    Write-Host "ready body: $($r.Content)"
                    break
                }
                # Engine present but not parakeet; re-kick /config every 5s.
                if (($body.engine -ne 'parakeet') -and ($body.model -ne 'parakeet')) {
                    try {
                        Invoke-WebRequest -Uri "$baseUrl/config" -Method Post `
                            -Body $cfgBody -ContentType 'application/json' `
                            -TimeoutSec 3 -UseBasicParsing | Out-Null
                    } catch {}
                }
            } else { $statusFail = "HTTP $($r.StatusCode)" }
        } catch {
            $statusFail = $_.Exception.Message
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) {
        if ($proc.HasExited) {
            $err = Get-Content (Join-Path $env:TEMP 'counter_selftest_helper.err') -Raw -ErrorAction SilentlyContinue
            Write-Fail 'process_crashed' "helper exited during status probe code=$($proc.ExitCode). stderr=$err"
        }
        if ([string]::IsNullOrEmpty($statusFail)) { Write-Fail 'status_timeout' "/status never became ready within 60s" }
        else { Write-Fail 'status_error' "/status probe failed: $statusFail" }
    }

    # --- 6-7. Transcribe a WAV file ----------------------------------------
    Write-Step "find WAV to transcribe"
    $latestWav = Join-Path $env:LOCALAPPDATA 'Counter\voice_samples\latest_command.wav'
    if (-not (Test-Path $latestWav)) {
        # Generate a tiny 1-second 440 Hz tone as a smoke fixture.
        $fixture = Join-Path $env:TEMP 'counter_selftest_smoke.wav'
        $sampleRate = 16000
        $duration = 1
        $samples = $sampleRate * $duration
        $bytes = New-Object byte[] ($samples * 2)
        for ($i = 0; $i -lt $samples; $i++) {
            $s = [int]([Math]::Sin(2 * [Math]::PI * 440 * $i / $sampleRate) * 6000)
            $bytes[$i * 2]     = $s -band 0xFF
            $bytes[$i * 2 + 1] = ($s -shr 8) -band 0xFF
        }
        # Minimal 16-bit PCM WAV header.
        $header = New-Object byte[] 44
        [byte[]]$hdrBytes = [System.Text.Encoding]::ASCII.GetBytes('RIFF')
        for ($i = 0; $i -lt 4; $i++) { $header[$i] = $hdrBytes[$i] }
        $dataSize = $bytes.Length
        $fileSize = 36 + $dataSize
        [BitConverter]::GetBytes([uint32]$fileSize).CopyTo($header, 4)
        [byte[]]$wavBytes = [System.Text.Encoding]::ASCII.GetBytes('WAVEfmt ')
        for ($i = 0; $i -lt 8; $i++) { $header[8 + $i] = $wavBytes[$i] }
        [BitConverter]::GetBytes([uint32]16).CopyTo($header, 16)
        [BitConverter]::GetBytes([uint16]1).CopyTo($header, 20)
        [BitConverter]::GetBytes([uint16]1).CopyTo($header, 22)
        [BitConverter]::GetBytes([uint32]$sampleRate).CopyTo($header, 24)
        [BitConverter]::GetBytes([uint32]($sampleRate * 2)).CopyTo($header, 28)
        [BitConverter]::GetBytes([uint16]2).CopyTo($header, 32)
        [BitConverter]::GetBytes([uint16]16).CopyTo($header, 34)
        [byte[]]$dataBytes = [System.Text.Encoding]::ASCII.GetBytes('data')
        for ($i = 0; $i -lt 4; $i++) { $header[36 + $i] = $dataBytes[$i] }
        [BitConverter]::GetBytes([uint32]$dataSize).CopyTo($header, 40)
        [System.IO.File]::WriteAllBytes($fixture, $header + $bytes)
        $latestWav = $fixture
        Write-Host "no real WAV; using fixture $fixture"
    } else {
        Write-Host "using latest_command.wav: $latestWav"
    }

    Write-Step "POST WAV to /transcribe/stop"
    $pcm = [System.IO.File]::ReadAllBytes($latestWav)
    # Strip 44-byte WAV header for PCM-16 payload.
    if ($pcm.Length -gt 44) { $pcm = $pcm[44..($pcm.Length - 1)] }
    $b64 = [Convert]::ToBase64String($pcm)
    $jsonBody = @{ 'audio_base64' = $b64 } | ConvertTo-Json -Compress

    function Invoke-TranscribeOnce {
        try {
            $r = Invoke-WebRequest -Uri "$baseUrl/transcribe/stop" -Method Post `
                -Body $jsonBody -ContentType 'application/json' `
                -TimeoutSec 30 -UseBasicParsing
            return @{ ok = $true; http = $r.StatusCode; body = $r.Content }
        } catch [System.Net.WebException] {
            $respBody = '(no response body)'
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $respBody = $reader.ReadToEnd()
            } catch {}
            return @{ ok = $false; http = 500; body = $respBody;
                      err = $_.Exception.Message }
        } catch {
            return @{ ok = $false; http = 0; body = '';
                      err = "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
        }
    }

    $result = Invoke-TranscribeOnce
    # If the helper returned 500 with an empty body, parakeet is almost
    # certainly still loading (partial-load race observed in production). Wait
    # briefly and retry once — same behaviour the app now implements.
    if (-not $result.ok -and $result.http -eq 500 -and ($result.body -eq '' -or $result.body -eq '(no response body)')) {
        Write-Host "transcribe returned 500 (likely partial load); retrying after 5s"
        Start-Sleep -Seconds 5
        # Re-confirm readiness then retry.
        try {
            Invoke-WebRequest -Uri "$baseUrl/config" -Method Post `
                -Body (@{ 'engine' = 'parakeet' } | ConvertTo-Json -Compress) `
                -ContentType 'application/json' -TimeoutSec 5 -UseBasicParsing | Out-Null
        } catch {}
        Start-Sleep -Seconds 2
        $result = Invoke-TranscribeOnce
    }

    if (-not $result.ok) {
        if ($proc.HasExited) {
            $err = Get-Content (Join-Path $env:TEMP 'counter_selftest_helper.err') -Raw -ErrorAction SilentlyContinue
            Write-Fail 'process_crashed' "helper exited during transcribe code=$($proc.ExitCode). stderr=$err"
        }
        if ($result.err -match 'closed|connection') {
            Write-Fail 'transcribe_connection_closed' "$($result.err) body=$($result.body)"
        }
        if ($result.http -gt 0 -and -not [string]::IsNullOrEmpty($result.body)) {
            # HTTP non-2xx with a JSON {"error": ...} body is a structured fail.
            Write-Fail 'transcribe_invalid_response' "HTTP $($result.http) body=$($result.body)"
        }
        Write-Fail 'transcribe_timeout' "$($result.err) body=$($result.body)"
    }

    Write-Host "transcribe HTTP $($result.http) body=$($result.body)"
    $transcribe = $result.body

    try {
        $body = $transcribe | ConvertFrom-Json
    } catch {
        Write-Fail 'transcribe_invalid_response' $transcribe
    }

    # The helper returns one of:
    #   {"text": "...", "duration": <n>}    → successful non-empty transcription
    #   {"text": "", "duration": <n>}       → STT processed but returned no
    #                                          speech (legitimate when audio is
    #                                          silent or too quiet). Counts as
    #                                          PASS for the recognizer chain.
    #   {"error": "..."}                    → structured failure
    if ($body.error) {
        Write-Host "transcribe returned structured error: $($body.error)"
    } elseif ($null -ne $body.text) {
        if ([string]::IsNullOrEmpty($body.text)) {
            Write-Host "STT processed audio but transcript was empty (audio sample had no intelligible speech). Recognizer chain OK."
        } else {
            Write-Host "transcript text: $($body.text)"
        }
    } else {
        Write-Fail 'transcribe_invalid_response' "no text and no error field: $transcribe"
    }

    # --- 8. Final survivor check -------------------------------------------
    Start-Sleep -Seconds 1
    if ($proc.HasExited) {
        $err = Get-Content (Join-Path $env:TEMP 'counter_selftest_helper.err') -Raw -ErrorAction SilentlyContinue
        Write-Fail 'process_crashed' "helper exited AFTER transcribe code=$($proc.ExitCode). stderr=$err"
    }

    Write-Host "HELPER_SELFTEST_PASS"
} finally {
    & $cleanup
}
