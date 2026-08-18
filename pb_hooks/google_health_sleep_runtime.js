// Server-owned Google Health API sleep synchronization runtime for PocketBase JSVM.
// This is the canonical web/cloud ingestion path. It intentionally stores only
// the sleep interval (start -> end) in LIFE OS records; Google sleep stages are
// not persisted or exposed in the Timeline.

var __healthCollection = "sleep_sync_connections";
var __healthProviderStorage = "google_fit"; // keep existing connection/UI compatibility
var __healthDefaultMinutes = 21 * 60;
var __healthLookbackDays = 30;
var __healthCatchupIntervalMs = 30 * 60 * 1000;
var __healthScope = "https://www.googleapis.com/auth/googlehealth.sleep.readonly";

function __healthEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __healthPublicBaseUrl() {
    return __healthEnv("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __healthReturnUrl() {
    return __healthEnv("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __healthTokenKey(app) {
    var key = __healthEnv("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __healthEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("PocketBase encryption key is not configured");
}

function __healthGoogleConfig() {
    var clientId = __healthEnv("SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_ID") || __healthEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = __healthEnv("SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_SECRET") || __healthEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
    if (!clientId || !clientSecret) throw new Error("Google Health OAuth is not configured");
    return {
        clientId: clientId,
        clientSecret: clientSecret,
        redirectUri: __healthPublicBaseUrl() + "/api/sleep-sync/google-fit/callback"
    };
}

function __healthFormEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __healthDate(value) {
    var date = value instanceof Date ? value : new Date(value);
    return isNaN(date.getTime()) ? null : date;
}

function __healthUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __healthConnection(app, userId, createIfMissing) {
    try {
        return app.findFirstRecordByFilter(
            __healthCollection,
            "user_id = {:uid} && provider = {:provider}",
            { uid: userId, provider: __healthProviderStorage }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var record = new Record(app.findCollectionByNameOrId(__healthCollection));
    record.set("user_id", userId);
    record.set("provider", __healthProviderStorage);
    record.set("enabled", false);
    record.set("daily_sync_minutes", __healthDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __healthNeedsReconnect(errorText) {
    var raw = String(errorText || "").toLowerCase();
    if (!raw) return false;
    return raw.indexOf("google health authorization is required") >= 0 ||
        raw.indexOf("insufficient authentication scopes") >= 0 ||
        raw.indexOf("insufficientpermissions") >= 0 ||
        raw.indexOf("insufficient permission") >= 0 ||
        raw.indexOf("invalid_grant") >= 0;
}

function __healthStatus(connection) {
    if (!connection) {
        return {
            configured: false,
            provider: "google_health",
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
    var lastError = String(connection.get("last_error") || "");
    var hasRefresh = String(connection.get("refresh_token_enc") || "").length > 0;
    var reconnectRequired = __healthNeedsReconnect(lastError);
    var configured = hasRefresh && !reconnectRequired;
    return {
        configured: configured,
        provider: "google_health",
        enabled: configured && !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __healthDefaultMinutes),
        status: configured ? (connection.get("status") || "connected") : "disconnected",
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_sleep_count: Number(connection.get("last_sleep_count") || 0),
        last_activity_count: 0,
        history_complete: true,
        last_error: reconnectRequired ? "Google Health authorization is required" : (lastError || null)
    };
}

function __healthExchangeCode(app, code) {
    var cfg = __healthGoogleConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __healthFormEncode({
            code: code,
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            redirect_uri: cfg.redirectUri,
            grant_type: "authorization_code"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        throw new Error("Google Health token exchange failed: HTTP " + res.statusCode);
    }
    return res.json;
}

function __healthAccessToken(app, connection) {
    var key = __healthTokenKey(app);
    var currentEnc = String(connection.get("access_token_enc") || "");
    var expiresAt = __healthDate(connection.get("access_token_expires_at"));
    if (currentEnc && expiresAt && expiresAt.getTime() > Date.now() + 120000) {
        return String($security.decrypt(currentEnc, key));
    }

    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("Google Health refresh token is missing");
    var cfg = __healthGoogleConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __healthFormEncode({
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
    var expiresIn = Number(res.json.expires_in || 3600);
    connection.set("access_token_enc", $security.encrypt(String(res.json.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + expiresIn * 1000).toISOString());
    app.save(connection);
    return String(res.json.access_token);
}

function __healthNormalizeSleep(row) {
    row = row || {};
    var sleep = row.sleep || {};
    var interval = sleep.interval || {};
    var start = __healthDate(interval.startTime);
    var end = __healthDate(interval.endTime);
    if (!start || !end || end.getTime() <= start.getTime() || end.getTime() > Date.now()) return null;
    var name = String(row.name || "").trim();
    var externalId = name || ("google-health|" + start.toISOString() + "|" + end.toISOString());
    var modifiedAt = __healthDate(sleep.updateTime) || __healthDate(sleep.createTime) || end;
    return {
        externalId: externalId,
        start: start,
        end: end,
        modifiedAt: modifiedAt,
        application: "google_health"
    };
}

function __healthOverlapMs(aStart, aEnd, bStart, bEnd) {
    return Math.max(0, Math.min(aEnd.getTime(), bEnd.getTime()) - Math.max(aStart.getTime(), bStart.getTime()));
}

function __healthCleanSessions(sessions) {
    var valid = [];
    for (var i = 0; i < sessions.length; i++) {
        var s = sessions[i];
        if (s.end.getTime() - s.start.getTime() >= 20 * 60 * 1000) valid.push(s);
    }
    valid.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    var out = [];
    for (var j = 0; j < valid.length; j++) {
        var candidate = valid[j];
        var duplicate = -1;
        for (var k = 0; k < out.length; k++) {
            var overlap = __healthOverlapMs(candidate.start, candidate.end, out[k].start, out[k].end);
            var shorter = Math.min(
                candidate.end.getTime() - candidate.start.getTime(),
                out[k].end.getTime() - out[k].start.getTime()
            );
            if (shorter > 0 && overlap / shorter >= 0.80) { duplicate = k; break; }
        }
        if (duplicate < 0) out.push(candidate);
        else if ((candidate.end.getTime() - candidate.start.getTime()) > (out[duplicate].end.getTime() - out[duplicate].start.getTime())) out[duplicate] = candidate;
    }
    out.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return out;
}

function __healthFetchSleep(accessToken, start, end) {
    var rows = [];
    var pageToken = "";
    var page = 0;
    var filter = 'sleep.interval.end_time >= "' + start.toISOString() + '" AND sleep.interval.end_time < "' + end.toISOString() + '"';
    do {
        var params = {
            dataSourceFamily: "users/me/dataSourceFamilies/all-sources",
            pageSize: 25,
            filter: filter
        };
        if (pageToken) params.pageToken = pageToken;
        var res = $http.send({
            url: "https://health.googleapis.com/v4/users/me/dataTypes/sleep/dataPoints:reconcile?" + __healthFormEncode(params),
            method: "GET",
            headers: {
                "authorization": "Bearer " + accessToken,
                "accept": "application/json"
            },
            timeout: 60
        });
        if (res.statusCode === 401 || res.statusCode === 403) {
            var detail = "";
            try { detail = JSON.stringify(res.json || {}); } catch (_) {}
            if (detail.toLowerCase().indexOf("service_disabled") >= 0 || detail.toLowerCase().indexOf("accessnotconfigured") >= 0) {
                throw new Error("Google Health API is not enabled in the Google Cloud project");
            }
            throw new Error("Google Health authorization is required");
        }
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
            throw new Error("Google Health sleep request failed: HTTP " + res.statusCode);
        }
        var pageRows = res.json.dataPoints || [];
        for (var r = 0; r < pageRows.length; r++) rows.push(pageRows[r]);
        pageToken = String(res.json.nextPageToken || "").trim();
        page++;
        if (page > 200) throw new Error("Google Health returned too many sleep pages");
    } while (pageToken);

    var sessions = [];
    for (var i = 0; i < rows.length; i++) {
        var session = __healthNormalizeSleep(rows[i]);
        if (session) sessions.push(session);
    }
    return __healthCleanSessions(sessions);
}

function __healthProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __healthSleepCategory(app, userId, language) {
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

function __healthFindExisting(app, userId, session) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_health' && external_id = {:external}",
            { uid: userId, external: session.externalId }
        );
    } catch (_) {}
    try {
        var candidates = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && (title = 'Sleep' || title = 'Сон' || external_kind = 'sleep') && start_time < {:end} && end_time > {:start}",
            "",
            20,
            0,
            { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
        );
        var duration = session.end.getTime() - session.start.getTime();
        var best = null;
        var bestRatio = 0;
        for (var i = 0; i < candidates.length; i++) {
            var rs = __healthDate(candidates[i].get("start_time"));
            var re = __healthDate(candidates[i].get("end_time"));
            if (!rs || !re || re.getTime() <= rs.getTime()) continue;
            var overlap = __healthOverlapMs(session.start, session.end, rs, re);
            var shorter = Math.min(duration, re.getTime() - rs.getTime());
            var ratio = shorter > 0 ? overlap / shorter : 0;
            if (ratio >= 0.80 && ratio > bestRatio) { best = candidates[i]; bestRatio = ratio; }
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

function __healthLocalClock(profile, now) {
    var offsetHours = Number(profile.get("timezone_offset") || 0);
    var local = new Date(now.getTime() + offsetHours * 3600000);
    return {
        minutes: local.getUTCHours() * 60 + local.getUTCMinutes(),
        day: local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0")
    };
}

function __healthRunConnection(app, connection) {
    var userId = String(connection.get("user_id") || "");
    if (!userId) throw new Error("Google Health connection has no user");
    var profile = __healthProfile(app, userId);
    var accessToken = __healthAccessToken(app, connection);
    var now = new Date();
    var start = new Date(now.getTime() - __healthLookbackDays * 86400000);
    var sessions = __healthFetchSleep(accessToken, start, now);
    var category = __healthSleepCategory(app, userId, profile.get("primary_language"));
    var imported = 0;
    for (var i = 0; i < sessions.length; i++) imported += __healthUpsert(app, userId, profile, category, sessions[i]);

    var local = __healthLocalClock(profile, now);
    connection.set("status", "connected");
    connection.set("last_sync_at", now.toISOString());
    connection.set("last_sync_local_day", local.day);
    connection.set("last_session_count", sessions.length);
    connection.set("last_imported_count", imported);
    connection.set("last_sleep_count", sessions.length);
    connection.set("last_activity_count", 0);
    connection.set("last_error", "");
    app.save(connection);
    try { app.logger().info("google health sleep sync complete", "sessions", sessions.length, "imported", imported); } catch (_) {}
    return { sessions: sessions.length, imported: imported, sleep: sessions.length };
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
    var cfg = __healthGoogleConfig();
    __healthTokenKey(e.app);
    var connection = __healthConnection(e.app, e.auth.id, true);
    var state = $security.randomStringWithAlphabet(48, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    connection.set("oauth_state", state);
    connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);

    var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __healthFormEncode({
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        response_type: "code",
        scope: __healthScope,
        access_type: "offline",
        prompt: "consent",
        include_granted_scopes: "true",
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
    try { connection = e.app.findFirstRecordByData(__healthCollection, "oauth_state", state); } catch (_) {}
    if (!connection) return e.html(400, "<h1>Google Health connection failed</h1><p>Invalid or expired state.</p>");
    var expires = __healthDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) return e.html(400, "<h1>Google Health connection failed</h1><p>Authorization expired.</p>");

    try {
        var token = __healthExchangeCode(e.app, code);
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

        try { __healthRunSafe(e.app, connection); } catch (_) {}
        var returnUrl = __healthReturnUrl();
        return e.html(200,
            "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'>" +
            "<title>Life OS</title><h1>Google Health connected</h1><p>Sleep is being synchronized to Life OS.</p>"
        );
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Google Health connection failed</h1><p>Return to Life OS and try again.</p>");
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
        return e.json(200, { ok: true, sessions: result.sessions, imported: result.imported, sleep: result.sleep });
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
    var connections = [];
    try {
        connections = app.findRecordsByFilter(
            __healthCollection,
            "enabled = true && provider = 'google_fit'",
            "",
            500,
            0
        );
    } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < connections.length; i++) {
        try {
            var connection = connections[i];
            if (__healthNeedsReconnect(connection.get("last_error"))) continue;
            var profile = __healthProfile(app, String(connection.get("user_id") || ""));
            var local = __healthLocalClock(profile, now);
            var dueMinutes = Number(connection.get("daily_sync_minutes") || __healthDefaultMinutes);
            var lastDay = String(connection.get("last_sync_local_day") || "");
            var lastSync = __healthDate(connection.get("last_sync_at"));
            var stale = !lastSync || now.getTime() - lastSync.getTime() >= __healthCatchupIntervalMs;
            var dailyDue = local.minutes >= dueMinutes && lastDay !== local.day;
            if (!stale && !dailyDue) continue;
            __healthRunSafe(app, connection);
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
