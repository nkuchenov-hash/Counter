// Server-owned Google cloud sleep synchronization for PocketBase JSVM.
// Google Health API provides recent reconciled sleep. Existing Google Fit-imported
// records remain canonical history in PocketBase; clients never read device-local data.

var __collection = "sleep_sync_connections";
var __storageProvider = "google_fit"; // compatibility with the existing connection row
var __defaultMinutes = 21 * 60;
var __catchupMs = 5 * 60 * 1000;
var __lookbackMs = 30 * 86400000;
var __fitScope = "https://www.googleapis.com/auth/fitness.sleep.read";
var __healthScope = "https://www.googleapis.com/auth/googlehealth.sleep.readonly";
var __oauthScopes = __fitScope + " " + __healthScope;
var __scopeRequired = "google_health_scope_required";

function __env(name) {
  try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}
function __baseUrl() { return __env("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io"; }
function __returnUrl() { return __env("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/"; }
function __date(value) {
  var d = value instanceof Date ? value : new Date(value);
  return isNaN(d.getTime()) ? null : d;
}
function __form(values) {
  var parts = [];
  for (var key in values) if (Object.prototype.hasOwnProperty.call(values, key)) {
    parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
  }
  return parts.join("&");
}
function __uuid() {
  var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
  return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}
function __tokenKey(app) {
  var key = __env("SLEEP_SYNC_TOKEN_KEY");
  if (key.length === 32) return key;
  try {
    var envName = String(app.encryptionEnv() || "").trim();
    var inherited = envName ? __env(envName) : "";
    if (inherited.length === 32) return inherited;
  } catch (_) {}
  throw new Error("PocketBase encryption key is not configured");
}
function __config() {
  var clientId = __env("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
  var clientSecret = __env("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
  if (!clientId || !clientSecret) throw new Error("Google OAuth is not configured");
  return {
    clientId: clientId,
    clientSecret: clientSecret,
    redirectUri: __baseUrl() + "/api/sleep-sync/google-fit/callback"
  };
}
function __connection(app, userId, create) {
  try {
    return app.findFirstRecordByFilter(__collection, "user_id = {:uid} && provider = {:provider}", {
      uid: userId, provider: __storageProvider
    });
  } catch (_) { if (!create) return null; }
  var record = new Record(app.findCollectionByNameOrId(__collection));
  record.set("user_id", userId);
  record.set("provider", __storageProvider);
  record.set("enabled", false);
  record.set("daily_sync_minutes", __defaultMinutes);
  record.set("status", "disconnected");
  app.save(record);
  return record;
}
function __needsAuth(errorText) {
  var raw = String(errorText || "").toLowerCase();
  return raw.indexOf("invalid_grant") >= 0 || raw.indexOf("account_not_linked") >= 0 || raw.indexOf(__scopeRequired) >= 0;
}
function __status(connection) {
  if (!connection) return {
    configured: false, provider: "google_cloud", enabled: false, daily_sync_minutes: __defaultMinutes,
    status: "disconnected", last_sync_at: null, last_session_count: 0, last_imported_count: 0,
    last_sleep_count: 0, last_activity_count: 0, history_complete: false, last_error: null
  };
  var error = String(connection.get("last_error") || "");
  var configured = String(connection.get("refresh_token_enc") || "").length > 0 && !__needsAuth(error);
  return {
    configured: configured,
    provider: "google_cloud",
    enabled: configured && !!connection.get("enabled"),
    daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __defaultMinutes),
    status: configured ? (connection.get("status") || "connected") : "disconnected",
    last_sync_at: connection.get("last_sync_at") || null,
    last_session_count: Number(connection.get("last_session_count") || 0),
    last_imported_count: Number(connection.get("last_imported_count") || 0),
    last_sleep_count: Number(connection.get("last_sleep_count") || 0),
    last_activity_count: 0,
    history_complete: String(connection.get("last_full_sync_at") || "").length > 0,
    last_error: configured ? (error || null) : (String(connection.get("refresh_token_enc") || "") ? "authorization_required" : null)
  };
}
function __exchangeCode(code) {
  var cfg = __config();
  var res = $http.send({
    url: "https://oauth2.googleapis.com/token", method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: __form({ code: code, client_id: cfg.clientId, client_secret: cfg.clientSecret, redirect_uri: cfg.redirectUri, grant_type: "authorization_code" }),
    timeout: 30
  });
  if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) throw new Error("Google token exchange failed: HTTP " + res.statusCode);
  return res.json;
}
function __accessToken(app, connection) {
  var key = __tokenKey(app);
  var current = String(connection.get("access_token_enc") || "");
  var expires = __date(connection.get("access_token_expires_at"));
  if (current && expires && expires.getTime() > Date.now() + 120000) return String($security.decrypt(current, key));
  var refresh = String(connection.get("refresh_token_enc") || "");
  if (!refresh) throw new Error("Google refresh token is missing");
  var cfg = __config();
  var res = $http.send({
    url: "https://oauth2.googleapis.com/token", method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: __form({
      refresh_token: String($security.decrypt(refresh, key)), client_id: cfg.clientId,
      client_secret: cfg.clientSecret, grant_type: "refresh_token"
    }), timeout: 30
  });
  if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) throw new Error("Google token refresh failed: HTTP " + res.statusCode);
  var ttl = Number(res.json.expires_in || 3600);
  connection.set("access_token_enc", $security.encrypt(String(res.json.access_token), key));
  connection.set("access_token_expires_at", new Date(Date.now() + ttl * 1000).toISOString());
  app.save(connection);
  return String(res.json.access_token);
}
function __scopeError(res) {
  if (!res || res.statusCode !== 403) return false;
  var raw = "";
  try { raw = JSON.stringify(res.json || {}).toLowerCase(); } catch (_) {}
  return raw.indexOf("scope") >= 0 || raw.indexOf("permission") >= 0 || raw.indexOf("insufficient") >= 0;
}
function __normalize(point) {
  point = point || {};
  var sleep = point.sleep || {};
  var interval = sleep.interval || {};
  var start = __date(interval.startTime || interval.start_time);
  var end = __date(interval.endTime || interval.end_time);
  if (!start || !end || end.getTime() <= start.getTime() || end.getTime() > Date.now()) return null;
  var name = String(point.dataPointName || point.data_point_name || "").trim();
  var updated = __date(point.updateTime || point.update_time || sleep.updateTime || sleep.update_time) || end;
  return {
    externalId: name ? "health|" + name : "health|" + start.toISOString() + "|" + end.toISOString(),
    start: start, end: end, modifiedAt: updated
  };
}
function __fetchSleep(accessToken, start, end) {
  var rows = [], pageToken = "", page = 0;
  do {
    var query = {
      pageSize: 25,
      dataSourceFamily: "users/me/dataSourceFamilies/all-sources",
      filter: 'sleep.interval.end_time >= "' + start.toISOString() + '" AND sleep.interval.end_time < "' + end.toISOString() + '"'
    };
    if (pageToken) query.pageToken = pageToken;
    var res = $http.send({
      url: "https://health.googleapis.com/v4/users/me/dataTypes/sleep/dataPoints:reconcile?" + __form(query),
      method: "GET", headers: { "authorization": "Bearer " + accessToken, "accept": "application/json" }, timeout: 60
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
      if (__scopeError(res)) throw new Error(__scopeRequired);
      throw new Error("Google Health sleep request failed: HTTP " + res.statusCode);
    }
    var points = res.json.dataPoints || res.json.data_points || [];
    for (var i = 0; i < points.length; i++) { var s = __normalize(points[i]); if (s) rows.push(s); }
    pageToken = String(res.json.nextPageToken || res.json.next_page_token || "").trim();
    if (++page > 1000) throw new Error("Google Health returned too many sleep pages");
  } while (pageToken);
  rows.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
  return rows;
}
function __overlapRatio(aStart, aEnd, bStart, bEnd) {
  var overlap = Math.max(0, Math.min(aEnd.getTime(), bEnd.getTime()) - Math.max(aStart.getTime(), bStart.getTime()));
  var shorter = Math.min(aEnd.getTime() - aStart.getTime(), bEnd.getTime() - bStart.getTime());
  return shorter > 0 ? overlap / shorter : 0;
}
function __profile(app, userId) { return app.findRecordById("profiles", userId); }
function __category(app, userId, language) {
  try { return app.findFirstRecordByFilter("categories", "user_id = {:uid} && (name = 'Sleep' || name = 'Сон')", { uid: userId }); } catch (_) {}
  var c = new Record(app.findCollectionByNameOrId("categories"));
  var ru = String(language || "").toLowerCase() === "ru";
  var slug = "sleep_" + $security.randomStringWithAlphabet(6, "0123456789abcdefghijklmnopqrstuvwxyz");
  c.set("user_id", userId); c.set("category_id", slug); c.set("normalized_id", slug);
  c.set("name", ru ? "Сон" : "Sleep"); c.set("order", 0); c.set("color_value", 0); c.set("icon_code_point", 0); c.set("is_archived", false);
  app.save(c); return c;
}
function __existing(app, userId, session) {
  try {
    var rows = app.findRecordsByFilter(
      "records", "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && start_time < {:end} && end_time > {:start}",
      "", 20, 0, { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
    );
    var best = null, ratio = 0;
    for (var i = 0; i < rows.length; i++) {
      var rs = __date(rows[i].get("start_time")), re = __date(rows[i].get("end_time"));
      if (!rs || !re || re.getTime() <= rs.getTime()) continue;
      var r = __overlapRatio(session.start, session.end, rs, re);
      if (r >= 0.80 && r > ratio) { best = rows[i]; ratio = r; }
    }
    if (best) return best;
  } catch (_) {}
  try { return app.findFirstRecordByFilter("records", "user_id = {:uid} && external_source = 'google_fit' && external_id = {:id}", { uid: userId, id: session.externalId }); } catch (_) {}
  return null;
}
function __upsert(app, userId, profile, category, session) {
  var existing = __existing(app, userId, session);
  var record = existing || new Record(app.findCollectionByNameOrId("records"));
  var ru = String(profile.get("primary_language") || "").toLowerCase() === "ru";
  record.set("user_id", userId); record.set("record_id", existing ? record.get("record_id") : __uuid());
  record.set("status", "completed"); record.set("title", ru ? "Сон" : "Sleep");
  record.set("start_time", session.start.toISOString()); record.set("end_time", session.end.toISOString());
  record.set("category_id", category.id); record.set("category_link", category.id); record.set("type", "record"); record.set("checklist", "[]");
  // Keep the existing storage enum for schema compatibility. The Health ID prefix identifies the primary source internally.
  record.set("external_source", "google_fit"); record.set("external_id", session.externalId); record.set("external_kind", "sleep");
  record.set("external_updated_at", session.modifiedAt.toISOString()); record.set("sleep_source", "google_fit"); record.set("sleep_external_id", session.externalId);
  app.save(record); return existing ? 0 : 1;
}
function __localDay(profile, now) {
  var offset = Number(profile.get("timezone_offset") || 0);
  var local = new Date(now.getTime() + offset * 3600000);
  return local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0");
}
function __runConnection(app, connection) {
  var userId = String(connection.get("user_id") || "");
  if (!userId) throw new Error("Sleep connection has no user");
  var profile = __profile(app, userId), now = new Date(), token = __accessToken(app, connection);
  var sessions;
  try { sessions = __fetchSleep(token, new Date(now.getTime() - __lookbackMs), now); }
  catch (err) {
    if (String(err) === "Error: " + __scopeRequired || String(err) === __scopeRequired) {
      connection.set("status", "connected"); connection.set("last_error", __scopeRequired); connection.set("last_sync_at", now.toISOString()); app.save(connection);
      return { sessions: 0, imported: 0, authorizationRequired: true };
    }
    throw err;
  }
  var category = __category(app, userId, profile.get("primary_language")), imported = 0;
  for (var i = 0; i < sessions.length; i++) imported += __upsert(app, userId, profile, category, sessions[i]);
  connection.set("status", "connected"); connection.set("last_error", ""); connection.set("last_sync_at", now.toISOString());
  connection.set("last_sync_local_day", __localDay(profile, now)); connection.set("last_session_count", sessions.length);
  connection.set("last_imported_count", imported); connection.set("last_sleep_count", sessions.length); connection.set("last_activity_count", 0); app.save(connection);
  if (imported > 0) try { app.logger().info("cloud sleep imported", "imported", imported, "sessions", sessions.length); } catch (_) {}
  return { sessions: sessions.length, imported: imported, authorizationRequired: false };
}
function __runSafe(app, connection) {
  try { connection.set("status", "syncing"); app.save(connection); return __runConnection(app, connection); }
  catch (err) { connection.set("status", "error"); connection.set("last_error", String(err)); connection.set("last_sync_at", new Date().toISOString()); app.save(connection); throw err; }
}
function status(e) { return e.json(200, __status(__connection(e.app, e.auth.id, false))); }
function connect(e) {
  var cfg = __config(); __tokenKey(e.app);
  var c = __connection(e.app, e.auth.id, true), oldState = String(c.get("oauth_state") || ""), oldExpiry = __date(c.get("oauth_state_expires_at")), state;
  if (oldState && oldState.indexOf(c.id + ".") === 0 && oldExpiry && oldExpiry.getTime() > Date.now() + 60000) state = oldState;
  else {
    state = c.id + "." + $security.randomStringWithAlphabet(40, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    c.set("oauth_state", state); c.set("oauth_state_expires_at", new Date(Date.now() + 20 * 60000).toISOString());
  }
  c.set("status", "connecting"); c.set("last_error", ""); e.app.save(c);
  var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __form({
    client_id: cfg.clientId, redirect_uri: cfg.redirectUri, response_type: "code", scope: __oauthScopes,
    access_type: "offline", prompt: "consent", include_granted_scopes: "true", state: state
  });
  return e.json(200, { authorization_url: url });
}
function callback(e) {
  var q = e.requestInfo().query || {}, state = String(q.state || ""), code = String(q.code || "");
  if (String(q.error || "")) return e.html(400, "<h1>Sleep synchronization cancelled</h1>");
  if (!state || !code) return e.html(400, "<h1>Sleep synchronization failed</h1><p>Missing OAuth response.</p>");
  var c = null, parts = state.split(".");
  if (parts.length === 2 && parts[0]) { try { c = e.app.findRecordById(__collection, parts[0]); } catch (_) {} if (c && String(c.get("oauth_state") || "") !== state) c = null; }
  if (!c) try { c = e.app.findFirstRecordByData(__collection, "oauth_state", state); } catch (_) {}
  var expiry = c ? __date(c.get("oauth_state_expires_at")) : null;
  if (!c || !expiry || expiry.getTime() < Date.now()) return e.html(400, "<h1>Sleep synchronization failed</h1><p>Invalid or expired authorization.</p>");
  try {
    var token = __exchangeCode(code), key = __tokenKey(e.app);
    if (!token.refresh_token) throw new Error("Google did not return a refresh token");
    c.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
    c.set("access_token_enc", $security.encrypt(String(token.access_token || ""), key));
    c.set("access_token_expires_at", new Date(Date.now() + Number(token.expires_in || 3600) * 1000).toISOString());
    c.set("enabled", true); c.set("status", "connected"); c.set("oauth_state", ""); c.set("oauth_state_expires_at", ""); c.set("last_error", ""); e.app.save(c);
    try { __runSafe(e.app, c); } catch (_) {}
    var ret = __returnUrl();
    return e.html(200, "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='1;url=" + ret + "'><title>Life OS</title><h1>Sleep synchronization connected</h1><p>Your sleep is being synchronized to Life OS.</p>");
  } catch (err) { c.set("status", "error"); c.set("last_error", String(err)); e.app.save(c); return e.html(500, "<h1>Sleep synchronization failed</h1><p>Return to Life OS and try again.</p>"); }
}
function settings(e) {
  var body = e.requestInfo().body || {}, c = __connection(e.app, e.auth.id, true);
  if (body.enabled !== undefined) c.set("enabled", !!body.enabled);
  if (body.daily_sync_minutes !== undefined) c.set("daily_sync_minutes", Math.floor(Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __defaultMinutes))));
  e.app.save(c); return e.json(200, __status(c));
}
function run(e) {
  var c = __connection(e.app, e.auth.id, false);
  if (!c || !String(c.get("refresh_token_enc") || "")) return e.json(409, { error: "not_connected" });
  try { var r = __runSafe(e.app, c); return e.json(200, { ok: true, sessions: r.sessions, imported: r.imported, authorization_required: r.authorizationRequired }); }
  catch (err) { return e.json(502, { ok: false, error: "sleep_sync_failed" }); }
}
function remove(e) { var c = __connection(e.app, e.auth.id, false); if (c) e.app.delete(c); return e.json(200, { ok: true }); }
function cron(app) {
  var rows = [];
  try { rows = app.findRecordsByFilter(__collection, "enabled = true && provider = 'google_fit'", "", 500, 0); } catch (_) { return; }
  var now = new Date();
  for (var i = 0; i < rows.length; i++) {
    try {
      var c = rows[i]; if (__needsAuth(c.get("last_error"))) continue;
      var last = __date(c.get("last_sync_at")); if (last && now.getTime() - last.getTime() < __catchupMs) continue;
      __runSafe(app, c);
    } catch (_) {}
  }
}
module.exports = { status: status, connect: connect, callback: callback, settings: settings, run: run, remove: remove, cron: cron };
