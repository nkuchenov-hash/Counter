# PocketBase: pub get → bootstrap schema → migrate CSVs (local PB only).
# References: POCKETBASE_MANIFEST.md, DATA_MAP.md, tool/bootstrap_pb_schema.dart, tool/migrate_data.dart
# Do not commit credentials; rotate PB admin password after setup.

$ErrorActionPreference = 'Stop'

$ProjectRoot = 'C:\Users\nkuch\Development\Apps\counter\counter'
$CsvDir = 'C:\Users\nkuch\Development\Apps\counter\counter\lib\migration_data'
$CsvProfiles = Join-Path $CsvDir 'profiles.csv'
$CsvCategories = Join-Path $CsvDir 'categories.csv'
$CsvRecords = Join-Path $CsvDir 'records.csv'
$CsvTags = Join-Path $CsvDir 'tags.csv'
$CsvPlans = Join-Path $CsvDir 'plans.csv'

Set-Location -LiteralPath $ProjectRoot

$env:PB_BASE_URL = 'http://127.0.0.1:8090'
$env:PB_ADMIN_EMAIL = 'Kuchenov@yandex.ru'
$env:PB_ADMIN_PASSWORD = 'Fer-jGd-pdh-g57'
$env:MIGRATION_DEFAULT_PASSWORD = 'TempUserPwd123!'

Write-Host '=== dart pub get ===' -ForegroundColor Cyan
dart pub get
if ($LASTEXITCODE -ne 0) {
  Write-Host "dart pub get exit code: $LASTEXITCODE" -ForegroundColor Red
  Read-Host 'Press Enter to close...'
  exit $LASTEXITCODE
}

Write-Host '=== dart run tool/bootstrap_pb_schema.dart ===' -ForegroundColor Cyan
dart run tool/bootstrap_pb_schema.dart
if ($LASTEXITCODE -ne 0) {
  Write-Host "bootstrap exit code: $LASTEXITCODE" -ForegroundColor Red
  Read-Host 'Press Enter to close...'
  exit $LASTEXITCODE
}

Write-Host '=== dart run tool/migrate_data.dart (hardcoded CSV paths) ===' -ForegroundColor Cyan
# Args order: profiles, categories, records, tags, plans
dart run tool/migrate_data.dart $CsvProfiles $CsvCategories $CsvRecords $CsvTags $CsvPlans
if ($LASTEXITCODE -ne 0) {
  Write-Host "migrate_data exit code: $LASTEXITCODE" -ForegroundColor Red
  Read-Host 'Press Enter to close...'
  exit $LASTEXITCODE
}

Write-Host '=== Done ===' -ForegroundColor Green
Read-Host 'Press Enter to close...'
