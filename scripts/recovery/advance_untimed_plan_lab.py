#!/usr/bin/env python3
"""Preserve legacy date-only plans in a NEW offline PocketBase lab clone.

Old Flutter caches stored a wall-clock placeholder but no UTC instants for
some historical plans. Never convert that placeholder into an invented
timestamp. Use the original dateKey as PocketBase initial_date_key so a
recoverable task remains available as an UNTImED dated plan, and keep its
original raw version in salvage inventory.

Only uniquely identified plans with a category demonstrated by >=2 source
record links are eligible. No existing data is overwritten. This output
cannot substitute for the original full production PocketBase backup.
"""
import collections
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
from restore_browser_clone import insert,require

def main(inventory_file,base_file,output_file):
    inv_path,base_path,out_path=map(Path,(inventory_file,base_file,output_file))
    require(inv_path.is_file() and base_path.is_file(),"missing inputs")
    require(not out_path.exists() and not out_path.is_symlink(),"refusing overwrite")
    require(out_path.parent.is_dir(),"output parent missing")
    report_path=out_path.with_suffix(".manifest.json")
    require(not report_path.exists(),"refusing report overwrite")
    os.umask(0o077)
    inv=sqlite3.connect("file:"+str(inv_path.resolve())+"?mode=ro",uri=True)
    db=sqlite3.connect("file:"+str(base_path.resolve())+"?mode=ro",uri=True)
    try:
        require(db.execute("PRAGMA integrity_check").fetchone()[0]=="ok","base is corrupt")
        owner=dict(inv.execute("SELECT key,value FROM metadata")).get("owner_pb_id")
        require(owner and db.execute("SELECT COUNT(*) FROM profiles WHERE id=?",(owner,)).fetchone()[0]==1,
                "owner mismatch")
        categories=[json.loads(x[0]) for x in inv.execute("SELECT raw FROM categories")]
        records=[json.loads(x[0]) for x in inv.execute("SELECT raw FROM records")]
        plans=[json.loads(x[0]) for x in inv.execute("SELECT raw FROM plan_versions")]
        cat_ids={x[0] for x in db.execute("SELECT id FROM categories")}
        imported_records={x[0] for x in db.execute("SELECT id FROM records")}
        biz_to_cat=collections.defaultdict(set)
        for c in categories:
            biz_to_cat[str(c.get("category_id") or "")].add(c.get("id"))

        source_to_cat={}
        for r in records:
            if r.get("id") not in imported_records:continue
            cat=r.get("category_link") or r.get("category_id")
            if cat not in cat_ids:
                choices=biz_to_cat.get(str(cat),set())
                if len(choices)!=1:continue
                cat=next(iter(choices))
            if cat in cat_ids and r.get("source_plan_id"):
                source_to_cat[r["source_plan_id"]]=cat

        versions=collections.defaultdict(list)
        for p in plans:versions[p.get("pocketRecordId")].append(p)
        local_evidence=collections.defaultdict(lambda:collections.Counter())
        for pid,cat in source_to_cat.items():
            for v in versions.get(pid,()):
                local=v.get("categoryId")
                if isinstance(local,int) and local>0:
                    local_evidence[local][cat]+=1
        local_to_cat={k:next(iter(v)) for k,v in local_evidence.items()
                      if len(v)==1 and sum(v.values())>=2}
        existing_pb={x[0] for x in db.execute("SELECT id FROM plans")}
        existing_biz={x[0] for x in db.execute("SELECT plan_id FROM plans")}
        biz_counts=collections.Counter(p.get("plan_row_id") for p in plans)
        used_tag_ids={x[0] for x in db.execute("SELECT id FROM tags")}
        candidates={}
        reasons=collections.Counter()
        parent_ids={}
        for pid,rows in versions.items():
            if pid in existing_pb:continue
            if len(rows)!=1:
                reasons["duplicate_cached_versions"]+=len(rows)
                continue
            p=rows[0]
            biz=p.get("plan_row_id")
            local=p.get("categoryId")
            if not isinstance(pid,str) or not re.fullmatch("[a-z0-9]{15}",pid):
                reasons["invalid_pb_id"]+=1
                continue
            if not isinstance(biz,str) or not biz.strip() or biz_counts[biz]!=1 or biz in existing_biz:
                reasons["business_id_collision"]+=1
                continue
            if p.get("start_utc") or p.get("end_utc") or p.get("start_time"):
                reasons["has_utc_or_partial_utc"]+=1
                continue
            dk=p.get("initial_date_key") or p.get("dateKey")
            if not isinstance(dk,str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}",dk):
                reasons["missing_original_day"]+=1
                continue
            cat=local_to_cat.get(local)
            if not cat or cat not in cat_ids:
                reasons["unresolved_category"]+=1
                continue
            if p.get("isSynced") is False:
                reasons["unsynced_operation"]+=1
                continue
            title=str(p.get("title") or "").strip()
            if not title:
                reasons["missing_title"]+=1
                continue
            tags=p.get("tags") or []
            if not isinstance(tags,list):
                reasons["unreadable_tags"]+=1
                continue
            tagids=[t.get("pocket_id") for t in tags if isinstance(t,dict)]
            if len(tagids)!=len(tags) or any(t not in used_tag_ids for t in tagids):
                reasons["unresolved_tag_link"]+=1
                continue
            delta=p.get("notes_delta")
            if isinstance(delta,str):
                try:delta=json.loads(delta) if delta.strip() else None
                except ValueError:
                    reasons["invalid_notes"]+=1
                    continue
            if delta is not None and not isinstance(delta,(list,dict)):
                reasons["invalid_notes"]+=1
                continue
            try:
                order=int(p.get("order") or 0)
                reminder=int(p.get("reminder_offset") or 0)
            except (ValueError,TypeError):
                reasons["invalid_order"]+=1
                continue
            record={
                "id":pid,"user_id":owner,"plan_id":biz,
                "category_id":cat,"title":title,
                "is_done":bool(p.get("is_done",p.get("isDone",False))),
                "order":order,"initial_date_key":dk,
                "is_postponed":bool(p.get("is_postponed",False)),
                "start_time":"","end_time":"",
                "notes_plain":p.get("notes_plain") or "",
                "checklist":p.get("checklist") if isinstance(p.get("checklist"),list) else [],
                "tags_link":list(dict.fromkeys(tagids)),
                "reminder_offset":reminder,
            }
            if delta is not None:record["notes_delta"]=delta
            if p.get("rrule"):record["rrule"]=p["rrule"]
            if isinstance(p.get("exception_dates"),list):
                record["exception_dates"]=p["exception_dates"]
            if p.get("recurrence_instance_date_key"):
                record["recurrence_instance_date_key"]=p["recurrence_instance_date_key"]
            parent=p.get("parent_plan_pocket_id") or p.get("parent_plan_id")
            if parent:parent_ids[pid]=str(parent)
            candidates[pid]=record

        # Retain existing and new linked plans, otherwise avoid inventing
        # a parent that might have been removed from the historical source.
        while True:
            dropped=[pid for pid,parent in parent_ids.items()
                if pid in candidates and (parent==pid or
                    parent not in candidates and parent not in existing_pb)]
            if not dropped:break
            for pid in dropped:
                candidates.pop(pid)
                reasons["unresolved_parent"]+=1

        fd,tmp=tempfile.mkstemp(prefix=".lifeos-day-plans-",suffix=".sqlite",dir=out_path.parent)
        os.close(fd)
        try:
            out=sqlite3.connect(tmp)
            out.row_factory=sqlite3.Row
            db.backup(out)
            try:
                out.execute("PRAGMA foreign_keys=ON")
                with out:
                    for row in candidates.values():
                        insert(out,"plans",row)
                    for pid,parent in parent_ids.items():
                        if pid in candidates and (parent in candidates or parent in existing_pb):
                            out.execute("UPDATE plans SET parent_plan_id=? WHERE id=?",(parent,pid))
                require(out.execute("PRAGMA integrity_check").fetchone()[0]=="ok","bad SQLite integrity")
                require(not out.execute("PRAGMA foreign_key_check").fetchall(),"bad foreign keys")
                require(out.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==len(existing_pb)+len(candidates),
                        "wrong plan count")
            finally:out.close()
            summary={
              "format":"lifeos-untimed-plan-recovery-lab-v1",
              "input_plan_rows":len(existing_pb),
              "new_date_only_plans":len(candidates),
              "final_plan_rows":len(existing_pb)+len(candidates),
              "category_mappings":len(local_to_cat),
              "original_utc_times_recovered_for_date_only":0,
              "original_auth_recovered":False,
              "source_untouched":True,
              "production_ready":False,
              "quarantine_reasons":dict(reasons),
              "warning":"New plans have original date but intentionally no clock time. Raw wall placeholder is preserved in source inventory."
            }
            os.chmod(tmp,0o600)
            with tempfile.NamedTemporaryFile("w",encoding="utf8",dir=out_path.parent,
                              prefix=".lifeos-day-plan-report-",delete=False) as f:
                tmp_report=f.name
                json.dump(summary,f,ensure_ascii=False,indent=2)
                f.write("\n")
            os.chmod(tmp_report,0o600)
            os.replace(tmp,out_path)
            os.replace(tmp_report,report_path)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        print("PASS: separate dated-untimed plan clone created; original SQLite unchanged.")
        print("PLANS: "+str(len(existing_pb))+" existing + "+str(len(candidates))+" restored date-only")
        print("PASS: no inferred hours/timezones, integrity and FK checks; NOT production ready.")
    finally:
        inv.close()
        db.close()

if __name__=="__main__":
    try:
        require(len(sys.argv)==4,"Usage: advance_untimed_plan_lab.py SALVAGE.sqlite TIMED_LAB.sqlite NEW_LAB.sqlite")
        main(*sys.argv[1:])
    except Exception as exc:
        print("ERROR: "+str(exc),file=sys.stderr)
        sys.exit(1)
