#!/usr/bin/env python3
"""Import *non-conflicting* browser data into an isolated PocketBase SQLite CLONE.

Never opens a network listener; never modifies the input database, staging
service, or real production SQLite file. Original records and every quarantined
version remain preserved in the browser-salvage inventory.

This is a RECOVERY LAB, NOT A LOGIN-READY PRODUCTION DATABASE. The source
browser export has no original PocketBase auth password hashes or profile.
"""
import collections
import datetime
import json
import os
import pathlib
import re
import sqlite3
import sys
import tempfile

def require(ok, message):
    if not ok:
        raise RuntimeError(message)

def ident(name):
    require(re.fullmatch(r"[A-Za-z_][A-Za-z_0-9]*",name) is not None,
            "unsafe SQL identifier")
    return '"'+name+'"'

def cols(db,table):
    return {row["name"]:row for row in db.execute("PRAGMA table_info("+ident(table)+")")}

def insert(db,table,row):
    fields=cols(db,table)
    payload={k:v for k,v in row.items() if k in fields}
    for k,v in list(payload.items()):
        if isinstance(v,(dict,list)):
            payload[k]=json.dumps(v,ensure_ascii=False,separators=(',',':'))
        if isinstance(v,bool):
            payload[k]=int(v)
        if v is None: payload[k]=''
    keys=list(payload)
    require("id" in keys,table+": primary key missing")
    sql="INSERT INTO "+ident(table)+" ("+",".join(map(ident,keys))+") VALUES ("+",".join('?' for _ in keys)+")"
    db.execute(sql,[payload[k] for k in keys])

