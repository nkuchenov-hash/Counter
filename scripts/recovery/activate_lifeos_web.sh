#!/usr/bin/env bash
# User-authorized replacement LIFE OS web recovery, no Beget dependency.
# Run locally on LIFEOS2 through interactive ssh -tt as root.
# Never delete original phone app, browser caches, SQLite salvage or old stage.
set -euo pipefail
umask 077
[ "$(id -u)" = 0 ]
[ -t 0 ] || { echo 'Run through ssh -tt to create your own login password'; exit 2; }
SRC=/opt/lifeos/source
BASE=/opt/lifeos/recovery-candidate
ARCH=/var/backups/lifeos-stage
PB=/opt/lifeos/pocketbase
DOMAIN=137-22-146-109.sslip.io
SITE=/var/www/lifeos-recovery
[ -f "$ARCH/browser-recovered-plans-lab-20261104.sqlite" ]
if [ ! -s "$BASE/pb_data/data.db" ]; then
  echo 'Preparing recovered records, categories, tags and plans...'
  bash "$SRC/scripts/recovery/build_live_candidate.sh"
fi
OWNER=$(python3 - "$ARCH/browser-salvage-20261104.sqlite" <<'PY'
import sqlite3,sys
c=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
owner=dict(c.execute('SELECT key,value FROM metadata'))['owner_pb_id']
assert len(owner)==15
print(owner)
PY
)
export LIFEOS_RECOVERY_OWNER_ID="$OWNER"

