#!/usr/bin/env python3
"""Fail-closed LIFE OS recovery cutover readiness audit.

Read-only: inspect final offline PocketBase SQLite and optional health URL.
This explicitly refuses to certify a profile placeholder or stale multi-open
record database as ready for user login. Never modifies SQLite or service.
"""
import os
import pathlib
import sqlite3
import sys
from urllib.request import urlopen
from urllib.error import URLError

def check(path, expected_owner):
    errors=[]
    db=sqlite3.connect("file:"+str(path.resolve())+"?mode=ro",uri=True)
    try:
        if db.execute("PRAGMA integrity_check").fetchone()[0]!="ok":
            errors.append("SQLite integrity check failed")
        fk=db.execute("PRAGMA foreign_key_check").fetchall()
        if fk:errors.append("foreign key violations: "+str(len(fk)))
        required=["profiles","categories","records","plans","tags"]
        for name in required:
            count=db.execute("SELECT COUNT(*) FROM _collections WHERE name=?",(name,)).fetchone()[0]
            if count!=1:errors.append("missing "+name)
        if errors:return errors
        counts={t:db.execute("SELECT COUNT(*) FROM "+t).fetchone()[0] for t in required}
        print("RECOVERY CLONE COUNTS:",counts)
        if counts["records"]<3276:errors.append("fewer than original salvaged records")
        if counts["plans"]<515:errors.append("missing confirmed timed plans")
        if counts["categories"]<125:errors.append("missing confirmed categories")
        profile=db.execute("SELECT email,password FROM profiles WHERE id=?",(expected_owner,)).fetchone()
        if not profile:
            errors.append("original profile ID not present")
        elif not profile[0] or not profile[1] or len(profile[1])<20:
            errors.append("original profile is a recovery placeholder; password auth not provisioned")
        index=db.execute("SELECT name FROM sqlite_master WHERE type='index' AND name='idx_records_one_open_primary_per_owner'").fetchone()
        if not index:errors.append("database lacks primary singleton unique index")
        both_triggers=db.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='trigger' "
            "AND name IN ('trg_records_running_end_insert','trg_records_running_end_update')"
        ).fetchone()[0]
        if both_triggers!=2:errors.append("database lacks running status/end_time consistency triggers")
        open_rows=db.execute(
            "SELECT user_id,COUNT(*) FROM records WHERE status='running' "
            "AND (parent_id IS NULL OR parent_id='') "
            "AND (end_time IS NULL OR end_time='') GROUP BY user_id HAVING COUNT(*)>1"
        ).fetchall()
        if open_rows:errors.append("multiple open primary records per owner")
    finally:db.close()
    return errors

if __name__=="__main__":
    if len(sys.argv)!=3:
        print("Usage: audit_recovery_cutover.py FINAL_CLONE.sqlite OWNER_POCKETBASE_ID")
        sys.exit(2)
    dbfile=pathlib.Path(sys.argv[1])
    if not dbfile.is_file():
        print("FAIL: database missing",file=sys.stderr)
        sys.exit(2)
    issues=check(dbfile,sys.argv[2])
    if issues:
        for issue in issues:print("BLOCKED:",issue)
        print("DO NOT CUT OVER; user accounts, server hooks, app endpoint or data remain unverified.")
        sys.exit(1)
    print("PASS: offline database readiness, but public HTTPS/API and client E2E still require separate checks.")
