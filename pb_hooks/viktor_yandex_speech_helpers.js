// Yandex SpeechKit pure route helpers. PocketBase route callback contexts are
// isolated: handlers must require this module INSIDE each callback.
// Keep all credentials and audio in the request scope, never module state.
function viktorYandexSpeechAuth(e, withAudio) {
  const info = e.requestInfo();
  if (!info.auth || !info.auth.id) return {error: "auth_required", status: 401};
  const body = info.body || {};
  let key = String(body.api_key || "").trim();
  let folder = String(body.yandex_folder_id || "").trim();
  if (key.length === 0) {
    const secret = String($os.getenv("VIKTOR_VAULT_KEY") || "");
    if (secret.length === 32) {
      try {
        const row = $app.findFirstRecordByFilter(
          "viktor_connections",
          "user_id = {:owner} && provider = 'yandex'",
          {owner: info.auth.id}
        );
        const raw = $security.decrypt(row.getString("payload_enc"), secret);
        const data = JSON.parse(typeof raw === "string"
          ? raw : Buffer.from(raw).toString("utf8"));
        key = String(data.api_key || "").trim();
        folder = folder || String(data.folder_id || "");
      } catch (_) {
        // Missing or inaccessible credentials fail closed.
      }
    }
  }
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

// SpeechKit REST v3 returns adjacent JSON objects without guaranteed line
// separators. Decode an entire bounded response, never model/provider prose.
function viktorYandexSpeechFrames(raw) {
  if (typeof raw !== "string" || raw.length > 3000000) return [];
  try {
    const decoded = JSON.parse(raw);
    return Array.isArray(decoded) ? decoded.slice(0, 200) : [decoded];
  } catch (_) {}
  const frames = [];
  let start = -1, depth = 0, inString = false, escaped = false;
  for (let i = 0; i < raw.length; i++) {
    const ch = raw[i];
    if (depth === 0) {
      if (/\s/.test(ch)) continue;
      if (ch !== "{") return [];
      start = i;
      depth = 1;
      inString = false;
      escaped = false;
      continue;
    }
    if (inString) {
      if (escaped) escaped = false;
      else if (ch === "\\") escaped = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') inString = true;
    else if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) {
        try { frames.push(JSON.parse(raw.slice(start, i + 1))); }
        catch (_) { return []; }
        if (frames.length > 200) return [];
      }
    }
  }
  return depth === 0 ? frames : [];
}

module.exports = {
  auth: viktorYandexSpeechAuth,
  frames: viktorYandexSpeechFrames,
};
