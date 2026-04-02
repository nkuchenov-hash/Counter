# Fast commit + push to main (nkuchenov-hash/Counter)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

git add .
git commit -m "Fast update: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
git push origin main

Write-Host "🚀 Pushed! Your update is being built. It will be live at: https://nkuchenov-hash.github.io/Counter/"
