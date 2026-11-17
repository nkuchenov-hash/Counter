'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

let createRoute;
class MockRecord {
  constructor() { this.id = ''; this.values = {}; }
  set(name, value) { this.values[name] = value; }
  getString(name) { return String(this.values[name] ?? ''); }
  getBool(name) { return this.values[name] === true; }
}
vm.runInNewContext(
  fs.readFileSync('pb_hooks/viktor.schedule_commit.pb.js', 'utf8'),
  {routerAdd(method, path, handler) {
    assert.equal(method, 'POST');
    if (path === '/api/viktor/schedule/create') createRoute = handler;
  }, Record: MockRecord, Date, Set, Math, Number, Object, String, Array, RegExp},
  {timeout: 3000}
);
assert.equal(typeof createRoute, 'function');

const owner = 'aaaaabbbbbccccc';
const category = 'ccccccccccccccc';
const otherCategory = 'ddddddddddddddd';
const one = '00000000-0000-5000-8000-000000000001';
const two = '00000000-0000-5000-8000-000000000002';
const start = '2026-11-17T17:00:00.000Z';
const end = '2026-11-17T17:30:00.000Z';
const start2 = '2026-11-17T17:30:00.000Z';
const end2 = '2026-11-17T18:00:00.000Z';
const clone = x => JSON.parse(JSON.stringify(x));
const rows = [
  {plan_id:one, title:'Cook eggs', category_id:category,
   start_time:start, end_time:end, initial_date_key:'2026-11-17'},
  {plan_id:two, title:'Cook fish', category_id:category,
   start_time:start2, end_time:end2, initial_date_key:'2026-11-17'},
];
let stored = {};
let failOnIndex = -1;
const app = {
  runInTransaction(callback) {
    const staged = clone(stored);
    let sequence = Object.keys(staged).length;
    let saved = 0;
    const tx = {
      findRecordById(collectionName, id) {
        assert.equal(collectionName, 'categories');
        const values = {
          [category]: {user_id:owner, is_archived:false},
          [otherCategory]: {user_id:'different_user', is_archived:false},
        }[id];
        if (!values) throw new Error('category_not_found');
        const record = new MockRecord();
        record.id = id; record.values = values;
        return record;
      },
      findRecordsByFilter(collectionName, filter, order, limit, offset, params) {
        assert.equal(collectionName, 'plans');
        return Object.entries(staged).filter(([, values]) => {
          if (values.user_id !== params.owner) return false;
          if (params.pid != null) return values.plan_id === params.pid;
          return Date.parse(values.start_time) < Date.parse(params.latest) &&
            Date.parse(values.end_time) > Date.parse(params.earliest);
        }).map(([id, values]) => {
          const record = new MockRecord();
          record.id = id; record.values = values; return record;
        });
      },
      findCollectionByNameOrId(name) { assert.equal(name, 'plans'); return {}; },
      save(record) {
        if (saved++ === failOnIndex) throw new Error('simulated_db_failure');
        record.id = 'created' + String(++sequence).padStart(8, '0');
        staged[record.id] = clone(record.values);
      },
    };
    callback(tx);
    stored = staged; // all-or-nothing
  },
};
function call(creates = rows, authenticated = owner) {
  let outcome;
  createRoute({
    requestInfo() { return {
      auth: authenticated ? {id:authenticated} : null,
      body: {request_id:'viktor_20261117_batch', creates},
    }; },
    app,
    json(status, body) { outcome = {status, body}; return outcome; },
  });
  return outcome;
}
assert.equal(call(rows, null).status, 401);
assert.equal(call([rows[0]]).status, 400);
assert.equal(call([rows[0], rows[0]]).status, 400);
assert.equal(call([rows[0], {...rows[1], start_time:start}]).status, 400);
assert.equal(Object.keys(stored).length, 0);
assert.equal(call([{...rows[0], category_id:otherCategory}, rows[1]]).status,409);
assert.equal(Object.keys(stored).length, 0);
stored['blocker00000001'] = {user_id:owner, title:'Already booked',
  plan_id:'another-plan', start_time:start, end_time:end};
assert.equal(call().status, 409);
delete stored['blocker00000001'];
failOnIndex=1;
assert.equal(call().status,409);
assert.equal(Object.keys(stored).length,0, 'rollback on second save failure');
failOnIndex=-1;
const first=call();
assert.equal(first.status,200);
assert.equal(first.body.count,2);
assert.equal(first.body.replay,false);
assert.equal(Object.keys(stored).length,2);
const retry=call();
assert.equal(retry.status,200);
assert.equal(retry.body.replay,true);
assert.equal(Object.keys(stored).length,2, 'idempotent retry cannot duplicate');
assert.equal(call([{...rows[0], title:'Changed'}, rows[1]]).status,409);
assert.equal(Object.keys(stored).length,2);
process.stdout.write('Viktor atomic multi-plan create verified\n');
