/// <reference path="../pb_data/types.d.ts" />
// Google Fit is the only health source. The server owns OAuth, catch-up and upserts.

var __fitCollection = "sleep_sync_connections";
var __fitProvider = "google_fit";
var __fitDefaultMinutes = 21 * 60;
var __fitLookbackDays = 14;
var __fitScopes = [
    "https://www.googleapis.com/auth/fitness.sleep.read",
    "https://www.googleapis.com/auth/fitness.activity.read"
].join(" ");

function __fitEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __fitPublicBaseUrl() {
    return __fitEnv("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __fitReturnUrl() {
    return __fitEnv("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __fitTokenKey(app) {
    var key = __fitEnv("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __fitEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("PocketBase encryption key is not configured");
}

function __fitGoogleConfig(app) {
    var clientId = __fitEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = __fitEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
    if (!clientId || !clientSecret) {
        try {
            var profiles = app.findCollectionByNameOrId("profiles");
            var result = profiles.oauth2.getProviderConfig("google");
            var provider = result[0];
            var found = result[1];
            if (found && provider) {
                clientId = clientId || String(provider.clientId || "").trim();
                clientSecret = clientSecret || String(provider.clientSecret || "").trim();
            }
        } catch (_) {}
    }
    if (!clientId || !clientSecret) throw new Error("Google Fit OAuth is not configured");
    return {
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: __fitPublicBaseUrl() + "/api/sleep-sync/google-fit/callback"
    };
}

function __fitFormEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __fitDate(value) {
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __fitUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __fitConnection(app, userId, createIfMissing) {
    try {
        return app.findFirstRecordByFilter(__fitCollection, "user_id = {:uid} && provider = {:provider}", {
            uid: userId,
            provider: __fitProvider
        });
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var record = new Record(app.findCollectionByNameOrId(__fitCollection));
    record.set("user_id", userId);
    record.set("provider", __fitProvider);
    record.set("enabled", false);
    record.set("daily_sync_minutes", __fitDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __fitStatus(connection) {
    if (!connection) {
        return {
            configured: false, provider: __fitProvider, enabled: false,
            daily_sync_minutes: __fitDefaultMinutes, status: "disconnected",
            last_sync_at: null, last_session_count: 0, last_imported_count: 0,
            last_sleep_count: 0, last_activity_count: 0, last_error: null
        };
    }
    return {
        configured: String(connection.get("refresh_token_enc") || "").length > 0,
        provider: connection.get("provider") || __fitProvider,
        enabled: !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __fitDefaultMinutes),
        status: connection.get("status") || "disconnected",
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_sleep_count: Number(connection.get("last_sleep_count") || 0),
        last_activity_count: Number(connection.get("last_activity_count") || 0),
        last_error: connection.get("last_error") || null
    };
}

function __fitExchangeCode(app, code) {
    var cfg = __fitGoogleConfig(app);
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __fitFormEncode({
            code: code, client_id: cfg.clientId, client_secret: cfg.clientSecret,
            redirect_uri: cfg.redirectUri, grant_type: "authorization_code"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google token exchange failed: HTTP " + res.statusCode);
    }
    return res.json;
}

function __fitAccessToken(app, connection) {
    var key = __fitTokenKey(app);
    var currentEnc = String(connection.get("access_token_enc") || "");
    var expiresAt = __fitDate(connection.get("access_token_expires_at"));
    if (currentEnc && expiresAt && expiresAt.getTime() > Date.now() + 120000) {
        return String($security.decrypt(currentEnc, key));
    }
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("Google Fit refresh token is missing");
    var cfg = __fitGoogleConfig(app);
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __fitFormEncode({
            refresh_token: String($security.decrypt(refreshEnc, key)),
            client_id: cfg.clientId, client_secret: cfg.clientSecret,
            grant_type: "refresh_token"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
        throw new Error("Google token refresh failed: HTTP " + res.statusCode);
    }
    var expiresIn = Number(res.json.expires_in || 3600);
    connection.set("access_token_enc", $security.encrypt(String(res.json.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + expiresIn * 1000).toISOString());
    app.save(connection);
    return String(res.json.access_token);
}

function __fitFetchSessions(accessToken, start, end, activityType) {
    var url = "https://www.googleapis.com/fitness/v1/users/me/sessions" +
        "?startTime=" + encodeURIComponent(start.toISOString()) +
        "&endTime=" + encodeURIComponent(end.toISOString());
    if (activityType !== null && activityType !== undefined) {
        url += "&activityType=" + encodeURIComponent(String(activityType));
    }
    var res = $http.send({
        url: url, method: "GET",
        headers: { "authorization": "Bearer " + accessToken, "accept": "application/json" },
        timeout: 45
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google Fit sessions request failed: HTTP " + res.statusCode);
    }
    return res.json.session || [];
}

function __fitNormalizeSession(row, kind) {
    row = row || {};
    var startMillis = Number(row.startTimeMillis || 0);
    var endMillis = Number(row.endTimeMillis || 0);
    if (!isFinite(startMillis) || !isFinite(endMillis) || endMillis <= startMillis) return null;
    var start = new Date(startMillis);
    var end = new Date(endMillis);
    if (isNaN(start.getTime()) || isNaN(end.getTime()) || end.getTime() > Date.now()) return null;
    var appInfo = row.application || {};
    var appIdentity = String(appInfo.packageName || appInfo.name || "unknown");
    var sessionId = String(row.id || "").trim();
    var externalId = "google-fit|" + appIdentity + "|" +
        (sessionId || (kind + "|" + start.toISOString() + "|" + end.toISOString()));
    var modified = Number(row.modifiedTimeMillis || 0);
    return {
        kind: kind,
        externalId: externalId,
        activityType: Number(row.activityType || 0),
        name: String(row.name || "").trim(),
        start: start,
        end: end,
        modifiedAt: modified > 0 ? new Date(modified) : end
    };
}

function __fitSessions(accessToken, start, end) {
    var sleepRows = __fitFetchSessions(accessToken, start, end, 72);
    var allRows = __fitFetchSessions(accessToken, start, end, null);
    var byId = {};
    var sleep = [];
    var activities = [];
    var i;
    for (i = 0; i < sleepRows.length; i++) {
        var s = __fitNormalizeSession(sleepRows[i], "sleep");
        if (!s) continue;
        byId[s.externalId] = true;
        sleep.push(s);
    }
    for (i = 0; i < allRows.length; i++) {
        if (Number((allRows[i] || {}).activityType || 0) === 72) continue;
        var a = __fitNormalizeSession(allRows[i], "activity");
        if (!a || byId[a.externalId]) continue;
        byId[a.externalId] = true;
        activities.push(a);
    }
    return { sleep: sleep, activities: activities };
}

function __fitProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __fitCategory(app, userId, kind, language) {
    var names = kind === "sleep" ? ["Sleep", "Сон"] : ["Activity", "Активность"];
    try {
        return app.findFirstRecordByFilter(
            "categories", "user_id = {:uid} && (name = {:a} || name = {:b})",
            { uid: userId, a: names[0], b: names[1] }
        );
    } catch (_) {}
    var category = new Record(app.findCollectionByNameOrId("categories"));
    var ru = String(language || "").toLowerCase() === "ru";
    var slug = kind + "_" + $security.randomStringWithAlphabet(6, "0123456789abcdefghijklmnopqrstuvwxyz");
    category.set("user_id", userId);
    category.set("category_id", slug);
    category.set("normalized_id", slug);
    category.set("name", kind === "sleep" ? (ru ? "Сон" : "Sleep") : (ru ? "Активность" : "Activity"));
    category.set("order", 0);
    category.set("color_value", 0);
    category.set("icon_code_point", 0);
    category.set("is_archived", false);
    app.save(category);
    return category;
}

function __fitFindExisting(app, userId, session) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_fit' && external_id = {:external}",
            { uid: userId, external: session.externalId }
        );
    } catch (_) {}
    if (session.kind === "sleep") {
        try {
            return app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && sleep_source = 'google_fit' && sleep_external_id = {:external}",
                { uid: userId, external: session.externalId }
            );
        } catch (_) {}
    }
    return null;
}

function __fitActivityTitle(session, ru) {
    if (session.name) return session.name;
    var type = Number(session.activityType || 0);
    var en = {1:"Cycling",7:"Walking",8:"Running",9:"Aerobics",10:"Badminton",11:"Baseball",12:"Basketball",13:"Biathlon",16:"Boxing",25:"Elliptical",27:"Football",29:"Golf",35:"Hiking",44:"Rowing",47:"Skiing",54:"Swimming",58:"Tennis",80:"Yoga"};
    var ruNames = {1:"Велосипед",7:"Ходьба",8:"Бег",9:"Аэробика",10:"Бадминтон",11:"Бейсбол",12:"Баскетбол",13:"Биатлон",16:"Бокс",25:"Эллипс",27:"Футбол",29:"Гольф",35:"Поход",44:"Гребля",47:"Лыжи",54:"Плавание",58:"Теннис",80:"Йога"};
    return (ru ? ruNames[type] : en[type]) || (ru ? "Активность" : "Activity");
}

function __fitUpsert(app, userId, profile, category, session) {
    var existing = __fitFindExisting(app, userId, session);
    var record = existing || new Record(app.findCollectionByNameOrId("records"));
    var ru = String(profile.get("primary_language") || "").toLowerCase() === "ru";
    record.set("user_id", userId);
    record.set("record_id", existing ? record.get("record_id") : __fitUuid());
    record.set("status", "completed");
    record.set("title", session.kind === "sleep" ? (ru ? "Сон" : "Sleep") : __fitActivityTitle(session, ru));
    record.set("start_time", session.start.toISOString());
    record.set("end_time", session.end.toISOString());
    record.set("category_id", category.id);
    record.set("category_link", category.id);
    record.set("type", "record");
    record.set("checklist", "[]");
    record.set("external_source", "google_fit");
    record.set("external_id", session.externalId);
    record.set("external_kind", session.kind);
    record.set("external_updated_at", session.modifiedAt.toISOString());
    if (session.kind === "sleep") {
        record.set("sleep_source", "google_fit");
        record.set("sleep_external_id", session.externalId);
    }
    app.save(record);
    return existing ? 0 : 1;
}

function __fitLocalClock(profile, now) {
    var offsetHours = Number(profile.get("timezone_offset") || 0);
    var local = new Date(now.getTime() + offsetHours * 3600000);
    return {
        minutes: local.getUTCHours() * 60 + local.getUTCMinutes(),
        day: local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0")
    };
}

function __fitRunConnection(app, connection) {
    var userId = String(connection.get("user_id") || "");
    if (!userId) throw new Error("Google Fit connection has no user");
    var profile = __fitProfile(app, userId);
    var accessToken = __fitAccessToken(app, connection);
    var end = new Date();
    var start = new Date(end.getTime() - __fitLookbackDays * 86400000);
    var sessions = __fitSessions(accessToken, start, end);
    var sleepCategory = __fitCategory(app, userId, "sleep", profile.get("primary_language"));
    var activityCategory = sessions.activities.length > 0 ? __fitCategory(app, userId, "activity", profile.get("primary_language")) : null;
    var imported = 0;
    var i;
    for (i = 0; i < sessions.sleep.length; i++) imported += __fitUpsert(app, userId, profile, sleepCategory, sessions.sleep[i]);
    for (i = 0; i < sessions.activities.length; i++) imported += __fitUpsert(app, userId, profile, activityCategory, sessions.activities[i]);
    var local = __fitLocalClock(profile, end);
    connection.set("status", "connected");
    connection.set("last_sync_at", end.toISOString());
    connection.set("last_sync_local_day", local.day);
    connection.set("last_session_count", sessions.sleep.length + sessions.activities.length);
    connection.set("last_imported_count", imported);
    connection.set("last_sleep_count", sessions.sleep.length);
    connection.set("last_activity_count", sessions.activities.length);
    connection.set("last_error", "");
    app.save(connection);
    return { sessions: sessions.sleep.length + sessions.activities.length, imported: imported, sleep: sessions.sleep.length, activities: sessions.activities.length };
}

function __fitRunSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __fitRunConnection(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        connection.set("last_sync_at", new Date().toISOString());
        app.save(connection);
        try { app.logger().error("google fit sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

routerAdd("GET", "/api/sleep-sync/status", function(e) {
    return e.json(200, __fitStatus(__fitConnection(e.app, e.auth.id, false)));
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var cfg = __fitGoogleConfig(e.app);
    __fitTokenKey(e.app);
    var connection = __fitConnection(e.app, e.auth.id, true);
    var state = $security.randomStringWithAlphabet(48, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    connection.set("oauth_state", state);
    connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);
    var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __fitFormEncode({
        client_id: cfg.clientId, redirect_uri: cfg.redirectUri, response_type: "code",
        scope: __fitScopes, access_type: "offline", prompt: "consent",
        include_granted_scopes: "true", state: state
    });
    return e.json(200, { authorization_url: url });
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    var code = String(query.code || "");
    if (String(query.error || "")) return e.html(400, "<h1>Google Fit connection cancelled</h1>");
    if (!state || !code) return e.html(400, "<h1>Google Fit connection failed</h1><p>Missing OAuth response.</p>");
    var connection = null;
    try { connection = e.app.findFirstRecordByData(__fitCollection, "oauth_state", state); } catch (_) {}
    if (!connection) return e.html(400, "<h1>Google Fit connection failed</h1><p>Invalid or expired state.</p>");
    var expires = __fitDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) return e.html(400, "<h1>Google Fit connection failed</h1><p>Authorization expired.</p>");
    try {
        var token = __fitExchangeCode(e.app, code);
        var key = __fitTokenKey(e.app);
        if (!token.refresh_token) throw new Error("Google did not return a refresh token");
        connection.set("refresh_token_enc", $security.encrypt(String(token.refresh_token), key));
        connection.set("access_token_enc", $security.encrypt(String(token.access_token || ""), key));
        connection.set("access_token_expires_at", new Date(Date.now() + Number(token.expires_in || 3600) * 1000).toISOString());
        connection.set("enabled", true);
        connection.set("status", "connected");
        connection.set("oauth_state", "");
        connection.set("oauth_state_expires_at", "");
        connection.set("last_error", "");
        e.app.save(connection);
        try { __fitRunSafe(e.app, connection); } catch (_) {}
        var returnUrl = __fitReturnUrl();
        return e.html(200, "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'><title>Life OS</title><h1>Google Fit connected</h1><p>Sleep and activities now synchronize automatically.</p>");
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Google Fit connection failed</h1><p>Return to Life OS and try again.</p>");
    }
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var body = e.requestInfo().body || {};
    var connection = __fitConnection(e.app, e.auth.id, true);
    if (body.enabled !== undefined) connection.set("enabled", !!body.enabled);
    if (body.daily_sync_minutes !== undefined) {
        var minutes = Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __fitDefaultMinutes));
        connection.set("daily_sync_minutes", Math.floor(minutes));
    }
    e.app.save(connection);
    return e.json(200, __fitStatus(connection));
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var connection = __fitConnection(e.app, e.auth.id, false);
    if (!connection || !String(connection.get("refresh_token_enc") || "")) return e.json(409, { error: "not_connected" });
    try {
        var result = __fitRunSafe(e.app, connection);
        return e.json(200, { ok: true, sessions: result.sessions, imported: result.imported, sleep: result.sleep, activities: result.activities });
    } catch (_) {
        return e.json(502, { ok: false, error: "provider_sync_failed" });
    }
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var connection = __fitConnection(e.app, e.auth.id, false);
    if (connection) e.app.delete(connection);
    return e.json(200, { ok: true });
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_google_fit_sync", "*/15 * * * *", function() {
    var connections = [];
    try { connections = $app.findRecordsByFilter(__fitCollection, "enabled = true && provider = 'google_fit'", "updated", 500, 0); } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < connections.length; i++) {
        try {
            var connection = connections[i];
            var profile = __fitProfile($app, String(connection.get("user_id") || ""));
            var local = __fitLocalClock(profile, now);
            var dueMinutes = Number(connection.get("daily_sync_minutes") || __fitDefaultMinutes);
            var lastDay = String(connection.get("last_sync_local_day") || "");
            if (local.minutes < dueMinutes || lastDay === local.day) continue;
            __fitRunSafe($app, connection);
        } catch (_) {}
    }
});