# P0 tray-hidden native overlay smoke test (Windows).
# Hides Counter to tray, synthesizes hotkey, requires native overlay marker.
# Optional: -PrepareTimeoutSmoke uses build with DESKTOP_VOICE_FORCE_PREPARE_TIMEOUT=true

param(
    [switch]$PrepareTimeoutSmoke,
    [switch]$CommandFirstSmoke
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

$logPath = Join-Path $env:TEMP 'counter_desktop_voice_pipeline.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

function Find-CounterExe {
    if ($PrepareTimeoutSmoke) {
        $timeoutBuild = Join-Path $repoRoot 'build\windows\x64\runner\Release\counter.exe'
        if (Test-Path $timeoutBuild) { return $timeoutBuild }
    }
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
    param(
        [string]$Marker,
        [int]$TimeoutSec = 90
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $logPath) {
            $text = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
            if ($text -and $text.Contains($Marker)) { return $text }
        }
        Start-Sleep -Milliseconds 500
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

function Hide-CounterToTray {
    param([System.Diagnostics.Process]$Process)
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class WinTray {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    public const uint WM_CLOSE = 0x0010;
}
"@
    $deadline = (Get-Date).AddSeconds(20)
    while ((Get-Date) -lt $deadline) {
        $Process.Refresh()
        if ($Process.MainWindowHandle -ne [IntPtr]::Zero) {
            [void][WinTray]::PostMessage($Process.MainWindowHandle, [WinTray]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
            return
        }
        Start-Sleep -Milliseconds 300
    }
    Write-Host 'Main window handle not found — assuming launch-hidden tray mode'
}

Write-Host "=== Desktop Voice Hotkey Smoke (tray-hidden native overlay) ==="
if ($PrepareTimeoutSmoke) {
    Write-Host 'Mode: PrepareTimeoutSmoke (requires DESKTOP_VOICE_FORCE_PREPARE_TIMEOUT build)'
}
Write-Host "Log: $logPath"

$exe = Find-CounterExe
Write-Host "Exe: $exe"

Get-Process counter,counter_stt_helper -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$env:COUNTER_DESKTOP_VOICE_SMOKE = '1'
$env:COUNTER_DESKTOP_VOICE_SMOKE_FORCE_ENABLE = '1'
$proc = Start-Process -FilePath $exe -PassThru
Write-Host "PID: $($proc.Id)"

$readyText = Wait-LogMarker 'DESKTOP_VOICE_HOTKEY_REGISTERED' 120
if (-not $readyText) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'TIMEOUT: DESKTOP_VOICE_HOTKEY_REGISTERED not seen (enable Desktop Voice in settings)'
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
    if ($null -eq $hotkeyLabel -and $line -match 'DESKTOP_VOICE_HOTKEY_REGISTERED\s+(.+)$') {
        $candidate = $Matches[1].Trim()
        if ($candidate -notmatch '^yes combo=') {
            $hotkeyLabel = $candidate
        }
    }
}
if ([string]::IsNullOrWhiteSpace($hotkeyLabel)) {
    throw 'FAIL: could not parse registered hotkey combo from pipeline log'
}
Write-Host "Registered hotkey: $hotkeyLabel"

function Fire-NativeSmokeHotkey {
    $trigger = Join-Path $env:TEMP 'counter_voice_smoke_fire.hotkey'
    Set-Content -Path $trigger -Value '1' -NoNewline
}

$null = Wait-LogMarker 'DESKTOP_VOICE_APP_READY' 60
Start-Sleep -Seconds 2
Hide-CounterToTray -Process $proc
Start-Sleep -Seconds 2

for ($i = 1; $i -le 5; $i++) {
    Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
    Start-Sleep -Milliseconds 500
    if ($proc.HasExited) {
        throw "FAIL: counter.exe exited after tray-hidden hotkey press #$i"
    }
}
Start-Sleep -Seconds 2

$logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
if (-not ($logText -and $logText.Contains('DESKTOP_VOICE_HOTKEY_RECEIVED'))) {
    Write-Host 'SendInput missed — trying native smoke file hook'
    Fire-NativeSmokeHotkey
    Start-Sleep -Seconds 2
}

if ($proc.HasExited) {
    throw 'FAIL: counter.exe exited after tray-hidden hotkey stress'
}

if ($CommandFirstSmoke) {
    $inject = Join-Path $env:TEMP 'counter_voice_smoke_inject_running'
    Set-Content -Path $inject -Value '1' -NoNewline
    Start-Sleep -Seconds 1
    Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
    Start-Sleep -Seconds 2
    $cfLog = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    if ($cfLog -and $cfLog.Contains('DESKTOP_VOICE_HOTKEY_STOP_RUNNING')) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw 'FAIL: command-first violated — hotkey stopped running record'
    }
}

$logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
$received = $logText -and $logText.Contains('DESKTOP_VOICE_HOTKEY_RECEIVED')
$nativeTray = $logText -and $logText.Contains('DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN_WHILE_TRAY_HIDDEN')
$nativeShown = $logText -and $logText.Contains('DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN')
$notifOnly = $logText -and $logText.Contains('DESKTOP_VOICE_NOTIFICATION_FALLBACK_USED')
$resizeMarker = $logText -and ($logText.Contains('OVERLAY_HOST_CAPSULE') -or $logText.Contains('setAsFrameless'))

if (-not $received) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: DESKTOP_VOICE_HOTKEY_RECEIVED missing'
}

