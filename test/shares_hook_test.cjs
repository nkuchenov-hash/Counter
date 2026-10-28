'use strict';
// Run: node test/shares_hook_test.cjs
// Pure Node test: no PocketBase server needed. Confirms route permission gates
// before server deployment. Full two-account device E2E remains a separate gate.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const routes = new Map();
const db = {
  profiles: [], people: [], plans: [],
  shared_objects: [], shared_members: [], shared_messages: [],
};
let nextId = 1;
class Record {
  constructor(collection) {
    this.collection = collection;
    this.id = String(nextId++).padStart(15, '0');
    this.data = {};
  }
  set(k, v) { this.data[k] = v; }
  get(k) { return this.data[k]; }
  getString(k) { return String(this.data[k] ?? ''); }
  getBool(k) { return this.data[k] === true; }
  getInt(k) { return Number(this.data[k] || 0); }
}
function row(table, id, data) {
  const out = new Record(table);
  out.id = id;
  out.data = {...data, created: '2026-10-28T00:00:00Z'};
  db[table].push(out);
  return out;
}
const owner = 'aaaaabbbbbccccc', recipient = 'dddddeeeeefffff';
const outsider = 'ggggghhhhhiiiii';
const ownerPlan = '111112222233333';
const personId = '444445555566666';
const blockedId = '777778888899999';
row('profiles', owner, {email: 'owner@sample.test', verified: true});
row('profiles', recipient, {email: 'friend@sample.test', verified: true});
row('profiles', outsider, {email: 'other@sample.test', verified: true});
row('people', personId, {
  user_id: owner, primary_email: 'friend@sample.test',
  relationship_status: 'important', archived: false,
});
row('people', blockedId, {
  user_id: owner, primary_email: 'other@sample.test',
  relationship_status: 'blocked', archived: false,
});
row('plans', ownerPlan, {
  user_id: owner, title: 'Walk', notes_plain: 'PRIVATE JOURNAL',
  start_time: '2026-10-31 13:00:00.000Z',
  end_time: '2026-10-31 14:00:00.000Z', order: 2,
});

const $app = {
  findCollectionByNameOrId: name => name,
  save: record => {
    const records = db[record.collection];
    if (!records.includes(record)) records.push(record);
  },
  findRecordById: (table, id) => {
    const out = db[table].find(record => record.id === id);
    if (!out) throw new Error('not found: '+table);
    return out;
  },
  findFirstRecordByFilter: (table, filter, args) => {
    let found;
    if (table === 'profiles') {
      found = db.profiles.find(r => r.getString('email') === args.email &&
        r.getBool('verified'));
    } else if (table === 'shared_members') {
      found = db.shared_members.find(r => r.getString('object_id') === args.sid &&
        r.getString('user_id') === args.uid);
    }
    if (!found) throw new Error('not found');
    return found;
  },
  findRecordsByFilter: (table, filter, sort, limit, offset, args) => {
    const rows = db[table].filter(r => {
      if (table === 'shared_objects') {
        return r.getString('owner_id') === args.uid && !r.getBool('archived');
      }
      if (table === 'shared_members') {
        return filter.includes('object_id')
          ? r.getString('object_id') === args.sid
          : r.getString('user_id') === args.uid &&
            r.getString('status') !== 'revoked';
      }
      return r.getString('object_id') === args.sid;
    });
    return rows.slice(offset, offset+limit);
  },
  runInTransaction: fn => fn($app),
};
vm.runInNewContext(fs.readFileSync('pb_hooks/shares.pb.js', 'utf8'), {
  Record, $app, Date, Set, JSON,
  routerAdd: (method, path, handler) => routes.set(method+' '+path, handler),
}, {timeout: 5000});

function call(method, path, user, body = {}, params = {}) {
  const handler = routes.get(method+' '+path);
  assert.ok(handler, method+' '+path);
  let response;
  handler({
    requestInfo: () => ({auth: user ? {id: user} : null, body}),
    request: {pathValue: name => params[name]},
    json: (status, data) => (response = {status, data}),
  });
  assert.ok(response);
  return response;
}
assert.equal(call('POST', '/api/shares', '', {}).status, 401);
assert.equal(call('POST', '/api/shares', outsider, {
  kind:'plan_day', wall_day:'2026-10-31', plan_ids:[ownerPlan],
}).status, 403);
assert.equal(call('POST', '/api/shares', owner, {
  kind:'plan_day', wall_day:'bad', plan_ids:[ownerPlan],
}).status, 400);
const created = call('POST', '/api/shares', owner, {
  kind:'plan_day', wall_day:'2026-10-31', plan_ids:[ownerPlan],
  title:'Saturday',
});
assert.equal(created.status, 201);
assert.equal(created.data.content.items[0].title, 'Walk');
assert.equal(JSON.stringify(created.data).includes('PRIVATE JOURNAL'), false,
  'Server must not serialize private plan Notes into a share');
