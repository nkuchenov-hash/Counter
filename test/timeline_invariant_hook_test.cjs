'use strict';
// Behavioural checks against the actual PocketBase interval helper.
// No production data, provider credentials or server writes.
const assert = require('node:assert/strict');
const h = require('../pb_hooks/records.interval_sanitize_helpers.js');
const { test } = require('node:test');
global.BadRequestError = class BadRequestError extends Error {};
const owner = 'owner1234567890';
const other = 'other1234567890';
const iso = (value) => new Date(value).toISOString();
const at = (time) => '2026-11-27T' + time + ':00.000+03:00';
const record = (id, start, end, extra = {}) => ({
  id, user_id: owner, parent_id: '', start_time: iso(start),
  end_time: end ? iso(end) : '', status: end ? 'completed' : 'running',
  ...extra,
});
const model = (row) => ({
  id: row.id,
  get: (field) => row[field],
  set: (field, value) => { row[field] = value; },
  data: row,
});
function fixture(records, fail = false) {
  const stored = new Map(records.map(row => [row.id, {...row}]));
  function makeApp(data, inTx = false) {
    return {
      findRecordsByFilter(collection, filter, order, limit, offset, params) {
        assert.equal(collection, 'records');
        assert.equal(params.uid, owner);
        let rows = [...data.values()].filter(row => row.user_id === params.uid);
        if (filter.includes("parent_id = ''")) rows = rows.filter(row => !row.parent_id);
        if (filter.includes('id != {:id}')) rows = rows.filter(row => row.id !== params.id);
        // Emulate PocketBase's string comparison rather than Date.parse, which
        // would hide a production bug caused by using T instead of a space.
        const dbDate = value => value.replace('T', ' ');
        if (params.start) assert.match(params.start, /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}Z$/);
        if (filter.includes('start_time >= {:start}')) rows = rows.filter(row =>
          dbDate(row.start_time) >= params.start);
        if (filter.includes('start_time < {:start}')) rows = rows.filter(row =>
          dbDate(row.start_time) < params.start);
        if (filter.includes("end_time = '' || end_time > {:start}")) rows = rows.filter(row =>
          !row.end_time || dbDate(row.end_time) > params.start);
        rows.sort((a,b) => Date.parse(a.start_time) - Date.parse(b.start_time) ||
          a.id.localeCompare(b.id));
        if (order.startsWith('-')) rows.reverse();
        return rows.slice(offset, limit > 0 ? offset + limit : undefined)
          .map(row => model({...row}));
      },
      findRecordById(collection, id) {
        assert.equal(collection, 'records');
        assert.ok(data.has(id), 'Missing row ' + id);
        return model({...data.get(id)});
      },
      saveNoValidate(row) {
        if (fail) throw new Error('injected save failure');
        // Real PB invokes model hooks for corrective writes as well.
        const event = {app:this, record:row, next() {
          event.app._persist(row);
        }};
        h.reconcileRecordWrite(event);
      },
      _persist(row) { data.set(row.id, {...row.data}); },
      runInTransaction(callback) {
        if (inTx) { callback(this); return; }
        const staged = new Map([...data].map(([key,row]) => [key,{...row}]));
        callback(makeApp(staged, true));
        data.clear();
        for (const [id,row] of staged) data.set(id,row);
      },
    };
  }
  return {app:makeApp(stored), stored};
}
function write(app, row) {
  const subject = model({...row});
  const event = {app, record:subject, next() {
    event.app._persist(subject);
  }};
  h.reconcileRecordWrite(event);
  assert.equal(event.app, app, 'Original app restored');
  return subject.data;
}
function assertNoOverlap(stored) {
  const rows = [...stored.values()].filter(r => r.user_id === owner && !r.parent_id)
    .sort((a,b) => Date.parse(a.start_time) - Date.parse(b.start_time));
  for (let i=1;i<rows.length;i++) {
    const prior=rows[i-1], next=rows[i];
    assert.ok(prior.end_time && Date.parse(prior.end_time) <= Date.parse(next.start_time),
      'Overlapping primary records: ' + prior.id + ' / ' + next.id);
  }
}
function screenshotRows() {
  return [
    record('preparation', at('00:40'), at('09:23')),
    record('sleep', at('01:57'), at('09:17'), {
      title:'Сон', sleep_source:'xiaomi', external_kind:'sleep',
    }),
    record('morning', at('09:23'), null),
  ];
}
test('exact reported sleep overlap is reconciled without shortening sleep', () => {
  const {app, stored} = fixture(screenshotRows());
  h.sanitizeAllPrimaryIntervalsForUser(app, owner);
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assert.equal(stored.get('sleep').end_time, iso(at('09:17')));
  assertNoOverlap(stored);
});
test('recent sleep overlap is repaired even beyond the first 2000 historical rows', () => {
  const old = Array.from({length: 2101}, (_,i) => {
    const start = Date.UTC(2025,0,1) + i * 3600000;
    return record('history-'+i, start, start + 1800000);
  });
  const {app, stored} = fixture([...old, ...screenshotRows()]);
  h.sanitizeAllPrimaryIntervalsForUser(app, owner);
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assert.equal(stored.get('sleep').end_time, iso(at('09:17')));
  assertNoOverlap(stored);
});
test('a late stop cannot overwrite an existing sleep boundary in a large history', () => {
  const old = Array.from({length: 2101}, (_,i) => {
    const start = Date.UTC(2025,0,1) + i * 3600000;
    return record('history-'+i, start, start + 1800000);
  });
  const rows = screenshotRows();
  const {app} = fixture([...old, ...rows]);
  const subject = model({...rows[0]});
  h.clampSubjectEndAgainstLaterStarts(app, subject, subject.id);
  assert.equal(subject.get('end_time'), iso(at('01:57')));
});
test('open predecessor closes at sleep start; child and another owner are untouched', () => {
  const rows = screenshotRows();
  rows[0].end_time = '';
  rows[0].status = 'running';
  rows.push(record('child', at('01:00'), at('09:00'), {parent_id:'preparation'}));
  rows.push(record('other-owner', at('00:00'), at('10:00'), {user_id:other}));
  const {app, stored} = fixture(rows);
  h.sanitizeAllPrimaryIntervalsForUser(app, owner);
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assert.equal(stored.get('preparation').status, 'completed');
  assert.equal(stored.get('child').end_time, iso(at('09:00')));
  assert.equal(stored.get('other-owner').end_time, iso(at('10:00')));
  assertNoOverlap(stored);
});
test('adjacent boundaries are valid and do not alter either record', () => {
  const rows = screenshotRows();
  rows[0].end_time = iso(at('01:57'));
  const {app, stored} = fixture(rows);
  h.sanitizeAllPrimaryIntervalsForUser(app, owner);
  assert.deepEqual([...stored.values()], rows);
  assertNoOverlap(stored);
});
test('failed corrective save must not report successful reconciliation', () => {
  const {app} = fixture(screenshotRows(), true);
  assert.throws(() => h.sanitizeAllPrimaryIntervalsForUser(app, owner),
    /injected save failure/);
});

