# Create/update or inspect %USERPROFILE%\Desktop\Counter.lnk for installed Counter.
# Dot-source from install_desktop_voice_release.ps1 and smoke_desktop_voice_installed.ps1.

function Get-CounterInstalledPaths {
    $installDir = Join-Path $env:LOCALAPPDATA 'Programs\Counter'
    [PSCustomObject]@{
        InstallDir   = $installDir
        InstalledExe = Join-Path $installDir 'counter.exe'
        ShortcutPath = Join-Path $env:USERPROFILE 'Desktop\Counter.lnk'
    }
}

function Normalize-PathForCompare {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    try {
        return [System.IO.Path]::GetFullPath($Path).TrimEnd('\').ToLowerInvariant()
    } catch {
        return $Path.Trim().TrimEnd('\').ToLowerInvariant()
    }
}

function Test-IsStaleShortcutTarget {
    param([string]$TargetPath)
    if ([string]::IsNullOrWhiteSpace($TargetPath)) { return $true }
    $norm = Normalize-PathForCompare $TargetPath
    if ($norm -match '\\build\\windows\\') { return $true }
    if ($norm -match '\\development\\apps\\counter\\') { return $true }
    if ($norm -match '\\counter\\build\\') { return $true }
    if ($norm -match '\\runner\\debug\\') { return $true }
    if ($norm -match '\\runner\\release\\' -and $norm -notmatch '\\programs\\counter\\') {
        return $true
    }
    return $false
}

function Get-CounterDesktopShortcutInfo {
  $paths = Get-CounterInstalledPaths
  $info = [PSCustomObject]@{
    DesktopShortcutExists              = $false
    DesktopShortcutPath                = $paths.ShortcutPath
    DesktopShortcutTarget              = ''
    DesktopShortcutWorkingDirectory    = ''
    DesktopShortcutPointsToInstalledApp = $false
  }

  if (-not (Test-Path $paths.ShortcutPath)) {
    return $info
  }

  try {
    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($paths.ShortcutPath)
    $info.DesktopShortcutExists = $true
    $info.DesktopShortcutTarget = [string]$lnk.TargetPath
    $info.DesktopShortcutWorkingDirectory = [string]$lnk.WorkingDirectory
    $targetOk = (Normalize-PathForCompare $lnk.TargetPath) -eq
      (Normalize-PathForCompare $paths.InstalledExe)
    $workdirOk = (Normalize-PathForCompare $lnk.WorkingDirectory) -eq
      (Normalize-PathForCompare $paths.InstallDir)
    $info.DesktopShortcutPointsToInstalledApp = $targetOk -and $workdirOk
  } catch {
    $info.DesktopShortcutExists = $true
  }

  return $info
}

function Write-CounterDesktopShortcutSmokeFields {
    param($Info)
    Write-Host "desktop_shortcut_exists=$($Info.DesktopShortcutExists.ToString().ToLower())"
    Write-Host "desktop_shortcut_path=$($Info.DesktopShortcutPath)"
    Write-Host "desktop_shortcut_target=$($Info.DesktopShortcutTarget)"
    Write-Host "desktop_shortcut_working_directory=$($Info.DesktopShortcutWorkingDirectory)"
    Write-Host "desktop_shortcut_points_to_installed_app=$($Info.DesktopShortcutPointsToInstalledApp.ToString().ToLower())"
}

function Ensure-CounterDesktopShortcut {
    $paths = Get-CounterInstalledPaths
    if (-not (Test-Path $paths.InstalledExe)) {
        throw "Installed exe missing: $($paths.InstalledExe)"
    }

    $desktopDir = Split-Path $paths.ShortcutPath -Parent
    if (-not (Test-Path $desktopDir)) {
        New-Item -ItemType Directory -Force -Path $desktopDir | Out-Null
    }

    $existed = Test-Path $paths.ShortcutPath
    $previousTarget = ''
    if ($existed) {
        try {
            $shellRead = New-Object -ComObject WScript.Shell
            $prev = $shellRead.CreateShortcut($paths.ShortcutPath)
            $previousTarget = [string]$prev.TargetPath
        } catch {
            $previousTarget = ''
        }
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($paths.ShortcutPath)
    $shortcut.TargetPath = $paths.InstalledExe
    $shortcut.WorkingDirectory = $paths.InstallDir
    $shortcut.IconLocation = "$($paths.InstalledExe),0"
    $shortcut.Description = 'Counter — Life OS'
    $shortcut.Save()

    $targetNorm = Normalize-PathForCompare $paths.InstalledExe
    $prevNorm = Normalize-PathForCompare $previousTarget

    if (-not $existed) {
        Write-Host 'DESKTOP_VOICE_DESKTOP_SHORTCUT_CREATED'
    } elseif ($prevNorm -ne $targetNorm -or (Test-IsStaleShortcutTarget $previousTarget)) {
        Write-Host 'DESKTOP_VOICE_DESKTOP_SHORTCUT_UPDATED'
        if (-not [string]::IsNullOrWhiteSpace($previousTarget)) {
            Write-Host "desktop_shortcut_previous_target=$previousTarget"
        }
    }

    Write-Host 'DESKTOP_VOICE_DESKTOP_SHORTCUT_POINTS_TO_INSTALLED_APP'
    Write-Host "desktop_shortcut_path=$($paths.ShortcutPath)"
    Write-Host "desktop_shortcut_target=$($paths.InstalledExe)"
    Write-Host "desktop_shortcut_working_directory=$($paths.InstallDir)"

    $info = Get-CounterDesktopShortcutInfo
    Write-CounterDesktopShortcutSmokeFields $info
    return $info
}
