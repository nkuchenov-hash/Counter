/// <reference path="../pb_data/types.d.ts" />
// Yandex SpeechKit WAV transcription, using the same BYOK API key as YandexGPT.
// Audio and credentials are not persisted. All provider hosts are fixed.
// Helpers must be required inside the callback: PocketBase isolates handlers.
routerAdd("POST", "/api/viktor/transcribe-yandex", (e) => {
  const speech = require(`${__hooks}/viktor_yandex_speech_helpers.js`);
  const request = speech.auth(e, true);
  if (request.error) return e.json(request.status, {error: request.error});
  try {
    // REST v3 accepts WAV/base64 JSON; PocketBase $http.send does not
    // support a raw-byte request body for the older synchronous STT endpoint.
    const reply = $http.send({
      url: "https://stt.api.cloud.yandex.net/stt/v3/recognizeFileAsync",
      method: "POST",
      headers: {
        "Authorization": "Api-Key " + request.key,
        "x-folder-id": request.folder,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        content: request.encoded,
        recognitionModel: {
          model: "general",
          audioFormat: {containerAudio: {containerAudioType: "WAV"}},
          languageRestriction: {
            restrictionType: "WHITELIST",
            // LIFE OS commands frequently mix Russian and English names.
            // A UI locale is not a reliable audio-language restriction.
            languageCode: ["ru-RU", "en-US"]
          }
        }
      }),
      timeout: 30
    });
    if (reply.statusCode < 200 || reply.statusCode >= 300) {
      return e.json(502, {error: "speech_provider_rejected", status: reply.statusCode});
    }
    const operationId = String(JSON.parse(reply.raw).id || "");
    if (!/^[a-zA-Z0-9_-]{8,90}$/.test(operationId)) {
      return e.json(502, {error: "invalid_speech_response"});
    }
    return e.json(202, {provider: "yandex", operation_id: operationId});
  } catch (_) {
    return e.json(502, {error: "speech_provider_unreachable"});
  }
});

// Poll an operation using a POST so the BYOK credential cannot leak into URL
// query strings or access logs. Operation IDs are scoped by the Yandex key.
routerAdd("POST", "/api/viktor/transcribe-yandex/status", (e) => {
  const speech = require(`${__hooks}/viktor_yandex_speech_helpers.js`);
  const request = speech.auth(e, false);
  if (request.error) return e.json(request.status, {error: request.error});
  const headers = {
    "Authorization": "Api-Key " + request.key,
    "x-folder-id": request.folder
  };
  try {
    const operation = $http.send({
      url: "https://operation.api.cloud.yandex.net/operations/" + request.operationId,
      method: "GET", headers, timeout: 12
    });
    if (operation.statusCode < 200 || operation.statusCode >= 300) {
      return e.json(502, {error: "speech_provider_rejected", status: operation.statusCode});
    }
    const state = JSON.parse(operation.raw);
    if (!state.done) return e.json(202, {status: "pending"});
    if (state.error) return e.json(502, {error: "speech_provider_rejected"});
    const recognized = $http.send({
      url: "https://stt.api.cloud.yandex.net/stt/v3/getRecognition?operation_id=" +
        request.operationId,
      method: "GET", headers, timeout: 15
    });
    if (recognized.statusCode < 200 || recognized.statusCode >= 300) {
      return e.json(502, {error: "speech_provider_rejected", status: recognized.statusCode});
    }
    const entries = speech.frames(String(recognized.raw || ""));
    if (entries.length === 0) {
      return e.json(502, {error: "invalid_speech_response", stage: "result_stream"});
    }
    // SpeechKit REST v3 may deliver finalRefinement.normalizedText as a
    // separate streaming event. Refined text supersedes final for the same
    // index; never concatenate both versions of the same spoken phrase.
    const phrasesByIndex = {};
    let sequential = 0;
    for (const entry of entries) {
      const event = entry && (entry.result || entry);
      if (!event || typeof event !== "object") continue;
      const refined = event.finalRefinement &&
        event.finalRefinement.normalizedText;
      const final = event.final;
      const selected = refined || final;
      const alternatives = selected && selected.alternatives;
      if (!Array.isArray(alternatives) || alternatives.length === 0) continue;
      const phrase = String(alternatives[0].text || "").trim();
      if (!phrase) continue;
      const rawIndex = refined
        ? event.finalRefinement.finalIndex
        : event.audioCursors && event.audioCursors.finalIndex;
      const index = rawIndex !== undefined && rawIndex !== null &&
          /^\d+$/.test(String(rawIndex)) ? Number(rawIndex) : sequential++;
      const current = phrasesByIndex[index];
      if (!current || refined) {
        phrasesByIndex[index] = {text: phrase, refined: Boolean(refined)};
      }
    }
    const transcript = Object.keys(phrasesByIndex).map(Number)
      .sort((a, b) => a - b)
      .map(index => phrasesByIndex[index].text)
      .join(" ").trim().slice(0, 4000);
    if (!transcript) return e.json(422, {error: "no_speech_detected"});
    return e.json(200, {transcript, provider: "yandex"});
  } catch (_) {
    return e.json(502, {error: "speech_provider_unreachable"});
  }
});
