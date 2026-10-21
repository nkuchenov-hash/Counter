'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const handlers = new Map();
const rows = [];
let masterKey = '0123456789abcdef0123456789abcdef';
class Record {
  constructor(collection) {this.collection = collection; this.data = {};}
  getString(name) {return String(this.data[name] || '');}
  set(name, value) {this.data[name] = value;}
}
const app = {
  findCollectionByNameOrId(name) {
    assert.equal(name, 'viktor_connections');
    return {name};
  },
  findFirstRecordByFilter(table, filter, params) {
    assert.equal(table, 'viktor_connections');
    assert.match(filter, /user_id/);
    assert.match(filter, /provider/);
    const row = rows.find(x => x.getString('user_id') === params.owner &&
      x.getString('provider') === params.provider);
    if (!row) throw Error('Not found');
    return row;
  },
  findRecordsByFilter(table, filter, order, limit, offset, params) {
    assert.equal(table, 'viktor_connections');
    assert.ok(params.owner);
    // Production's vault table contains id, user_id, provider, model,
    // payload_enc and NO "updated" or "created" column. Sorting on a
    // nonexistent column was the actual cause of vault_unavailable on GET.
    assert.equal(order, 'provider',
      'Vault GET must sort on a column declared by its migration');
    return rows.filter(x => x.getString('user_id') === params.owner)
      .sort((a, b) => a.getString('provider').localeCompare(b.getString('provider')));
  },
  save(record) {
    if (!rows.includes(record)) rows.push(record);
  },
  delete(record) {
    const ix = rows.indexOf(record);
    if (ix >= 0) rows.splice(ix, 1);
  }
};
const migrationSource = fs.readFileSync(
  'pb_migrations/1792533600_viktor_connections.js', 'utf8'
);
assert.match(migrationSource, /name:\s*"provider"/,
  'Sorting relies on a declared provider field');
assert.doesNotMatch(migrationSource, /name:\s*"updated"/,
  'Production schema intentionally has no updated field');
const sandbox = {
  Record,
  Buffer,
  $app: app,
  $os: {getenv: name => name === 'VIKTOR_VAULT_KEY' ? masterKey : ''},
  $security: {
    encrypt(value, key) {
      assert.equal(key, masterKey);
      return 'cipher:' + Buffer.from(value).toString('base64');
    },
    decrypt(value, key) {
      assert.equal(key, masterKey);
      assert.ok(value.startsWith('cipher:'));
      return Buffer.from(value.slice(7), 'base64').toString();
    }
  },
  routerAdd(method, path, handler) {
    // PocketBase serializes each callback; outer lexical declarations are LOST.
    handlers.set(method + ' ' + path, handler.toString());
  }
};
vm.runInNewContext(fs.readFileSync('pb_hooks/viktor.connection.pb.js', 'utf8'),
  sandbox, {timeout: 2000});
const cjs = {exports: {}};
vm.runInNewContext(
  fs.readFileSync('pb_hooks/viktor_vault_helpers.js', 'utf8'),
  {...sandbox, module: cjs, toString: v => Buffer.from(v).toString('utf8')},
  {timeout: 2000}
);
const helpers = cjs.exports;

function call(method, owner, body = {}) {
  const handlerText = handlers.get(method + ' /api/viktor/connection');
  assert.equal(typeof handlerText, 'string');
  let result;
  const request = {
    requestInfo: () => ({
      auth: owner ? {id: owner} : null,
      body
    }),
    json(status, payload) {
      result = {status, payload: JSON.parse(JSON.stringify(payload))};
      return result;
    }
  };
  // Match production: fresh isolated runtime with only official bindings,
  // NOT functions/constants declared outside the registered route handler.
  const isolated = {
    e: request,
    __hooks: '/virtual/pb_hooks',
    require: path => {
      assert.equal(path, '/virtual/pb_hooks/viktor_vault_helpers.js');
      return helpers;
    },
    Record, Buffer,
    $app: app,
    $os: sandbox.$os,
    $security: sandbox.$security,
  };
  vm.runInNewContext('(' + handlerText + ')(e)', isolated, {timeout: 2000});
  return result;
}
const first = 'aaaaabbbbbccccc';
const second = 'dddddeeeeefffff';
const config = {
  provider: 'yandex', model: 'yandexgpt/rc',
  api_key: 'realistic-yandex-service-key',
  folder_id: 'b1g123456789abcde',
  speech_provider: 'groq',
};
assert.equal(call('POST', null, config).status, 401);
assert.equal(call('GET', null).status, 401);
const initiallyEmpty = call('GET', first);
assert.equal(initiallyEmpty.status, 200);
assert.equal(initiallyEmpty.payload.connections.length, 0,
  'A first-time user should have no warning/error from GET');
const missingKey = call('POST', first, {...config, api_key: ''});
assert.equal(missingKey.status, 400);
assert.equal(missingKey.payload.error, 'api_key_required');
const missingFolder = call('POST', first, {...config, folder_id: ''});
assert.equal(missingFolder.status, 400);
assert.equal(missingFolder.payload.error, 'yandex_folder_id_required');
const wrongFolder = call('POST', first, {...config, folder_id: 'default'});
assert.equal(wrongFolder.status, 400);
assert.equal(wrongFolder.payload.error, 'invalid_yandex_folder_id');
const shortKey = call('POST', first, {...config, api_key: 'short'});
assert.equal(shortKey.status, 400);
assert.equal(shortKey.payload.error, 'api_key_too_short');
assert.equal(rows.length, 0);
assert.equal(call('POST', first, config).status, 200);
assert.equal(rows.length, 1);
assert.ok(!rows[0].getString('payload_enc').includes(config.api_key),
  'Database must not store plaintext credential');
assert.equal(rows[0].getString('user_id'), first);
const connected = call('GET', first);
assert.equal(connected.status, 200);
assert.equal(connected.payload.connections[0].provider, 'yandex');
assert.equal(connected.payload.connections[0].folder_id, config.folder_id);
assert.ok(!JSON.stringify(connected).includes(config.api_key),
  'Connection status must never return credential');
const encrypted = rows[0].getString('payload_enc');
rows[0].set('payload_enc', 'unreadable-payload');
const corrupted = call('GET', first);
assert.equal(corrupted.status, 503,
  'A decrypt failure must be reported, never disguised as a missing key');
assert.equal(corrupted.payload.error, 'vault_connection_unreadable');
assert.ok(!JSON.stringify(corrupted).includes(config.api_key));
rows[0].set('payload_enc', encrypted);
assert.equal(call('GET', second).payload.connections.length, 0,
  'Another user must not list the connection');
assert.equal(call('POST', first, {
  provider: 'yandex', model: 'yandexgpt/latest',
}).status, 200, 'Metadata update must not erase credential');
assert.equal(rows.length, 1);
const decoded = JSON.parse(Buffer.from(rows[0]
  .getString('payload_enc').slice(7), 'base64').toString());
assert.equal(decoded.api_key, config.api_key);
assert.equal(decoded.folder_id, config.folder_id);
assert.equal(call('DELETE', second, {provider: 'yandex'}).status, 200);
assert.equal(rows.length, 1, 'Another user cannot remove our credentials');
assert.equal(call('DELETE', first, {provider: 'yandex'}).status, 200);
assert.equal(rows.length, 0);
masterKey = '';
assert.equal(call('GET', first).status, 503, 'Unconfigured vault fails closed');
assert.equal(call('POST', first, config).status, 503);
process.stdout.write('Viktor isolated-route BYOK vault access, encryption and guest GET: PASS\n');
