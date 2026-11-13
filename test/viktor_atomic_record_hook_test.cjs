'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

let handler;
vm.runInNewContext(fs.readFileSync('pb_hooks/viktor.record_resize.pb.js', 'utf8'),
  {routerAdd(method, route, fn) {
    assert.equal(method, 'POST');
    assert.equal(route, '/api/viktor/records/resize-adjacent');
    handler = fn;
  }, Date, Set, Object, Array, Number, String, RegExp, Math}, {timeout: 3000});
assert.equal(typeof handler, 'function');

const owner = 'aaaaabbbbbccccc';
const stranger = 'bbbbbaaaaaccccc';
const firstId = 'firstrecord0001';
const secondId = 'secondrecord001';
const obstacleId = 'otherrecord0001';
const revision = '2026-11-13T17:30:00.000Z';
const start = '2026-11-13T13:00:00.000Z';
const oldBoundary = '2026-11-13T14:00:00.000Z';
const finish = '2026-11-13T16:00:00.000Z';
const newBoundary = '2026-11-13T13:30:00.000Z';

const clone = data => JSON.parse(JSON.stringify(data));
let rows;
let rejectedSave = '';
function reset() {
  rows = {
    [firstId]: {user_id:owner, title:'Обед', parent_id:'',
      updated:revision,status:'stopped',start_time:start,
      end_time:oldBoundary},
    [secondId]: {user_id:owner, title:'Этника сайт', parent_id:'',
      updated:revision,status:'stopped',start_time:oldBoundary,
      end_time:finish},
  };
  rejectedSave = '';
}
reset();
function model(id, obj) {
  return {id, getString(k) {return String(obj[k] ?? '');},
    set(k,v) {obj[k] = v;}};
}
const app = {
  runInTransaction(callback) {
    const staged = clone(rows);
    callback({
      findRecordById(table,id) {
        assert.equal(table,'records');
        if (!staged[id]) throw new Error('missing_record');
        return model(id,staged[id]);
      },
      findRecordsByFilter(table,filter,sort,limit,offset,params) {
        assert.equal(table,'records');
        return Object.entries(staged).filter(([,row]) => {
          if (row.user_id !== owner) return false;
          const t = Date.parse(row.start_time);
          if (filter.includes('start_time >')) {
            return t > Date.parse(params.first) &&
              t < Date.parse(params.second);
          }
          const end = row.end_time ? Date.parse(row.end_time)
              : Number.POSITIVE_INFINITY;
          return t < Date.parse(params.finish) &&
            end > Date.parse(params.begin);
        }).map(([id,obj])=>model(id,obj));
      },
      save(record) {
        if (record.id === rejectedSave) throw Error('simulated_save_failure');
      },
    });
    rows = staged;
  },
};
function request() {
  return {
    request_id:'viktor_20261113_abcdef012345',
    first:{id:firstId,expected_title:'Обед',expected_status:'stopped',
      expected_updated:revision,expected_start:start,
      expected_end:oldBoundary,new_end:newBoundary},
    second:{id:secondId,expected_title:'Этника сайт',
      expected_status:'stopped',expected_updated:revision,
      expected_start:oldBoundary,expected_end:finish,
      new_start:newBoundary},
  };
}
function call(payload=request(), user=owner) {
  let answer;
  handler({
    requestInfo() {return {auth:user ? {id:user} : null,body:payload};},
    app, json(status,body) {answer={status,body}; return answer;},
  });
  return answer;
}
assert.equal(call(request(),null).status,401);
assert.equal(call({...request(),rogue:true}).status,200,
  'Extra top-level fields are inert and cannot change the whitelist');
reset();
const wrongUser=call(request(),stranger);
assert.equal(wrongUser.status,409);
assert.equal(rows[firstId].end_time,oldBoundary);
reset();
assert.equal(call({...request(),first:{...request().first,
  unexpected:'anything'}}).status,400);
assert.equal(call({...request(),second:{...request().second,
  id:firstId}}).status,400);
assert.equal(call({...request(),first:{...request().first,
  new_end:'2026-11-13T14:30:00.000Z'}}).status,400);
assert.equal(call({...request(),second:{...request().second,
  expected_updated:'2026-11-13T17:30:00.500Z'}}).status,409);
assert.equal(rows[firstId].end_time,oldBoundary);
rows[obstacleId]={user_id:owner,title:'Call',parent_id:'',
  updated:revision,status:'stopped',
  start_time:'2026-11-13T13:40:00.000Z',
  end_time:'2026-11-13T13:55:00.000Z'};
assert.equal(call().status,409);
assert.equal(rows[firstId].end_time,oldBoundary);
delete rows[obstacleId];
rejectedSave=secondId;
assert.equal(call().status,409);
assert.equal(rows[firstId].end_time,oldBoundary,
  'Failure on second save must rollback first edit');
rejectedSave='';
assert.equal(call().status,200);
assert.equal(rows[firstId].end_time,newBoundary);
assert.equal(rows[secondId].start_time,newBoundary);
assert.equal(rows[secondId].end_time,finish);
assert.equal(call().status,409,
  'A stale request cannot be committed twice');
process.stdout.write('Viktor atomic Record resize transaction verified\\n');
