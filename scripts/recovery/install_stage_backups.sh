#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Must run as root" >&2; exit 1; }
script=/opt/lifeos/source/scripts/recovery/backup_stage.sh
[ -f "$script" ] || { echo "Missing backup_stage.sh" >&2; exit 1; }
install -m 0700 "$script" /usr/local/sbin/lifeos-stage-backup
cat >/etc/systemd/system/lifeos-stage-backup.service <<'UNIT'
[Unit]
Description=Validated LIFE OS staging-only backup
After=lifeos-recovery-stage.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/sbin/lifeos-stage-backup
NoNewPrivileges=true
PrivateTmp=true
UNIT
cat >/etc/systemd/system/lifeos-stage-backup.timer <<'UNIT'
[Unit]
Description=Daily local LIFE OS staging backup

[Timer]
OnCalendar=*-*-* 03:20:00 UTC
RandomizedDelaySec=10m
Persistent=true
Unit=lifeos-stage-backup.service

[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now lifeos-stage-backup.timer
systemctl start lifeos-stage-backup.service
systemctl --no-pager --full status lifeos-stage-backup.service | head -n 14
systemctl list-timers --all lifeos-stage-backup.timer
echo 'NOTE: Staging backup is local to this VPS, not an offsite copy.'
