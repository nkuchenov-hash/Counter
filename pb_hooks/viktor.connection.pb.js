/// <reference path="../pb_data/types.d.ts" />
// Account-scoped, encrypted-at-rest BYOK vault. The API NEVER returns API
// keys or raw ciphertext. The server handles provider requests on behalf of
// the authenticated owner and does not expose this collection directly.
// Return only non-secret connection status for ALL providers, so any device
// can load its preferred model without ever retrieving an API key.
routerAdd("GET", "/api/viktor/connection", (e) => {
  const vault = require(`${__hooks}/viktor_vault_helpers.js`);
  const owner = vault.owner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const secret = vault.key();
  if (!secret) return e.json(503, {error: "vault_unconfigured"});
  let records;
  try {
    records = $app.findRecordsByFilter(
      "viktor_connections",
      "user_id = {:owner}", "-updated", 20, 0, {owner: owner}
    );
  } catch (_) {
    return e.json(503, {error: "vault_unavailable"});
  }
  const connections = [];
  for (const record of records) {
    try {
      const provider = String(record.getString("provider") || "");
      if (!vault.models[provider]) continue;
      const payload = vault.decrypt(record.getString("payload_enc"), secret);
      connections.push({
        provider: provider,
        model: String(record.getString("model") || ""),
        folder_id: provider === "yandex"
          ? String(payload.folder_id || "") : "",
        speech_provider: String(payload.speech_provider || ""),
        has_speech_key: !!payload.speech_api_key,
      });
    } catch (_) {
      // A stored-but-unreadable credential is NOT an empty connection.
      // Report a safe error rather than silently telling the UI no key exists.
      return e.json(503, {error: "vault_connection_unreadable"});
    }
  }
  return e.json(200, {connections: connections});
});

// An explicit user Save action persists the connection. An empty api_key
// updates metadata without silently overwriting a previously saved key.
routerAdd("POST", "/api/viktor/connection", (e) => {
  const vault = require(`${__hooks}/viktor_vault_helpers.js`);
  const owner = vault.owner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const secret = vault.key();
  if (!secret) return e.json(503, {error: "vault_unconfigured"});
  const body = e.requestInfo().body || {};
  const provider = String(body.provider || "");
  const model = String(body.model || "");
  if (!vault.models[provider]) {
    return e.json(400, {error: "unsupported_provider"});
  }
  if (vault.models[provider].indexOf(model) < 0) {
    return e.json(400, {error: "unsupported_model"});
  }
  const apiKey = String(body.api_key || "").trim();
  const speechKey = String(body.speech_api_key || "").trim();
  const folderId = String(body.folder_id || "").trim();
  const speechProvider = String(body.speech_provider || "");
  const gigaScope = String(body.gigachat_scope || "pers");
  // Return a stable, field-specific error code. Never echo secret values.
  if (apiKey.length > 2048 || speechKey.length > 2048) {
    return e.json(400, {error: "api_key_too_long"});
  }
  if (apiKey.length > 0 && apiKey.length < 12) {
    return e.json(400, {error: "api_key_too_short"});
  }
  if (speechKey.length > 0 && speechKey.length < 12) {
    return e.json(400, {error: "speech_api_key_too_short"});
  }
  if (speechProvider && !["groq", "openai", "gemini"].includes(speechProvider)) {
    return e.json(400, {error: "unsupported_speech_provider"});
  }
  if (!["pers", "b2b", "corp"].includes(gigaScope)) {
    return e.json(400, {error: "invalid_gigachat_scope"});
  }
  let record = vault.find(owner, provider);
  let previous = {};
  if (record) {
    try {
      previous = vault.decrypt(record.getString("payload_enc"), secret);
    } catch (_) {
      return e.json(503, {error: "vault_unavailable"});
    }
  }
  const effectiveKey = apiKey || String(previous.api_key || "");
  const effectiveFolder = folderId || String(previous.folder_id || "");
  if (!effectiveKey) {
    return e.json(400, {error: "api_key_required"});
  }
  if (effectiveKey.length < 12) {
    return e.json(400, {error: "api_key_too_short"});
  }
  if (effectiveKey.length > 2048) {
    return e.json(400, {error: "api_key_too_long"});
  }
  if (provider === "yandex" && !effectiveFolder) {
    return e.json(400, {error: "yandex_folder_id_required"});
  }
  if (provider === "yandex" &&
      !/^[a-zA-Z0-9_-]{10,64}$/.test(effectiveFolder)) {
    return e.json(400, {error: "invalid_yandex_folder_id"});
  }
  const payload = {
    api_key: effectiveKey,
    folder_id: provider === "yandex" ? effectiveFolder : "",
    speech_provider: speechProvider || String(previous.speech_provider || "groq"),
    speech_api_key: speechKey || String(previous.speech_api_key || ""),
    gigachat_scope: gigaScope,
  };
  try {
    if (!record) {
      record = new Record($app.findCollectionByNameOrId("viktor_connections"));
      record.set("user_id", owner);
      record.set("provider", provider);
    }
    record.set("model", model);
    record.set("payload_enc", $security.encrypt(JSON.stringify(payload), secret));
    $app.save(record);
    // The write isn't successful until the saved ciphertext can be read
    // back and decrypted using the exact same master key.
    const persisted = vault.find(owner, provider);
    if (!persisted) throw new Error("missing saved connection");
    const verified = vault.decrypt(persisted.getString("payload_enc"), secret);
    if (verified.api_key !== effectiveKey ||
        (provider === "yandex" && verified.folder_id !== effectiveFolder)) {
      throw new Error("saved connection did not match");
    }
  } catch (_) {
    return e.json(503, {error: "vault_save_failed"});
  }
  return e.json(200, {configured: true, provider: provider, model: model,
    folder_id: provider === "yandex" ? effectiveFolder : ""});
});

routerAdd("DELETE", "/api/viktor/connection", (e) => {
  const vault = require(`${__hooks}/viktor_vault_helpers.js`);
  const owner = vault.owner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const body = e.requestInfo().body || {};
  const provider = String(body.provider || "");
  if (!vault.models[provider]) {
    return e.json(400, {error: "unsupported_provider"});
  }
  const record = vault.find(owner, provider);
  if (record) {
    try { $app.delete(record); }
    catch (_) { return e.json(503, {error: "vault_delete_failed"}); }
  }
  return e.json(200, {configured: false, provider: provider});
});
