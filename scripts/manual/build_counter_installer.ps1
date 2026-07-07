# Build/install Inno Setup 6 ISCC if missing, then compile CounterSetup.exe.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

function Find-Iscc {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    $cmd = Get-Command iscc -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$iscc = Find-Iscc
if (-not $iscc) {
    Write-Host 'ISCC.exe not found — installing Inno Setup 6 via winget...'
    winget install --id JRSoftware.InnoSetup -e --accept-package-agreements --accept-source-agreements
    $iscc = Find-Iscc
}
if (-not $iscc) {
    throw 'Inno Setup 6 ISCC.exe still not found after winget install'
}
Write-Host "Using ISCC: $iscc"
Push-Location $repoRoot
try {
    & $iscc (Join-Path $repoRoot 'installer\windows\counter.iss')
    if ($LASTEXITCODE -ne 0) { throw "ISCC failed exit=$LASTEXITCODE" }
    $out = Join-Path $repoRoot 'installer\windows\output\CounterSetup.exe'
    if (-not (Test-Path $out)) { throw "CounterSetup.exe missing at $out" }
    $item = Get-Item $out
    Write-Host "CounterSetup.exe built size=$($item.Length) mtime=$($item.LastWriteTime)"
} finally {
    Pop-Location
}
