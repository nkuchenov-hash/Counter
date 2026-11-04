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
  // The preserved owner ID is also the value used by records/categories/plans.
  // Without this field, Flutter rejects the recovered profile after successful login.
  profile.set('user_id', id);
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

# Keep code/migrations root-owned while allowing PocketBase's lifeos service to read them.
# The newly generated owner-recovery migration is created under umask 077.
# Without granting group access, PocketBase panics on registration and auto-restarts.
chown root:lifeos "$BASE"
chmod 750 "$BASE"
chgrp -R lifeos "$BASE/pb_migrations" "$BASE/pb_hooks"
chmod -R g+rX "$BASE/pb_migrations" "$BASE/pb_hooks"
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
# Older recovered candidates claimed auth without populating profiles.user_id.
# Repair only this specific, verified one-owner recovery; the script is idempotent.
bash "$SRC/scripts/recovery/repair_profile_user_id.sh"
for n in $(seq 1 20); do
  if curl -fsS --max-time 2 http://127.0.0.1:8102/api/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -fsS --max-time 5 http://127.0.0.1:8102/api/health >/dev/null
# Every rerun must confirm the recovered profile exists, even after initial credential
# setup (when the original plaintext password is intentionally no longer available).
python3 - "$BASE/pb_data/data.db" "$LIFEOS_RECOVERY_OWNER_ID" <<'PY'
import sqlite3,sys
db=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
assert db.execute('PRAGMA quick_check').fetchone()[0]=='ok','Recovered SQLite quick_check failed'
owner=db.execute('SELECT email,password,user_id FROM profiles WHERE id=?',(sys.argv[2],)).fetchone()
assert owner and '@' in (owner[0] or '') and bool(owner[1]),'Recovered login missing'
assert owner[2]==sys.argv[2], 'Recovered profile user_id missing or mismatched'
for table,minimum in [('profiles',1),('records',3276),('categories',125),('plans',1102),('tags',8)]:
    count=db.execute('SELECT COUNT(*) FROM '+table).fetchone()[0]
    assert count>=minimum,(table,count)
    print('VERIFIED',table,count)
db.close()
print('PASS: recovery login exists and recovered database remains intact')
PY
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
# Patch the already published gh-pages HTML in place. Its original 12-second
# "app failed" timer can fire while downloading multi-megabyte Flutter assets.
# The original web build remains otherwise untouched (especially local caches).
python3 - "$SITE/Counter/index.html" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
html=p.read_text(encoding='utf-8')
old='      window.setTimeout(showBootFailure, 12000);'
new='      window.setTimeout(showBootFailure, 90000);'
if old in html:
    assert html.count(old)==1
    hint='''      window.setTimeout(function () {
        if (statusShown || document.querySelector('flutter-view, flt-glass-pane')) return;
        var hint = document.createElement('div');
        hint.id = 'lifeos-loading-hint';
        hint.textContent = 'Загрузка LIFE OS…';
        hint.style.cssText =
          'position:fixed;bottom:24px;left:0;right:0;text-align:center;' +
          'font:16px/1.5 Arial,sans-serif;color:#111;pointer-events:none;';
        document.body.appendChild(hint);
      }, 4000);
'''
    html=html.replace(old,hint+new)
    cleanup='        if (panel) panel.remove();'
    assert html.count(cleanup)==1
    html=html.replace(cleanup,cleanup+'''
        var hint = document.getElementById('lifeos-loading-hint');
        if (hint) hint.remove();''')
    p.write_text(html,encoding='utf-8')
    print('PASS: slow first-load displays progress; no misleading failure after 12 seconds')
elif new in html:
    print('PASS: slow-load HTML fix already installed')
else:
    raise SystemExit('BLOCKED: unexpected web loader layout; refusing to patch')
