#!/usr/bin/env bash
set -euo pipefail
# Copy verified staging archives to an independent encrypted restic repository.
umask 077
[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
conf=/etc/lifeos/offsite-backup.env
[ -f "$conf" ] || { echo "Not configured: $conf" >&2; exit 2; }
[ "$(stat -c %a "$conf")" = "600" ] || { echo "Require chmod 600 $conf" >&2; exit 2; }
[ "$(stat -c %u "$conf")" = 0 ] || { echo "Config must be root-owned" >&2; exit 2; }
set -a
source "$conf"
set +a
: "${RESTIC_REPOSITORY:?Set RESTIC_REPOSITORY}"
: "${RESTIC_PASSWORD_FILE:?Set RESTIC_PASSWORD_FILE}"
[ -s "$RESTIC_PASSWORD_FILE" ] || { echo "Missing restic password file" >&2; exit 2; }
if [[ "$RESTIC_REPOSITORY" != s3:https://* ]]; then
  if [ "${LIFEOS_ALLOW_LOCAL_RESTIC_TEST:-}" != "1" ]; then
    echo "Remote storage must be HTTPS S3 at an independent provider" >&2
    exit 2
  fi
fi
directory=/var/backups/lifeos-stage
[ -d "$directory" ] || { echo "Missing $directory" >&2; exit 2; }
latest="$(find "$directory" -maxdepth 1 -type f -name 'stage-*.tar.gz' -printf '%f\n' | sort | tail -n 1)"
[ -n "$latest" ] || { echo "No staging archives found" >&2; exit 2; }
cd "$directory"
sha256sum --check "$latest.sha256"
restic snapshots --latest 1 >/dev/null
restic backup "$directory" --tag lifeos-stage --host LIFEOS2 --exclude='*.lock' --exclude='.build.*'
restic check
echo "SUCCESS: encrypted offsite backup completed and repository checked."
