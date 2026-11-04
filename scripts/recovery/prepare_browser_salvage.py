#!/usr/bin/env python3
"""Read-only LIFE OS browser rescue normalizer.

Creates a SEPARATE SQLite inventory beside the original exported JSON.
Does NOT modify PocketBase, create accounts, replay mutations, or infer IDs.
All raw versions and conflicting business IDs are retained for reconciliation.
Usage: python3 prepare_browser_salvage.py INPUT.json OUTPUT.sqlite
"""
import collections
import datetime
import hashlib
import json
import os
import pathlib
import sqlite3
import sys
import tempfile

def decoded(value):
    for _ in range(3):
        if isinstance(value, str):
            value = json.loads(value)
    return value

def require(condition, msg):
    if not condition:
        raise ValueError(msg)

def main(source, target):
    source, target = pathlib.Path(source), pathlib.Path(target)
    require(source.is_file(), "missing input JSON")
    require(not target.exists() and not target.is_symlink(), "refusing overwrite of output")
    require(source.resolve() != target.resolve(), "input/output must differ")
    report_file = target.with_suffix('.report.json')
    require(not report_file.exists(), "refusing overwrite of report")
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    require(digest == '2746296c2604b5d952ca7456fce1e39bd9a96f58aa86654c986212f8f93ab0ae'
            or os.environ.get('LIFEOS_TEST_FIXTURE') == '1',
            "SHA256 mismatch: input differs from user's original browser export")
    data = json.loads(source.read_text(encoding='utf-8'))
    require(data.get('type') == 'LIFE_OS_BROWSER_RECOVERY', 'invalid export type')
    local = data['localStorage']

    def largest_cache(name):
        batches = [decoded(raw) for key, raw in local.items() if name in key]
        require(batches and all(isinstance(x, list) for x in batches), 'invalid or missing ' + name)
        rows = max(batches, key=len)
        require(bool(rows) and all(isinstance(x, dict) for x in rows), 'empty or invalid ' + name)
        return rows

    records = largest_cache('cache_records_flat_v1_')
    categories = largest_cache('cache_categories_raw_v1_')
    plans = []
    for key, raw in local.items():
        if 'cache_plans_day_v1_' in key:
            day = key.rsplit('_', 1)[-1]
            value = decoded(raw)
            require(isinstance(value, list) and all(isinstance(x, dict) for x in value), 'invalid plan cache')
            plans.extend((day, x) for x in value)
    require(plans, 'no plans found')
    owners = {r.get('user_id') for r in records + categories}
    require(len(owners) == 1 and next(iter(owners)), 'mixed/missing user ownership')
    owner = next(iter(owners))
    require(len({r.get('id') for r in records}) == len(records), 'duplicate PocketBase record primary keys')
    require(len({r.get('id') for r in categories}) == len(categories), 'duplicate PocketBase category primary keys')

    def conflicts(items, field):
        counts = collections.Counter(x.get(field) for x in items if x.get(field))
        return {k for k, n in counts.items() if n > 1}

    r_conflict = conflicts(records, 'record_id')
    c_conflict = conflicts(categories, 'category_id')
    p_conflict = conflicts([p for _, p in plans], 'pocketRecordId')
    queues = []
    for entry in data.get('indexedDB', {}).get('lifeos_record_journal_v1', {}).get('entry', []):
        value = entry.get('value') or {}
        store = value.get('store')
        if value.get('key') != 'queue' or store not in ('record_mutations', 'plan_mutations'):
            continue
        batch = json.loads(value['value']['raw'])
        require(isinstance(batch, list) and all(isinstance(x, dict) for x in batch), 'invalid durable journal')
        queues.extend((store, x) for x in batch)

    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix='.lifeos-salvage-', suffix='.sqlite', dir=target.parent)
    os.close(fd)
    try:
        os.chmod(temp, 0o600)
        conn = sqlite3.connect(temp)
        try:
            conn.executescript("""
                PRAGMA journal_mode=DELETE;
                CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE categories (pb_id TEXT PRIMARY KEY, business_id TEXT, owner_id TEXT, status TEXT NOT NULL, raw TEXT NOT NULL);
                CREATE TABLE records (pb_id TEXT PRIMARY KEY, business_id TEXT, owner_id TEXT, status TEXT NOT NULL, raw TEXT NOT NULL);
                CREATE TABLE plan_versions (n INTEGER PRIMARY KEY AUTOINCREMENT, pb_id TEXT, business_id TEXT, cache_day TEXT, legacy_category_id TEXT, status TEXT NOT NULL, raw TEXT NOT NULL);
                CREATE TABLE offline_mutations (n INTEGER PRIMARY KEY AUTOINCREMENT, queue TEXT NOT NULL, operation_id TEXT, kind TEXT, business_id TEXT, raw TEXT NOT NULL);
            """)
            serialized = lambda x: json.dumps(x, ensure_ascii=False, sort_keys=True, separators=(',', ':'))
            meta = {
                'source_sha256': digest, 'owner_pb_id': owner,
                'inventory_format': 'lifeos-salvage-v1',
                'source_export_date': str(data.get('date','')),
                'created_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'disposition': 'offline read-only inventory; NOT a PocketBase database',
            }
            conn.executemany('INSERT INTO metadata VALUES (?,?)', list(meta.items()))
            conn.executemany('INSERT INTO categories VALUES (?,?,?,?,?)', [
                (r['id'], str(r.get('category_id','')), owner,
                 'business_id_conflict' if r.get('category_id') in c_conflict else 'candidate',
                 serialized(r)) for r in categories])
            conn.executemany('INSERT INTO records VALUES (?,?,?,?,?)', [
                (r['id'], str(r.get('record_id','')), owner,
                 'business_id_conflict' if r.get('record_id') in r_conflict else 'candidate',
                 serialized(r)) for r in records])
            conn.executemany('INSERT INTO plan_versions (pb_id,business_id,cache_day,legacy_category_id,status,raw) VALUES (?,?,?,?,?,?)', [
                (str(r.get('pocketRecordId') or ''), str(r.get('plan_row_id') or ''), day,
                 str(r.get('categoryId', r.get('category_id', ''))),
                 'missing_identity' if not r.get('pocketRecordId') or not r.get('plan_row_id')
                 else 'conflicting_cached_versions' if r.get('pocketRecordId') in p_conflict
                 else 'needs_category_mapping',
                 serialized(r)) for day,r in plans])
            conn.executemany('INSERT INTO offline_mutations (queue,operation_id,kind,business_id,raw) VALUES (?,?,?,?,?)', [
                (store, str(op.get('operationId','')),str(op.get('kind','')),str(op.get('businessId','')),
                 serialized(op)) for store,op in queues])
            conn.commit()
            require(conn.execute('PRAGMA integrity_check').fetchone()[0] == 'ok', 'SQLite corruption')
            for table, expected in [('categories', len(categories)),('records',len(records)),
                                    ('plan_versions',len(plans)),('offline_mutations',len(queues))]:
                require(conn.execute('SELECT COUNT(*) FROM ' + table).fetchone()[0] == expected,
                        table + ': row count mismatch')
        finally:
            conn.close()
        report = {
            'source_sha256': digest, 'owner_pb_id': owner,
            'records': len(records), 'categories': len(categories),
            'plan_versions': len(plans), 'unique_plan_pb_ids': len({r.get('pocketRecordId') for _,r in plans if r.get('pocketRecordId')}),
            'record_duplicate_business_id_groups': len(r_conflict),
            'category_duplicate_business_id_groups': len(c_conflict),
            'plan_conflicting_groups': len(p_conflict),
            'offline_pending_operations': len(queues),
            'replayed_operations': 0, 'pocketbase_modified': False,
            'production_import_safe': False,
            'warning': 'Preserved conflicts and unresolved legacy category IDs; do not directly import to PocketBase.',
        }
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', prefix='.lifeos-report-',dir=target.parent,delete=False) as f:
            tmp_report = f.name
            json.dump(report,f,ensure_ascii=False,indent=2)
            f.write('\n')
        os.chmod(tmp_report,0o600)
        os.replace(temp,str(target))
        os.replace(tmp_report,str(report_file))
        print('PASS: browser export hash verified; generated separate SQLite rescue inventory')
        print('PASS: SQLite integrity, raw rows and conflict-preserving checks')
        print(f"COUNTS: {len(records)} records; {len(categories)} categories; {len(plans)} plan versions; {len(queues)} pending operations")
        print('PASS: no PocketBase databases or services modified')
    finally:
        if os.path.exists(temp):
            os.remove(temp)

if __name__ == '__main__':
    try:
        require(len(sys.argv)==3, 'usage: prepare_browser_salvage.py INPUT.json OUTPUT.sqlite')
        main(sys.argv[1],sys.argv[2])
    except Exception as e:
        print('ERROR:',e,file=sys.stderr)
        sys.exit(1)
