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
const created = stored.fields.find(f => f.name === 'created');
assert.ok(created, 'Created column must be explicitly declared before indexing');
assert.equal(created.type, 'autodate');
assert.equal(created.onCreate, true);

// Reproduce the outage: JS syntax passes while SQL index creation fails when
// an index references a missing field. The collection save mock must enforce it.
function validateIndexColumns(collection) {
  const fields = new Set(['id', ...collection.fields.map(field => field.name)]);
  for (const index of collection.indexes) {
    const match = index.match(/\bON\s+([a-z_][a-z_0-9]*)\s*\(([^)]+)\)/i);
    assert.ok(match, 'Unable to parse index: ' + index);
    assert.equal(match[1], collection.name);
    for (const column of match[2].split(',').map(c => c.trim())) {
      assert.ok(fields.has(column),
        'Index references missing column: ' + column);
    }
  }
}
validateIndexColumns(stored);
assert.throws(
  () => validateIndexColumns({
    ...stored,
    fields: stored.fields.filter(f => f.name !== 'created'),
  }),
  /Index references missing column: created/,
  'Guard must catch the exact 2026-10-23 production failure');
assert.ok(stored.indexes.some(x => x.includes('UNIQUE INDEX')));
const initial = stored;
up(app);
assert.equal(stored, initial, 'Migration is idempotent');
down(app);
assert.equal(stored, null);
process.stdout.write('Viktor owner-scoped dialogue migration OK\n');
