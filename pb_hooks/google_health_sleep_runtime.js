// Server-owned Google Health sleep synchronization for PocketBase JSVM.
// Google Health reconciles sleep across cloud sources, including data uploaded
// from Health Connect. Existing Google Fit records remain history in PocketBase.

var __healthCollection = "sleep_sync_connections";
var __healthProvider = "google_health";
var __healthDefaultMinutes = 21 * 60;
var __healthCatchupMs = 15 * 60 * 1000;
var __healthLookbackMs = 30 * 86400000;
var __healthScope = "https://www.googleapis.com/auth/googlehealth.sleep.readonly";

function __healthEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __healthBaseUrl() {
    return __healthEnv("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __healthReturnUrl() {
    return __healthEnv("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __healthDate(value) {
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __healthForm(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __healthUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __healthTokenKey(app) {
    var key = __healthEnv("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var envName = String(app.encryptionEnv() || "").trim();
        var inherited = envName ? __healthEnv(envName) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("PocketBase encryption key is not configured");
}

function __healthConfig() {
    var clientId = __healthEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = __healthEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
    if (!clientId || !clientSecret) throw new Error("Google OAuth is not configured");
    return {
        clientId: clientId,
        clientSecret: clientSecret,
        // Keep the already-registered redirect URI. The endpoint now completes
        // Google Health authorization rather than legacy Google Fit authorization.
        redirectUri: __healthBaseUrl() + "/api/sleep-sync/google-fit/callback"
    };
}

function __healthConnection(app, userId, createIfMissing) {
    try {
        return app.findFirstRecordByFilter(
            __healthCollection,
            "user_id = {:uid} && provider = {:provider}",
            { uid: userId, provider: __healthProvider }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var record = new Record(app.findCollectionByNameOrId(__healthCollection));
    record.set("user_id", userId);
    record.set("provider", __healthProvider);
    record.set("enabled", false);
    record.set("daily_sync_minutes", __healthDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __healthNeedsReconnect(errorText) {
    var raw = String(errorText || "").toLowerCase();
    return raw.indexOf("invalid_grant") >= 0 ||
        raw.indexOf("insufficient authentication scopes") >= 0 ||
        raw.indexOf("insufficient permission") >= 0 ||
        raw.indexOf("disallowed oauth scope") >= 0 ||
        raw.indexOf("disallowed_oauth_scopes") >= 0 ||
        raw.indexOf("authorization_required") >= 0;
}

function __healthStatus(connection) {
    if (!connection) {
        return {
            configured: false,
            provider: __healthProvider,
            enabled: false,
            daily_sync_minutes: __healthDefaultMinutes,
            status: "disconnected",
            last_sync_at: null,
            last_session_count: 0,
            last_imported_count: 0,
            last_sleep_count: 0,
            last_activity_count: 0,
            history_complete: false,
            last_error: null
        };
    }
    var error = String(connection.get("last_error") || "");
    var hasRefresh = String(connection.get("refresh_token_enc") || "").length > 0;
    var reconnect = __healthNeedsReconnect(error);
    var configured = hasRefresh && !reconnect;
    return {
        configured: configured,
        provider: __healthProvider,
        enabled: configured && !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __healthDefaultMinutes),
        status: configured ? (connection.get("status") || "connected") : "disconnected",
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_sleep_count: Number(connection.get("last_sleep_count") || 0),
        last_activity_count: 0,
        history_complete: String(connection.get("last_sync_at") || "").length > 0,
        last_error: reconnect ? "Google Health authorization is required" : (error || null)
    };
}

function __healthExchangeCode(code) {
    var cfg = __healthConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __healthForm({
            code: code,
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            redirect_uri: cfg.redirectUri,
            grant_type: "authorization_code"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google token exchange failed: HTTP " + res.statusCode);
    }
    return res.json;
}

function __healthAccessToken(app, connection) {
    var key = __healthTokenKey(app);
    var current = String(connection.get("access_token_enc") || "");
    var expires = __healthDate(connection.get("access_token_expires_at"));
    if (current && expires && expires.getTime() > Date.now() + 120000) {
        return String($security.decrypt(current, key));
    }

    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("Google Health refresh token is missing");
    var cfg = __healthConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __healthForm({
            refresh_token: String($security.decrypt(refreshEnc, key)),
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            grant_type: "refresh_token"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
        throw new Error("Google Health token refresh failed: HTTP " + res.statusCode);
    }
    var ttl = Number(res.json.expires_in || 3600);
    connection.set("access_token_enc", $security.encrypt(String(res.json.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + ttl * 1000).toISOString());
    app.save(connection);
    return String(res.json.access_token);
}

function __healthNormalize(point) {
    point = point || {};
    var sleep = point.sleep || {};
    var interval = sleep.interval || {};
    var start = __healthDate(interval.startTime || interval.start_time);
    var end = __healthDate(interval.endTime || interval.end_time);
    if (!start || !end || end.getTime() <= start.getTime() || end.getTime() > Date.now()) return null;
    var duration = end.getTime() - start.getTime();
    if (duration < 20 * 60000 || duration > 36 * 3600000) return null;

    var metadata = sleep.metadata || {};
    var name = String(point.name || metadata.externalId || metadata.external_id || "").trim();
    var updated = __healthDate(sleep.updateTime || sleep.update_time) || end;
    var source = point.dataSource || point.data_source || {};
    return {
        externalId: name ? "google_health|" + name : "google_health|" + start.toISOString() + "|" + end.toISOString(),
        start: start,
        end: end,
        modifiedAt: updated,
        platform: String(source.platform || "").trim()
    };
}

function __healthFetchSleep(accessToken, start, end) {
    var rows = [];
    var pageToken = "";
    var page = 0;
    do {
        var query = {
            pageSize: 100,
            dataSourceFamily: "users/me/dataSourceFamilies/all-sources",
            filter: 'sleep.interval.end_time >= "' + start.toISOString() + '" AND sleep.interval.end_time < "' + end.toISOString() + '"'
        };
        if (pageToken) query.pageToken = pageToken;
        var res = $http.send({
            url: "https://health.googleapis.com/v4/" + "users/me/dataTypes/sleep/dataPoints:reconcile?" + __healthForm(query),
            method: "GET",
            headers: {
                "authorization": "Bearer " + accessToken,
                "accept": "application/json"
            },
            timeout: 60
        });
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
            var detail = "";
            try { detail = JSON.stringify(res.json || {}); } catch (_) {}
            throw new Error("Google Health sleep request failed: HTTP " + res.statusCode + (detail ? " " + detail : ""));
        }
        var points = res.json.dataPoints || res.json.data_points || [];
        for (var i = 0; i < points.length; i++) {
            var normalized = __healthNormalize(points[i]);
            if (normalized) rows.push(normalized);
        }
        pageToken = String(res.json.nextPageToken || res.json.next_page_token || "").trim();
        page++;
        if (page > 1000) throw new Error("Google Health returned too many sleep pages");
    } while (pageToken);
    rows.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return rows;
}

function __healthProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __healthCategory(app, userId, language) {
    try {
        return app.findFirstRecordByFilter(
            "categories",
            "user_id = {:uid} && (name = 'Sleep' || name = 'Сон')",
            { uid: userId }
        );
    } catch (_) {}
    var category = new Record(app.findCollectionByNameOrId("categories"));
    var ru = String(language || "").toLowerCase() === "ru";
    var slug = "sleep_" + $security.randomStringWithAlphabet(6, "0123456789abcdefghijklmnopqrstuvwxyz");
    category.set("user_id", userId);
    category.set("category_id", slug);
    category.set("normalized_id", slug);
    category.set("name", ru ? "Сон" : "Sleep");
    category.set("order", 0);
    category.set("color_value", 0);
    category.set("icon_code_point", 0);
    category.set("is_archived", false);
    app.save(category);
    return category;
}

function __healthOverlapRatio(aStart, aEnd, bStart, bEnd) {
    var overlap = Math.max(0, Math.min(aEnd.getTime(), bEnd.getTime()) - Math.max(aStart.getTime(), bStart.getTime()));
    var shorter = Math.min(aEnd.getTime() - aStart.getTime(), bEnd.getTime() - bStart.getTime());
    return shorter > 0 ? overlap / shorter : 0;
}

function __healthFindExisting(app, userId, session) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_health' && external_id = {:id}",
            { uid: userId, id: session.externalId }
        );
    } catch (_) {}
    try {
        var rows = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && start_time < {:end} && end_time > {:start}",
            "",
            30,
            0,
            { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
        );
        var best = null;
        var bestRatio = 0;
        for (var i = 0; i < rows.length; i++) {
            var start = __healthDate(rows[i].get("start_time"));
            var end = __healthDate(rows[i].get("end_time"));
            if (!start || !end || end.getTime() <= start.getTime()) continue;
            var ratio = __healthOverlapRatio(session.start, session.end, start, end);
            if (ratio >= 0.80 && ratio > bestRatio) {
                best = rows[i];
                bestRatio = ratio;
            }
        }
        if (best) return best;
    } catch (_) {}
    return null;
}

function __healthUpsert(app, userId, profile, category, session) {
    var existing = __healthFindExisting(app, userId, session);
    var record = existing || new Record(app.findCollectionByNameOrId("records"));
    var ru = String(profile.get("primary_language") || "").toLowerCase() === "ru";
    record.set("user_id", userId);
    record.set("record_id", existing ? record.get("record_id") : __healthUuid());
    record.set("status", "completed");
    record.set("title", ru ? "Сон" : "Sleep");
    record.set("start_time", session.start.toISOString());
    record.set("end_time", session.end.toISOString());
    record.set("category_id", category.id);
    record.set("category_link", category.id);
    record.set("type", "record");
    record.set("checklist", "[]");
    record.set("external_source", "google_health");
    record.set("external_id", session.externalId);
    record.set("external_kind", "sleep");
    record.set("external_updated_at", session.modifiedAt.toISOString());
    record.set("sleep_source", "google_health");
    record.set("sleep_external_id", session.externalId);
    app.save(record);
    return existing ? 0 : 1;
}

function __healthLocalDay(profile, now) {
    var offset = Number(profile.get("timezone_offset") || 0);
    var local = new Date(now.getTime() + offset * 3600000);
    return local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0");
}

function __healthDisableLegacyFit(app, userId) {
    try {
        var legacy = app.findFirstRecordByFilter(
            __healthCollection,
            "user_id = {:uid} && provider = 'google_fit'",
            { uid: userId }
        );
        legacy.set("enabled", false);
        app.save(legacy);
    } catch (_) {}
}

function __healthRunConnection(app, connection) {
    var userId = String(connection.get("user_id") || "");
    if (!userId) throw new Error("Google Health connection has no user");
    var profile = __healthProfile(app, userId);
    var now = new Date();
    var accessToken = __healthAccessToken(app, connection);
    var sessions = __healthFetchSleep(accessToken, new Date(now.getTime() - __healthLookbackMs), now);
    var category = __healthCategory(app, userId, profile.get("primary_language"));
    var imported = 0;
    for (var i = 0; i < sessions.length; i++) imported += __healthUpsert(app, userId, profile, category, sessions[i]);

    connection.set("status", "connected");
    connection.set("last_error", "");
    connection.set("last_sync_at", now.toISOString());
    connection.set("last_sync_local_day", __healthLocalDay(profile, now));
    connection.set("last_session_count", sessions.length);
    connection.set("last_imported_count", imported);
    connection.set("last_sleep_count", sessions.length);
    connection.set("last_activity_count", 0);
    app.save(connection);
    __healthDisableLegacyFit(app, userId);
    try { app.logger().info("google health sleep sync complete", "sessions", sessions.length, "imported", imported); } catch (_) {}
    return { sessions: sessions.length, imported: imported };
}

function __healthRunSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __healthRunConnection(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        connection.set("last_sync_at", new Date().toISOString());
        app.save(connection);
        try { app.logger().error("google health sleep sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

function status(e) {
    return e.json(200, __healthStatus(__healthConnection(e.app, e.auth.id, false)));
}

function connect(e) {
    var cfg = __healthConfig();
    __healthTokenKey(e.app);
    var connection = __healthConnection(e.app, e.auth.id, true);
    var existingState = String(connection.get("oauth_state") || "");
    var existingExpires = __healthDate(connection.get("oauth_state_expires_at"));
    var state = "";
    if (existingState && existingState.indexOf(connection.id + ".") === 0 && existingExpires && existingExpires.getTime() > Date.now() + 60000) {
        state = existingState;
    } else {
        state = connection.id + "." + $security.randomStringWithAlphabet(40, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
        connection.set("oauth_state", state);
        connection.set("oauth_state_expires_at", new Date(Date.now() + 20 * 60000).toISOString());
    }
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);

    var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __healthForm({
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        response_type: "code",
        scope: __healthScope,
        access_type: "offline",
        prompt: "consent",
        state: state
    });
    return e.json(200, { authorization_url: url });
}

function callback(e) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    var code = String(query.code || "");
    if (String(query.error || "")) return e.html(400, "<h1>Google Health connection cancelled</h1>");
    if (!state || !code) return e.html(400, "<h1>Google Health connection failed</h1><p>Missing OAuth response.</p>");

    var connection = null;
    var parts = state.split(".");
    if (parts.length === 2 && parts[0]) {
        try { connection = e.app.findRecordById(__healthCollection, parts[0]); } catch (_) {}
        if (connection && String(connection.get("oauth_state") || "") !== state) connection = null;
    }
    if (!connection) {
        try { connection = e.app.findFirstRecordByData(__healthCollection, "oauth_state", state); } catch (_) {}
    }
    var expires = connection ? __healthDate(connection.get("oauth_state_expires_at")) : null;
    if (!connection || !expires || expires.getTime() < Date.now()) {
        return e.html(400, "<h1>Google Health connection failed</h1><p>Invalid or expired authorization.</p>");
    }

    try {
        var token = __healthExchangeCode(code);
        var key = __healthTokenKey(e.app);
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
        __healthRunSafe(e.app, connection);
        var returnUrl = __healthReturnUrl();
        return e.html(200,
            "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='1;url=" + returnUrl + "'>" +
            "<title>LIFE OS</title><h1>Google Health connected</h1><p>Sleep is being synchronized to LIFE OS.</p>"
        );
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Google Health connection failed</h1><p>Return to LIFE OS and try again.</p>");
    }
}

function settings(e) {
    var body = e.requestInfo().body || {};
    var connection = __healthConnection(e.app, e.auth.id, true);
    if (body.enabled !== undefined) connection.set("enabled", !!body.enabled);
    if (body.daily_sync_minutes !== undefined) {
        var minutes = Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __healthDefaultMinutes));
        connection.set("daily_sync_minutes", Math.floor(minutes));
    }
    e.app.save(connection);
    return e.json(200, __healthStatus(connection));
}

function run(e) {
    var connection = __healthConnection(e.app, e.auth.id, false);
    if (!connection || !String(connection.get("refresh_token_enc") || "")) return e.json(409, { error: "not_connected" });
    try {
        var result = __healthRunSafe(e.app, connection);
        return e.json(200, { ok: true, sessions: result.sessions, imported: result.imported });
    } catch (err) {
        return e.json(502, { ok: false, error: String(err) });
    }
}

function remove(e) {
    var connection = __healthConnection(e.app, e.auth.id, false);
    if (connection) e.app.delete(connection);
    return e.json(200, { ok: true });
}

function cron(app) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            __healthCollection,
            "enabled = true && provider = 'google_health'",
            "",
            500,
            0
        );
    } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < rows.length; i++) {
        try {
            if (__healthNeedsReconnect(rows[i].get("last_error"))) continue;
            var last = __healthDate(rows[i].get("last_sync_at"));
            if (last && now.getTime() - last.getTime() < __healthCatchupMs) continue;
            __healthRunSafe(app, rows[i]);
        } catch (_) {}
    }
}

module.exports = {
    status: status,
    connect: connect,
    callback: callback,
    settings: settings,
    run: run,
    remove: remove,
    cron: cron
};
