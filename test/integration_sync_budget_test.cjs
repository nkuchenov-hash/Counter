// Run with node --test test/integration_sync_budget_test.cjs.
// Execute the actual PocketBase hook source under mocked provider HTTP.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
function load(name, respond) {
  let now = 100000;
  const calls = [];
  class Clock extends Date { static now() { return now; } }
  const ctx = vm.createContext({
    Date: Clock, routerAdd() {}, cronAdd() {},
    $apis: {requireAuth() {}},
    $http: {send(options) {
      calls.push(options.timeout);
      const reply = respond(options, calls.length);
      now += reply.elapsed || 0;
      return {statusCode: reply.statusCode || 200, json: reply.json};
    }},
  });
  vm.runInContext(fs.readFileSync('pb_hooks/' + name + '_integrations.pb.js', 'utf8'), ctx);
  return {ctx, calls};
}
for (const [name, prefix] of [['calendar','__calendar'],['people','__people']]) {
  test(name + ': request timeout fits remaining budget', () => {
    const {ctx,calls} = load(name, () => ({json: {}, elapsed: 0}));
    ctx[prefix+'HttpJson']({timeout:60}, 107900);
    assert.deepEqual(calls, [7]);
    assert.throws(() => ctx[prefix+'HttpJson']({timeout:60}, 100500), /deadline_exceeded/);
    assert.deepEqual(calls, [7]);
  });
  test(name + ': repeated provider cursor throws, not partial success', () => {
    const {ctx,calls} = load(name, () => ({json: name==='calendar'
      ? {items:[], nextPageToken:'same'} : {connections:[], nextPageToken:'same'}}));
    const read = name==='calendar' ? ctx.__calendarGoogleCalendars : ctx.__peopleGoogleContacts;
    assert.throws(() => read('test-token', 175000), /pagination_repeated/);
    assert.equal(calls.length, 2);
  });
  test(name + ': late successful page is rejected, not a complete empty snapshot', () => {
    const {ctx,calls} = load(name, () => ({json:{}, elapsed:80000}));
    const read = name==='calendar' ? ctx.__calendarGoogleCalendars : ctx.__peopleGoogleContacts;
    assert.throws(() => read('test-token', 175000), /deadline_exceeded/);
    assert.equal(calls.length, 1);
  });
  test(name + ': complete multipage empty snapshot is accepted', () => {
    const {ctx,calls} = load(name, (_options,n) => ({json: n===1
      ? {nextPageToken:'next'} : {}}));
    const read = name==='calendar' ? ctx.__calendarGoogleCalendars : ctx.__peopleGoogleContacts;
    assert.equal(read('test-token', 175000).length, 0);
    assert.equal(calls.length, 2);
  });
}
test('calendar sync never upserts or cleans an incomplete calendar response', () => {
  const {ctx} = load('calendar', () => ({json:{items:[],nextPageToken:'same'}}));
  const fields={provider:'google',user_id:'u',account_id:'a',calendars_json:[{id:'c',enabled:true}]};
  const connection={get:k=>fields[k],set:(k,v)=>fields[k]=v};
  ctx.__calendarRefreshAccess=()=> 'token';
  ctx.__calendarSanitizeCalendars=x=>x;
  let writes=0,cleanups=0;
  ctx.__calendarUpsertPlan=()=>{writes++;};
  ctx.__calendarCleanupStale=()=>{cleanups++;};
  assert.throws(()=>ctx.__calendarSyncOne({findRecordById:()=>({})},connection), /pagination_repeated/);
  assert.equal(writes,0); assert.equal(cleanups,0);
});
test('People sync never archives from incomplete provider read', () => {
  const {ctx} = load('people', () => ({json:{connections:[],nextPageToken:'same'}}));
  const fields={provider:'google_contacts',user_id:'u'};
  const connection={get:k=>fields[k],set:(k,v)=>fields[k]=v};
  ctx.__peopleProviderConfig=()=>({});
  ctx.__peopleRefreshAccess=()=> 'token';
  ctx.__peopleProviderIdentity=()=>({id:'a'});
  let writes=0;
  ctx.__peopleUpsertSourceRows=()=>{writes++;};
  assert.throws(()=>ctx.__peopleSyncOne({},connection), /pagination_repeated/);
  assert.equal(writes,0);
});

for (const [name, prefix] of [['calendar','__calendar'],['people','__people']]) {
  test(name + ': late token rotation persists before deadline is raised', () => {
    const {ctx} = load(name, () => ({json:{access_token:'new-access',refresh_token:'new-refresh',expires_in:3600},elapsed:11000}));
    const fields={provider:'microsoft',refresh_token_enc:'old-refresh'};
    const connection={get:k=>fields[k],set:(k,v)=>fields[k]=v};
    ctx.$security={encrypt:x=>x,decrypt:x=>x};
    ctx[prefix+'TokenKey']=()=> 'test-key';
    ctx[prefix+'ProviderConfig']=()=>({refreshable:true,tokenUrl:'https://test.invalid',clientId:'id',clientSecret:'secret'});
    let persisted;
    assert.throws(()=>ctx[prefix+'RefreshAccess']({save:()=>{persisted={...fields};}},connection,110000),/deadline_exceeded/);
    assert.equal(persisted.refresh_token_enc,'new-refresh');
    assert.equal(persisted.access_token_enc,'new-access');
  });
}
