#!/usr/bin/env python3
"""Private video evidence -> one NEW, isolated PocketBase recovery SQLite clone.

Use AFTER browser-recovered-plans-lab is generated. No original backend IDs
are available from a screen recording. The generated row IDs are explicitly
deterministic *reconstruction IDs*, NOT claims of original PocketBase identity.

Requires exact original visible title, local date/time, category path, and a
unique unarchived matching category. Does not silently invent end times for
long-running records or reconcile uncertain screen times.

Never writes to the input DB, live PocketBase, or an existing output. A
sidecar JSON preserves source and quarantine decisions for later matching.
"""
import collections
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
import uuid
from zoneinfo import ZoneInfo

from restore_browser_clone import insert, require

def norm(value):
    return " ".join(str(value or "").casefold().strip().split())

ALIASES={
    "работа":"work", "жизнь":"life",
    "еда":"food", "здоровье":"health",
}
def canonical_path(path):
    return tuple(ALIASES.get(norm(x),norm(x)) for x in path.split(">"))

def clock(value):
    if not isinstance(value,str) or not re.fullmatch(r"[0-2]\d:[0-5]\d",value):
        return None
    h,m=map(int,value.split(":"))
    return (h,m) if h<24 else None

def local_instant(date,clock_value):
    if not re.fullmatch(r"\d{4}-\d\d-\d\d",str(date)):
        raise ValueError("bad date")
    y,m,d=map(int,date.split("-"))
    h,mi=clock_value
    return dt.datetime(y,m,d,h,mi,tzinfo=ZoneInfo("Europe/Moscow"))