PY
# Caddy needs to traverse /var/www to serve $SITE/Counter, but the host
# originally had /var/www mode 0700 (root only). Grant traverse ONLY, not
# listing or write access, and leave all other children unchanged.
[ -d /var/www ] || { echo 'ERROR: expected /var/www missing'; exit 1; }
chmod o+x /var/www
chmod a+rx "$SITE" "$SITE/Counter"
if id caddy >/dev/null 2>&1 && command -v runuser >/dev/null 2>&1; then
  runuser -u caddy -- test -r "$SITE/Counter/index.html" || {
    echo 'ERROR: Caddy service account cannot read Flutter index.html'
    namei -l "$SITE/Counter/index.html"
    exit 1
  }
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
# Permit only our two known configurations: original health-only staging,
# or the exact live Caddyfile produced by this recovery script on a prior run.
# Never overwrite unknown domain configuration or unrelated Caddy sites.
CADDY_STAGE="$SRC/scripts/recovery/Caddyfile.health-only"
CADDY_NEXT=/etc/caddy/Caddyfile.new-lifeos
CADDY_ALREADY_LIVE=0
if grep -Fq "$DOMAIN" /etc/caddy/Caddyfile; then
  if cmp -s "$CADDY_STAGE" /etc/caddy/Caddyfile; then
    echo 'PASS: recognized original LIFE OS health-only staging Caddyfile; upgrading it to live app.'
    : > "$CADDY_NEXT"
  elif [ -f "$CADDY_NEXT" ] && cmp -s "$CADDY_NEXT" /etc/caddy/Caddyfile; then
    echo 'PASS: recognized previously installed LIFE OS live Caddyfile; retrying failed public checks.'
    CADDY_ALREADY_LIVE=1
  else
    echo 'BLOCKED: recovery domain exists in a nonstandard Caddyfile; refusing to modify existing routes.'
    exit 1
  fi
else
  cp /etc/caddy/Caddyfile "$CADDY_NEXT"
fi
if [ "$CADDY_ALREADY_LIVE" -eq 0 ]; then
  printf '\n' >> "$CADDY_NEXT"
  cat >>"$CADDY_NEXT" <<CADDY
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
fi
caddy validate --config /etc/caddy/Caddyfile.new-lifeos --adapter caddyfile
cp /etc/caddy/Caddyfile.new-lifeos /etc/caddy/Caddyfile
systemctl reload caddy
# Report which route fails instead of a bare "curl: HTTP 403".
for entry in 'HEALTH:/api/health' 'WEB:/Counter/' 'BOOTSTRAP:/Counter/flutter_bootstrap.js'; do
  label="${entry%%:*}"
  route="${entry#*:}"
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 15 "https://$DOMAIN$route") || {
    echo "FAILED: $label ($route) transport failure"
    exit 1
  }
  echo "PUBLIC_$label HTTP $code ($route)"
  if [ "$code" != 200 ]; then
    echo "FAILED: public $label check; inspect Caddy routes and file permissions before retrying."
    echo 'WEB FILE ACCESS:'
    namei -l "$SITE/Counter/index.html" || true
    exit 1
  fi
done
# A 200 on a URL can be an HTML fallback instead of the actual JS/WASM file.
# Probe type, transfer size and elapsed time for the large first-load assets.
for spec in 'MAIN:/Counter/main.dart.js:100000:javascript' 'CANVASKIT:/Counter/canvaskit/canvaskit.wasm:100000:wasm' 'CHROMIUM_CANVASKIT:/Counter/canvaskit/chromium/canvaskit.wasm:100000:wasm'; do
  name="${spec%%:*}"
  rest="${spec#*:}"
  route="${rest%%:*}"
  rest="${rest#*:}"
  min="${rest%%:*}"
  kind="${rest##*:}"
  response=$(curl -fsS --max-time 60 -o /dev/null -w '%{http_code} %{content_type} %{size_download} %{time_total}' "https://$DOMAIN$route") || {
    echo "FAILED: $name download request"; exit 1;
  }
  read -r code mime bytes seconds <<<"$response"
  echo "ASSET_$name: HTTP $code, type=$mime, bytes=$bytes, seconds=$seconds"
  if [ "$code" != 200 ] || [ "$bytes" -lt "$min" ]; then
    echo "FAILED: $name missing or unexpectedly small"; exit 1
  fi
  case "$kind:$mime" in
    javascript:*javascript*|javascript:*ecmascript*|wasm:application/wasm) ;;
    *) echo "FAILED: $name returned wrong media type (HTML fallback?)"; exit 1 ;;
  esac
done
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
