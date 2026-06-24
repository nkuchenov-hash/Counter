# One-command deploy: analyze, build web, commit (if dirty), push main.
# GitHub Actions (.github/workflows/deploy.yml) publishes build/web → gh-pages.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $Root

function Invoke-External {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Command
    )

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
}

function Invoke-Flutter {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$FlutterArgs
    )

    # Flutter writes analyzer summaries to stderr even on success; with
    # $ErrorActionPreference = 'Stop' that becomes a terminating error.
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & flutter @FlutterArgs
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    if ($exitCode -ne 0) {
        exit $exitCode
    }
}

if (-not (Test-Path -LiteralPath 'lib/core/env/env.dart')) {
  Write-Host '==> creating lib/core/env/env.dart from example (gitignored)' -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path 'lib/core/env' | Out-Null
  Copy-Item -LiteralPath 'lib/core/env/env.dart.example' -Destination 'lib/core/env/env.dart'
}

Write-Host '==> flutter analyze' -ForegroundColor Cyan
Invoke-Flutter analyze --no-fatal-infos --no-fatal-warnings

Write-Host '==> flutter build web' -ForegroundColor Cyan
$gitCommit = (git rev-parse --short HEAD).Trim()
$buildTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
Invoke-Flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run --pwa-strategy=none `
  --dart-define=GIT_COMMIT=$gitCommit `
  --dart-define=BUILD_TIME=$buildTime

$branch = git branch --show-current
if (-not $branch) {
  throw 'Not on a git branch.'
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host '==> commit changes' -ForegroundColor Cyan
  $addExit = Invoke-External { git add -A }
  if ($addExit -ne 0) { exit $addExit }
  $msg = "Deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $commitExit = Invoke-External { git commit -m $msg }
  if ($commitExit -ne 0) { exit $commitExit }
}

Write-Host "==> push to origin/$branch" -ForegroundColor Cyan
$pushExit = Invoke-External { git push origin $branch }
if ($pushExit -ne 0) { exit $pushExit }

Write-Host ''
Write-Host 'Pushed. GitHub Actions will build and deploy to gh-pages.' -ForegroundColor Green
Write-Host 'Live: https://nkuchenov-hash.github.io/Counter/' -ForegroundColor Green
