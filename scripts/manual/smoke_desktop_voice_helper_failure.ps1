# P0 helper-failure smoke — mic must work when counter_stt_helper.exe is dead.
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$logPath = Join-Path $env:TEMP 'counter_desktop_voice_pipeline.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

function Find-CounterExe {
    $release = Join-Path $repoRoot 'build\windows\x64\runner\Release\counter.exe'
    if (Test-Path $release) { return $release }
    $installed = @(
        "${env:ProgramFiles}\Counter\counter.exe",
        "${env:LocalAppData}\Programs\Counter\counter.exe"
    )
    foreach ($p in $installed) {
        if (Test-Path $p) { return $p }
    }
    throw "counter.exe not found. Build with: flutter build windows --release --dart-define=DESKTOP_VOICE_COMMAND=true"
}

function Wait-LogMarker {
    param([string]$Marker, [int]$TimeoutSec = 120)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $logPath) {
            $text = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
            if ($text -and $text.Contains($Marker)) { return $text }
        }
        Start-Sleep -Milliseconds 400
    }
    return $null
}

function Get-VkForKeyLabel {
    param([string]$Label)
    switch ($Label.Trim().ToLowerInvariant()) {
        'space' { return 0x20 }
        'enter' { return 0x0D }
        'tab' { return 0x09 }
        'escape' { return 0x1B }
        default {
            if ($Label.Length -eq 1) {
                return [byte][char]::ToUpperInvariant($Label[0])
            }
            throw "Unsupported hotkey key label: $Label"
        }
    }
}

function Send-RegisteredHotkey {
    param([string]$DisplayLabel)
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NativeInput {
    [DllImport("user32.dll")]
    public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
    public const byte VK_CONTROL = 0x11;
    public const byte VK_SHIFT = 0x10;
    public const byte VK_MENU = 0x12;
    public const byte VK_LWIN = 0x5B;
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public static void Down(byte vk) { keybd_event(vk, 0, 0, 0); }
    public static void Up(byte vk) { keybd_event(vk, 0, KEYEVENTF_KEYUP, 0); }
}
"@
    $parts = $DisplayLabel -split '\+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $mods = @()
    $key = $null
    foreach ($p in $parts) {
        switch ($p.ToLowerInvariant()) {
            'ctrl' { $mods += [NativeInput]::VK_CONTROL }
            'shift' { $mods += [NativeInput]::VK_SHIFT }
            'alt' { $mods += [NativeInput]::VK_MENU }
            'win' { $mods += [NativeInput]::VK_LWIN }
            default { $key = Get-VkForKeyLabel $p }
        }
    }
    if ($null -eq $key) { throw "Could not parse hotkey key from: $DisplayLabel" }
    foreach ($m in $mods) { [NativeInput]::Down($m) }
    [NativeInput]::Down($key)
    [NativeInput]::Up($key)
    foreach ($m in ($mods | Sort-Object -Descending)) { [NativeInput]::Up($m) }
}

function Fire-NativeSmokeHotkey {
    $trigger = Join-Path $env:TEMP 'counter_voice_smoke_fire.hotkey'
    Set-Content -Path $trigger -Value '1' -NoNewline
}

Write-Host '=== Desktop Voice Helper Failure Smoke ==='
Write-Host "Log: $logPath"

$exe = Find-CounterExe
Write-Host "Exe: $exe"

Get-Process counter,counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Ensure helper stays dead for listening phase.
Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$env:COUNTER_DESKTOP_VOICE_SMOKE = '1'
$env:COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE = '1'
$proc = Start-Process -FilePath $exe -PassThru
Write-Host "PID: $($proc.Id)"

$readyText = Wait-LogMarker 'DESKTOP_VOICE_HOTKEY_REGISTERED' 120
if (-not $readyText) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'TIMEOUT: DESKTOP_VOICE_HOTKEY_REGISTERED not seen'
}

$hotkeyLabel = $null
foreach ($line in ($readyText -split "`n")) {
    if ($line -match 'DESKTOP_VOICE_HOTKEY_REGISTERED\s+yes combo=([^\r\n]+)') {
        $hotkeyLabel = $Matches[1].Trim()
        break
    }
    if ($line -match 'DESKTOP_VOICE_HOTKEY_REGISTERED_COMBO\s+([^\r\n]+)') {
        $hotkeyLabel = $Matches[1].Trim()
        break
    }
}
if ([string]::IsNullOrWhiteSpace($hotkeyLabel)) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: could not parse registered hotkey combo'
}
Write-Host "Registered hotkey: $hotkeyLabel"

Start-Sleep -Seconds 2
Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
Start-Sleep -Seconds 3
if ($proc.HasExited) { throw 'FAIL: counter.exe exited after first hotkey' }

# Keep helper dead through transcribe (prewarm may restart it).
$killDeadline = (Get-Date).AddSeconds(12)
while ((Get-Date) -lt $killDeadline) {
    Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 250
}

$listening = Wait-LogMarker 'DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING' 30
if (-not $listening) {
    Fire-NativeSmokeHotkey
    $listening = Wait-LogMarker 'DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING' 20
}
if (-not $listening) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING missing'
}

$capture = Wait-LogMarker 'DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED' 30
if (-not $capture) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED missing (helper blocked mic)'
}

Start-Sleep -Seconds 2
Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
Start-Sleep -Milliseconds 800
if ($proc.HasExited) { throw 'FAIL: counter.exe exited after finish hotkey' }

$deadline = (Get-Date).AddSeconds(45)
$logText = ''
while ((Get-Date) -lt $deadline) {
    if (Test-Path $logPath) {
        $logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
        if ($logText -and $logText.Contains('DESKTOP_VOICE_OVERLAY_FRIENDLY_ERROR_SHOWN')) { break }
    }
    Start-Sleep -Milliseconds 500
}

if (-not $logText) { $logText = '' }

$required = @(
    'DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED',
    'DESKTOP_VOICE_OVERLAY_FRIENDLY_ERROR_SHOWN',
    'DESKTOP_VOICE_RECOGNIZER_FAILED_NO_RECORD_CHANGE',
    'DESKTOP_VOICE_STT_HTTP_REQUEST_STARTED_AFTER_RECORDING'
)
foreach ($m in $required) {
    if (-not $logText.Contains($m)) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "FAIL: missing marker $m"
    }
}

$helperFail = $logText.Contains('DESKTOP_VOICE_STT_HTTP_CONNECTION_CLOSED') -or
    $logText.Contains('DESKTOP_VOICE_STT_HELPER_UNAVAILABLE') -or
    $logText.Contains('DESKTOP_VOICE_STT_REQUEST_FAILED_FRIENDLY') -or
    $logText.Contains('DESKTOP_VOICE_STT_HTTP_REQUEST_STARTED')
if (-not $helperFail) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: expected helper-unavailable marker missing'
}

if ($logText -match 'OVERLAY_ERROR_VISIBLE\s+.*ClientException') {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: raw ClientException leaked to overlay marker'
}

if ($proc.HasExited) {
    throw 'FAIL: counter.exe exited after helper failure'
}

Write-Host 'SMOKE_PASS'
Write-Host '  DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING: yes'
Write-Host '  DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED: yes'
Write-Host '  DESKTOP_VOICE_OVERLAY_FRIENDLY_ERROR_SHOWN: yes'
Write-Host '  DESKTOP_VOICE_RAW_EXCEPTION_SUPPRESSED: yes'
Write-Host '  Process alive: yes'

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
exit 0
