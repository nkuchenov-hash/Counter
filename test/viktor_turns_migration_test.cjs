'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(
  'pb_migrations/1792710000_viktor_turns.js', 'utf8');
let up, down;
const sandbox = {
  migrate(migrateUp, migrateDown) {
    up = migrateUp;
    down = migrateDown;
  },
  Collection: class Collection {
    constructor(spec) { Object.assign(this, spec); }
  },
};
vm.runInNewContext(source, sandbox, {timeout: 3000});
assert.equal(typeof up, 'function');
assert.equal(typeof down, 'function');

let stored;
const app = {
  hasTable(name) { return name === 'viktor_turns' && stored != null; },
  findCollectionByNameOrId(name) {
    if (name === 'profiles') return {id: 'profiles-record-id'};
    if (name === 'viktor_turns') return stored;
    throw new Error('Unknown collection ' + name);
  },
  save(value) {stored = value;},
  delete(value) {
    assert.equal(value, stored);
    stored = null;
  },
};
up(app);
assert.equal(stored.name, 'viktor_turns');
for (const rule of ['listRule', 'viewRule', 'createRule', 'deleteRule']) {
  assert.equal(stored[rule], 'user_id = @request.auth.id',
    rule + ' must scope the request to its owner');
}
assert.equal(stored.updateRule, null, 'Cannot edit dialogue turns');
assert.equal(stored.fields.find(f => f.name === 'user_id').collectionId,
  'profiles-record-id');
assert.deepEqual([...stored.fields.find(f => f.name === 'role').values],
  ['user', 'assistant']);
assert.equal(stored.fields.find(f => f.name === 'body').max, 6000);
assert.ok(stored.indexes.some(x => x.includes('UNIQUE INDEX')));
const initial = stored;
up(app);
assert.equal(stored, initial, 'Migration is idempotent');
down(app);
assert.equal(stored, null);
process.stdout.write('Viktor owner-scoped dialogue migration OK\n');
