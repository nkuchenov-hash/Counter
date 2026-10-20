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
    return rows.filter(x => x.getString('user_id') === params.owner).reverse();
  },
  save(record) {
    if (!rows.includes(record)) rows.push(record);
  },
  delete(record) {
    const ix = rows.indexOf(record);
    if (ix >= 0) rows.splice(ix, 1);
  }
};
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
    handlers.set(method + ' ' + path, handler);
  }
};
vm.runInNewContext(fs.readFileSync('pb_hooks/viktor.connection.pb.js', 'utf8'),
  sandbox, {timeout: 2000});

function call(method, owner, body = {}) {
  const route = handlers.get(method + ' /api/viktor/connection');
  assert.equal(typeof route, 'function');
  let result;
  route({
    requestInfo: () => ({
      auth: owner ? {id: owner} : null,
      body
    }),
    json(status, payload) {
      result = {status, payload: JSON.parse(JSON.stringify(payload))};
      return result;
    }
  });
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
assert.equal(call('POST', first, {...config, api_key: ''}).status, 400);
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
process.stdout.write('Viktor account BYOK vault access and encryption contract: PASS\n');
