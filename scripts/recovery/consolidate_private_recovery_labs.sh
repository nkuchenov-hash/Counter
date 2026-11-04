#!/usr/bin/env bash
set -euo pipefail
# Consolidate ALL safely recoverable evidence into yet another independent
# SQLite PocketBase lab. Never modify running PocketBase, old Android app,
# earlier lab snapshots, or web hosting. No user data is committed to GitHub.
umask 077
[[ "$(id -u)" == 0 ]] || { echo 'ERROR: root required' >&2; exit 1; }
src=/opt/lifeos/source/scripts/recovery
backup=/var/backups/lifeos-stage
export_json="$backup/LIFEOS_VIDEO_RECOVERY_REVIEWED_2026-11-04.json"
original_json="$backup/browser-recovery-20261104.json"
inventory="$backup/browser-salvage-20261104.sqlite"
timed_lab="$backup/browser-recovered-plans-lab-20261104.sqlite"
untimed_lab="$backup/browser-recovered-dated-lab-20261104.sqlite"
full_lab="$backup/browser-recovered-video-lab-20261104.sqlite"
[[ -s "$export_json" && -s "$original_json" && -s "$inventory" && -s "$timed_lab" ]] || {
  echo 'ERROR: source video JSON or prior recovery snapshots missing. Nothing changed.' >&2
  exit 1
}
echo '4f039fb85d396aca4785a4fe8dcccdfc7187c6fd608556f75f909dc0016cdd12  /var/backups/lifeos-stage/LIFEOS_VIDEO_RECOVERY_REVIEWED_2026-11-04.json' | sha256sum -c -
echo '2746296c2604b5d952ca7456fce1e39bd9a96f58aa86654c986212f8f93ab0ae  /var/backups/lifeos-stage/browser-recovery-20261104.json' | sha256sum -c -
python3 "$src/advance_untimed_plan_lab.py" "$inventory" "$timed_lab" "$untimed_lab"
python3 "$src/import_video_evidence_lab.py" "$export_json" "$untimed_lab" "$full_lab"
[[ "$(sqlite3 "$full_lab" 'PRAGMA integrity_check;')" == ok ]] || {
  echo 'ERROR: final isolated lab integrity check failed' >&2
  exit 1
}
[[ -z "$(sqlite3 "$full_lab" 'PRAGMA foreign_key_check;')" ]] || {
  echo 'ERROR: final isolated lab foreign key check failed' >&2
  exit 1
}
chmod 600 "$export_json" "$untimed_lab" "$full_lab" \
  "$untimed_lab.manifest.json" "$full_lab.evidence.json"
systemctl start lifeos-stage-offsite.service
systemctl show lifeos-stage-offsite.service -p Result -p ExecMainStatus --no-pager
echo 'RECOVERY CONSOLIDATED AND BACKED UP IN PRIVATE OFFSITE; NO LIVE DB CUTOVER'
