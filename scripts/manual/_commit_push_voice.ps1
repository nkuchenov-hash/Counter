git add -A
if ($LASTEXITCODE -ne 0) { exit 1 }
git commit -m "refactor(voice): unify voice ownership across platforms"
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host "COMMITTED=$(git rev-parse HEAD)"
git push -u origin HEAD
if ($LASTEXITCODE -ne 0) { exit 1 }
Write-Host "PUSHED=$(git rev-parse HEAD)"
git status -sb
