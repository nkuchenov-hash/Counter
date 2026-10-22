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
        if (resultMode === 'stream' || resultMode === 'adjacent') {
          return {statusCode: 200, raw: [
            JSON.stringify({result: {
              audioCursors: {finalIndex: '0'},
              final: {alternatives: [{text: 'позвонить AGE Solutions'}]}}}),
            JSON.stringify({result: {
              finalRefinement: {finalIndex: '0', normalizedText: {
                alternatives: [{text: 'Позвонить AGE Solutions'}]}}}}),
            JSON.stringify({result: {
              audioCursors: {finalIndex: '1'},
              final: {alternatives: [{text: 'в пятницу в 12:00 NY'}]}}})
          ].join(resultMode === 'adjacent' ? '' : '\n')};
        }
        const result = resultMode === 'refinement'
          ? {finalRefinement: {finalIndex: '0', normalizedText: {
              alternatives: [{text: 'Включи запись'}]}}}
          : {final: {alternatives: [{text: 'Поменяй эти две карточки местами'}]}};
        return {statusCode: 200, raw: JSON.stringify({result})};
      }
      throw Error('Unexpected host');
    }
  }
};
// PocketBase runs every route handler in a fresh isolated VM. Rehydrate the
// captured function source without the top-level declarations so that helpers
// must be explicitly required inside the callback.
const hookSource = fs.readFileSync('pb_hooks/viktor.transcribe_yandex.pb.js', 'utf8');
assert.doesNotMatch(hookSource, /^function viktorYandexSpeechAuth/m);
assert.doesNotMatch(hookSource, /^function viktorYandexSpeechFrames/m);
vm.runInNewContext(hookSource, sandbox, {timeout: 3000});
function isolatedHandler(handler) {
  const host = {
    ...sandbox,
    __hooks: 'pb_hooks',
    // Requiring CommonJS modules in the callback is the PocketBase-supported
    // way to share reusable logic across isolated route contexts.
    require(name) {
      assert.equal(name, 'pb_hooks/viktor_yandex_speech_helpers.js');
      const module = {exports: {}};
      const helperSource = fs.readFileSync(name, 'utf8');
      vm.runInNewContext(helperSource, {...sandbox, module, Buffer},
        {timeout: 3000});
      return module.exports;
    }
  };
  return vm.runInNewContext('(' + handler.toString() + ')', host,
    {timeout: 3000});
}
const start = isolatedHandler(routes['/api/viktor/transcribe-yandex']);
const status = isolatedHandler(routes['/api/viktor/transcribe-yandex/status']);
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
  ['ru-RU', 'en-US']
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
resultMode = 'stream';
const streaming = invoke(status, polling);
assert.equal(streaming.statusCode, 200);
assert.equal(streaming.data.transcript,
  'Позвонить AGE Solutions в пятницу в 12:00 NY',
  'Use finalRefinement for each chunk once, without duplicate final text');
resultMode = 'adjacent';
const adjacent = invoke(status, polling);
assert.equal(adjacent.statusCode, 200,
  'SpeechKit REST v3 adjacent JSON frames must parse without newline delimiters');
assert.equal(adjacent.data.transcript,
  'Позвонить AGE Solutions в пятницу в 12:00 NY');
assert.equal(outbound.length, 10, 'All speech response forms were requested');
vaultKey = '0123456789abcdef0123456789abcdef';
const cloudStarted = invoke(start, {
  ...base,
  api_key: '',
  yandex_folder_id: '',
});
assert.equal(cloudStarted.statusCode, 202,
  'SpeechKit must use server-stored key without device secret');
assert.equal(outbound[10].headers.Authorization,
  'Api-Key yandex-server-stored-key');
assert.equal(outbound[10].headers['x-folder-id'], 'b1g9testfolder11');
process.stdout.write('Viktor Yandex one-key SpeechKit contract: PASS\\n');
