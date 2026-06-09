# One-command deploy: analyze, build web, commit (if dirty), push main.
# GitHub Actions (.github/workflows/deploy.yml) publishes build/web → gh-pages.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $Root

if (-not (Test-Path -LiteralPath 'lib/core/env/env.dart')) {
  Write-Host '==> creating lib/core/env/env.dart from example (gitignored)' -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path 'lib/core/env' | Out-Null
  Copy-Item -LiteralPath 'lib/core/env/env.dart.example' -Destination 'lib/core/env/env.dart'
}

Write-Host '==> flutter analyze' -ForegroundColor Cyan
flutter analyze --no-fatal-infos --no-fatal-warnings
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '==> flutter build web' -ForegroundColor Cyan
flutter build web --release --base-href="/Counter/" --no-tree-shake-icons --no-wasm-dry-run
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$branch = git branch --show-current
if (-not $branch) {
  throw 'Not on a git branch.'
}

$dirty = git status --porcelain
if ($dirty) {
  Write-Host '==> commit changes' -ForegroundColor Cyan
  git add -A
  $msg = "Deploy: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  git commit -m $msg
}

Write-Host "==> push to origin/$branch" -ForegroundColor Cyan
git push origin $branch
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host 'Pushed. GitHub Actions will build and deploy to gh-pages.' -ForegroundColor Green
Write-Host 'Live: https://nkuchenov-hash.github.io/Counter/' -ForegroundColor Green
