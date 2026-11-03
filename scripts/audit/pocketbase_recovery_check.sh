#!/usr/bin/env bash
set -euo pipefail
# Runs against a disposable SQLite database; never point at production.
if [ -z "\${GITHUB_WORKSPACE:-}" ]; then
  echo "Only run in an isolated GitHub Actions runner." >&2
  exit 2
fi
base="$RUNNER_TEMP/lifeos-pb-recovery-check"
mkdir -p "$base/bin" "$base/data"
curl -fsSL "https://github.com/pocketbase/pocketbase/releases/download/v0.40.6/pocketbase_0.40.6_linux_amd64.zip" -o "$base/pocketbase.zip"
unzip -oq "$base/pocketbase.zip" pocketbase -d "$base/bin"
chmod +x "$base/bin/pocketbase"
"$base/bin/pocketbase" migrate up --dir="$base/data" --migrationsDir="$GITHUB_WORKSPACE/pb_migrations"
DB="$base/data/data.db"
[ -f "$DB" ] || { echo "Missing test database: $DB" >&2; exit 1; }
actual="$(sqlite3 "$DB" 'PRAGMA integrity_check;')"
[ "$actual" = ok ] || { echo "Bad SQLite integrity: $actual" >&2; exit 1; }
for col in profiles categories tags plans records sleep_sync_connections calendar_integrations paths path_revisions viktor_turns; do
  count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM _collections WHERE name='$col';")
  [ "$count" = 1 ] || { echo "Missing collection: $col" >&2; exit 1; }
done
check_field() {
  col="$1"; field="$2"
  count=$(sqlite3 "$DB" "SELECT COUNT(*) FROM pragma_table_info('$col') WHERE name='$field';")
  [ "$count" = 1 ] || { echo "Missing $col.$field" >&2; exit 1; }
}
for field in user_id email tier is_admin; do check_field profiles "$field"; done
for field in user_id category_id parent_id default_plan_timezone; do check_field categories "$field"; done
for field in user_id tag_id domain; do check_field tags "$field"; done
for field in user_id plan_id parent_plan_id notes_delta initial_date_key is_postponed; do check_field plans "$field"; done
for field in user_id record_id category_id category_link source_plan_id parent_id notes_delta sleep_source external_id; do check_field records "$field"; done
"$base/bin/pocketbase" migrate up --dir="$base/data" --migrationsDir="$GITHUB_WORKSPACE/pb_migrations"
[ "$(sqlite3 "$DB" 'PRAGMA integrity_check;')" = ok ] || exit 1
echo 'PASS: Fresh schema, all incremental migrations, required fields, repeat apply and SQLite integrity.'
