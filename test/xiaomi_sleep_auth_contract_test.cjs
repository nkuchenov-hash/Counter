'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const runtime = fs.readFileSync(path.join(root, 'pb_hooks/xiaomi_sleep_runtime.js'), 'utf8');
const deploy = fs.readFileSync(path.join(root, '.github/workflows/deploy-pocketbase.yml'), 'utf8');

function section(start, end) {
  const first = runtime.indexOf(start);
  const last = runtime.indexOf(end, first + start.length);
  assert.ok(first >= 0 && last > first, 'Missing Xiaomi runtime section ' + start);
  return runtime.slice(first, last);
}

const connect = section('function connect(e) {', 'function authorize(e) {');
const authorize = section('function authorize(e) {', 'function settings(e) {');
const status = section('function __xiaomiStatus(app, connection) {', 'function __xiaomiProfile(app, userId) {');

// Startup must not wait for Xiaomi to produce a QR or for its first data import.
assert.match(connect, /authorization_url:/);
assert.match(connect, /__xiaomiExists\(__xiaomiPython\)/);
assert.match(connect, /__xiaomiExists\(__xiaomiBridgePath\(\)\)/);
assert.match(connect, /previousStatus !== "error"/);
assert.doesNotMatch(connect, /waitScript|seq 1 80|awaiting_scan|__xiaomiRunSafe|\.output\(\)/);
assert.doesNotMatch(authorize, /__xiaomiRunSafe/);

// The authorization page must be usable while the QR worker prepares.
assert.match(authorize, /phase === "starting" \|\| phase === "refreshing"/);
assert.match(authorize, /http-equiv='refresh'/);
assert.match(authorize, /__xiaomiHasToken\(userId\)/);

// Worker failures and missing server runtime must surface, not stick indefinitely.
assert.match(status, /loginState\.status \|\| ""/);
assert.match(status, /xiaomi_authorization_login_failed/);
assert.match(status, /phase === "error"/);
assert.match(connect, /xiaomi_authorization_runtime_unavailable/);

// A deployment to a new/recovered server must provision the non-PocketBase venv.
assert.match(deploy, /python3 -m venv \/opt\/lifeos-xiaomi-sleep/);
assert.match(deploy, /mi-fitness==0\.2\.0/);
assert.match(deploy, /from mi_fitness import MiHealthClient, XiaomiAuth/);

console.log('Xiaomi authorization nonblocking/recovery and deploy contracts passed.');
