'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('pb_hooks/viktor.transcribe.pb.js', 'utf8');
let handle;
let outbound;
let requests = 0;
const sandbox = {
  Buffer,
  $os: {getenv: () => ''},
  routerAdd(method, path, callback) {
    assert.equal(method, 'POST');
    assert.equal(path, '/api/viktor/transcribe');
    handle = callback;
  },
  $security: {base64Decode: text => Buffer.from(text, 'base64')},
  $filesystem: {fileFromBytes: (data, name) => ({name, bytes: data.length})},
  $http: {send: request => {
    outbound = request;
    requests++;
    if (request.url.includes('generativelanguage')) {
      return {statusCode: 200, raw: JSON.stringify({
        candidates: [{content: {parts: [{text: 'Покажи планы на сегодня'}]}}]
      })};
    }
    return {statusCode: 200, raw: JSON.stringify({
      text: 'Покажи планы на сегодня'
    })};
  }},
};
vm.runInNewContext(source, sandbox, {timeout: 3000});
assert.equal(typeof handle, 'function');

const wav = Buffer.alloc(16044);
wav.write('RIFF', 0);
wav.write('WAVE', 8);
const body = {
  provider: 'groq',
  api_key: 'gsk-test-key-not-real',
  audio_base64: wav.toString('base64'),
  language: 'ru',
};
function request(patch = {}, signedIn = true) {
  let response;
  handle({
    requestInfo: () => ({
      auth: signedIn ? {id: 'aaaaabbbbbccccc'} : null,
      body: {...body, ...patch}
    }),
    json: (status, data) => {
      response = {status, data};
      return response;
    }
  });
  assert.ok(response);
  return response;
}
assert.equal(request({}, false).status, 401);
assert.equal(request({provider: 'http://127.0.0.1/'}).status, 400);
assert.equal(request({api_key: ''}).status, 400);
assert.equal(request({audio_base64: 'too short'}).status, 413);
assert.equal(request({audio_base64: Buffer.alloc(16044).toString('base64')}).status, 400,
  'Non-WAV audio is rejected');

const groq = request();
assert.equal(groq.status, 200);
assert.equal(groq.data.transcript, 'Покажи планы на сегодня');
assert.equal(outbound.url, 'https://api.groq.com/openai/v1/audio/transcriptions');
assert.equal(outbound.body.model, 'whisper-large-v3-turbo');
assert.equal(outbound.body.file.name, 'viktor.wav');
assert.equal(outbound.body.language, 'ru');
assert.equal(outbound.headers.Authorization, 'Bearer gsk-test-key-not-real');

const openai = request({provider: 'openai'});
assert.equal(openai.status, 200);
assert.equal(outbound.url, 'https://api.openai.com/v1/audio/transcriptions');
assert.equal(outbound.body.model, 'gpt-4o-mini-transcribe');

const gemini = request({provider: 'gemini'});
assert.equal(gemini.status, 200);
assert.equal(outbound.url,
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent');
assert.equal(outbound.headers['x-goog-api-key'], body.api_key);
const parsed = JSON.parse(outbound.body);
assert.equal(parsed.contents[0].parts[1].inline_data.mime_type, 'audio/wav');
assert.equal(parsed.contents[0].parts[1].inline_data.data, body.audio_base64);
assert.equal(requests, 3, 'Denied requests must not invoke providers');
process.stdout.write('Viktor real-audio STT route contracts: PASS\n');