def api_utc(value):
    return value.astimezone(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S.000Z")

def fingerprint(row):
    # Source recording, frame and all readable identity attributes.
    return json.dumps([
        row.get("date_local"),row.get("title"),row.get("category_path_visible"),
        row.get("start_clock"),row.get("end_clock"),
        row.get("source_seconds_approx")],
        ensure_ascii=False,separators=(",",":"))

def existing_cat_paths(db):
    db.row_factory=sqlite3.Row
    cats={r["id"]:dict(r) for r in db.execute("SELECT * FROM categories")}
    paths=collections.defaultdict(list)
    for row in cats.values():
        if row.get("is_archived"):continue
        nodes=[]
        visited=set()
        c=row
        for _ in range(16):
            if c["id"] in visited:break
            visited.add(c["id"])
            nodes.append(c.get("name") or "")
            parent=c.get("parent_id")
            if not parent:break
            c=cats.get(parent)
            if c is None:
                nodes=[]
                break
        if nodes:
            paths[tuple(reversed([norm(x) for x in nodes]))].append(row["id"])
    return paths

def main(video_json,original_lab,new_lab):
    video_json,original_lab,new_lab=map(Path,(video_json,original_lab,new_lab))
    require(video_json.is_file() and original_lab.is_file(),"missing private video or offline lab")
    require(not new_lab.exists() and not new_lab.is_symlink(),"refusing overwrite")
    require(new_lab.resolve()!=original_lab.resolve(),"offline lab must not be modified")
    require(new_lab.parent.is_dir(),"output directory missing")
    sidecar=new_lab.with_suffix(".evidence.json")
    require(not sidecar.exists(),"refusing overwrite sidecar")
    source=json.loads(video_json.read_text(encoding="utf8"))
    rows=source.get("entries")
    require(isinstance(rows,list) and rows, "no entries in reviewed video")
    require(source.get("source_video_sha256") and source.get("completeness","").startswith("PARTIAL"),
            "not an identified reviewed partial video export")
    video_sha=source["source_video_sha256"]
    known=sqlite3.connect("file:"+str(original_lab.resolve())+"?mode=ro",uri=True)
    known.row_factory=sqlite3.Row
    try:
        require(known.execute("PRAGMA integrity_check").fetchone()[0]=="ok","input DB corruption")
        owners=known.execute("SELECT id FROM profiles").fetchall()
        require(len(owners)==1,"expected one recovery placeholder owner")
        owner=owners[0]["id"]
        category_paths=existing_cat_paths(known)
        existing_ids={row["id"] for row in known.execute("SELECT id FROM records")}
        seen_records={(row["title"].casefold().strip(),
                       str(row["start_time"]),row["category_id"])
                      for row in known.execute("SELECT title,start_time,category_id FROM records")}
        seen_source=collections.Counter(fingerprint(r) for r in rows)
        results=[]
        importable=[]
        used_ids=set()

        for idx,r in enumerate(rows):
            reason=None
            title=(r.get("title") or "").strip()
            if not title:reason="missing_title"
            if r.get("timezone_label")!="MSK":reason=reason or "unverified_timezone"
            start=clock(r.get("start_clock"))
            end=clock(r.get("end_clock"))
            if not start:reason=reason or "invalid_start"
            if not end:reason=reason or "missing_end"
            key=fingerprint(r)
            if seen_source[key]>1:reason=reason or "duplicate_in_visual_evidence"
            flag=str(r.get("review_flag") or "")
            if flag.startswith("running") or "still_running" in flag:
                reason=reason or "still_running_unbounded"
            if flag not in ("visible","zero_duration_as_displayed","overnight_as_displayed"):
                reason=reason or "uncertain_clock_or_duration"
            catpath=canonical_path(r.get("category_path_visible") or "")
            candidates=category_paths.get(catpath,[])
            if len(candidates)!=1:reason=reason or "unmatched_or_ambiguous_category"
            start_utc=end_utc=None
            if start and end and not reason:
                try:
                    st=local_instant(r["date_local"],start)
                    en=local_instant(r["date_local"],end)
                    if en<st:
                        if flag!="overnight_as_displayed":
                            reason="ambiguous_overnight"
                        else:
                            en+=dt.timedelta(days=1)
                    duration=(en-st).total_seconds()
                    if duration>16*3600:
                        reason="suspicious_long_interval"
                    if duration==0 and flag!="zero_duration_as_displayed":
                        reason="unexpected_zero_interval"
                    start_utc=api_utc(st)
                    end_utc=api_utc(en)
                except (ValueError,TypeError):
                    reason="bad_local_timestamp"
            if not reason:
                matching=(norm(title),start_utc,candidates[0])
                if matching in seen_records:
                    reason="already_present_in_recovered_db"
            # Deterministic recovery-only ID. Marker prevents claims that
            # source server ID is known; sidecar stores the visual provenance.
            digest=hashlib.sha256((video_sha+"|"+key).encode()).hexdigest()
            pb_id="v"+digest[:14]
            biz=str(uuid.uuid5(uuid.NAMESPACE_URL,"lifeos-screen-recovery/"+video_sha+"/"+key))
            if pb_id in existing_ids or pb_id in used_ids:
                reason=reason or "generated_id_collision"
            entry={
              "source_index":idx, "source_seconds_approx":r.get("source_seconds_approx"),
              "date_local":r.get("date_local"),"title":title,
              "category_path_visible":r.get("category_path_visible"),
              "review_flag":flag,"source_video_sha256":video_sha,
              "original_pocketbase_id":None,"original_business_id":None,
              "reconstructed_pocketbase_id":pb_id if not reason else None,
              "reconstructed_business_id":biz if not reason else None,
              "start_utc":start_utc,"end_utc":end_utc,
              "disposition":"quarantined" if reason else "imported_offline_lab",
              "reason":reason,
            }
            results.append(entry)
            if reason:continue
            used_ids.add(pb_id)
            seen_records.add((norm(title),start_utc,candidates[0]))
            importable.append({
              "id":pb_id,"record_id":biz,"user_id":owner,
              "title":title,"type":"record","status":"completed",
              "start_time":start_utc,"end_time":end_utc,
              "category_id":candidates[0],"category_link":candidates[0],
              "checklist":[],"note":"",
            })

        fd,tmp=tempfile.mkstemp(prefix=".lifeos-video-",suffix=".sqlite",
                                 dir=new_lab.parent)
        os.close(fd)
        try:
            db=sqlite3.connect(tmp)
            db.row_factory=sqlite3.Row
            known.backup(db)
            try:
                db.execute("PRAGMA foreign_keys=ON")
                with db:
                    for row in importable: insert(db,"records",row)
                require(db.execute("PRAGMA integrity_check").fetchone()[0]=="ok",
                        "video lab failed SQLite integrity")
                require(not db.execute("PRAGMA foreign_key_check").fetchall(),
                        "video lab failed FK check")
                require(db.execute("SELECT COUNT(*) FROM records").fetchone()[0]==len(existing_ids)+len(importable),
                        "unexpected row count")
            finally:db.close()
            report={
                "format":"lifeos-video-recovery-offline-lab-v1",
                "source_video_sha256":video_sha,
                "source_json_sha256":hashlib.sha256(video_json.read_bytes()).hexdigest(),
                "user_private_data":True,
                "reviewed_entries":len(rows),
                "imported_offline_lab":len(importable),
                "quarantined":len(rows)-len(importable),
                "reason_counts":dict(collections.Counter(e["reason"] for e in results if e["reason"])),
                "each_entry":results,
                "original_server_ids_restored":0,
                "original_auth_recovered":False,
                "input_lab_modified":False,
                "production_ready":False,
                "warning":"Reconstructed records are incomplete and use generated local IDs; do NOT merge with original Beget DB without explicit reconciliation."
            }
            os.chmod(tmp,0o600)
            with tempfile.NamedTemporaryFile("w",encoding="utf8",
                    dir=new_lab.parent,prefix=".lifeos-evidence-",delete=False) as f:
                temporary_sidecar=f.name
                json.dump(report,f,ensure_ascii=False,indent=2)
                f.write("\n")
            os.chmod(temporary_sidecar,0o600)
            os.replace(tmp,new_lab)
            os.replace(temporary_sidecar,sidecar)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        print("PASS: video evidence classified; original SQLite lab untouched.")
        print("VIDEO ROWS: "+str(len(rows)))
        print("RECONSTRUCTED: "+str(len(importable)))
        print("QUARANTINED: "+str(len(rows)-len(importable)))
        print("PASS: SQLite integrity and FK checks. NO PRODUCTION CUTOVER.")
    finally:known.close()

if __name__=="__main__":
    try:
        require(len(sys.argv)==4,
                "Usage: import_video_evidence_lab.py PRIVATE_VIDEO.json PREVIOUS_LAB.sqlite NEW_LAB.sqlite")
        main(*sys.argv[1:])
    except Exception as e:
        print("ERROR: "+str(e),file=sys.stderr)
        sys.exit(1)
