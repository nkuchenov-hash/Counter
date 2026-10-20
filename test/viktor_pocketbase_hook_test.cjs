'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('pb_hooks/viktor.propose.pb.js', 'utf8');
let route;
let calls = 0;
let lastRequest;
const sandbox = {
  routerAdd(method, url, callback) {
    assert.equal(method, 'POST');
    assert.equal(url, '/api/viktor/propose');
    route = callback;
  },
  $os: { getenv: () => '' },
  $security: {randomStringWithAlphabet: () => '1234567890abcdef1234567890abcdef'},
  $http: { send(request) {
    calls++;
    lastRequest = request;
    if (request.url.includes('/api/v2/oauth')) {
      return {statusCode: 200, raw: JSON.stringify({access_token: 'test-access-token-from-oauth'})};
    }
    return {
      statusCode: 200,
      raw: JSON.stringify({
        choices: [{message: {content: JSON.stringify({
          message: 'Готово к проверке',
          actions: [{name: 'list_day_plans', arguments: {wall_day: '2026-10-20'}}],
        })}}]
      })
    };
  }},
};
vm.runInNewContext(source, sandbox, {timeout: 3000, filename: 'viktor.propose.pb.js'});
assert.equal(typeof route, 'function');

const base = {
  request_id: 'viktor_test_20261020',
  wall_day: '2026-10-20',
  text: 'Какие сегодня планы?',
  mode: 'byok',
  provider: 'openai',
  model: 'gpt-4o-mini',
  api_key: 'sk-example-testing-only',
  day_plans: []
};
function invoke(body, tier = 'free') {
  let response;
  route({
    requestInfo: () => ({
      body,
      auth: tier === null ? null : {
        id: 'aaaaabbbbbccccc',
        getString: (name) => name === 'tier' ? tier : '',
      },
    }),
    json: (status, value) => {
      response = {status, value};
      return response;
    }
  });
  assert.ok(response, 'Every request must be answered');
  return response;
}

assert.equal(invoke(base, null).status, 401, 'Sign-in required');
assert.equal(invoke({...base, mode: 'hosted'}).status, 403, 'Free hosted blocked');
assert.equal(invoke({...base, mode: 'hosted'}, 'pro').status, 503, 'Unmetered hosted blocked');
assert.equal(invoke({...base, provider: 'my-internal-url'}).status, 400,
  'No user-defined provider endpoint');
assert.equal(invoke({...base, day_plans: Array.from({length: 61}, () => ({}))}).status, 413,
  'No silent truncation of plan context');
assert.equal(invoke({...base, request_id: 'bad'}).status, 400,
  'A valid request ID is mandatory');
const ok = invoke(base);
assert.equal(ok.status, 200, 'BYOK works for authenticated free user');
assert.equal(ok.value.version, 1);
assert.equal(ok.value.request_id, base.request_id);
assert.equal(calls, 1, 'Only one call reached the provider');
assert.equal(lastRequest.url, 'https://api.openai.com/v1/chat/completions');
assert.equal(lastRequest.headers.Authorization, 'Bearer ' + base.api_key);
assert.equal(JSON.parse(lastRequest.body).messages[1].role, 'user');

// Russian model providers have independent request/authentication contracts.
const yandex = invoke({...base,
  provider: 'yandex',
  model: 'yandexgpt/rc',
  yandex_folder_id: 'b1g9testfolder11',
});
assert.equal(yandex.status, 200);
assert.equal(lastRequest.url,
  'https://ai.api.cloud.yandex.net/v1/chat/completions');
assert.equal(lastRequest.headers.Authorization, 'Api-Key ' + base.api_key);
assert.equal(lastRequest.headers['OpenAI-Project'], 'b1g9testfolder11');
assert.equal(JSON.parse(lastRequest.body).model,
  'gpt://b1g9testfolder11/yandexgpt/rc');
assert.equal(invoke({...base, provider: 'yandex',
  model: 'yandexgpt/rc', yandex_folder_id: ''}).status, 400);

const giga = invoke({...base,
  provider: 'gigachat', model: 'GigaChat-2',
  api_key: 'personal-basic-sber-key-test',
});
assert.equal(giga.status, 200);
assert.equal(lastRequest.url, 'https://api.giga.chat/v1/chat/completions');
assert.equal(lastRequest.headers.Authorization,
  'Bearer test-access-token-from-oauth');

const selected = invoke({...base,
  selected_plan_ids: ['aaaaabbbbbccccc', 'not-real-id'],
  day_plans: [{
    id: 'aaaaabbbbbccccc', title: 'Зарядка',
    duration_minutes: 30, start_time: '09:00', recurrent: false
  }],
});
assert.equal(selected.status, 200);
const modelContext = JSON.parse(JSON.parse(lastRequest.body).messages[1].content);
assert.deepEqual(modelContext.selected_plan_ids, ['aaaaabbbbbccccc']);

const protectSource = fs.readFileSync('pb_hooks/viktor.protect_tier.pb.js', 'utf8');
const hooks = {};
vm.runInNewContext(protectSource, {
  onRecordCreateRequest(cb, collection) { hooks['create_' + collection] = cb; },
  onRecordUpdateRequest(cb, collection) { hooks['update_' + collection] = cb; },
  ForbiddenError: class ForbiddenError extends Error {},
}, {timeout: 3000});
assert.equal(typeof hooks.create_profiles, 'function');
assert.equal(typeof hooks.update_profiles, 'function');
function checkTier(hook, body, superuser = false) {
  let next = false;
  let failed = false;
  try {
    hook({
      requestInfo: () => ({body, auth: {isSuperuser: superuser}}),
      next: () => {next = true;},
    });
  } catch (_) {
    failed = true;
  }
  return {next, failed};
}
assert.equal(checkTier(hooks.update_profiles, {tier: 'pro'}).failed, true,
  'Client cannot grant Pro');
assert.equal(checkTier(hooks.create_profiles, {tier: 'pro'}).failed, true,
  'Client cannot register as Pro');
assert.equal(checkTier(hooks.update_profiles, {theme_mode: 'dark'}).next, true,
  'Ordinary settings remain writable');
assert.equal(checkTier(hooks.update_profiles, {tier: 'pro'}, true).next, true,
  'Admin can set entitlements');

process.stdout.write('Viktor proposal and entitlement hook contracts: PASS\n');