test('server import atomically repairs an open predecessor and preserves source bounds', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture([{...rows[0], end_time:'', status:'running'}]);
  write(app, rows[1]);
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assert.equal(stored.get('sleep').end_time, iso(at('09:17')));
  assertNoOverlap(stored);
});
test('failed predecessor correction rolls back the sleep insert', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture([rows[0]], true);
  assert.throws(() => write(app, rows[1]), /injected save failure/);
  assert.equal(stored.has('sleep'), false);
  assert.deepEqual(stored.get('preparation'), rows[0]);
});
test('late Stop cannot expand across authoritative sleep', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture(rows);
  write(app, rows[0]);
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assertNoOverlap(stored);
});
test('second running primary closes the old timer without touching child records', () => {
  const rows = screenshotRows();
  const child = record('child', at('01:00'), null, {parent_id:'preparation'});
  const {app, stored} = fixture([{...rows[0], end_time:'', status:'running'}, child]);
  write(app, rows[2]);
  assert.equal(stored.get('preparation').end_time, iso(at('09:23')));
  assert.notEqual(stored.get('preparation').status, 'running');
  assert.equal(stored.get('child').end_time, '');
  assertNoOverlap(stored);
});
test('ordinary record starting inside sleep is rejected without modifying data', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture([rows[1]]);
  assert.throws(() => write(app, record('conflict', at('03:00'), at('04:00'))),
    /authoritative sleep/);
  assert.deepEqual([...stored.values()], [rows[1]]);
});
test('same-start conflicting primary cannot silently produce a zero-length replacement', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture([rows[1]]);
  assert.throws(() => write(app, record('conflict', at('01:57'), at('04:00'))),
    /Conflicting primary/);
  assert.deepEqual([...stored.values()], [rows[1]]);
});
test('scheduled repair uses atomic predecessor correction and preserves sleep', () => {
  const rows = screenshotRows();
  const {app, stored} = fixture(rows);
  h.repairSleepPredecessors(app, model(rows[1]));
  assert.equal(stored.get('preparation').end_time, iso(at('01:57')));
  assert.equal(stored.get('sleep').end_time, iso(at('09:17')));
  assertNoOverlap(stored);
});
