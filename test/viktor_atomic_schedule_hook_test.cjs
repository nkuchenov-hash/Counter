'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
let route;
vm.runInNewContext(
  fs.readFileSync('pb_hooks/viktor.schedule_commit.pb.js', 'utf8'),
  {routerAdd(method, path, handler) {
    assert.equal(method, 'POST');
    assert.equal(path, '/api/viktor/schedule/commit');
    route = handler;
  }, Date, Set, Math, Number, Object, String, Array, RegExp},
  {timeout: 3000}
);
assert.equal(typeof route, 'function');
const owner = 'aaaaabbbbbccccc';
const other = 'rrrrrsssssttttt';
const one = 'aaaaabbbbb11111';
const two = 'aaaaabbbbb22222';
const blocker = 'aaaaabbbbb33333';
const fresh = '2026-10-22T17:00:00.000Z';
const t1 = '2026-10-20T11:00:00.000Z';
const t2 = '2026-10-20T12:00:00.000Z';
const t3 = '2026-10-20T13:00:00.000Z';
const copy = value => JSON.parse(JSON.stringify(value));
let data;
let rejectSaveId = null;
function reset() {
  data = {
    [one]: {user_id:owner,title:'Report',is_done:false,
      updated:fresh,start_time:t1,end_time:t2,
      category_id:'',rrule:'',recurrence_instance_date_key:'',
      external_read_only:false},
    [two]: {user_id:owner,title:'Call',is_done:false,
      updated:fresh,start_time:t2,end_time:t3,
      category_id:'',rrule:'',recurrence_instance_date_key:'',
      external_read_only:false},
  };
  rejectSaveId = null;
}
reset();
function mockRecord(id, values) {
  return {
    id, data: values,
    getString(key) {return String(values[key] ?? '');},
    getBool(key) {return values[key] === true;},
    set(key, value) {values[key] = value;},
  };
}
const app = {
  runInTransaction(callback) {
    const staged = copy(data);
    const tx = {
      findRecordById(collection, id) {
        assert.equal(collection, 'plans');
        if (!staged[id]) throw new Error('plan_missing');
        return mockRecord(id, staged[id]);
      },
      findRecordsByFilter(collection, filter, order, limit, offset, params) {
        assert.equal(collection, 'plans');
        assert.equal(params.owner, owner);
        return Object.entries(staged).filter(([,r]) =>
          r.user_id === owner && Date.parse(r.start_time) < Date.parse(params.latest) &&
          Date.parse(r.end_time) > Date.parse(params.earliest))
          .map(([id, r]) => mockRecord(id, r));
      },
      save(record) {
        if (record.id === rejectSaveId) throw new Error('simulated_failure');
      },
    };
    callback(tx);
    data = staged; // only successful tx commits
  },
};
const patch = (id, originalStart, originalEnd, nextStart, nextEnd, title) => ({
  id, expected_updated:fresh, expected_start:originalStart,
  expected_end:originalEnd, expected_title:title, expected_is_done:false,
  start_time:nextStart, end_time:nextEnd,
  initial_date_key:'2026-10-20', is_postponed:true,
});
const moves = [
  patch(one,t1,t2,'2026-10-21T09:00:00.000Z',
    '2026-10-21T10:00:00.000Z','Report'),
  patch(two,t2,t3,'2026-10-21T10:00:00.000Z',
    '2026-10-21T11:00:00.000Z','Call'),
];
function call(patches = moves, userId = owner) {
  let result;
  route({
    requestInfo() {return {
      auth:userId ? {id:userId} : null,
      body:{request_id:'viktor_20261022_atomic', patches},
    };},
    app,
    json(status, body) {result={status,body};return result;},
  });
  return result;
}
assert.equal(call(moves, null).status, 401);
assert.equal(call([{...moves[0], unexpected:'danger'}]).status,400);
assert.equal(call([moves[0], {...moves[0]}]).status,400,
  'duplicate plan IDs must be rejected at validation before transaction');
assert.equal(data[one].start_time,t1,
  'duplicate plan validation must not change any plan');
assert.equal(call([moves[0], {...moves[0], id:'invalid'}]).status,400,
  'malformed plan IDs must be rejected before transaction');
assert.equal(call(moves, other).status,409);
assert.equal(data[one].start_time,t1, 'owner mismatch must not write');
const stale = moves.map(p => ({...p}));
stale[1].expected_updated='2026-10-21T10:00:00.000Z';
assert.equal(call(stale).status,409);
assert.equal(data[one].start_time,t1, 'stale row must rollback entire batch');
data[blocker] = {...data[one],
  title:'Another appointment',
  start_time:'2026-10-21T09:30:00.000Z',
  end_time:'2026-10-21T10:30:00.000Z'};
assert.equal(call(moves).status,409);
assert.equal(data[one].start_time,t1,'colliding destination must rollback');
delete data[blocker];
rejectSaveId=two;
assert.equal(call(moves).status,409);
assert.equal(data[one].start_time,t1,'failure in second write must rollback first');
rejectSaveId=null;
const ok=call(moves);
assert.equal(ok.status,200);
assert.equal(ok.body.updated,2);
assert.equal(data[one].start_time,'2026-10-21T09:00:00.000Z');
assert.equal(data[two].start_time,'2026-10-21T10:00:00.000Z');
assert.equal(data[one].is_postponed,true);
assert.equal(call(moves).status,409,
 'stale retry must not blindly apply the same command a second time');
process.stdout.write('Viktor atomic multi-day schedule commit verified\n');
