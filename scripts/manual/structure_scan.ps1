# structure_scan.ps1 — generate repo structure snapshot for documentation audits.
# Usage: .\scripts\manual\structure_scan.ps1 [-OutDir docs/reports]

param(
    [string]$OutDir = "docs/reports"
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Get-TreeLines {
    param([string[]]$Paths, [int]$MaxDepth = 6)
    $lines = @()
    foreach ($p in $Paths) {
        $full = Join-Path $root $p
        if (-not (Test-Path $full)) { continue }
        $lines += "=== $p/ ==="
        Get-ChildItem -Path $full -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $r = $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
                $r -notmatch '^\.dart_tool/' -and
                $r -notmatch '^build/' -and
                $r -notmatch '/\.gradle/' -and
                $r -notmatch '/Pods/'
            } |
            ForEach-Object {
                $rel = $_.FullName.Substring($root.Length + 1) -replace '\\', '/'
                $depth = ($rel -split '/').Count
                if ($depth -le $MaxDepth) {
                    $lines += $rel
                }
            }
    }
    return $lines
}

$tracked = git -C $root ls-files
$tracked | Set-Content -Encoding utf8 (Join-Path $OutDir "_tracked_files.tmp")
git -C $root status --short | Set-Content -Encoding utf8 (Join-Path $OutDir "_working_tree_status.tmp")

$counts = [ordered]@{
    tracked_all = ($tracked | Measure-Object -Line).Lines
    lib         = ($tracked | Where-Object { $_ -like 'lib/*' } | Measure-Object -Line).Lines
    lib_dart    = ($tracked | Where-Object { $_ -like 'lib/*.dart' -or $_ -like 'lib/**/*.dart' } | Measure-Object -Line).Lines
    test        = ($tracked | Where-Object { $_ -like 'test/*' } | Measure-Object -Line).Lines
    docs        = ($tracked | Where-Object { $_ -like 'docs/*' } | Measure-Object -Line).Lines
    scripts     = ($tracked | Where-Object { $_ -like 'scripts/*' } | Measure-Object -Line).Lines
    assets      = ($tracked | Where-Object { $_ -like 'assets/*' } | Measure-Object -Line).Lines
}

$treeSections = @('lib', 'test', 'scripts', 'docs', 'assets', 'web', 'android', 'ios', 'windows', 'linux', 'macos', '.github')
$treeOut = @("# Structure tree snapshot", "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "# SHA: $(git -C $root rev-parse --short HEAD)", "")
foreach ($sec in $treeSections) {
    $treeOut += Get-TreeLines @($sec)
    $treeOut += ""
}
$treePath = Join-Path $OutDir "_structure_tree_snapshot.tmp"
$treeOut | Set-Content -Encoding utf8 $treePath

Write-Host "structure_scan: tracked=$($counts.tracked_all) lib_dart=$($counts.lib_dart) test=$($counts.test) docs=$($counts.docs)"
Write-Host "Outputs: $OutDir/_tracked_files.tmp, _structure_tree_snapshot.tmp"
$counts.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key)=$($_.Value)" }
