#!/usr/bin/env bash
# One-time, evidence-bound repair of the recovered owner profile's user_id.
# The recovered profile id and collection relation IDs must NEVER be replaced.
set -euo pipefail
umask 077
[ "$(id -u)" -eq 0 ] || { echo 'Run this recovery repair as root.' >&2; exit 2; }
BASE=/opt/lifeos/recovery-candidate
ARCH=/var/backups/lifeos-stage
PB=/opt/lifeos/pocketbase
SERVICE=lifeos-recovery-live.service
DB="$BASE/pb_data/data.db"
SALVAGE="$ARCH/browser-salvage-20261104.sqlite"
MIGRATION="$BASE/pb_migrations/1793832030_restore_profile_user_id.js"
[ -s "$DB" ] && [ -s "$SALVAGE" ] && [ -f "$BASE/owner-provisioned.marker" ] || {
  echo 'BLOCKED: verified recovered database, owner marker or source inventory missing.'
  exit 2
}
OWNER="$(python3 - "$SALVAGE" <<'PY'
import sqlite3,sys,re
db=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
owner=dict(db.execute('SELECT key,value FROM metadata'))['owner_pb_id']
assert re.fullmatch(r'[a-z0-9]{15}',owner), 'Invalid source owner ID'
print(owner)
PY
)"
export LIFEOS_RECOVERY_OWNER_ID="$OWNER"
# Read-only preflight. Not even the profile field is changed before this passes.
CURRENT="$(python3 - "$DB" "$OWNER" <<'PY'
import sqlite3,sys
db=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
owner=sys.argv[2]
assert db.execute('PRAGMA quick_check').fetchone()[0]=='ok', 'SQLite integrity failed'
assert db.execute('SELECT COUNT(*) FROM profiles').fetchone()[0]==1, 'Not a single-owner recovery'
p=db.execute('SELECT user_id,email,password FROM profiles WHERE id=?',(owner,)).fetchone()
assert p and '@' in (p[1] or '') and bool(p[2]), 'Recovered auth profile missing'
assert (p[0] or '') in ('',owner), 'Conflicting existing user_id; refusing overwrite'
for table,minimum in [('categories',125),('records',3276),('plans',1102),('tags',8)]:
    count=db.execute('SELECT COUNT(*) FROM '+table).fetchone()[0]
    assert count>=minimum,(table,'unexpected loss of restored rows',count)
    wrong=db.execute('SELECT COUNT(*) FROM '+table+' WHERE user_id IS NULL OR user_id<>?',(owner,)).fetchone()[0]
    assert wrong==0,(table,'owner mismatch; refusing to alter identity',wrong)
print(p[0] or '')
PY
)"
if [ "$CURRENT" = "$OWNER" ]; then
  echo 'PASS: owner profile user_id already matches recovered data; no database change needed.'
  systemctl is-active --quiet "$SERVICE"
  curl -fsS --max-time 5 http://127.0.0.1:8102/api/health
  exit 0
fi
echo 'PASS: owner and all restored collection relations match; missing profile user_id confirmed.'
# Stop PocketBase before copying the active SQLite database and applying migrations.
systemctl stop "$SERVICE"
trap 'systemctl start lifeos-recovery-live.service >/dev/null 2>&1 || true' EXIT
BACKUP="$ARCH/recovered-before-profile-user-id-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
python3 - "$DB" "$BACKUP" <<'PY'
import sqlite3,sys,os
src=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
dst=sqlite3.connect(sys.argv[2])
try: src.backup(dst)
finally: src.close(); dst.close()
os.chmod(sys.argv[2],0o600)
check=sqlite3.connect('file:'+sys.argv[2]+'?mode=ro',uri=True)
assert check.execute('PRAGMA integrity_check').fetchone()[0]=='ok','Pre-repair backup failed integrity check'
check.close()
print('PASS: consistent pre-repair backup saved and verified.')
PY
if [ ! -f "$MIGRATION" ]; then
  cat > "$MIGRATION" <<'JS'
migrate((app) => {
  const owner = String($os.getenv('LIFEOS_RECOVERY_OWNER_ID') || '');
  if (!/^[a-z0-9]{15}$/.test(owner)) throw new Error('Missing verified recovery owner');
  const profile = app.findRecordById('profiles', owner);
  const previous = String(profile.get('user_id') || '').trim();
  if (previous && previous !== owner) throw new Error('Existing user_id conflicts with recovery owner');
  if (!String(profile.get('email') || '').includes('@')) throw new Error('Recovery auth not provisioned');
  profile.set('user_id', owner);
  app.save(profile);
}, (app) => { throw new Error('Recovery owner identity repair is not reversible'); });
JS
fi
chgrp lifeos "$MIGRATION"
chmod 640 "$MIGRATION"
chgrp -R lifeos "$BASE/pb_migrations" "$BASE/pb_hooks"
chmod -R g+rX "$BASE/pb_migrations" "$BASE/pb_hooks"
"$PB" migrate up --dir="$BASE/pb_data" --migrationsDir="$BASE/pb_migrations" --hooksDir="$BASE/pb_hooks"
python3 - "$DB" "$OWNER" <<'PY'
import sqlite3,sys
db=sqlite3.connect('file:'+sys.argv[1]+'?mode=ro',uri=True)
assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok','Post-repair SQLite integrity failed'
assert db.execute('PRAGMA foreign_key_check').fetchall()==[], 'Post-repair foreign keys failed'
assert db.execute('SELECT user_id FROM profiles WHERE id=?',(sys.argv[2],)).fetchone()==(sys.argv[2],),'Profile owner still missing'
for t,n in [('profiles',1),('records',3276),('plans',1102),('categories',125),('tags',8)]:
    count=db.execute('SELECT COUNT(*) FROM '+t).fetchone()[0]
    assert count>=n,(t,count)
    print('VERIFIED',t,count)
print('PASS: profile user_id restored to original PB id; all related data preserved.')
PY
systemctl start "$SERVICE"
for i in $(seq 1 15); do
  if curl -fsS --max-time 2 http://127.0.0.1:8102/api/health >/dev/null 2>&1; then break; fi
  sleep 1
done
curl -fsS --max-time 5 http://127.0.0.1:8102/api/health
echo
systemctl start lifeos-stage-offsite.service
trap - EXIT
echo 'SUCCESS: recovered profile identity repaired; refresh the LIFE OS page.'
