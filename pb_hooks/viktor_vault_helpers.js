// Pure, immutable helpers for PocketBase's isolated route-handler VMs.
// IMPORTANT: load with require(`${__hooks}/viktor_vault_helpers.js`) *inside*
// each routerAdd callback. Top-level .pb.js functions are not visible there.
const models = Object.freeze({
  yandex: Object.freeze(["yandexgpt/rc", "yandexgpt/latest"]),
  gigachat: Object.freeze(["GigaChat-2", "GigaChat-2-Pro", "GigaChat-2-Max"]),
  openai: Object.freeze(["gpt-4o-mini", "gpt-4.1-mini"]),
  groq: Object.freeze(["llama-3.3-70b-versatile", "openai/gpt-oss-20b"]),
  gemini: Object.freeze(["gemini-2.5-flash", "gemini-2.5-flash-lite"]),
  openrouter: Object.freeze(["qwen/qwen3-32b", "deepseek/deepseek-chat"])
});

function owner(event) {
  const auth = event.requestInfo().auth;
  return auth && /^[a-z0-9]{15}$/.test(String(auth.id || ""))
    ? String(auth.id) : "";
}

function key() {
  const value = String($os.getenv("VIKTOR_VAULT_KEY") || "");
  return value.length === 32 ? value : null;
}

function decrypt(ciphertext, secret) {
  const plain = $security.decrypt(ciphertext, secret);
  // $security.decrypt returns either a UTF-8 string or Go []byte.
  return JSON.parse(typeof plain === "string" ? plain : toString(plain));
}

function find(ownerId, provider) {
  try {
    return $app.findFirstRecordByFilter(
      "viktor_connections",
      "user_id = {:owner} && provider = {:provider}",
      {owner: ownerId, provider: provider}
    );
  } catch (_) {
    return null;
  }
}

module.exports = {models: models, owner: owner, key: key,
  decrypt: decrypt, find: find};