def main(inventory_path, source_db, target_db):
    inventory_path,source_db,target_db=map(pathlib.Path,(inventory_path,source_db,target_db))
    require(inventory_path.is_file() and source_db.is_file(),"missing input")
    require(not target_db.exists() and not target_db.is_symlink(),"refusing to overwrite target")
    require(source_db.resolve()!=target_db.resolve(),"clone target must differ from staging")
    require(inventory_path.resolve()!=target_db.resolve(),"clone target must differ from inventory")
    require(target_db.parent.exists(),"target parent directory must already exist")
    manifest=target_db.with_suffix(".manifest.json")
    require(not manifest.exists(),"refusing to overwrite manifest")
    os.umask(0o077)

    src=sqlite3.connect("file:"+str(inventory_path.resolve())+"?mode=ro",uri=True)
    src.row_factory=sqlite3.Row
    source=sqlite3.connect("file:"+str(source_db.resolve())+"?mode=ro",uri=True)
    source.row_factory=sqlite3.Row
    candidates={}; counters={}
    try:
        metadata=dict(src.execute("SELECT key,value FROM metadata"))
        require(metadata.get("inventory_format")=="lifeos-salvage-v1","unsupported inventory")
        owner=metadata.get("owner_pb_id")
        require(bool(re.fullmatch(r"[a-z0-9]{15}",owner or "")),"invalid preserved PocketBase owner ID")

        categories=[json.loads(r["raw"]) for r in src.execute("SELECT raw FROM categories")]
        records=[json.loads(r["raw"]) for r in src.execute("SELECT raw FROM records")]
        category_biz=collections.Counter(str(c.get("category_id") or "") for c in categories)
        record_biz=collections.Counter(str(r.get("record_id") or "") for r in records)
        category_ids={c["id"] for c in categories}
        accepted_categories={}
        skipped_categories=set()

        for c in categories:
            pk=c.get("id"); biz=str(c.get("category_id") or "")
            if pk in skipped_categories: continue
            if not re.fullmatch(r"[a-z0-9]{15}",pk or "") or not biz or category_biz[biz]>1 or c.get("user_id")!=owner:
                skipped_categories.add(pk)
            else:
                accepted_categories[pk]=c

        accepted_records={}
        skipped_records=set()
        corrected_category_relations=0
        unresolved_source_plan_refs=0

        for r in records:
            pk=r.get("id"); biz=str(r.get("record_id") or "")
            ref=r.get("category_link") or r.get("category_id")
            if ref not in category_ids:
                skipped_records.add(pk); continue
            if (not re.fullmatch(r"[a-z0-9]{15}",pk or "") or not biz or
                record_biz[biz]>1 or r.get("user_id")!=owner or
                ref not in accepted_categories or not r.get("title") or
                not r.get("start_time") or
                r.get("status") not in ("running","stopped","completed") or
                not r.get("type")):
                skipped_records.add(pk); continue
            copy=dict(r)
            # Both values are PocketBase relations. Legacy records may carry
            # business slugs in category_id; use the known, preserved row ID.
            if copy.get("category_id")!=ref or copy.get("category_link")!=ref:
                corrected_category_relations+=1
            copy["category_id"]=ref
            copy["category_link"]=ref
            # Plans are quarantined pending proven legacy category-ID mapping.
            # Preserve the original relation in the inventory, do not point
            # to a nonexistent plan row in this isolated recovery clone.
            if copy.get("source_plan_id"):
                unresolved_source_plan_refs+=1
                copy["source_plan_id"]=""
            accepted_records[pk]=copy

        for c in accepted_categories.values():
            parent=c.get("parent_id") or ""
            if parent and parent not in accepted_categories:
                # Keep original parent in inventory, quarantine this category
                # and every record that depends on it rather than mutate links.
                skipped_categories.add(c["id"])
        for pk in skipped_categories:
            accepted_categories.pop(pk,None)
        for pk,r in list(accepted_records.items()):
            if r["category_id"] not in accepted_categories:
                skipped_records.add(pk)
                accepted_records.pop(pk,None)

        # A clean, empty schema is mandatory. We will never merge over an
        # existing user or live staging dataset.
        for table in ("profiles","categories","tags","plans","records"):
            require(source.execute("SELECT COUNT(*) FROM "+ident(table)).fetchone()[0]==0,
                    "source PocketBase schema contains data; refusing clone import")
        require(source.execute("PRAGMA integrity_check").fetchone()[0][0]=="ok",
                "input schema failed SQLite integrity_check")

        fd,tmp=tempfile.mkstemp(prefix=".lifeos-lab-",suffix=".sqlite",dir=target_db.parent)
        os.close(fd)
        try:
            work=sqlite3.connect(tmp)
            work.row_factory=sqlite3.Row
            source.backup(work)
            work.execute("PRAGMA foreign_keys=ON")
            try:
                with work:
                    # Recovery-only identity placeholder. No password or email
                    # is restored because they are absent from browser export.
                    # This must NEVER be promoted to production as an auth account.
                    insert(work,"profiles",{"id":owner,"email":"","verified":False})
                    for c in accepted_categories.values():
                        entry={k:v for k,v in c.items() if not k.startswith("_")}
                        insert(work,"categories",entry)
                    for r in accepted_records.values():
                        entry={k:v for k,v in r.items() if not k.startswith("_") and k!="expand"}
                        insert(work,"records",entry)
                require(work.execute("PRAGMA integrity_check").fetchone()[0][0]=="ok",
                        "recovery clone failed SQLite integrity check")
                require(work.execute("PRAGMA foreign_key_check").fetchall()==[],
                        "recovery clone failed SQLite foreign-key check")
                for table, expected in [("profiles",1),("categories",len(accepted_categories)),("records",len(accepted_records))]:
                    require(work.execute("SELECT COUNT(*) FROM "+ident(table)).fetchone()[0]==expected,
                            table+": wrong imported row count")
                require(work.execute("SELECT COUNT(*) FROM plans").fetchone()[0]==0,
                        "plans must remain quarantined")
            finally:
                work.close()

            summary={
                "format":"lifeos-recovery-clone-lab-v1",
                "source_inventory_sha256": metadata.get("source_sha256"),
                "owner_preserved":True,
                "original_account_login_recovered":False,
                "categories_total":len(categories),
                "categories_imported":len(accepted_categories),
                "categories_quarantined":len(categories)-len(accepted_categories),
                "records_total":len(records),
                "records_imported":len(accepted_records),
                "records_quarantined":len(records)-len(accepted_records),
                "legacy_category_relations_resolved":corrected_category_relations,
                "source_plan_relations_deferred":unresolved_source_plan_refs,
                "plans_imported":0,
                "original_inventory_modified":False,
                "live_staging_modified":False,
                "production_ready":False,
                "warning":"Offline clone only. Auth credentials, plan relations, tags and incomplete source history are not restored.",
            }
            target_db=target_db.resolve(strict=False)
            pathlib.Path(tmp).chmod(0o600)
            with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",dir=target_db.parent,
                   prefix=".lifeos-manifest-",delete=False) as f:
                mf=f.name
                json.dump(summary,f,ensure_ascii=False,indent=2)
                f.write("\n")
            os.chmod(mf,0o600)
            os.replace(tmp,target_db)
            os.replace(mf,manifest)
        finally:
            if os.path.exists(tmp):os.unlink(tmp)
        print("PASS: isolated PocketBase clone created from empty reconstructed schema.")
        print("PASS: SQLite integrity and foreign key checks; original PB IDs preserved.")
        print("CATEGORIES: "+str(len(accepted_categories))+"/"+str(len(categories)))
        print("RECORDS: "+str(len(accepted_records))+"/"+str(len(records)))
        print("DEFERRED: plans, auth/password, missing source_plan relations, and quarantined duplicates.")
        print("PASS: source inventory and live staging unchanged; NO PRODUCTION CUTOVER.")
    finally:
        src.close()
        source.close()

if __name__=="__main__":
    try:
        require(len(sys.argv)==4,"Usage: restore_browser_clone.py SALVAGE.sqlite EMPTY_STAGE.sqlite NEW_CLONE.sqlite")
        main(*sys.argv[1:])
    except Exception as err:
        print("ERROR: "+str(err),file=sys.stderr)
        sys.exit(1)
