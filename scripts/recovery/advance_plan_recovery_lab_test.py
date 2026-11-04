#!/usr/bin/env python3
"""CI-only disposable test: plan recovery must not touch staging or fabricate IDs."""
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile

HERE=pathlib.Path(__file__).parent
OWNER="abcdefghijklmno"

def entry(data):
    return json.dumps(data,ensure_ascii=False,separators=(",",":"))

def execute(script,*args):
    subprocess.run([sys.executable,str(HERE/script),*[str(a) for a in args]],check=True)

def main(empty_db):
    with tempfile.TemporaryDirectory() as tmp:
        folder=pathlib.Path(tmp)
        inv=folder/"inventory.sqlite"
        existing=folder/"base-lab.sqlite"
        output=folder/"plans-lab.sqlite"
        c=sqlite3.connect(inv)
        c.executescript("""
        CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);
        CREATE TABLE categories (pb_id TEXT PRIMARY KEY,business_id TEXT,owner_id TEXT,status TEXT,raw TEXT);
        CREATE TABLE records (pb_id TEXT PRIMARY KEY,business_id TEXT,owner_id TEXT,status TEXT,raw TEXT);
        CREATE TABLE plan_versions (n INTEGER PRIMARY KEY AUTOINCREMENT,pb_id TEXT,business_id TEXT,cache_day TEXT,legacy_category_id TEXT,status TEXT,raw TEXT);
        """)
        c.executemany("INSERT INTO metadata VALUES (?,?)",
            [("inventory_format","lifeos-salvage-v1"),("owner_pb_id",OWNER),("source_sha256","synthetic-fixture")])
        cat={"id":"cat111111111111","category_id":"synthetic-category","name":"Synthetic",
             "user_id":OWNER}
        c.execute("INSERT INTO categories VALUES (?,?,?,?,?)",
            (cat["id"],cat["category_id"],OWNER,"candidate",entry(cat)))
        for i in (1,2):
            rec={
              "id":"rec"+str(i)*12,"record_id":"biz-rec-"+str(i),"user_id":OWNER,
              "title":"Test source record "+str(i),"type":"record","status":"stopped",
              "start_time":"2026-09-21 10:00:00.000Z",
              "end_time":"2026-09-21 11:00:00.000Z",
              "category_id":"synthetic-category","category_link":cat["id"],
              "source_plan_id":"plan11111111111",
            }
            c.execute("INSERT INTO records VALUES (?,?,?,?,?)",
                (rec["id"],rec["record_id"],OWNER,"candidate",entry(rec)))
        base={
          "pocketRecordId":"plan11111111111","plan_row_id":"plan-uuid-good",
          "title":"Recovered plan test","categoryId":12345,"category_id":12345,
          "start_utc":"2026-09-21T09:00:00.000Z","end_utc":"2026-09-21T10:00:00.000Z",
          "dateKey":"2026-09-21","is_done":False,"isSynced":True,
          "notes_delta":'[{"insert":"hello"}]',
          "tags":[{"pocket_id":"tag111111111111","tag_id":1,
                   "name":"task","domain":"plan","sort_order":0}],
        }
        old=dict(base,pocketRecordId="plan22222222222",
                 plan_row_id="plan-uuid-old",start_utc=None,end_utc=None)
        for p in (base,old,old):
            c.execute("INSERT INTO plan_versions (pb_id,business_id,cache_day,legacy_category_id,status,raw) VALUES (?,?,?,?,?,?)",
              (p["pocketRecordId"],p["plan_row_id"],"2026-09-21",str(p["categoryId"]),"candidate",entry(p)))
        c.commit()
        c.close()

        execute("restore_browser_clone.py",inv,empty_db,existing)
        execute("advance_plan_recovery_lab.py",inv,existing,output)
        db=sqlite3.connect(output)
        assert db.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
        assert db.execute("PRAGMA foreign_key_check").fetchall()==[]
        assert db.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==1
        assert db.execute("SELECT COUNT(*) FROM tags").fetchone()[0]==1
        assert db.execute("SELECT COUNT(*) FROM records WHERE source_plan_id='plan11111111111'").fetchone()[0]==2
        assert db.execute("SELECT COUNT(*) FROM plans WHERE category_id='cat111111111111'").fetchone()[0]==1
        assert db.execute("SELECT tags_link,notes_delta FROM plans").fetchone()==(
            '["tag111111111111"]','[{"insert":"hello"}]')
        db.close()
        src=sqlite3.connect(existing)
        assert src.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==0
        assert src.execute("SELECT COUNT(*) FROM records WHERE source_plan_id != ''").fetchone()[0]==0
        src.close()
        report=json.loads(output.with_suffix('.manifest.json').read_text())
        assert report["plan_records_imported"]==1
        assert report["plan_versions_deferred"]==2
        assert report["proven_category_mappings"]==1
        assert report["original_auth_credentials_recovered"] is False
        result=subprocess.run([sys.executable,str(HERE/"advance_plan_recovery_lab.py"),
                str(inv),str(existing),str(output)],capture_output=True,text=True)
        assert result.returncode!=0 and "overwrite" in result.stderr
        print("PASS: plan/category evidence mapping, tag ID preservation, source link repair, duplicate quarantine, and source safety.")

if __name__=="__main__":
    assert len(sys.argv)==2,"require clean PocketBase data.db"
    main(sys.argv[1])
