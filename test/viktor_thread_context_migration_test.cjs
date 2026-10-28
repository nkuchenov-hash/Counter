'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(
  'pb_migrations/1793190000_viktor_thread_context.js', 'utf8');
let up, down;
class Fields {
  constructor(fields) { this.values = [...fields]; }
  getByName(name) { return this.values.find(f => f.name === name) || null; }
  add(field) { this.values.push(field); }
  removeById(id) {
    this.values = this.values.filter(f => f.id !== id);
  }
}
const initial = [
  {name: 'user_id'}, {name: 'conversation_id'},
  {name: 'client_turn_id'}, {name: 'role'}, {name: 'body'},
  {name: 'created'},
];
const turns = {name: 'viktor_turns', fields: new Fields(initial)};
const saved = new Map([['viktor_turns', turns]]);
const sandbox = {
  migrate(a, b) { up = a; down = b; },
  TextField: class { constructor(config) {
    Object.assign(this, config); this.id = config.name; } },
  Collection: class { constructor(config) { Object.assign(this, config); } },
};
vm.runInNewContext(source, sandbox, {timeout: 2500});
const app = {
  hasTable(name) { return saved.has(name); },
  findCollectionByNameOrId(name) {
    if (name === 'profiles') return {id: 'profiles-id'};
    if (!saved.has(name)) throw new Error('unknown ' + name);
    return saved.get(name);
  },
  save(collection) { saved.set(collection.name, collection); },
  delete(collection) { saved.delete(collection.name); },
};
up(app);
const threads = saved.get('viktor_threads');
assert.ok(threads);
for (const key of ['listRule', 'viewRule', 'createRule',
  'updateRule', 'deleteRule']) {
  assert.equal(threads[key], 'user_id = @request.auth.id');
}
assert.ok(threads.indexes.some(x => x.includes('UNIQUE INDEX')));
for (const key of ['sent_at_utc', 'message_day', 'message_timezone']) {
  assert.ok(turns.fields.getByName(key), key + ' missing');
}
const fieldsBefore = turns.fields.values.length;
up(app);
assert.equal(fieldsBefore, turns.fields.values.length,
  'Migration must be idempotent');
assert.equal(saved.get('viktor_threads'), threads);
down(app);
assert.ok(!saved.has('viktor_threads'));
assert.equal(turns.fields.values.length, initial.length);
process.stdout.write('Viktor conversation and time metadata migration OK\n');
