#!/usr/bin/env bash
set -euo pipefail
# DISASTER RECOVERY DRILL only. Restore from encrypted offsite repository
# into an isolated temporary directory. No live data is modified.
umask 077
[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
conf=/etc/lifeos/offsite-backup.env
[ -f "$conf" ] || { echo "Missing offsite repository configuration" >&2; exit 1; }
[ "$(stat -c %u "$conf")" = 0 ] || { echo "Offsite config not root-owned" >&2; exit 1; }
[ "$(stat -c %a "$conf")" = 600 ] || { echo "Offsite config must be mode 0600" >&2; exit 1; }
set -a
source "$conf"
set +a
: "${RESTIC_REPOSITORY:?}"
: "${RESTIC_PASSWORD_FILE:?}"
[ -s "$RESTIC_PASSWORD_FILE" ] || { echo "Missing restic password" >&2; exit 1; }
tmp="$(mktemp -d /tmp/lifeos-offsite-drill.XXXXXXXX)"
trap 'rm -rf "$tmp"' EXIT
echo "Restoring latest encrypted backup from remote repository to an isolated temporary directory..."
restic restore latest --tag lifeos-stage --target "$tmp/restore"
backup_dir="$tmp/restore/var/backups/lifeos-stage"
[ -d "$backup_dir" ] || { echo "Expected backup directory missing from restored snapshot" >&2; exit 1; }
archive_name="$(find "$backup_dir" -maxdepth 1 -type f -name 'stage-*.tar.gz' -printf '%f\n' | sort | tail -n 1)"
[ -n "$archive_name" ] || { echo "No stage archive in restored snapshot" >&2; exit 1; }
archive="$backup_dir/$archive_name"
checksum_file="$archive.sha256"
[ -s "$checksum_file" ] || { echo "No SHA256 checksum for restored archive" >&2; exit 1; }
expected="$(awk 'NR == 1 {print $1}' "$checksum_file")"
actual="$(sha256sum "$archive" | awk '{print $1}')"
[[ "$expected" =~ ^[a-f0-9]{64}$ && "$actual" == "$expected" ]] || {
  echo "Restored archive checksum mismatch" >&2
  exit 1
}
tar -tzf "$archive" >/dev/null
tar -xOzf "$archive" './pb_data/data.db' > "$tmp/verified-data.db"
integrity="$(sqlite3 "$tmp/verified-data.db" 'PRAGMA integrity_check;')"
[ "$integrity" = ok ] || { echo "SQLite integrity check failed" >&2; exit 1; }
for collection in profiles categories tags plans records; do
  count="$(sqlite3 "$tmp/verified-data.db" "SELECT COUNT(*) FROM _collections WHERE name='$collection';")"
  [ "$count" = 1 ] || { echo "Missing collection $collection" >&2; exit 1; }
done
echo "PASS: encrypted remote snapshot restored; archive checksum and SQLite integrity verified."
echo "PASS: PocketBase core collections present in recovered database."
echo "WARNING: this verifies reconstructed staging data, not missing historical Beget accounts."
