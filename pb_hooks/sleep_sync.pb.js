/// <reference path="../pb_data/types.d.ts" />
// Server-owned sleep synchronization.
// Google Fit is the first cloud adapter. The cron runs without any Life OS client.

var __sleepSyncCollection = "sleep_sync_connections";
var __sleepSyncProvider = "google_fit";
var __sleepSyncDefaultMinutes = 21 * 60;
var __sleepSyncLookbackDays = 14;
var __sleepSyncGoogleScope = "https://www.googleapis.com/auth/fitness.sleep.read";

function __sleepSyncEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __sleepSyncPublicBaseUrl() {
    return __sleepSyncEnv("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __sleepSyncReturnUrl() {
    return __sleepSyncEnv("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __sleepSyncTokenKey(app) {
    var key = __sleepSyncEnv("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __sleepSyncEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("PocketBase encryption key is not configured");
}

function __sleepSyncGoogleConfig(app) {
    var clientId = __sleepSyncEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = __sleepSyncEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
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
        redirectUri: __sleepSyncPublicBaseUrl() + "/api/sleep-sync/google-fit/callback",
    };
}

function __sleepSyncFormEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __sleepSyncDate(value) {
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __sleepSyncUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __sleepSyncGetConnection(app, userId, createIfMissing) {
    try {
        return app.findFirstRecordByFilter(__sleepSyncCollection, "user_id = {:uid} && provider = {:provider}", {
            uid: userId,
            provider: __sleepSyncProvider,
        });
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var collection = app.findCollectionByNameOrId(__sleepSyncCollection);
    var record = new Record(collection);
    record.set("user_id", userId);
    record.set("provider", __sleepSyncProvider);
    record.set("enabled", false);
    record.set("daily_sync_minutes", __sleepSyncDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __sleepSyncStatusPayload(connection) {
    if (!connection) {
        return {
            configured: false,
            provider: __sleepSyncProvider,
            enabled: false,
            daily_sync_minutes: __sleepSyncDefaultMinutes,
            status: "disconnected",
            last_sync_at: null,
            last_session_count: 0,
            last_imported_count: 0,
            last_error: null,
        };
    }
    return {
        configured: String(connection.get("refresh_token_enc") || "").length > 0,
        provider: connection.get("provider") || __sleepSyncProvider,
        enabled: !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __sleepSyncDefaultMinutes),
        status: connection.get("status") || "disconnected",
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_error: connection.get("last_error") || null,
    };
}

function __sleepSyncExchangeCode(app, code) {
    var cfg = __sleepSyncGoogleConfig(app);
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __sleepSyncFormEncode({
            code: code,
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            redirect_uri: cfg.redirectUri,
            grant_type: "authorization_code",
        }),
        timeout: 30,
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google token exchange failed: HTTP " + res.statusCode);
    }
    return res.json;
}

function __sleepSyncRefreshAccess(app, connection) {
    var key = __sleepSyncTokenKey(app);
    var currentEnc = String(connection.get("access_token_enc") || "");
    var expiresAt = __sleepSyncDate(connection.get("access_token_expires_at"));
    if (currentEnc && expiresAt && expiresAt.getTime() > Date.now() + 120000) {
        return String($security.decrypt(currentEnc, key));
    }
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("Google Fit refresh token is missing");
    var cfg = __sleepSyncGoogleConfig(app);
    var refreshToken = String($security.decrypt(refreshEnc, key));
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __sleepSyncFormEncode({
            refresh_token: refreshToken,
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            grant_type: "refresh_token",
        }),
        timeout: 30,
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

function __sleepSyncGoogleSessions(accessToken, start, end) {
    var url = "https://www.googleapis.com/fitness/v1/users/me/sessions" +
        "?startTime=" + encodeURIComponent(start.toISOString()) +
        "&endTime=" + encodeURIComponent(end.toISOString()) +
        "&activityType=72";
    var res = $http.send({
        url: url,
        method: "GET",
        headers: {
            "authorization": "Bearer " + accessToken,
            "accept": "application/json",
        },
        timeout: 45,
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google Fit sleep request failed: HTTP " + res.statusCode);
    }
    var rows = res.json.session || [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i] || {};
        if (Number(row.activityType || 0) !== 72) continue;
        var startMillis = Number(row.startTimeMillis || 0);
        var endMillis = Number(row.endTimeMillis || 0);
        if (!isFinite(startMillis) || !isFinite(endMillis) || endMillis <= startMillis) continue;
        var startDate = new Date(startMillis);
        var endDate = new Date(endMillis);
        if (isNaN(startDate.getTime()) || isNaN(endDate.getTime()) || endDate.getTime() > Date.now()) continue;
        var application = row.application || {};
        var appIdentity = String(application.packageName || application.name || "unknown");
        var sessionId = String(row.id || "");
        var externalId = "google-fit|" + appIdentity + "|" +
            (sessionId || (startDate.toISOString() + "|" + endDate.toISOString()));
        out.push({
            externalId: externalId,
            start: startDate,
            end: endDate,
        });
    }
    out.sort(function(a, b) { return a.end.getTime() - b.end.getTime(); });
    return out;
}
function __sleepSyncProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __sleepSyncCategory(app, userId, language) {
    var existing = null;
    try {
        existing = app.findFirstRecordByFilter("categories", "user_id = {:uid} && (name = 'Sleep' || name = 'Сон')", { uid: userId });
    } catch (_) {}
    if (existing) return existing;

    var collection = app.findCollectionByNameOrId("categories");
    var category = new Record(collection);
    var name = String(language || "").toLowerCase() === "ru" ? "Сон" : "Sleep";
    var slug = "sleep_" + $security.randomStringWithAlphabet(6, "0123456789abcdefghijklmnopqrstuvwxyz");
    category.set("user_id", userId);
    category.set("category_id", slug);
    category.set("normalized_id", slug);
    category.set("name", name);
    category.set("order", 0);
    category.set("color_value", 0);
    category.set("icon_code_point", 0);
    category.set("is_archived", false);
    app.save(category);
    return category;
}

function __sleepSyncRecordDate(record, field) {
    return __sleepSyncDate(record.get(field));
}

function __sleepSyncOverlappingRecords(app, userId, start, end) {
    try {
        return app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && start_time < {:end} && (end_time = '' || end_time > {:start})",
            "start_time",
            500,
            0,
            { uid: userId, start: start.toISOString(), end: end.toISOString() }
        );
    } catch (_) {
        return [];
    }
}

function __sleepSyncFindExisting(app, userId, externalId, start, end) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && sleep_source = 'google_fit' && sleep_external_id = {:external}",
            { uid: userId, external: externalId }
        );
    } catch (_) {}

    var candidates = __sleepSyncOverlappingRecords(app, userId, new Date(start.getTime() - 3 * 3600000), new Date(end.getTime() + 3 * 3600000));
    var best = null;
    var bestScore = -Infinity;
    for (var i = 0; i < candidates.length; i++) {
        var title = String(candidates[i].get("title") || "").trim().toLowerCase();
        if (title !== "sleep" && title !== "сон") continue;
        var rowStart = __sleepSyncRecordDate(candidates[i], "start_time");
        var rowEnd = __sleepSyncRecordDate(candidates[i], "end_time");
        if (!rowStart || !rowEnd) continue;
        var overlap = Math.max(0, Math.min(rowEnd.getTime(), end.getTime()) - Math.max(rowStart.getTime(), start.getTime()));
        var drift = Math.abs(rowStart.getTime() - start.getTime()) + Math.abs(rowEnd.getTime() - end.getTime());
        var score = overlap * 10 - drift;
        if (score > bestScore) { bestScore = score; best = candidates[i]; }
    }
    return best;
}

function __sleepSyncApplyConflicts(app, userId, start, end, existingId) {
    var records = __sleepSyncOverlappingRecords(app, userId, start, end);
    for (var i = 0; i < records.length; i++) {
        var record = records[i];
        if (record.id === existingId) continue;
        var rowStart = __sleepSyncRecordDate(record, "start_time");
        if (!rowStart) continue;
        if (rowStart.getTime() < start.getTime()) {
            record.set("end_time", start.toISOString());
            record.set("status", "stopped");
            app.save(record);
        } else {
            app.delete(record);
        }
    }
}

function __sleepSyncImportSession(app, userId, profile, category, session) {
    var existing = __sleepSyncFindExisting(app, userId, session.externalId, session.start, session.end);
    __sleepSyncApplyConflicts(app, userId, session.start, session.end, existing ? existing.id : "");
    var record = existing || new Record(app.findCollectionByNameOrId("records"));
    var language = String(profile.get("primary_language") || "").toLowerCase();
    record.set("user_id", userId);
    record.set("record_id", existing ? record.get("record_id") : __sleepSyncUuid());
    record.set("status", "completed");
    record.set("title", language === "ru" ? "Сон" : "Sleep");
    record.set("start_time", session.start.toISOString());
    record.set("end_time", session.end.toISOString());
    record.set("category_id", category.id);
    record.set("category_link", category.id);
    record.set("type", "record");
    record.set("checklist", "[]");
    record.set("sleep_source", "google_fit");
    record.set("sleep_external_id", session.externalId);
    app.save(record);
    return existing ? 0 : 1;
}

function __sleepSyncLocalClock(profile, now) {
    var offsetHours = Number(profile.get("timezone_offset") || 0);
    var local = new Date(now.getTime() + offsetHours * 3600000);
    return {
        minutes: local.getUTCHours() * 60 + local.getUTCMinutes(),
        day: local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0"),
    };
}

function __sleepSyncRunConnection(app, connection) {
    var userId = String(connection.get("user_id") || "");
    if (!userId) throw new Error("Sleep sync connection has no user");
    var profile = __sleepSyncProfile(app, userId);
    var accessToken = __sleepSyncRefreshAccess(app, connection);
    var end = new Date();
    var start = new Date(end.getTime() - __sleepSyncLookbackDays * 86400000);
    var sessions = __sleepSyncGoogleSessions(accessToken, start, end);
    var category = __sleepSyncCategory(app, userId, profile.get("primary_language"));
    var imported = 0;
    for (var i = 0; i < sessions.length; i++) {
        imported += __sleepSyncImportSession(app, userId, profile, category, sessions[i]);
    }
    var local = __sleepSyncLocalClock(profile, end);
    connection.set("status", "connected");
    connection.set("last_sync_at", end.toISOString());
    connection.set("last_sync_local_day", local.day);
    connection.set("last_session_count", sessions.length);
    connection.set("last_imported_count", imported);
    connection.set("last_error", "");
    app.save(connection);
    return { sessions: sessions.length, imported: imported };
}

function __sleepSyncRunSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __sleepSyncRunConnection(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        connection.set("last_sync_at", new Date().toISOString());
        app.save(connection);
        try { app.logger().error("sleep sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var connection = __sleepSyncGetConnection(e.app, e.auth.id, false);
    return e.json(200, __sleepSyncStatusPayload(connection));
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var cfg = __sleepSyncGoogleConfig(e.app);
    __sleepSyncTokenKey(e.app);
    var connection = __sleepSyncGetConnection(e.app, e.auth.id, true);
    var state = $security.randomStringWithAlphabet(48, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    connection.set("oauth_state", state);
    connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);
    var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __sleepSyncFormEncode({
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        response_type: "code",
        scope: __sleepSyncGoogleScope,
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: "true",
        state: state,
    });
    return e.json(200, { authorization_url: url });
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    var code = String(query.code || "");
    var providerError = String(query.error || "");
    if (providerError) return e.html(400, "<h1>Sleep synchronization cancelled</h1><p>Google did not grant access.</p>");
    if (!state || !code) return e.html(400, "<h1>Sleep synchronization failed</h1><p>Missing OAuth response.</p>");
    var connection = null;
    try {
        connection = e.app.findFirstRecordByData(__sleepSyncCollection, "oauth_state", state);
    } catch (_) {}
    if (!connection) return e.html(400, "<h1>Sleep synchronization failed</h1><p>Invalid or expired state.</p>");
    var expires = __sleepSyncDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) return e.html(400, "<h1>Sleep synchronization failed</h1><p>Authorization expired.</p>");
    try {
        var token = __sleepSyncExchangeCode(e.app, code);
        var key = __sleepSyncTokenKey(e.app);
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
        try { __sleepSyncRunSafe(e.app, connection); } catch (_) {}
        var returnUrl = __sleepSyncReturnUrl();
        return e.html(200, "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'><title>Life OS</title><h1>Google Fit connected</h1><p>Sleep will now synchronize on the server every evening. You can return to Life OS.</p>");
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Sleep synchronization failed</h1><p>Return to Life OS and try again.</p>");
    }
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var body = e.requestInfo().body || {};
    var connection = __sleepSyncGetConnection(e.app, e.auth.id, true);
    if (body.enabled !== undefined) connection.set("enabled", !!body.enabled);
    if (body.daily_sync_minutes !== undefined) {
        var minutes = Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __sleepSyncDefaultMinutes));
        connection.set("daily_sync_minutes", Math.floor(minutes));
    }
    e.app.save(connection);
    return e.json(200, __sleepSyncStatusPayload(connection));
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var connection = __sleepSyncGetConnection(e.app, e.auth.id, false);
    if (!connection || !String(connection.get("refresh_token_enc") || "")) return e.json(409, { error: "not_connected" });
    try {
        var result = __sleepSyncRunSafe(e.app, connection);
        return e.json(200, { ok: true, sessions: result.sessions, imported: result.imported });
    } catch (err) {
        return e.json(502, { ok: false, error: "provider_sync_failed" });
    }
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var connection = __sleepSyncGetConnection(e.app, e.auth.id, false);
    if (connection) e.app.delete(connection);
    return e.json(200, { ok: true });
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_sleep_sync", "*/15 * * * *", function() {
    var connections = [];
    try {
        connections = $app.findRecordsByFilter(__sleepSyncCollection, "enabled = true && provider = 'google_fit'", "updated", 500, 0);
    } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < connections.length; i++) {
        var connection = connections[i];
        try {
            var userId = String(connection.get("user_id") || "");
            var profile = __sleepSyncProfile($app, userId);
            var local = __sleepSyncLocalClock(profile, now);
            var dueMinutes = Number(connection.get("daily_sync_minutes") || __sleepSyncDefaultMinutes);
            var lastDay = String(connection.get("last_sync_local_day") || "");
            if (local.minutes < dueMinutes || lastDay === local.day) continue;
            __sleepSyncRunSafe($app, connection);
        } catch (_) {}
    }
});