if [ ! -f "$BASE/owner-provisioned.marker" ]; then
  read -r -p 'LIFE OS login email: ' LIFEOS_OWNER_EMAIL < /dev/tty
  read -r -s -p 'NEW LIFE OS password (12+ characters): ' LIFEOS_OWNER_PASSWORD < /dev/tty
  printf '\n'
  # SSH/Windows terminals may leave a CR or invisible whitespace after the email.
  LIFEOS_OWNER_EMAIL=$(printf '%s' "$LIFEOS_OWNER_EMAIL" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
  [[ "$LIFEOS_OWNER_EMAIL" =~ ^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$ ]] || { echo 'Invalid login email format (after normalization).'; exit 2; }
  [ "$(printf %s "$LIFEOS_OWNER_PASSWORD" | wc -c)" -ge 12 ] || { echo 'Password must contain at least 12 characters.'; exit 2; }
  export LIFEOS_OWNER_EMAIL LIFEOS_OWNER_PASSWORD
  cat > "$BASE/pb_migrations/1793832010_claim_recovery_owner.js" <<'JS'
migrate((app) => {
  const id = $os.getenv('LIFEOS_RECOVERY_OWNER_ID');
  const email = String($os.getenv('LIFEOS_OWNER_EMAIL') || '').trim().toLowerCase();
  const password = String($os.getenv('LIFEOS_OWNER_PASSWORD') || '');
  if (!/^[a-z0-9]{15}$/.test(id) || !email.includes('@') || password.length < 12) {
    throw new Error('Recovery login credentials missing');
  }
  const profile = app.findRecordById('profiles', id);
  if (String(profile.get('email') || '').trim()) {
    throw new Error('Refusing to overwrite a real account');
  }
  profile.set('email', email);
  if (String(profile.get('email') || '') !== email) {
    throw new Error('Recovery email did not survive PocketBase field normalization');
  }
  profile.setPassword(password);
  profile.setVerified(true);
  app.save(profile);
}, (app) => { throw new Error('Identity recovery cannot be rolled back'); });
JS
  "$PB" migrate up --dir="$BASE/pb_data" --migrationsDir="$BASE/pb_migrations" --hooksDir="$BASE/pb_hooks"
  touch "$BASE/owner-provisioned.marker"
  chmod 600 "$BASE/owner-provisioned.marker"
fi

# Keep code/migrations root-owned; allow service account to traverse candidate folder.
chown root:lifeos "$BASE"
chmod 750 "$BASE"
chown -R lifeos:lifeos "$BASE/pb_data"
chmod 700 "$BASE/pb_data"
cat >/etc/systemd/system/lifeos-recovery-live.service <<UNIT
[Unit]
Description=LIFE OS restored PocketBase
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=lifeos
Group=lifeos
WorkingDirectory=$BASE
ExecStart=$PB serve --http=127.0.0.1:8102 --dir=$BASE/pb_data --migrationsDir=$BASE/pb_migrations --hooksDir=$BASE/pb_hooks
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
ProtectSystem=full
ReadWritePaths=$BASE/pb_data
PrivateTmp=true
[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now lifeos-recovery-live.service
for n in $(seq 1 20); do
  if curl -fsS --max-time 2 http://127.0.0.1:8102/api/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -fsS --max-time 5 http://127.0.0.1:8102/api/health >/dev/null
if [ -n "$(printenv LIFEOS_OWNER_PASSWORD || true)" ]; then
python3 - <<'PY'
import json,os,urllib.request
base='http://127.0.0.1:8102'
data=json.dumps({'identity':os.environ['LIFEOS_OWNER_EMAIL'],'password':os.environ['LIFEOS_OWNER_PASSWORD']}).encode()
req=urllib.request.Request(base+'/api/collections/profiles/auth-with-password',data=data,headers={'Content-Type':'application/json'})
with urllib.request.urlopen(req,timeout=12) as r: auth=json.load(r)
assert auth['record']['id']==os.environ['LIFEOS_RECOVERY_OWNER_ID']
for name,minimum in [('records',3276),('categories',125),('plans',515),('tags',8)]:
    req=urllib.request.Request(base+'/api/collections/'+name+'/records?perPage=1',headers={'Authorization':auth['token']})
    with urllib.request.urlopen(req,timeout=15) as r: result=json.load(r)
    assert result['totalItems']>=minimum,(name,result['totalItems'])
    print(name.upper(),result['totalItems'])
print('PASS: original profile login and restored data')
PY
unset LIFEOS_OWNER_PASSWORD LIFEOS_OWNER_EMAIL
fi

if [ ! -f "$SITE/Counter/main.dart.js" ]; then
  WEB_TMP=$(mktemp -d /tmp/lifeos-web-XXXXXX)
  trap 'rm -rf "$WEB_TMP"' EXIT
  git clone -q --depth=1 --branch gh-pages https://github.com/nkuchenov-hash/Counter.git "$WEB_TMP/pages"
  mkdir -p "$SITE/Counter"
  python3 - "$WEB_TMP/pages" "$SITE/Counter" "$DOMAIN" <<'PY'
import pathlib,shutil,sys
src,dest=map(pathlib.Path,sys.argv[1:3])
shutil.copytree(src,dest,dirs_exist_ok=True,ignore=shutil.ignore_patterns('.git'))
old=b'https://217-114-0-201.sslip.io'
new=('https://'+sys.argv[3]).encode()
main=dest/'main.dart.js'
raw=main.read_bytes()
assert old in raw, 'Original backend URL missing from web bundle; refusing unpatched launch'
main.write_bytes(raw.replace(old,new))
for name in ('index.html','flutter_bootstrap.js','canvaskit/canvaskit.wasm'):
    assert (dest/name).is_file(),name
print('PASS: original LIFE OS Flutter web assets point to the recovered PocketBase URL')
PY
  chmod -R a+rX "$SITE"
fi
# Consistent SQLite backup from live candidate BEFORE making API accessible.
python3 - "$BASE/pb_data/data.db" "$ARCH/recovered-live-ready-$(date -u +%Y%m%dT%H%M%SZ).sqlite" <<'PY'
import sqlite3,sys,os
source=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
target=sqlite3.connect(sys.argv[2])
try:source.backup(target)
finally:source.close();target.close()
os.chmod(sys.argv[2],0o600)
PY
systemctl start lifeos-stage-offsite.service
cp -a /etc/caddy/Caddyfile "/etc/caddy/Caddyfile.before-lifeos-$(date -u +%Y%m%dT%H%M%SZ)"
# Preserve unrelated Caddy sites; the recovery domain must not be preconfigured.
if grep -Fq "$DOMAIN" /etc/caddy/Caddyfile; then
  echo "BLOCKED: recovery domain already exists in Caddyfile. Inspect before editing."
  exit 1
fi
cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.new-lifeos
printf '\n' >> /etc/caddy/Caddyfile.new-lifeos
cat >>/etc/caddy/Caddyfile.new-lifeos <<CADDY
$DOMAIN {
    encode gzip zstd
    @admin path /_/ /_/*
    handle @admin {
        respond "Admin dashboard not public" 403
    }
    handle /api/* {
        reverse_proxy 127.0.0.1:8102
    }
    @home path /
    redir @home /Counter/ 302
    handle {
        root * $SITE
        try_files {path} /Counter/index.html
        file_server
    }
}
CADDY
caddy validate --config /etc/caddy/Caddyfile.new-lifeos --adapter caddyfile
cp /etc/caddy/Caddyfile.new-lifeos /etc/caddy/Caddyfile
systemctl reload caddy
curl -fsS --max-time 15 "https://$DOMAIN/api/health" >/dev/null
curl -fsS --max-time 15 "https://$DOMAIN/Counter/" >/dev/null
curl -fsS --max-time 15 "https://$DOMAIN/Counter/flutter_bootstrap.js" >/dev/null
python3 - "$DOMAIN" <<'PY'
import json,sys,urllib.request,urllib.error
url='https://'+sys.argv[1]+'/api/collections/records/records?perPage=1'
try:
  with urllib.request.urlopen(url,timeout=15) as response:
    payload=json.load(response)
  assert payload.get('items')==[], 'Anonymous users must never see private record contents'
except urllib.error.HTTPError as e:
  assert e.code in (401,403,404),('Unexpected public API response',e.code)
print('PASS: anonymous record access exposes no user data')
PY
echo "SUCCESS: https://$DOMAIN/Counter/"
echo 'Sign in with the email and new password chosen in this SSH session.'
echo 'Old Android app and original backup archives remain untouched.'
