#!/usr/bin/env bash
# Isolated recovery candidate only. Does not expose API / switch service.
set -euo pipefail
umask 077
[[ "$(id -u)" == 0 ]]
source_dir=/opt/lifeos/source
backup=/var/backups/lifeos-stage
candidate=/opt/lifeos/recovery-candidate
pb=/opt/lifeos/pocketbase
[[ -f "$backup/browser-salvage-20261104.sqlite" ]]
[[ -f "$backup/browser-recovered-plans-lab-20261104.sqlite" ]]
[[ -f "$backup/browser-recovery-20261104.json" ]]
[[ -x "$pb" ]]
[[ "$(sha256sum "$backup/browser-recovery-20261104.json" | cut -d' ' -f1)" == "2746296c2604b5d952ca7456fce1e39bd9a96f58aa86654c986212f8f93ab0ae" ]] || {
  echo "BLOCKED: source browser export checksum mismatch"; exit 1;
}
echo "Step 1: recover eligible date-only plans without timestamp invention"
if [[ ! -e "$backup/browser-recovered-dated-lab-20261104.sqlite" ]]; then
  python3 "$source_dir/scripts/recovery/advance_untimed_plan_lab.py" \
    "$backup/browser-salvage-20261104.sqlite" \
    "$backup/browser-recovered-plans-lab-20261104.sqlite" \
    "$backup/browser-recovered-dated-lab-20261104.sqlite"
fi
input="$backup/browser-recovered-dated-lab-20261104.sqlite"
python3 - "$input" <<'PY'
import sqlite3,sys
db=sqlite3.connect("file:"+sys.argv[1]+"?mode=ro",uri=True)
assert db.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
assert db.execute("PRAGMA foreign_key_check").fetchall()==[]
assert db.execute("select count(*) from profiles").fetchone()[0]==1
assert db.execute("select count(*) from records").fetchone()[0]>=3276
assert db.execute("select count(*) from plans").fetchone()[0]>=515
print("CHECKED: restore source integrity and counts",flush=True)
PY
echo "Step 2: construct independent production-candidate database"
if [[ -e "$candidate/pb_data/data.db" ]]; then
  echo "BLOCKED: candidate DB already exists, refusing overwrite"
  exit 1
fi
install -d -m 0700 "$candidate" "$candidate/pb_data"
cp -a "$source_dir/pb_migrations" "$candidate/pb_migrations"
cp -a "$source_dir/pb_hooks" "$candidate/pb_hooks"
python3 - "$input" "$candidate/pb_data/data.db" <<'PY'
import os,sqlite3,sys
src,dst=sys.argv[1:]
inp=sqlite3.connect("file:"+src+"?mode=ro",uri=True)
out=sqlite3.connect(dst)
try:inp.backup(out)
finally:inp.close();out.close()
os.chmod(dst,0o600)
print("Candidate DB copied with SQLite backup API")
PY
echo "Step 3: apply migration on independent candidate only"
"$pb" migrate up --dir="$candidate/pb_data" \
  --migrationsDir="$candidate/pb_migrations" \
  --hooksDir="$candidate/pb_hooks"
python3 - "$candidate/pb_data/data.db" <<'PY'
import sqlite3,sys
c=sqlite3.connect(sys.argv[1])
assert c.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
assert c.execute("PRAGMA foreign_key_check").fetchall()==[]
for table,min_count in (("profiles",1),("categories",125),("tags",8),("plans",515),("records",3276)):
  n=c.execute("SELECT count(*) FROM "+table).fetchone()[0]
  assert n>=min_count,(table,n)
  print("CANDIDATE "+table.upper()+"="+str(n))
assert c.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name='idx_records_one_open_primary_per_owner'").fetchone()[0]==1
assert c.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' AND name LIKE 'trg_records_running_end_%'").fetchone()[0]==2
assert c.execute("SELECT count(*) FROM profiles WHERE email!='' AND password!=''").fetchone()[0]==0
print("PASS: candidate integrity, schema and singleton invariant. Auth NOT yet provisioned.")
PY
# Keep the private data closed and unreadable by public service for now.
chown -R root:root "$candidate"
chmod 0700 "$candidate" "$candidate/pb_data"
chmod 0600 "$candidate/pb_data/data.db"
systemctl start lifeos-stage-offsite.service
echo "PASS: isolated production candidate and offsite backup completed; active service unchanged."
