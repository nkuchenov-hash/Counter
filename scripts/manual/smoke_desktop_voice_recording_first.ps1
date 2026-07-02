# Recording-first smoke — helper killed, first visible state must be Listening.
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$logPath = Join-Path $env:TEMP 'counter_desktop_voice_pipeline.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

$ruForbidden = [System.Text.Encoding]::UTF8.GetString(
    [byte[]](0xD0,0x9F,0xD0,0xBE,0xD0,0xB4,0xD0,0xB3,0xD0,0xBE,0xD1,0x82,0xD0,0xBE,0xD0,0xB2,0xD0,0xBA,0xD0,0xB0,0x20,0xD1,0x80,0xD0,0xB0,0xD1,0x81,0xD0,0xBF,0xD0,0xBE,0xD0,0xB7,0xD0,0xBD,0xD0,0xB0,0xD0,0xB2,0xD0,0xB0,0xD0,0xBD,0xD0,0xB8,0xD1,0x8F)
)

function Find-CounterExe {
    $release = Join-Path $repoRoot 'build\windows\x64\runner\Release\counter.exe'
    if (Test-Path $release) { return $release }
    throw "counter.exe not found. Build release first."
}

function Wait-LogMarker {
    param([string]$Marker, [int]$TimeoutSec = 90)
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
        default {
            if ($Label.Length -eq 1) {
                return [byte][char]::ToUpperInvariant($Label[0])
            }
            throw "Unsupported hotkey key: $Label"
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
    public const uint KEYEVENTF_KEYUP = 0x0002;
    public static void Down(byte vk) { keybd_event(vk, 0, 0, 0); }
    public static void Up(byte vk) { keybd_event(vk, 0, KEYEVENTF_KEYUP, 0); }
}
"@
    $parts = $DisplayLabel -split '\+' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $mods = @(); $key = $null
    foreach ($p in $parts) {
        switch ($p.ToLowerInvariant()) {
            'ctrl' { $mods += [NativeInput]::VK_CONTROL }
            'shift' { $mods += [NativeInput]::VK_SHIFT }
            default { $key = Get-VkForKeyLabel $p }
        }
    }
    foreach ($m in $mods) { [NativeInput]::Down($m) }
    [NativeInput]::Down($key); [NativeInput]::Up($key)
    foreach ($m in ($mods | Sort-Object -Descending)) { [NativeInput]::Up($m) }
}

Write-Host '=== Desktop Voice Recording-First Smoke ==='
$exe = Find-CounterExe
Get-Process counter,counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$env:COUNTER_DESKTOP_VOICE_SMOKE = '1'
$env:COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE = '1'
$proc = Start-Process -FilePath $exe -PassThru

$ready = Wait-LogMarker 'DESKTOP_VOICE_HOTKEY_REGISTERED' 120
if (-not $ready) { Stop-Process -Id $proc.Id -Force; throw 'TIMEOUT: hotkey registration' }

$hotkeyLabel = $null
foreach ($line in ($ready -split "`n")) {
    if ($line -match 'yes combo=([^\r\n]+)') { $hotkeyLabel = $Matches[1].Trim(); break }
}
if (-not $hotkeyLabel) { Stop-Process -Id $proc.Id -Force; throw 'FAIL: no hotkey combo' }

Get-Process counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
Start-Sleep -Seconds 3

$logText = Wait-LogMarker 'DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED' 30
if (-not $logText) { $logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue }

$required = @(
    'DESKTOP_VOICE_HOTKEY_RECEIVED',
    'DESKTOP_VOICE_FIRST_VISIBLE_STATE_LISTENING',
    'DESKTOP_VOICE_LOCAL_AUDIO_CAPTURE_STARTED',
    'DESKTOP_VOICE_AUDIO_BUFFER_STARTED'
)
foreach ($m in $required) {
    if (-not $logText.Contains($m)) {
        Stop-Process -Id $proc.Id -Force
        throw "FAIL: missing $m"
    }
}

$forbidden = @(
    'DESKTOP_VOICE_PREPARING_STARTED',
    $ruForbidden,
    'Preparing recognition',
    'Preparing speech recognition'
)
foreach ($f in $forbidden) {
    if ($logText.Contains($f)) {
        Stop-Process -Id $proc.Id -Force
        throw "FAIL: forbidden marker/text present: $f"
    }
}

Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
Start-Sleep -Seconds 2
if ($proc.HasExited) { throw 'FAIL: app exited' }

Write-Host 'RECORDING_FIRST_SMOKE_PASS'
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
exit 0
