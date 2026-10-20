/// <reference path="../pb_data/types.d.ts" />
// Account-scoped, encrypted-at-rest BYOK vault. The API NEVER returns API
// keys or raw ciphertext. The server handles provider requests on behalf of
// the authenticated owner and does not expose this collection directly.
function viktorVaultKey() {
  const key = String($os.getenv("VIKTOR_VAULT_KEY") || "");
  return key.length === 32 ? key : null;
}
function viktorVaultDec(ciphertext, secret) {
  const raw = $security.decrypt(ciphertext, secret);
  const decoded = typeof raw === "string" ? raw :
    Buffer.from(raw).toString("utf8");
  return JSON.parse(decoded);
}
function viktorVaultOwner(e) {
  const auth = e.requestInfo().auth;
  return auth && /^[a-z0-9]{15}$/.test(String(auth.id || ""))
    ? auth.id : "";
}
function viktorVaultFind(owner, provider) {
  try {
    return $app.findFirstRecordByFilter(
      "viktor_connections",
      "user_id = {:owner} && provider = {:provider}",
      {owner: owner, provider: provider}
    );
  } catch (_) { return null; }
}
const viktorVaultModels = {
  yandex: ["yandexgpt/rc", "yandexgpt/latest"],
  gigachat: ["GigaChat-2", "GigaChat-2-Pro", "GigaChat-2-Max"],
  openai: ["gpt-4o-mini", "gpt-4.1-mini"],
  groq: ["llama-3.3-70b-versatile", "openai/gpt-oss-20b"],
  gemini: ["gemini-2.5-flash", "gemini-2.5-flash-lite"],
  openrouter: ["qwen/qwen3-32b", "deepseek/deepseek-chat"]
};

// Return only non-secret connection status for ALL providers, so any device
// can load its preferred model without ever retrieving an API key.
routerAdd("GET", "/api/viktor/connection", (e) => {
  const owner = viktorVaultOwner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const secret = viktorVaultKey();
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
      if (!viktorVaultModels[provider]) continue;
      const payload = viktorVaultDec(record.getString("payload_enc"), secret);
      connections.push({
        provider: provider,
        model: String(record.getString("model") || ""),
        folder_id: provider === "yandex"
          ? String(payload.folder_id || "") : "",
        speech_provider: String(payload.speech_provider || ""),
        has_speech_key: !!payload.speech_api_key,
      });
    } catch (_) {
      // Never expose ciphertext, decryption errors, or secret values.
    }
  }
  return e.json(200, {connections: connections});
});

// An explicit user Save action persists the connection. An empty api_key
// updates metadata without silently overwriting a previously saved key.
routerAdd("POST", "/api/viktor/connection", (e) => {
  const owner = viktorVaultOwner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const secret = viktorVaultKey();
  if (!secret) return e.json(503, {error: "vault_unconfigured"});
  const body = e.requestInfo().body || {};
  const provider = String(body.provider || "");
  const model = String(body.model || "");
  if (!viktorVaultModels[provider] ||
      viktorVaultModels[provider].indexOf(model) < 0) {
    return e.json(400, {error: "unsupported_model"});
  }
  const apiKey = String(body.api_key || "").trim();
  const speechKey = String(body.speech_api_key || "").trim();
  const folderId = String(body.folder_id || "").trim();
  const speechProvider = String(body.speech_provider || "");
  const gigaScope = String(body.gigachat_scope || "pers");
  if (apiKey.length > 512 || speechKey.length > 512 ||
      (apiKey.length > 0 && apiKey.length < 12) ||
      (speechKey.length > 0 && speechKey.length < 12) ||
      (speechProvider && !["groq", "openai", "gemini"].includes(speechProvider)) ||
      !["pers", "b2b", "corp"].includes(gigaScope)) {
    return e.json(400, {error: "invalid_connection"});
  }
  let record = viktorVaultFind(owner, provider);
  let previous = {};
  if (record) {
    try {
      previous = viktorVaultDec(record.getString("payload_enc"), secret);
    } catch (_) {
      return e.json(503, {error: "vault_unavailable"});
    }
  }
  const effectiveKey = apiKey || String(previous.api_key || "");
  const effectiveFolder = folderId || String(previous.folder_id || "");
  if (effectiveKey.length < 12 || effectiveKey.length > 512 ||
      (provider === "yandex" &&
       !/^[a-zA-Z0-9_-]{10,64}$/.test(effectiveFolder))) {
    return e.json(400, {error: provider === "yandex"
      ? "api_key_or_folder_required" : "api_key_required"});
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
  } catch (_) {
    return e.json(503, {error: "vault_save_failed"});
  }
  return e.json(200, {configured: true, provider: provider, model: model,
    folder_id: provider === "yandex" ? effectiveFolder : ""});
});

routerAdd("DELETE", "/api/viktor/connection", (e) => {
  const owner = viktorVaultOwner(e);
  if (!owner) return e.json(401, {error: "auth_required"});
  const body = e.requestInfo().body || {};
  const provider = String(body.provider || "");
  if (!viktorVaultModels[provider]) {
    return e.json(400, {error: "unsupported_provider"});
  }
  const record = viktorVaultFind(owner, provider);
  if (record) {
    try { $app.delete(record); }
    catch (_) { return e.json(503, {error: "vault_delete_failed"}); }
  }
  return e.json(200, {configured: false, provider: provider});
});
