#!/usr/bin/env bash
set -euo pipefail
# Install scheduled offsite backup only after independently configured secrets.
[ "$(id -u)" -eq 0 ] || { echo "Run as root" >&2; exit 1; }
install -d -m 0700 /etc/lifeos
apt-get install -y restic
install -m 0700 /opt/lifeos/source/scripts/recovery/sync_offsite_stage.sh /usr/local/sbin/lifeos-stage-offsite
cat >/etc/systemd/system/lifeos-stage-offsite.service <<'UNIT'
[Unit]
Description=Send encrypted LIFE OS staging backups to independent cloud
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/sbin/lifeos-stage-offsite
NoNewPrivileges=true
PrivateTmp=true
UNIT
cat >/etc/systemd/system/lifeos-stage-offsite.timer <<'UNIT'
[Unit]
Description=Daily offsite LIFE OS staging backup

[Timer]
OnCalendar=*-*-* 04:20:00 UTC
RandomizedDelaySec=10m
Persistent=true
Unit=lifeos-stage-offsite.service

[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
if [ ! -f /etc/lifeos/offsite-backup.env ]; then
  echo "OFFSITE NOT ENABLED: independent S3 storage not yet configured."
  exit 0
fi
systemctl start lifeos-stage-offsite.service
systemctl enable --now lifeos-stage-offsite.timer
echo "SUCCESS: offsite backup verified once and daily timer enabled."
