# Fail if forbidden production Preparing overlay text exists in lib/ or windows/runner/.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
Set-Location $repoRoot

# UTF-8 bytes for: Подготовка распознавания
$ruForbidden = [System.Text.Encoding]::UTF8.GetString(
    [byte[]](0xD0,0x9F,0xD0,0xBE,0xD0,0xB4,0xD0,0xB3,0xD0,0xBE,0xD1,0x82,0xD0,0xBE,0xD0,0xB2,0xD0,0xBA,0xD0,0xB0,0x20,0xD1,0x80,0xD0,0xB0,0xD1,0x81,0xD0,0xBF,0xD0,0xBE,0xD0,0xB7,0xD0,0xBD,0xD0,0xB0,0xD0,0xB2,0xD0,0xB0,0xD0,0xBD,0xD0,0xB8,0xD1,0x8F)
)

$forbidden = @(
    $ruForbidden,
    'Preparing recognition',
    'Preparing speech recognition',
    'desktop_voice_overlay_stt_warming',
    'desktop_voice_overlay_preparing'
)

$scanRoots = @(
    (Join-Path $repoRoot 'lib'),
    (Join-Path $repoRoot 'windows\runner')
)

$hits = @()
foreach ($root in $scanRoots) {
    if (-not (Test-Path $root)) { continue }
    $files = Get-ChildItem $root -Recurse -File -Include *.dart,*.cpp,*.h,*.cc
    foreach ($file in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        foreach ($needle in $forbidden) {
            if ($content.Contains($needle)) {
                $hits += "$($file.FullName): $needle"
            }
        }
    }
}

if ($hits.Count -gt 0) {
    Write-Host 'NO_PREPARING_UI_FAIL'
    $hits | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host 'NO_PREPARING_UI_PASS'
exit 0
