#!/usr/bin/env python3
"""Fixture test for browser rescue normalizer. No real user data."""
import json
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile

with tempfile.TemporaryDirectory() as path:
    base=pathlib.Path(path)
    export={
      'type':'LIFE_OS_BROWSER_RECOVERY','date':'2026-11-04T00:00:00Z',
      'localStorage':{
        'flutter.cache_records_flat_v1_anon':json.dumps(json.dumps([])),
        'flutter.cache_records_flat_v1_11111111-1111-4111-8111-111111111111':
          json.dumps(json.dumps([
            {'id':'record000000001','record_id':'same','user_id':'abcdefghijklmno'},
            {'id':'record000000002','record_id':'same','user_id':'abcdefghijklmno'}
          ])),
        'flutter.cache_categories_raw_v1_11111111-1111-4111-8111-111111111111':
          json.dumps(json.dumps([
            {'id':'category0000001','category_id':'category','user_id':'abcdefghijklmno'},
            {'id':'category0000002','category_id':'category','user_id':'abcdefghijklmno'}
          ])),
        'flutter.cache_plans_day_v1_11111111-1111-4111-8111-111111111111_2026-09-30':
          json.dumps(json.dumps([
            {'pocketRecordId':'plan00000000001','plan_row_id':'plan-one','categoryId':123}
          ])),
        'flutter.cache_plans_day_v1_11111111-1111-4111-8111-111111111111_2026-10-01':
          json.dumps(json.dumps([
            {'pocketRecordId':'plan00000000001','plan_row_id':'plan-one','categoryId':123}
          ]))
      },
      'indexedDB':{'lifeos_record_journal_v1':{'entry':[{
        'value':{'store':'record_mutations','key':'queue',
                 'value':{'raw':json.dumps([{'operationId':'op1','businessId':'biz1','kind':'highlander_start'}])}}
      }]}},
      'errors':[]
    }
    src=base/'export.json'
    output=base/'inventory.sqlite'
    src.write_text(json.dumps(export))
    env=dict(os.environ, LIFEOS_TEST_FIXTURE='1')
    subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('prepare_browser_salvage.py')),
                    str(src),str(output)],env=env,check=True)
    db=sqlite3.connect(output)
    for table,expected in [('records',2),('categories',2),('plan_versions',2),('offline_mutations',1)]:
        assert db.execute('SELECT COUNT(*) FROM '+table).fetchone()[0]==expected
    assert db.execute("SELECT COUNT(*) FROM plan_versions WHERE status='conflicting_cached_versions'").fetchone()[0]==2
    assert db.execute("SELECT COUNT(*) FROM records WHERE status='business_id_conflict'").fetchone()[0]==2
    assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
    db.close()
    assert output.with_suffix('.report.json').is_file()
    again=subprocess.run([sys.executable,str(pathlib.Path(__file__).with_name('prepare_browser_salvage.py')),
                    str(src),str(output)],env=env,capture_output=True,text=True)
    assert again.returncode != 0 and 'overwrite' in again.stderr
    print('PASS: rescue normalizer preserves original versions, quarantines conflicts and refuses overwrite.')
