# architecture_guard.ps1 — repo structure + boundary audit.
# Usage:
#   .\scripts\audit\architecture_guard.ps1           # warnings for soft checks; exit 0
#   .\scripts\audit\architecture_guard.ps1 -Strict   # exit 1 on ANY violation
#
# Compares lib/ Dart files against docs/APP_STRUCTURE.md manifest keywords.
# Does NOT modify files.

param(
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

$appStructurePath = Join-Path $repoRoot 'docs\APP_STRUCTURE.md'
$appStructure = Get-Content $appStructurePath -Raw

$violations = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Violation([string]$msg) { $violations.Add($msg) }
function Add-Warning([string]$msg) { $warnings.Add($msg) }

# --- 0. APP_STRUCTURE debt wording (strict manifest hygiene) ---
$debtPatterns = @(
    '(?i)\blegacy\b',
    '(?i)\bdebt\b',
    '(?i)\btemporary\b',
    '(?i)\bquarantine\b',
    '(?i)\bcandidate\b',
    '(?i)\bconsolidate later\b',
    '(?i)\bknown drift\b',
    '(?i)\bP0U active\b',
    '(?i)\bperf debt\b',
    '(?i)\bunused stub\b',
    '(?i)\b0 imports\b',
    '(?i)\bstage [A-Z]\b',
    '(?i)\baudit (notes|debt|report)\b',
    '(?i)\bmigrate imports\b',
    '(?i)\bdo not delete while\b'
)
foreach ($pat in $debtPatterns) {
    if ($appStructure -match $pat) {
        Add-Violation "APP_STRUCTURE_DEBT_WORDING pattern '$pat' matched in docs/APP_STRUCTURE.md"
    }
}

# --- 1. Forbidden imports ---
$forbiddenImportRules = @(
    @{ Label = 'data->features'; Path = 'lib\data'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'core->features'; Path = 'lib\core'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'services->features'; Path = 'lib\services'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'core->database_service'; Path = 'lib\core'; Pattern = "import 'package:counter/data/database_service.dart'" }
)

foreach ($rule in $forbiddenImportRules) {
    $hits = @()
    if (Test-Path $rule.Path) {
        $hits = rg -l $rule.Pattern $rule.Path --glob '*.dart' 2>$null
    }
    foreach ($hit in $hits) {
        $rel = $hit.Replace('\', '/')
        Add-Violation "FORBIDDEN_IMPORT ($($rule.Label)) $rel"
    }
}

# --- 2. Root lib/*.dart allowlist (only entry files) ---
$rootLibAllow = @('main.dart', 'app_shell.dart')
Get-ChildItem lib -Filter '*.dart' -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($rootLibAllow -notcontains $_.Name) {
        Add-Violation "UNEXPECTED_ROOT_LIB lib/$($_.Name) (allowed: $($rootLibAllow -join ', '))"
    }
}

# --- 3. Experiment / diag filenames in lib/ ---
$experimentNamePattern = '^(p0|p1|pj|pk|diag|debug|probe|tmp|old|backup|hotfix)|_(diag|debug|probe|tmp|hotfix)\.dart$'
Get-ChildItem lib -Recurse -Filter '*.dart' -File | ForEach-Object {
    $name = $_.Name
    if ($name -match $experimentNamePattern) {
        $rel = $_.FullName.Replace($repoRoot + '\', '').Replace('\', '/')
        Add-Violation "EXPERIMENT_FILENAME $rel"
    }
}

# --- 4. lib/ Dart files missing from APP_STRUCTURE.md ---
$libDart = Get-ChildItem lib -Recurse -Filter '*.dart' -File
foreach ($f in $libDart) {
    $rel = $f.FullName.Replace($repoRoot + '\', '').Replace('\', '/')
    $needle = $rel -replace '^lib/', ''
    if ($appStructure -notmatch [regex]::Escape($f.Name) -and
        $appStructure -notmatch [regex]::Escape($needle)) {
        Add-Violation "UNDOCUMENTED_IN_APP_STRUCTURE $rel"
    }
}

# --- 5. Deleted-file regressions ---
$deletedMustStayGone = @(
  'Archive',
  'lib/auth_screen.dart',
  'lib/auth_service.dart',
  'lib/database_service.dart',
  'lib/models.dart',
  'lib/data/base_database.dart',
  'lib/core/subscription/app_tier.dart',
  'lib/data/html_stub.dart',
  'lib/features/more/more_view.dart',
  'lib/features/timeline/timeline_widgets.dart',
  'lib/shell',
  'lib/deploy.ps1',
  'lib/notes',
  'lib/core/p0u_diag.dart',
  'lib/core/p0u_feature_flags.dart',
  'lib/core/p0u_platform.dart',
  'lib/core/p0u_startup_diag.dart',
  'lib/core/perf_diag.dart',
  'lib/core/perf_flags.dart',
  'lib/core/plan_dup_trace.dart',
  'lib/data/p0t_render_snapshot.dart',
  'lib/data/warm_day_window.dart',
  'lib/data/rendered_day_body_cache.dart'
)
foreach ($gone in $deletedMustStayGone) {
    if (Test-Path (Join-Path $repoRoot $gone)) {
        Add-Violation "DELETED_FILE_REGRESSION $gone exists again"
    }
}

# --- 6. Tracked build / tool artifacts (must stay gitignored) ---
$trackedBuildPatterns = @(
    '^build/',
    '^\.dart_tool/flutter_build/',
    '^android/build/',
    '^ios/build/'
)
try {
    $tracked = git -C $repoRoot ls-files 2>$null
    if ($tracked) {
        foreach ($line in $tracked) {
            $norm = $line.Replace('\', '/')
            foreach ($pat in $trackedBuildPatterns) {
                if ($norm -match $pat) {
                    Add-Violation "TRACKED_BUILD_ARTIFACT $norm (should be gitignored)"
                    break
                }
            }
        }
    }
}
catch {
    Add-Warning "GIT_LS_FILES skipped: $_"
}

# --- 7. Large file warnings (>1800 lines) — warning mode only ---
Get-ChildItem lib -Recurse -Filter '*.dart' -File | ForEach-Object {
    $lines = (Get-Content $_.FullName | Measure-Object -Line).Lines
    if ($lines -gt 1800) {
        $rel = $_.FullName.Replace($repoRoot + '\', '').Replace('\', '/')
        Add-Warning "LARGE_FILE $rel lines=$lines (review mixed responsibilities; do not split by line count alone)"
    }
}

# --- 8. Raw UI primitives in features (informational warning) ---
$rawUi = @('ElevatedButton', 'FilledButton', 'OutlinedButton', 'TextButton', 'IconButton')
foreach ($w in $rawUi) {
    $count = (rg -c $w lib\features --glob '*.dart' 2>$null | Measure-Object).Count
    if ($count -gt 0) {
        Add-Warning "RAW_UI $w present in $count feature file(s) - migrate to AppButton/AppIconButton per DESIGN_SYSTEM"
    }
}

# --- Report ---
Write-Host ''
Write-Host '=== architecture_guard summary ===' -ForegroundColor Cyan
Write-Host "Mode: $(if ($Strict) { 'STRICT (exit 1 on any violation)' } else { 'WARNING (exit 0; LARGE_FILE/RAW_UI are warnings only)' })"
Write-Host "Violations: $($violations.Count)"
Write-Host "Warnings: $($warnings.Count)"
Write-Host ''

if ($violations.Count -gt 0) {
    Write-Host '--- Violations ---' -ForegroundColor Red
    $violations | ForEach-Object { Write-Host $_ }
}

if ($warnings.Count -gt 0) {
    Write-Host '--- Warnings ---' -ForegroundColor DarkYellow
    $warnings | Select-Object -First 25 | ForEach-Object { Write-Host $_ }
    if ($warnings.Count -gt 25) { Write-Host "... and $($warnings.Count - 25) more" }
}

if ($Strict -and $violations.Count -gt 0) {
    Write-Host ''
    Write-Host ('STRICT: exiting 1 with ' + $violations.Count + ' violation(s)') -ForegroundColor Red
    exit 1
}

if (-not $Strict -and $violations.Count -gt 0) {
    Write-Host ''
    Write-Host "Note: $($violations.Count) violation(s) reported (non-strict mode, exit 0). Re-run with -Strict to fail CI." -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'architecture_guard: done (exit 0)' -ForegroundColor Green
exit 0
