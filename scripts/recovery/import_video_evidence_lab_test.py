#!/usr/bin/env python3
"""Disposable PocketBase schema regression for screen-record recovery."""
import json
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
from restore_browser_clone import insert

OWNER="abcdefghijklmno"
def main(empty_pb):
    with tempfile.TemporaryDirectory() as directory:
        root=pathlib.Path(directory)
        base=root/"pre-video.sqlite"
        source=sqlite3.connect(f"file:{pathlib.Path(empty_pb).resolve()}?mode=ro",uri=True)
        target=sqlite3.connect(base)
        target.row_factory=sqlite3.Row
        source.backup(target)
        with target:
            insert(target,"profiles",{"id":OWNER,"email":""})
            insert(target,"categories",{
                "id":"life00000000001","name":"Life",
                "category_id":"life","user_id":OWNER
            })
            insert(target,"categories",{
                "id":"food00000000001","name":"Food",
                "category_id":"food","user_id":OWNER,
                "parent_id":"life00000000001"
            })
        source.close()
        target.close()
        assert base.is_file()
        sample={
            "completeness":"PARTIAL: reviewed frame subset",
            "source_video_sha256":"a"*64,
            "entries":[
              {"date_local":"2026-10-15","title":"Lunch",
               "category_path_visible":"Жизнь > Еда",
               "start_clock":"12:00","end_clock":"12:30",
               "timezone_label":"MSK","review_flag":"visible",
               "source_seconds_approx":10},
              {"date_local":"2026-10-15","title":"Still running",
               "category_path_visible":"Жизнь > Еда",
               "start_clock":"13:00","end_clock":None,
               "timezone_label":"MSK","review_flag":"running_as_displayed",
               "source_seconds_approx":14},
              {"date_local":"2026-10-15","title":"Confusing end",
               "category_path_visible":"Жизнь > Еда",
               "start_clock":"15:00","end_clock":"02:00",
               "timezone_label":"MSK","review_flag":"overnight_or_inconsistent_end",
               "source_seconds_approx":20},
              {"date_local":"2026-10-15","title":"No category",
               "category_path_visible":"Unknown > Here",
               "start_clock":"15:00","end_clock":"16:00",
               "timezone_label":"MSK","review_flag":"visible",
               "source_seconds_approx":21},
            ]
        }
        video=root/"screen.json"
        video.write_text(json.dumps(sample),encoding="utf8")
        output=root/"post-video.sqlite"
        script=pathlib.Path(__file__).with_name("import_video_evidence_lab.py")
        subprocess.run([sys.executable,str(script),str(video),str(base),str(output)],check=True)
        db=sqlite3.connect(output)
        row=db.execute("SELECT title,start_time,end_time,category_id FROM records").fetchone()
        assert row==("Lunch","2026-10-15 09:00:00.000Z",
                     "2026-10-15 09:30:00.000Z","food00000000001"),row
        assert db.execute("PRAGMA integrity_check").fetchone()[0]=="ok"
        assert not db.execute("PRAGMA foreign_key_check").fetchall()
        db.close()
        original=sqlite3.connect(base)
        assert original.execute("SELECT COUNT(*) FROM records").fetchone()[0]==0
        original.close()
        evidence=json.loads(output.with_suffix(".evidence.json").read_text())
        assert evidence["imported_offline_lab"]==1
        assert evidence["quarantined"]==3
        assert evidence["original_server_ids_restored"]==0
        assert evidence["production_ready"] is False
        print("PASS: no fabricated times, correct Moscow UTC conversion, category mapping, and source preservation.")
if __name__=="__main__":
    assert len(sys.argv)==2,"expected clean PocketBase schema path"
    main(sys.argv[1])
