/// <reference path="../pb_data/types.d.ts" />
// Yandex SpeechKit WAV transcription, using the same BYOK API key as YandexGPT.
// Audio and credentials are not persisted. All provider hosts are fixed.
function viktorYandexSpeechAuth(e, withAudio) {
  const info = e.requestInfo();
  if (!info.auth || !info.auth.id) return {error: "auth_required", status: 401};
  const body = info.body || {};
  const key = String(body.api_key || "").trim();
  const folder = String(body.yandex_folder_id || "").trim();
  if (key.length < 12 || key.length > 512) return {error: "speech_api_key_required", status: 400};
  if (!/^[a-zA-Z0-9_-]{10,64}$/.test(folder)) {
    return {error: "yandex_folder_id_required", status: 400};
  }
  if (!withAudio) {
    const operationId = String(body.operation_id || "");
    if (!/^[a-zA-Z0-9_-]{8,90}$/.test(operationId)) {
      return {error: "invalid_speech_operation", status: 400};
    }
    return {key, folder, operationId};
  }
  const encoded = String(body.audio_base64 || "");
  const language = String(body.language || "ru").toLowerCase();
  if (!["ru", "en"].includes(language) ||
      encoded.length < 21000 || encoded.length > 2600000 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(encoded)) {
    return {error: "invalid_or_oversized_audio", status: 413};
  }
  let wav;
  try { wav = Buffer.from(encoded, 'base64'); } catch (_) {
    return {error: "invalid_audio_encoding", status: 400};
  }
  if (!wav || wav.length < 16044 || wav.length > 1920044 ||
      String.fromCharCode.apply(null, Array.from(wav).slice(0, 4)) !== "RIFF" ||
      String.fromCharCode.apply(null, Array.from(wav).slice(8, 12)) !== "WAVE") {
    return {error: "invalid_audio_format", status: 400};
  }
  return {key, folder, encoded, language};
}

routerAdd("POST", "/api/viktor/transcribe-yandex", (e) => {
  const request = viktorYandexSpeechAuth(e, true);
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
            languageCode: [request.language === "ru" ? "ru-RU" : "en-US"]
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
  const request = viktorYandexSpeechAuth(e, false);
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
      url: "https://stt.api.cloud.yandex.net/stt/v3/getRecognition?operationId=" +
        request.operationId,
      method: "GET", headers, timeout: 15
    });
    if (recognized.statusCode < 200 || recognized.statusCode >= 300) {
      return e.json(502, {error: "speech_provider_rejected", status: recognized.statusCode});
    }
    let entries = [];
    try {
      const data = JSON.parse(recognized.raw);
      entries = Array.isArray(data) ? data : [data];
    } catch (_) {
      for (const line of String(recognized.raw || "").split(/\r?\n/)) {
        if (!line.trim()) continue;
        try { entries.push(JSON.parse(line)); } catch (_) {}
      }
    }
    const phrases = [];
    for (const entry of entries) {
      const event = entry && (entry.result || entry);
      const finalized = event && (event.final ||
        (event.finalRefinement && event.finalRefinement.normalizedText));
      const alternatives = finalized && finalized.alternatives;
      if (!Array.isArray(alternatives) || alternatives.length === 0) continue;
      const phrase = String(alternatives[0].text || "").trim();
      if (phrase && phrases[phrases.length - 1] !== phrase) phrases.push(phrase);
    }
    const transcript = phrases.join(" ").trim().slice(0, 4000);
    if (!transcript) return e.json(422, {error: "no_speech_detected"});
    return e.json(200, {transcript, provider: "yandex"});
  } catch (_) {
    return e.json(502, {error: "speech_provider_unreachable"});
  }
});
