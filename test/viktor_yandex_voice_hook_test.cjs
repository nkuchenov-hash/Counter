'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const routes = {};
const outbound = [];
let ready = false;
let resultMode = 'final';
let vaultKey = '';
const sandbox = {
  $os: {getenv: name => name === 'VIKTOR_VAULT_KEY' ? vaultKey : ''},
  $app: {
    findFirstRecordByFilter(table, condition, params) {
      assert.equal(table, 'viktor_connections');
      assert.equal(params.owner, 'aaaaabbbbbccccc');
      return {getString: () => 'ciphertext-not-client-visible'};
    }
  },
  $security: {
    decrypt(cipher, key) {
      assert.equal(cipher, 'ciphertext-not-client-visible');
      assert.equal(key, vaultKey);
      return JSON.stringify({
        api_key: 'yandex-server-stored-key',
        folder_id: 'b1g9testfolder11',
      });
    },
  },
  routerAdd(method, path, callback) {
    assert.equal(method, 'POST');
    routes[path] = callback;
  },
  Buffer,
  $http: {
    send(request) {
      outbound.push(request);
      if (request.url.endsWith('recognizeFileAsync')) {
        return {statusCode: 200, raw: JSON.stringify({id: 'recognition12345'})};
      }
      if (request.url.includes('operation.api.cloud.yandex.net')) {
        return {statusCode: 200, raw: JSON.stringify({done: ready})};
      }
      if (request.url.includes('getRecognition')) {
        assert.ok(request.url.endsWith('getRecognition?operation_id=recognition12345'),
          'SpeechKit REST v3 requires operation_id (per official Yandex docs)');
        const result = resultMode === 'refinement'
          ? {finalRefinement: {normalizedText: {
              alternatives: [{text: 'Включи запись'}]}}}
          : {final: {alternatives: [{text: 'Поменяй эти две карточки местами'}]}};
        return {statusCode: 200, raw: JSON.stringify({result})};
      }
      throw Error('Unexpected host');
    }
  }
};
vm.runInNewContext(
  fs.readFileSync('pb_hooks/viktor.transcribe_yandex.pb.js', 'utf8'),
  sandbox, {timeout: 3000}
);
const start = routes['/api/viktor/transcribe-yandex'];
const status = routes['/api/viktor/transcribe-yandex/status'];
assert.equal(typeof start, 'function');
assert.equal(typeof status, 'function');

const wav = Buffer.alloc(16044);
wav.write('RIFF', 0);
wav.write('WAVE', 8);
const base = {
  api_key: 'example-yandex-service-account-key',
  yandex_folder_id: 'b1g9testfolder11',
  language: 'ru',
  audio_base64: wav.toString('base64'),
};
function invoke(route, body, signedIn = true) {
  let result;
  route({
    requestInfo: () => ({body, auth: signedIn ? {id: 'aaaaabbbbbccccc'} : null}),
    json: (statusCode, data) => {
      result = {statusCode, data};
      return result;
    }
  });
  assert.ok(result);
  return result;
}
assert.equal(invoke(start, base, false).statusCode, 401);
assert.equal(invoke(start, {...base, api_key: ''}).statusCode, 400);
assert.equal(invoke(start, {...base, yandex_folder_id: 'no'}).statusCode, 400);
assert.equal(invoke(start, {...base, audio_base64: 'garbage'}).statusCode, 413);
assert.equal(outbound.length, 0, 'No external requests on invalid input');

const started = invoke(start, base);
assert.equal(started.statusCode, 202);
assert.equal(started.data.operation_id, 'recognition12345');
const submitted = outbound[0];
assert.equal(submitted.url, 'https://stt.api.cloud.yandex.net/stt/v3/recognizeFileAsync');
assert.equal(submitted.headers.Authorization, 'Api-Key ' + base.api_key);
assert.equal(submitted.headers['x-folder-id'], base.yandex_folder_id);
const payload = JSON.parse(submitted.body);
assert.equal(payload.content, base.audio_base64);
assert.equal(payload.recognitionModel.audioFormat.containerAudio.containerAudioType, 'WAV');
assert.deepEqual(
  JSON.parse(JSON.stringify(payload.recognitionModel.languageRestriction.languageCode)),
  ['ru-RU']
);
const polling = {...base, operation_id: started.data.operation_id};
assert.equal(invoke(status, polling, false).statusCode, 401);
assert.equal(invoke(status, {...polling, operation_id: '../../admin'}).statusCode, 400);
assert.equal(invoke(status, polling).statusCode, 202);
ready = true;
const finished = invoke(status, polling);
assert.equal(finished.statusCode, 200);
assert.equal(finished.data.transcript, 'Поменяй эти две карточки местами');
assert.equal(outbound[2].headers.Authorization, 'Api-Key ' + base.api_key);
resultMode = 'refinement';
const normalized = invoke(status, polling);
assert.equal(normalized.statusCode, 200);
assert.equal(normalized.data.transcript, 'Включи запись');
assert.equal(outbound.length, 6, 'Both Yandex result formats were requested');
vaultKey = '0123456789abcdef0123456789abcdef';
const cloudStarted = invoke(start, {
  ...base,
  api_key: '',
  yandex_folder_id: '',
});
assert.equal(cloudStarted.statusCode, 202,
  'SpeechKit must use server-stored key without device secret');
assert.equal(outbound[6].headers.Authorization,
  'Api-Key yandex-server-stored-key');
assert.equal(outbound[6].headers['x-folder-id'], 'b1g9testfolder11');
process.stdout.write('Viktor Yandex one-key SpeechKit contract: PASS\\n');
