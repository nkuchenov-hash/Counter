#!/usr/bin/env python3
"""Evidence-based PLAN recovery into a NEW offline PocketBase clone.

Inputs: read-only salvage inventory + previously produced offline lab SQLite.
Output: a new SQLite clone plus JSON manifest. NEVER writes to input database
or starts PocketBase; never guesses missing UTC instants, category mappings,
auth secrets, or conflicting/moved plan versions.
"""
import collections
import datetime as dt
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile

from restore_browser_clone import insert, ident, require

PB_ID=re.compile(r"^[a-z0-9]{15}$")
ISO_DAY=re.compile(r"^\d{4}-\d\d-\d\d$")
def raw_rows(db, table):
    return [json.loads(r[0]) for r in db.execute("SELECT raw FROM "+ident(table))]
def pbid(s):
    return isinstance(s,str) and PB_ID.fullmatch(s) is not None
def strict_utc(raw):
    if not isinstance(raw,str) or not raw or not raw.endswith("Z"):return None
    try:
        v=dt.datetime.fromisoformat(raw.replace("Z","+00:00"))
    except (ValueError,TypeError):
        return None
    if v.utcoffset()!=dt.timedelta(0):return None
    return v.astimezone(dt.timezone.utc).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]+"Z"
def main(inventory_path, existing_lab, output_path):
    inventory_path,existing_lab,output_path=map(Path,(inventory_path,existing_lab,output_path))
    require(inventory_path.is_file() and existing_lab.is_file(),"input inventory or offline lab missing")
    require(not output_path.exists() and not output_path.is_symlink(),"refusing to overwrite target clone")
    require(output_path.resolve()!=existing_lab.resolve(),"output must differ from existing offline lab")
    require(output_path.resolve()!=inventory_path.resolve(),"output must differ from salvage inventory")
    manifest=output_path.with_suffix(".manifest.json")
    require(not manifest.exists(),"refusing to overwrite manifest")
    require(output_path.parent.is_dir(),"output directory does not exist")
    os.umask(0o077)

    inventory=sqlite3.connect("file:"+str(inventory_path.resolve())+"?mode=ro",uri=True)
    lab=sqlite3.connect("file:"+str(existing_lab.resolve())+"?mode=ro",uri=True)
    try:
        meta=dict(inventory.execute("SELECT key,value FROM metadata"))
        owner=meta.get("owner_pb_id")
        require(meta.get("inventory_format")=="lifeos-salvage-v1" and pbid(owner),"invalid inventory")
        require(lab.execute("PRAGMA integrity_check").fetchone()[0]=="ok","existing lab integrity failed")
        require(lab.execute("SELECT COUNT(*) FROM profiles WHERE id=?",(owner,)).fetchone()[0]==1,
                "owner placeholder missing from offline lab")
        require(lab.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==0,
                "offline lab already has plans; refusing to overwrite")
        require(lab.execute("SELECT COUNT(*) FROM tags").fetchone()[0]==0,
                "offline lab already has tags; refusing to overwrite")
        imported_category_ids={x[0] for x in lab.execute("SELECT id FROM categories")}
        imported_record_ids={x[0] for x in lab.execute("SELECT id FROM records")}
        categories=raw_rows(inventory,"categories")
        records=raw_rows(inventory,"records")
        plan_versions=raw_rows(inventory,"plan_versions")

        cats_by_biz=collections.defaultdict(set)
        for c in categories:cats_by_biz[str(c.get("category_id") or "")].add(c.get("id"))
        def category_from_source_record(r):
            # Exact preserved PocketBase category relation takes priority.
            category=r.get("category_link") or r.get("category_id")
            if category in imported_category_ids:return category
            hits=cats_by_biz.get(str(category),set()) & imported_category_ids
            # Ambiguous original keys (including duplicate 'cat-life') are
            # never converted to an apparent unique key by filtering.
            if len(cats_by_biz.get(str(category),()))!=1:return None
            return next(iter(hits)) if len(hits)==1 else None

        by_plan_id=collections.defaultdict(list)
        for p in plan_versions:
            if pbid(p.get("pocketRecordId")):
                by_plan_id[p["pocketRecordId"]].append(p)

        evidence=collections.defaultdict(collections.Counter)
        for r in records:
            if r.get("id") not in imported_record_ids:continue
            pid=r.get("source_plan_id")
            if pid not in by_plan_id:continue
            ref=category_from_source_record(r)
            if not ref:continue
            # A plan's category ID may differ between historical cache
            # versions. Such conflicts must never produce a clean mapping.
            for numeric in {p.get("categoryId") for p in by_plan_id[pid]}:
                if isinstance(numeric,int) and numeric>0:
                    evidence[numeric][ref]+=1

        # At least two independently linked source records and *zero*
        # contradicting categories required to authorize local->PB mapping.
        local_to_pb={local:next(iter(links))
                     for local,links in evidence.items()
                     if len(links)==1 and sum(links.values())>=2}
        reject_reason=collections.Counter()
        tag_evidence=collections.defaultdict(lambda:collections.Counter())
        for p in plan_versions:
            for t in p.get("tags") or []:
                if not isinstance(t,dict):continue
                tid=t.get("pocket_id")
                if not pbid(tid):continue
                name=str(t.get("name") or "").strip()
                try:num=int(t.get("tag_id"))
                except (ValueError,TypeError):continue
                if num<=0 or not name:continue
                domain=t.get("domain")
                if domain not in (None,"","plan"):continue
                tag_evidence[tid][(name,num,"plan")]+=1
        # Never pick a winner in inconsistent tag identity data.
        good_tags={tid:next(iter(e)) for tid,e in tag_evidence.items() if len(e)==1}
        duplicate_tags_by_business=collections.Counter(info[1] for info in good_tags.values())
        good_tags={tid:v for tid,v in good_tags.items() if duplicate_tags_by_business[v[1]]==1}

        version_count=collections.Counter(p.get("pocketRecordId") for p in plan_versions)
        business_count=collections.Counter(p.get("plan_row_id") for p in plan_versions)
        accepted={}
        parent_refs={}
        all_refs={}
        for p in plan_versions:
            pid=p.get("pocketRecordId")
            business=p.get("plan_row_id")
            numeric=p.get("categoryId")
            reasons=[]
            if not pbid(pid) or not isinstance(business,str) or not business.strip():
                reasons.append("invalid_identity")
            if version_count[pid]!=1 or business_count[business]!=1:
                reasons.append("duplicate_cached_version")
            if numeric not in local_to_pb:
                reasons.append("unproven_category")
            start=strict_utc(p.get("start_utc") or p.get("start_time"))
            end=strict_utc(p.get("end_utc"))
            if not start or not end:
                reasons.append("missing_or_invalid_utc")
            elif end < start:
                reasons.append("reversed_time")
            if p.get("isSynced") is False:
                reasons.append("unsynced_pending")
            if not str(p.get("title") or "").strip():
                reasons.append("empty_title")
            original_tags=p.get("tags") or []
            if not isinstance(original_tags,list):
                reasons.append("invalid_tags")
                original_tags=[]
            tagids=[t.get("pocket_id") for t in original_tags if isinstance(t,dict)]
            if len(tagids)!=len(original_tags) or any(t not in good_tags for t in tagids):
                reasons.append("unknown_tag_relation")
            delta=p.get("notes_delta")
            if isinstance(delta,str):
                try:delta=json.loads(delta) if delta.strip() else None
                except (ValueError,TypeError):reasons.append("invalid_notes_delta")
            elif delta is not None and not isinstance(delta,(dict,list)):
                reasons.append("invalid_notes_delta")
            if reasons:
                for reason in set(reasons):reject_reason[reason]+=1
                continue
            try:
                order=int(p.get("order") or 0)
                offset=int(p.get("reminder_offset") or 0)
            except (ValueError,TypeError):
                reject_reason["invalid_plan_numbers"]+=1
                continue
            fields={
                "id":pid, "user_id":owner, "plan_id":business,
                "category_id":local_to_pb[numeric],
                "title":p["title"].strip(),
                "is_done":bool(p.get("is_done",p.get("isDone",False))),
                "order":order, "start_time":start, "end_time":end,
                "checklist":p.get("checklist") if isinstance(p.get("checklist"),list) else [],
                "notes_plain":p.get("notes_plain") or "",
                "tags_link":list(dict.fromkeys(tagids)),
                "reminder_offset":offset,
                "is_postponed":bool(p.get("is_postponed")),
            }
            if delta is not None:fields["notes_delta"]=delta
            initial=p.get("initial_date_key")
            if isinstance(initial,str) and ISO_DAY.fullmatch(initial):
                fields["initial_date_key"]=initial
            if p.get("rrule"):fields["rrule"]=str(p["rrule"])
            if isinstance(p.get("exception_dates"),list):
                fields["exception_dates"]=p["exception_dates"]
            parent=p.get("parent_plan_pocket_id") or p.get("parent_plan_id")
            if parent:parent_refs[pid]=str(parent)
            accepted[pid]=fields
            all_refs[pid]=p

        # Never silently drop parent-child structure or synthesize missing
        # parents. Defer children whose parent has not been recovered.
        while True:
            missing=[pid for pid,parent in parent_refs.items()
                     if pid in accepted and (parent not in accepted or parent==pid)]
            if not missing:break
            for pid in missing:
                accepted.pop(pid,None)
                reject_reason["missing_parent_relation"]+=1

        used_tagids={tag for data in accepted.values() for tag in data["tags_link"]}
        for tag in used_tagids:
            require(tag in good_tags,"resolved plan referenced unexpected tag")
        used_biz=collections.Counter(data["plan_id"] for data in accepted.values())
        require(all(c==1 for c in used_biz.values()),"plan business ID collision in candidates")
        require(all(x["category_id"] in imported_category_ids for x in accepted.values()),
                "candidate refers to missing category")

        fd,tmp=tempfile.mkstemp(prefix=".lifeos-plan-lab-",suffix=".sqlite",dir=output_path.parent)
        os.close(fd)
        try:
            work=sqlite3.connect(tmp)
            work.row_factory=sqlite3.Row
            lab.backup(work)
            try:
                work.execute("PRAGMA foreign_keys=ON")
                with work:
                    for tag in sorted(used_tagids):
                        name,num,domain=good_tags[tag]
                        insert(work,"tags",{
                            "id":tag, "tag_id":str(num),"name":name,
                            "user_id":owner,"domain":domain,"sort_order":0,
                        })
                    for pid,data in accepted.items():
                        # Parent relation populated only after all rows exist.
                        insert(work,"plans",data)
                    for pid,parent in parent_refs.items():
                        if pid in accepted and parent in accepted:
                            work.execute("UPDATE plans SET parent_plan_id=? WHERE id=?",
                                         (parent,pid))
                    restored_record_links=0
                    for r in records:
                        pid=r.get("source_plan_id")
                        if pid not in accepted or r.get("id") not in imported_record_ids:continue
                        work.execute("UPDATE records SET source_plan_id=? WHERE id=?",
                                     (pid,r["id"]))
                        restored_record_links+=1

                require(work.execute("PRAGMA integrity_check").fetchone()[0]=="ok",
                        "generated lab failed SQLite integrity check")
                require(work.execute("PRAGMA foreign_key_check").fetchall()==[],
                        "generated lab failed foreign key check")
                require(work.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==len(accepted),
                        "plan row count mismatch")
                require(work.execute("SELECT COUNT(*) FROM tags").fetchone()[0]==len(used_tagids),
                        "tag row count mismatch")
                require(work.execute("SELECT COUNT(*) FROM records WHERE source_plan_id != ''").fetchone()[0]==restored_record_links,
                        "source plan reference count mismatch")
                require(work.execute("SELECT COUNT(*) FROM profiles").fetchone()[0]==1,
                        "unexpected auth profile changes")
            finally:
                work.close()
            summary={
                "format":"lifeos-plan-recovery-lab-v1",
                "source_inventory_sha256":meta.get("source_sha256"),
                "plan_versions_total":len(plan_versions),
                "distinct_pocket_plan_ids":len(by_plan_id),
                "proven_category_mappings":len(local_to_pb),
                "plan_records_imported":len(accepted),
                "plan_versions_deferred":len(plan_versions)-len(accepted),
                "tags_restored_from_cached_plan_metadata":len(used_tagids),
                "source_plan_relations_relinked":restored_record_links,
                "deferred_reasons_overlapping":dict(reject_reason),
                "original_auth_credentials_recovered":False,
                "input_sqlite_modified":False,
                "production_ready":False,
                "warning":"Offline clone only; missing timestamps, conflicting versions, unmatched category links and original account credentials remain unrecovered."
            }
            os.chmod(tmp,0o600)
            with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",
                                             dir=output_path.parent,
                                             prefix=".plan-lab-report-",delete=False) as f:
                tmpm=f.name
                json.dump(summary,f,ensure_ascii=False,indent=2)
                f.write("\n")
            os.chmod(tmpm,0o600)
            os.replace(tmp,output_path)
            os.replace(tmpm,manifest)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        print("PASS: created independent SQLite clone with evidence-backed plans and original PB IDs.")
        print("PASS: SQLite integrity and foreign-key checks; original lab unchanged.")
        print("MAPPINGS: "+str(len(local_to_pb))+" categories with >=2 consistent source record links")
        print("PLANS: "+str(len(accepted))+"/"+str(len(plan_versions))+" versions safely imported")
        print("TAGS: "+str(len(used_tagids))+" consistent known PocketBase tag IDs restored")
        print("RECORD SOURCE LINKS: "+str(restored_record_links)+" restored where target plan exists")
        print("DEFERRED: ambiguous mappings, missing UTC, duplicated versions, original login credentials.")
        print("PASS: NO PRODUCTION CUTOVER; existing service and DB unchanged.")
    finally:
        inventory.close()
        lab.close()

if __name__=="__main__":
    try:
        require(len(sys.argv)==4,
                "Usage: advance_plan_recovery_lab.py INVENTORY.sqlite BASE_LAB.sqlite NEW_LAB.sqlite")
        main(*sys.argv[1:])
    except Exception as e:
        print("ERROR: "+str(e),file=sys.stderr)
        sys.exit(1)