const shareId = created.data.share.id;
const idParam = {id:shareId};
assert.equal(call('GET','/api/shares/{id}', outsider, {}, idParam).status,404);
assert.equal(call('GET','/api/shares/{id}', recipient, {}, idParam).status,404);
assert.equal(call('POST','/api/shares/{id}/invite',owner,
  {person_record_id:blockedId}, idParam).status,403);
assert.equal(call('POST','/api/shares/{id}/invite',recipient,
  {person_record_id:personId}, idParam).status,403);
const invite = call('POST','/api/shares/{id}/invite',owner,
  {person_record_id:personId}, idParam);
assert.equal(invite.status,200);
assert.equal(invite.data.member.user_id, recipient);
assert.equal(call('GET','/api/shares',recipient).data.shares[0].my_status,'invited');
assert.equal(call('GET','/api/shares/{id}',recipient,{},idParam).status,404);
const ownerDay = call('POST', '/api/shares/day', owner,
  {wall_day:'2026-10-31'});
assert.equal(ownerDay.status, 200);
assert.equal(ownerDay.data.shares.length, 1);
assert.equal(ownerDay.data.shares[0].content.items[0].title, 'Walk');
assert.equal(call('POST', '/api/shares/day', recipient,
  {wall_day:'2026-10-31'}).data.shares.length, 0,
  'Invited recipient cannot read shared day contents');
assert.equal(call('POST', '/api/shares/day', outsider,
  {wall_day:'2026-10-31'}).data.shares.length, 0);
assert.equal(call('POST', '/api/shares/day', owner,
  {wall_day:'invalid'}).status, 400);

assert.equal(call('POST','/api/shares/{id}/respond',recipient,
  {accept:true},idParam).status,200);
assert.equal(call('GET','/api/shares/{id}',recipient,{},idParam).status,200);
const participantDay = call('POST', '/api/shares/day', recipient,
  {wall_day:'2026-10-31'});
assert.equal(participantDay.status, 200);
assert.equal(participantDay.data.shares.length, 1);
assert.equal(participantDay.data.shares[0].my_status, 'accepted');
assert.equal(JSON.stringify(participantDay.data).includes('PRIVATE JOURNAL'), false);

assert.equal(call('POST','/api/shares/{id}/respond',outsider,
  {accept:true},idParam).status,404);
const commented = call('POST','/api/shares/{id}/messages',recipient,
  {kind:'comment',body:'Can we start later?'},idParam);
assert.equal(commented.status,201);
assert.equal(call('POST','/api/shares/{id}/messages',outsider,
  {kind:'comment',body:'Unauthorized'},idParam).status,404);
const proposed = call('POST','/api/shares/{id}/messages',recipient,{
  kind:'proposal',base_revision:1, patch:{
    plan_id:ownerPlan, title:'Afternoon walk',
  },
}, idParam);
assert.equal(proposed.status,201);
assert.equal(call('POST','/api/shares/{id}/messages',recipient,{
  kind:'proposal',base_revision:1, patch:{plan_id:ownerPlan,notes_plain:'steal'},
}, idParam).status,400);
const decisionRoute = '/api/shares/{id}/proposals/{messageId}/decide';
const decisionParams = {id:shareId, messageId:proposed.data.message.id};
assert.equal(call('POST',decisionRoute,recipient,
  {accept:true},decisionParams).status,403);
assert.equal(call('POST',decisionRoute,owner,
  {accept:true},decisionParams).status,200);
const after = call('GET','/api/shares/{id}',owner,{},idParam);
assert.equal(after.data.share.revision,2);
assert.equal(after.data.content.items[0].title,'Afternoon walk');
assert.equal(call('POST',decisionRoute,owner,
  {accept:true},decisionParams).status,409);
assert.equal(db.plans[0].getString('title'), 'Walk',
  'Collaborative draft must not silently mutate personal Plans');
const revoke = '/api/shares/{id}/members/{userId}/revoke';
const revokeParams = {id:shareId, userId:recipient};
assert.equal(call('POST',revoke, outsider,{},revokeParams).status,403);
assert.equal(call('POST',revoke,recipient,{},revokeParams).status,403);
assert.equal(call('POST',revoke,owner,{},revokeParams).status,200);
assert.equal(call('GET','/api/shares/{id}',recipient,{},idParam).status,404);
assert.equal(call('POST','/api/shares/day',recipient,
  {wall_day:'2026-10-31'}).data.shares.length,0);
assert.equal(call('POST','/api/shares/{id}/messages',recipient,
  {kind:'comment',body:'No access'},idParam).status,404);
assert.equal(call('POST','/api/shares/{id}/invite',owner,
  {person_record_id:personId},idParam).status,200);
assert.equal(call('POST','/api/shares/{id}/respond',recipient,
  {accept:true},idParam).status,200);
assert.equal(call('POST','/api/shares/{id}/leave',recipient,{},idParam).status,200);
assert.equal(call('GET','/api/shares/{id}',recipient,{},idParam).status,404);

process.stdout.write('Shares collaboration route contracts: PASS\n');
