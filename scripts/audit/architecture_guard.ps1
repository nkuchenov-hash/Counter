# architecture_guard.ps1 — repo structure + boundary audit.
# Usage:
#   .\scripts\audit\architecture_guard.ps1           # warnings for soft checks; exit 0
#   .\scripts\audit\architecture_guard.ps1 -Strict   # exit 1 on ANY violation
#
# Compares lib/ Dart files against docs/APP_STRUCTURE.md manifest keywords.
# Does NOT modify files.
# Cross-platform: Windows PowerShell / pwsh and Ubuntu GitHub Actions pwsh.

param(
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'

# Nested Join-Path — do not use Windows-only '..\..' literals (backslash is not a
# path separator on Linux / Ubuntu pwsh).
$repoRoot = (
    Resolve-Path (
        Join-Path (
            Join-Path $PSScriptRoot '..'
        ) '..'
    )
).Path
Set-Location $repoRoot

$appStructurePath = Join-Path (Join-Path $repoRoot 'docs') 'APP_STRUCTURE.md'
$appStructure = Get-Content $appStructurePath -Raw

$violations = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Violation([string]$msg) { $violations.Add($msg) }
function Add-Warning([string]$msg) { $warnings.Add($msg) }

function Get-RepoRelativePath([string]$fullPath) {
    $full = [System.IO.Path]::GetFullPath($fullPath)
    $root = [System.IO.Path]::GetFullPath($repoRoot)
    $rootPrefix = $root.TrimEnd([char[]]@('\', '/'))
    if ($full.Length -ge $rootPrefix.Length -and
        ($full.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or
         $full.StartsWith($rootPrefix, [System.StringComparison]::Ordinal))) {
        $rel = $full.Substring($rootPrefix.Length).TrimStart([char[]]@('\', '/'))
        return $rel.Replace('\', '/')
    }
    return $full.Replace('\', '/')
}

function Get-RepoPath([string[]]$segments) {
    $p = $repoRoot
    foreach ($s in $segments) {
        $p = Join-Path $p $s
    }
    return $p
}

# List dart files under a repo-relative directory whose contents match [regex] $pattern.
function Find-DartFilesMatching([string]$repoRelativeDir, [string]$pattern) {
    $searchRoot = Get-RepoPath ($repoRelativeDir -split '/')
    if (-not (Test-Path -LiteralPath $searchRoot)) {
        return @()
    }
    $hits = [System.Collections.Generic.List[string]]::new()
    Get-ChildItem -LiteralPath $searchRoot -Recurse -Filter '*.dart' -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            if (Select-String -LiteralPath $_.FullName -Pattern $pattern -Quiet) {
                $hits.Add((Get-RepoRelativePath $_.FullName))
            }
        }
    return $hits
}

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
# Path values use forward-slash repo-relative segments (resolved via Join-Path).
$forbiddenImportRules = @(
    @{ Label = 'data->features'; Path = 'lib/data'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'features->pocketbase'; Path = 'lib/features'; Pattern = "import 'package:pocketbase/" },
    @{ Label = 'app->pocketbase'; Path = 'lib/app'; Pattern = "import 'package:pocketbase/" },
    @{ Label = 'core->pocketbase'; Path = 'lib/core'; Pattern = "import 'package:pocketbase/" },
    @{ Label = 'shared->pocketbase'; Path = 'lib/shared'; Pattern = "import 'package:pocketbase/" },
    @{ Label = 'services->pocketbase'; Path = 'lib/services'; Pattern = "import 'package:pocketbase/" },
    @{ Label = 'core->features'; Path = 'lib/core'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'services->features'; Path = 'lib/services'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'core->database_service'; Path = 'lib/core'; Pattern = "import 'package:counter/data/database_service.dart'" },
    @{ Label = 'shared->features'; Path = 'lib/shared'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'shared->database_service'; Path = 'lib/shared'; Pattern = "import 'package:counter/data/database_service.dart'" },
    @{ Label = 'shared/voice->data/voice'; Path = 'lib/shared/voice'; Pattern = "import 'package:counter/data/voice/" },
    @{ Label = 'shared/categories->features'; Path = 'lib/shared/categories'; Pattern = "import 'package:counter/features/" },
    @{ Label = 'shared/categories->database_service'; Path = 'lib/shared/categories'; Pattern = "import 'package:counter/data/database_service.dart'" },
    @{ Label = 'shared/categories->app/shell'; Path = 'lib/shared/categories'; Pattern = "import 'package:counter/app/shell/" }
)

foreach ($rule in $forbiddenImportRules) {
    $hits = Find-DartFilesMatching $rule.Path $rule.Pattern
    foreach ($rel in $hits) {
        Add-Violation "FORBIDDEN_IMPORT ($($rule.Label)) $rel"
    }
}

# --- 2. Root lib/*.dart allowlist (only entry files) ---
$rootLibAllow = @('main.dart', 'app_shell.dart')
$libRoot = Get-RepoPath @('lib')
Get-ChildItem -LiteralPath $libRoot -Filter '*.dart' -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($rootLibAllow -notcontains $_.Name) {
        Add-Violation "UNEXPECTED_ROOT_LIB lib/$($_.Name) (allowed: $($rootLibAllow -join ', '))"
    }
}

# --- 2b. Fixed top-level owner layers under lib/ ---
$libLayerAllow = @('app', 'core', 'data', 'features', 'l10n', 'services', 'shared')
Get-ChildItem -LiteralPath $libRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if ($libLayerAllow -notcontains $_.Name) {
        Add-Violation "UNEXPECTED_LIB_LAYER lib/$($_.Name) (allowed owner layers: $($libLayerAllow -join ', '))"
    }
}

# --- 3. Experiment / diag filenames in lib/ ---
$experimentNamePattern = '^(p0|p1|pj|pk|diag|debug|probe|tmp|old|backup|hotfix)|_(diag|debug|probe|tmp|hotfix)\.dart$'
Get-ChildItem -LiteralPath $libRoot -Recurse -Filter '*.dart' -File | ForEach-Object {
    $name = $_.Name
    if ($name -match $experimentNamePattern) {
        $rel = Get-RepoRelativePath $_.FullName
        Add-Violation "EXPERIMENT_FILENAME $rel"
    }
}

# --- 4. lib/ Dart files missing from APP_STRUCTURE.md ---
$libDart = Get-ChildItem -LiteralPath $libRoot -Recurse -Filter '*.dart' -File
foreach ($f in $libDart) {
    $rel = Get-RepoRelativePath $f.FullName
    $needle = $rel -replace '^lib/', ''
    if ($appStructure -notmatch [regex]::Escape($f.Name) -and
        $appStructure -notmatch [regex]::Escape($needle)) {
        Add-Violation "UNDOCUMENTED_IN_APP_STRUCTURE $rel"
    }
}

# --- 4b. APP_STRUCTURE rows pointing at deleted Dart files ---
# Section 4 guarantees code -> docs. This reverse pass guarantees docs -> code,
# preventing renamed/deleted implementation rows from lingering indefinitely.
$appStructureDartRowMatches = [regex]::Matches(
    $appStructure,
    '(?m)^\|\s*`([^`]+\.dart)`\s*\|'
)
$appStructureReverseExemptions = @(
    'env.dart',
    'core/env/env.dart',
    'lib/core/env/env.dart'
)
foreach ($match in $appStructureDartRowMatches) {
    $declared = $match.Groups[1].Value.Trim().TrimStart('.', '/')
    if ($appStructureReverseExemptions -contains $declared) { continue }
    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add($declared)
    if ($declared.StartsWith('lib/')) {
        $candidates.Add($declared.Substring(4))
    }
    $found = $false
    foreach ($f in $libDart) {
        $actual = (Get-RepoRelativePath $f.FullName) -replace '^lib/', ''
        foreach ($candidate in $candidates) {
            if ($actual -eq $candidate -or $actual.EndsWith('/' + $candidate)) {
                $found = $true
                break
            }
        }
        if ($found) { break }
    }
    if (-not $found) {
        Add-Violation "STALE_APP_STRUCTURE_DART $declared"
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
  'lib/core/time',
  'lib/core/diagnostics',
  'lib/core/performance',
  'lib/core/diagnostics/runtime_log.dart',
  'lib/core/diagnostics/platform_log.dart',
  'lib/core/diagnostics/startup_log.dart',
  'lib/core/diagnostics/plan_duplicate_log.dart',
  'lib/core/diagnostics/desktop_voice_log.dart',
  'lib/core/diagnostics/desktop_voice_pipeline.dart',
  'lib/core/performance/runtime_flags.dart',
  'lib/core/performance/shell_flags.dart',
  'lib/core/performance/rebuild_metrics.dart',
  'lib/features/planning/diagnostics',
  'lib/core/services/desktop_voice_settings.dart',
  'lib/core/services/desktop_stt_helper_service.dart',
  'lib/core/services/desktop_voice_hotkey.dart',
  'lib/core/services/speech_engine_handle.dart',
  'lib/core/services/pcm_audio_utils.dart',
  'lib/core/widgets/app_mic_level_bars.dart',
  'lib/features/shared/voice_input_sheet.dart',
  'lib/features/shared/voice_capture_config.dart',
  'lib/features/shared/desktop_voice_widget.dart',
  'lib/features/shared/desktop_voice_capsule.dart',
  'lib/features/shared/desktop_voice_command_panel.dart',
  'lib/features/shared/desktop_voice_correction_sheet.dart',
  'lib/features/profile/desktop_voice_settings_section.dart',
  'lib/features/profile/desktop_voice_settings_desktop.dart',
  'lib/features/profile/desktop_voice_attempt_dialog.dart',
  'lib/data/voice_command_parser.dart',
  'lib/data/voice_domain_resolver.dart',
  'lib/data/desktop_stt_cloud_backend.dart',
  'lib/data/voice_audio_stub.dart',
  'lib/data/voice_audio_web.dart',
  'lib/data/price_reporter_client_match.dart',
  'lib/shared/voice/routing/desktop_voice_record_submit.dart',
  'lib/shared/voice/platforms/desktop/ui/desktop_voice_widget.dart',
  'lib/shared/voice/platforms/desktop/ui/desktop_voice_capsule.dart',
  'lib/shared/voice/platforms/desktop/ui/desktop_voice_correction_sheet.dart',
  'lib/shared/voice/platforms/desktop/ui/desktop_voice_command_panel.dart',
  'lib/shared/voice/platforms/desktop/desktop_voice_useful_candidate_evaluator.dart',
  'lib/shared/voice/platforms/desktop/desktop_stt_benchmark_harness.dart',
  'lib/shared/voice/platforms/desktop/desktop_voice_real_helper_latency_benchmark.dart',
  'lib/features/categories',
  'lib/core/plan_category_lookup.dart',
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
    $gonePath = Get-RepoPath ($gone -split '/')
    if (Test-Path -LiteralPath $gonePath) {
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
Get-ChildItem -LiteralPath $libRoot -Recurse -Filter '*.dart' -File | ForEach-Object {
    $lines = (Get-Content -LiteralPath $_.FullName | Measure-Object -Line).Lines
    if ($lines -gt 1800) {
        $rel = Get-RepoRelativePath $_.FullName
        Add-Warning "LARGE_FILE $rel lines=$lines (review mixed responsibilities; do not split by line count alone)"
    }
}

# --- 8. Raw UI primitives in features (informational warning) ---
$rawUi = @('ElevatedButton', 'FilledButton', 'OutlinedButton', 'TextButton', 'IconButton')
$featuresRoot = Get-RepoPath @('lib', 'features')
foreach ($w in $rawUi) {
    $fileCount = 0
    if (Test-Path -LiteralPath $featuresRoot) {
        Get-ChildItem -LiteralPath $featuresRoot -Recurse -Filter '*.dart' -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                if (Select-String -LiteralPath $_.FullName -Pattern $w -SimpleMatch -Quiet) {
                    $fileCount++
                }
            }
    }
    if ($fileCount -gt 0) {
        Add-Warning "RAW_UI $w present in $fileCount feature file(s) - migrate to AppButton/AppIconButton per DESIGN_SYSTEM"
    }
}


# --- 8b. Durable Paths ownership (hard structural law) ---
$pathCompatDir = Get-RepoPath @('lib', 'data', 'paths', 'compatibility')
if (Test-Path -LiteralPath $pathCompatDir) {
    Add-Violation "PATH_COMPATIBILITY_REGRESSION lib/data/paths/compatibility must not return"
}

$pathMarkerLeaks = Find-DartFilesMatching 'lib' 'LIFEOS_PATH::|LIFEOS_PATH_ACTION|LIFEOS_WEEK_ROUTINE'
foreach ($rel in $pathMarkerLeaks) {
    Add-Violation "PATH_MARKER_RUNTIME_LEAK $rel"
}

$pathToPlannerImports = Find-DartFilesMatching 'lib/data/paths' "import 'package:counter/data/plans/"
foreach ($rel in $pathToPlannerImports) {
    Add-Violation "PATH_DOMAIN_IMPORTS_PLANNER $rel"
}

$plannerPathImports = Find-DartFilesMatching 'lib/data/plans' "import 'package:counter/data/paths/"
foreach ($rel in $plannerPathImports) {
    if ($rel -ne 'lib/data/plans/path_planner_bridge.dart') {
        Add-Violation "PATH_PLANNER_BRIDGE_BYPASS $rel"
    }
}

$projectSpecificPathLeaks = Find-DartFilesMatching 'lib/data/paths' '(?i)KADR|КАДР|GOLOS|Игропоиск|Igropoisk|Price Reporter|Etnika|ZenMoney'
foreach ($rel in $projectSpecificPathLeaks) {
    Add-Violation "PATH_PROJECT_TEMPLATE_LEAK $rel"
}

$pathRepositoryBody = Get-Content -LiteralPath (Get-RepoPath @('lib','data','paths','path_repository.dart')) -Raw
if ($pathRepositoryBody -match "import 'package:pocketbase/|\.collection\(") {
    Add-Violation "PATH_REPOSITORY_DIRECT_PB_IO path_repository.dart must delegate to DatabaseService path_service part"
}

$pathServiceBody = Get-Content -LiteralPath (Get-RepoPath @('lib','data','paths','path_service.dart')) -Raw
if ($pathServiceBody -notmatch "part of '../database_service.dart';") {
    Add-Violation "PATH_SERVICE_NOT_DATABASE_PART lib/data/paths/path_service.dart"
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
