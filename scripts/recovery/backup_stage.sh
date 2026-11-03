#!/usr/bin/env bash
set -euo pipefail

# LIFE OS staging backup ONLY. Never writes to a production PocketBase database.
# Copy is consistent at SQLite level and verified before retention cleanup.
umask 077
source_dir=/opt/lifeos/recovery-stage
backup_dir=/var/backups/lifeos-stage
database="$source_dir/pb_data/data.db"
[ "$(id -u)" = 0 ] || { echo "Must run as root" >&2; exit 1; }
[ -f "$database" ] || { echo "Staging database not found" >&2; exit 1; }
for d in "$source_dir/pb_hooks" "$source_dir/pb_migrations"; do
  [ -d "$d" ] || { echo "Missing $d" >&2; exit 1; }
done
mkdir -p "$backup_dir"
chmod 0700 "$backup_dir"
exec 9>"$backup_dir/.backup.lock"
flock -n 9 || { echo "A backup is already running" >&2; exit 1; }
tmp="$(mktemp -d "$backup_dir/.build.XXXXXXXX")"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bundle/pb_data"
# Copy user files first, then replace the SQLite DB with a consistent online backup.
cp -a "$source_dir/pb_data/." "$tmp/bundle/pb_data/"
rm -f "$tmp/bundle/pb_data/data.db" "$tmp/bundle/pb_data/data.db-wal" "$tmp/bundle/pb_data/data.db-shm"
sqlite3 "$database" ".timeout 5000" ".backup '$tmp/bundle/pb_data/data.db'"
cp -a "$source_dir/pb_hooks" "$source_dir/pb_migrations" "$tmp/bundle/"
[ "$(sqlite3 "$tmp/bundle/pb_data/data.db" 'PRAGMA integrity_check;')" = ok ] || {
  echo "SQLite backup failed integrity check" >&2; exit 1;
}
printf 'LIFE OS PocketBase STAGING backup\nCreated (UTC): %s\n' "$(date -u +%FT%TZ)" > "$tmp/bundle/README.txt"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$backup_dir/stage-$timestamp.tar.gz"
tar -C "$tmp/bundle" -czf "$tmp/archive.tar.gz" .
tar -tzf "$tmp/archive.tar.gz" >/dev/null
mv "$tmp/archive.tar.gz" "$archive"
chmod 0600 "$archive"
sha256sum "$archive" > "$archive.sha256"
chmod 0600 "$archive.sha256"
# Retain the newest seven staging archives.
mapfile -t old < <(find "$backup_dir" -maxdepth 1 -type f -name 'stage-*.tar.gz' -printf '%f\n' | sort -r | tail -n +8)
for old_file in \${old[@]}; do
  rm -f "$backup_dir/$old_file" "$backup_dir/$old_file.sha256"
done
echo "STAGING BACKUP OK: $archive"
echo "WARNING: Local-only backup on the SAME VPS; not a disaster-recovery offsite copy."
