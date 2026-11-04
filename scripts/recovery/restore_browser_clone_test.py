#!/usr/bin/env python3
"""CI synthetic data test of isolated clone import using real fresh PocketBase schema."""
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile

def row(kind, value):
    return json.dumps(value,separators=(',', ':'),ensure_ascii=False)

def main(schema_db):
    owner="abcdefghijklmno"
    with tempfile.TemporaryDirectory() as tmp:
        root=pathlib.Path(tmp)
        inv=root/'inventory.sqlite'
        db=sqlite3.connect(inv)
        db.executescript("""
            CREATE TABLE metadata (key TEXT PRIMARY KEY,value TEXT NOT NULL);
            CREATE TABLE categories (pb_id TEXT PRIMARY KEY,business_id TEXT,owner_id TEXT,status TEXT,raw TEXT);
            CREATE TABLE records (pb_id TEXT PRIMARY KEY,business_id TEXT,owner_id TEXT,status TEXT,raw TEXT);
        """)
        db.executemany("INSERT INTO metadata VALUES (?,?)", [
            ("inventory_format","lifeos-salvage-v1"), ("owner_pb_id",owner),
            ("source_sha256","ci-test-only")
        ])
        cats=[
            {"id":"cat111111111111","category_id":"safe","name":"Safe","user_id":owner},
            {"id":"cat222222222222","category_id":"duplicate","name":"Duplicate A","user_id":owner},
            {"id":"cat333333333333","category_id":"duplicate","name":"Duplicate B","user_id":owner},
        ]
        for c in cats:
            db.execute("INSERT INTO categories VALUES (?,?,?,?,?)", (c['id'],c['category_id'],owner,'candidate',row('categories',c)))
        recs=[
            {"id":"rec111111111111","record_id":"unique-record","user_id":owner,
             "title":"Recovered offline","type":"record","status":"stopped",
             "start_time":"2026-09-21 10:00:00.000Z","end_time":"2026-09-21 11:00:00.000Z",
             "category_id":"safe","category_link":"cat111111111111",
             "source_plan_id":"missing-plan"},
            {"id":"rec222222222222","record_id":"duplicate-record","user_id":owner,
             "title":"Conflicting A","type":"record","status":"stopped",
             "start_time":"2026-09-21 10:00:00.000Z",
             "category_id":"cat111111111111","category_link":"cat111111111111"},
            {"id":"rec333333333333","record_id":"duplicate-record","user_id":owner,
             "title":"Conflicting B","type":"record","status":"stopped",
             "start_time":"2026-09-21 10:00:00.000Z",
             "category_id":"cat111111111111","category_link":"cat111111111111"},
            {"id":"rec444444444444","record_id":"cat-quarantine","user_id":owner,
             "title":"Ambiguous category","type":"record","status":"stopped",
             "start_time":"2026-09-21 10:00:00.000Z",
             "category_id":"cat222222222222","category_link":"cat222222222222"},
        ]
        for r in recs:
            db.execute("INSERT INTO records VALUES (?,?,?,?,?)",
              (r["id"],r["record_id"],owner,'candidate',row('records',r)))
        db.commit()
        db.close()
        target=root/'lab.sqlite'
        script=pathlib.Path(__file__).with_name('restore_browser_clone.py')
        subprocess.run([sys.executable,str(script),str(inv),str(schema_db),str(target)],check=True)
        lab=sqlite3.connect(target)
        assert lab.execute("SELECT COUNT(*) FROM profiles").fetchone()[0]==1
        assert lab.execute("SELECT COUNT(*) FROM categories").fetchone()[0]==1
        assert lab.execute("SELECT COUNT(*) FROM records").fetchone()[0]==1
        rec=lab.execute("SELECT id,record_id,category_id,category_link,source_plan_id FROM records").fetchone()
        assert rec==("rec111111111111","unique-record","cat111111111111","cat111111111111","")
        assert lab.execute("PRAGMA integrity_check").fetchone()[0]=='ok'
        lab.close()
        manifest=json.loads(target.with_suffix('.manifest.json').read_text())
        assert manifest['records_quarantined']==3
        assert manifest['categories_quarantined']==2
        assert manifest['production_ready'] is False
        result=subprocess.run([sys.executable,str(script),str(inv),str(schema_db),str(target)],
             capture_output=True,text=True)
        assert result.returncode!=0 and 'overwrite' in result.stderr
        print('PASS: isolated clone import, exact original IDs, category relation repair, duplicate quarantine, source protection.')
if __name__=='__main__':
    assert len(sys.argv)==2,'expected empty PocketBase schema data.db path'
    main(sys.argv[1])
