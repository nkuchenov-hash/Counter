#!/usr/bin/env bash
set -euo pipefail

# Safe staging only: no change to the old production PocketBase URL or data.
# Ubuntu 24.04 + /opt/lifeos/pocketbase v0.40.6 + recovery GitHub branch.

if [ "$(id -u)" -ne 0 ]; then echo 'ERROR: run as root' >&2; exit 1; fi
PB=/opt/lifeos/pocketbase
SRC=/opt/lifeos/source
STAGE=/opt/lifeos/recovery-stage
if [ ! -x "$PB" ] || [ ! -d "$SRC/pb_migrations" ] || [ ! -d "$SRC/pb_hooks" ]; then
  echo 'ERROR: PocketBase binary or source hooks/migrations missing' >&2; exit 1
fi
if [ ! -f "$SRC/pb_migrations/1785000000_bootstrap_core_collections.js" ]; then
  echo 'ERROR: recovery branch not checked out; no action taken' >&2; exit 1
fi
if [ -e /opt/lifeos/pb_data/data.db ]; then
  echo 'NOTICE: untouched existing production DB found in /opt/lifeos/pb_data' >&2
fi
mkdir -p "$STAGE" "$STAGE/pb_data"
cp -a "$SRC/pb_hooks" "$STAGE/"
cp -a "$SRC/pb_migrations" "$STAGE/"
"$PB" migrate up --dir="$STAGE/pb_data" --migrationsDir="$STAGE/pb_migrations"
sqlite3 "$STAGE/pb_data/data.db" 'PRAGMA integrity_check;' | grep -Fx ok
for table in profiles categories tags plans records; do
  [ "$(sqlite3 "$STAGE/pb_data/data.db" "SELECT COUNT(*) FROM _collections WHERE name='$table';")" = 1 ] || {
    echo "ERROR: missing table $table" >&2; exit 1;
  }
done
if ! getent passwd lifeos >/dev/null; then
  useradd --system --home /opt/lifeos --shell /usr/sbin/nologin lifeos
fi
chown root:lifeos "$STAGE"
chmod 0750 "$STAGE"
chown -R lifeos:lifeos "$STAGE/pb_data"
chmod 0700 "$STAGE/pb_data"
cat >/etc/systemd/system/lifeos-recovery-stage.service <<'UNIT'
[Unit]
Description=LIFE OS PocketBase recovery staging (localhost only)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=lifeos
Group=lifeos
WorkingDirectory=/opt/lifeos/recovery-stage
ExecStart=/opt/lifeos/pocketbase serve --http=127.0.0.1:8099 --dir=/opt/lifeos/recovery-stage/pb_data --migrationsDir=/opt/lifeos/recovery-stage/pb_migrations --hooksDir=/opt/lifeos/recovery-stage/pb_hooks
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
ReadWritePaths=/opt/lifeos/recovery-stage/pb_data
PrivateTmp=true

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now lifeos-recovery-stage.service
for attempt in 1 2 3 4 5 6; do
  if curl --fail --silent --show-error --max-time 2 http://127.0.0.1:8099/api/health; then
    echo
    echo 'SUCCESS: staging is live on 127.0.0.1:8099 only; production URL unchanged.'
    exit 0
  fi
  sleep 1
done
systemctl --no-pager status lifeos-recovery-stage.service || true
echo 'STAGING FAILED: see journalctl -u lifeos-recovery-stage.service -n 60' >&2
exit 1