if ($notifOnly -and -not $nativeTray -and -not $nativeShown) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: notification-only fallback used; native tray overlay required'
}

if (-not $nativeTray) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN_WHILE_TRAY_HIDDEN missing'
}

if ($resizeMarker) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw 'FAIL: main-window capsule resize marker detected'
}

if ($PrepareTimeoutSmoke) {
    Start-Sleep -Seconds 6
    $logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    $prep = $logText -and $logText.Contains('DESKTOP_VOICE_PREPARING_STARTED')
    $timeout = $logText -and $logText.Contains('DESKTOP_VOICE_STT_WARMUP_TIMEOUT')
    $errVis = $logText -and $logText.Contains('DESKTOP_VOICE_OVERLAY_ERROR_VISIBLE')
    if (-not $prep -or -not $timeout -or -not $errVis) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "FAIL: prepare-timeout markers missing (prep=$prep timeout=$timeout err=$errVis)"
    }
    Send-RegisteredHotkey -DisplayLabel $hotkeyLabel
    Start-Sleep -Seconds 2
    $logText = Get-Content $logPath -Raw -ErrorAction SilentlyContinue
    $hidden = $logText -and $logText.Contains('DESKTOP_VOICE_OVERLAY_HIDDEN')
    $cancelPrep = $logText -and $logText.Contains('DESKTOP_VOICE_HOTKEY_CANCEL_PREPARING')
    if (-not $hidden) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw 'FAIL: DESKTOP_VOICE_OVERLAY_HIDDEN missing after cancel'
    }
    Write-Host '  DESKTOP_VOICE_PREPARING_STARTED: yes'
    Write-Host '  DESKTOP_VOICE_STT_WARMUP_TIMEOUT: yes'
    Write-Host '  DESKTOP_VOICE_OVERLAY_ERROR_VISIBLE: yes'
    Write-Host '  DESKTOP_VOICE_OVERLAY_HIDDEN after cancel: yes'
    if ($cancelPrep) { Write-Host '  DESKTOP_VOICE_HOTKEY_CANCEL_PREPARING: yes' }
}

Write-Host 'SMOKE_PASS'
Write-Host "  Hotkey sent: $hotkeyLabel (tray-hidden x5)"
Write-Host '  DESKTOP_VOICE_HOTKEY_RECEIVED: yes'
Write-Host '  DESKTOP_VOICE_NATIVE_OVERLAY_SHOWN_WHILE_TRAY_HIDDEN: yes'
Write-Host '  Process alive: yes'
if ($notifOnly) { Write-Host '  WARN: notification fallback also logged' }

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
exit 0
