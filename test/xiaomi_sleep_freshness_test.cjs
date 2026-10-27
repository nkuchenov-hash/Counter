// Regression tests for missing Xiaomi nights and honest server sync status.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const runtime = fs.readFileSync('pb_hooks/xiaomi_sleep_runtime.js', 'utf8');

function harness() {
  const context = vm.createContext({
    module: { exports: {} },
    $os: { stat: () => ({}) }, // a saved Xiaomi token exists
  });
  vm.runInContext(runtime, context, { filename: 'xiaomi_sleep_runtime.js' });
  context.__xiaomiProfile = () => ({ get: () => 0 });
  context.__xiaomiDisableGoogleProviders = () => {};
  context.__xiaomiLocalClock = () => ({
    minutes: 11 * 60,
    day: '2026-10-27',
  });
  context.__xiaomiHasSleepForLocalDay = () => false;
  context.__xiaomiHasRecentSleep = () => true;
  const connectionValues = {
    user_id: 'user-one', enabled: true, status: 'connected',
    last_sync_at: '2026-10-26T07:00:00.000Z',
    last_error: '', last_session_count: 0,
  };
  const connection = {
    get: key => connectionValues[key],
    set: (key, value) => { connectionValues[key] = value; },
  };
  const app = { save: () => {}, logger: () => ({ error: () => {} }) };
  return { context, app, connection, connectionValues };
}

{
  const { context, app, connection } = harness();
  const result = context.__xiaomiStatus(app, connection);
  assert.equal(result.status, 'error', 'missing expected sleep must not appear connected');
  assert.equal(result.last_error, 'xiaomi_sleep_not_available_today');
  assert.equal(result.configured, true, 'missing sleep must not remove account authorization');
}
{
  const { context, app, connection } = harness();
  context.__xiaomiHasSleepForLocalDay = () => true;
  const result = context.__xiaomiStatus(app, connection);
  assert.equal(result.status, 'connected', 'imported night clears freshness warning');
  assert.equal(result.last_error, null);
}
{
  const { context, app, connection } = harness();
  context.__xiaomiLocalClock = () => ({ minutes: 8 * 60, day: '2026-10-27' });
  const result = context.__xiaomiStatus(app, connection);
  assert.equal(result.status, 'connected', 'recent yesterday sleep is valid before expected wake');
}
{
  const { context, app, connection } = harness();
  context.__xiaomiHasRecentSleep = () => false;
  context.__xiaomiRunBridge = () => ({ ok: true, sessions: [] });
  context.__xiaomiNormalizeSessions = () => [];
  context.__xiaomiSleepCategory = () => ({ id: 'sleep-cat' });
  const result = context.__xiaomiRunConnection(app, connection);
  assert.equal(result.imported, 0);
  assert.equal(connection.get('status'), 'error', 'zero imported nights must not fake freshness');
  assert.equal(connection.get('last_error'), 'xiaomi_sleep_not_available_today');
}
{
  const { context, app, connection } = harness();
  context.__xiaomiRunConnection = () => { throw Error('xiaomi transport failed'); };
  const before = connection.get('last_sync_at');
  assert.throws(() => context.__xiaomiRunSafe(app, connection), /transport failed/);
  assert.equal(connection.get('last_sync_at'), before, 'failed sync must preserve last successful fetch');
  assert.equal(connection.get('status'), 'error');
}
console.log('xiaomi_sleep_freshness_test: OK (5 cases)');
