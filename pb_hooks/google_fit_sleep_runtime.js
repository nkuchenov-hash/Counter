// Server-owned Google Fit sleep synchronization runtime for PocketBase JSVM.
// Shared logic lives in a CommonJS module because PocketBase route/cron handlers
// execute in isolated JS contexts.

var __fitRecovery = require(__hooks + "/google_fit_sleep_recovery.js");
var __fitCollection = "sleep_sync_connections";
var __fitProviderStorage = "google_fit";
var __fitDefaultMinutes = 21 * 60;
var __fitCorrectionLookbackDays = 30;
var __fitCatchupIntervalMs = 30 * 60 * 1000;
var __fitScope = "https://www.googleapis.com/auth/fitness.sleep.read";
var __fitHistoryStart = new Date(Date.UTC(2000, 0, 1));
var __fitSegmentHistoryStart = new Date(Date.UTC(2014, 9, 1));

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

function __fitGoogleConfig() {
    var clientId = __fitEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID") || __fitEnv("SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_ID");
    var clientSecret = __fitEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET") || __fitEnv("SLEEP_SYNC_GOOGLE_HEALTH_CLIENT_SECRET");
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
        return app.findFirstRecordByFilter(
            __fitCollection,
            "user_id = {:uid} && provider = {:provider}",
            { uid: userId, provider: __fitProviderStorage }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var record = new Record(app.findCollectionByNameOrId(__fitCollection));
    record.set("user_id", userId);
    record.set("provider", __fitProviderStorage);
    record.set("enabled", false);
    record.set("daily_sync_minutes", __fitDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __fitNeedsReconnect(errorText) {
    var raw = String(errorText || "").toLowerCase();
    if (!raw) return false;
    return raw.indexOf("account_not_linked") >= 0 ||
        raw.indexOf("google health authorization is required") >= 0 ||
        raw.indexOf("google health sleep request") >= 0 ||
        raw.indexOf("insufficient authentication scopes") >= 0 ||
        raw.indexOf("insufficientpermissions") >= 0 ||
        raw.indexOf("insufficient permission") >= 0 ||
        raw.indexOf("invalid_grant") >= 0;
}

function __fitStatus(connection) {
    if (!connection) {
        return {
            configured: false,
            provider: "google_fit",
            enabled: false,
            daily_sync_minutes: __fitDefaultMinutes,
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
    var reconnectRequired = __fitNeedsReconnect(lastError);
    var configured = hasRefresh && !reconnectRequired;
    return {
        configured: configured,
        provider: "google_fit",
        enabled: configured && !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __fitDefaultMinutes),
        status: configured ? (connection.get("status") || "connected") : "disconnected",
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_sleep_count: Number(connection.get("last_sleep_count") || 0),
        last_activity_count: 0,
        history_complete: String(connection.get("last_full_sync_at") || "").length > 0 && !!connection.get("segment_backfill_complete"),
        last_error: reconnectRequired ? "Google Fit authorization is required" : (lastError || null)
    };
}

function __fitExchangeCode(app, code) {
    var cfg = __fitGoogleConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __fitFormEncode({
            code: code,
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            redirect_uri: cfg.redirectUri,
            grant_type: "authorization_code"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        var detail = "";
        try { detail = JSON.stringify(res.json || {}); } catch (_) {}
        throw new Error("Google Fit token exchange failed: HTTP " + res.statusCode + (detail ? " " + detail : ""));
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
    var cfg = __fitGoogleConfig();
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __fitFormEncode({
            refresh_token: String($security.decrypt(refreshEnc, key)),
            client_id: cfg.clientId,
            client_secret: cfg.clientSecret,
            grant_type: "refresh_token"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
        var detail = "";
        try { detail = JSON.stringify(res.json || {}); } catch (_) {}
        throw new Error("Google Fit token refresh failed: HTTP " + res.statusCode + (detail ? " " + detail : ""));
    }
    var expiresIn = Number(res.json.expires_in || 3600);
    connection.set("access_token_enc", $security.encrypt(String(res.json.access_token), key));
    connection.set("access_token_expires_at", new Date(Date.now() + expiresIn * 1000).toISOString());
    app.save(connection);
    return String(res.json.access_token);
}

function __fitSessionsUrl(start, end, pageToken) {
    var params = {
        startTime: start.toISOString(),
        endTime: end.toISOString(),
        activityType: "72"
    };
    if (pageToken) params.pageToken = pageToken;
    return "https://www.googleapis.com/fitness/v1/users/me/sessions?" + __fitFormEncode(params);
}

function __fitNormalizeSleep(row) {
    row = row || {};
    var startMs = Number(row.startTimeMillis || 0);
    var endMs = Number(row.endTimeMillis || 0);
    if (!isFinite(startMs) || !isFinite(endMs) || startMs <= 0 || endMs <= startMs) return null;
    var start = new Date(startMs);
    var end = new Date(endMs);
    if (end.getTime() > Date.now()) return null;

    var application = row.application || {};
    var appId = String(application.packageName || application.name || "google_fit").trim() || "google_fit";
    var sessionId = String(row.id || "").trim();
    var externalId = sessionId
        ? appId + "|" + sessionId
        : appId + "|" + start.toISOString() + "|" + end.toISOString();
    var modifiedMs = Number(row.modifiedTimeMillis || 0);
    var modifiedAt = isFinite(modifiedMs) && modifiedMs > 0 ? new Date(modifiedMs) : end;

    return {
        externalId: externalId,
        start: start,
        end: end,
        modifiedAt: modifiedAt,
        application: appId
    };
}

function __fitFetchSleep(accessToken, start, end) {
    var rows = [];
    var pageToken = "";
    var page = 0;
    do {
        var res = $http.send({
            url: __fitSessionsUrl(start, end, pageToken),
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
            throw new Error("Google Fit sleep request failed: HTTP " + res.statusCode + (detail ? " " + detail : ""));
        }
        var pageRows = res.json.session || [];
        for (var r = 0; r < pageRows.length; r++) rows.push(pageRows[r]);
        pageToken = String(res.json.nextPageToken || "").trim();
        page++;
        if (page > 1000) throw new Error("Google Fit returned too many sleep session pages");
    } while (pageToken);

    var byId = {};
    for (var i = 0; i < rows.length; i++) {
        var session = __fitNormalizeSleep(rows[i]);
        if (session) byId[session.externalId] = session;
    }
    var out = [];
    for (var id in byId) {
        if (Object.prototype.hasOwnProperty.call(byId, id)) out.push(byId[id]);
    }
    out.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return __fitRecovery.cleanSessions(out);
}

function __fitProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __fitSleepCategory(app, userId, language) {
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

function __fitOverlapMs(aStart, aEnd, bStart, bEnd) {
    return Math.max(0, Math.min(aEnd.getTime(), bEnd.getTime()) - Math.max(aStart.getTime(), bStart.getTime()));
}

function __fitFindExisting(app, userId, session) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_fit' && external_id = {:external}",
            { uid: userId, external: session.externalId }
        );
    } catch (_) {}
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && sleep_source = 'google_fit' && sleep_external_id = {:external}",
            { uid: userId, external: session.externalId }
        );
    } catch (_) {}

    // Provider-owned overlap fallback lets segment-derived episodes repair truncated
    // or duplicated Google Fit sessions instead of creating another record.
    try {
        var candidates = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_fit' && external_kind = 'sleep' && start_time < {:end} && end_time > {:start}",
            "",
            20,
            0,
            { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
        );
        var sessionDuration = session.end.getTime() - session.start.getTime();
        var best = null;
        var bestRatio = 0;
        for (var i = 0; i < candidates.length; i++) {
            var rs = __fitDate(candidates[i].get("start_time"));
            var re = __fitDate(candidates[i].get("end_time"));
            if (!rs || !re || re.getTime() <= rs.getTime()) continue;
            var overlap = __fitOverlapMs(session.start, session.end, rs, re);
            var shorter = Math.min(sessionDuration, re.getTime() - rs.getTime());
            var ratio = shorter > 0 ? overlap / shorter : 0;
            if (ratio >= 0.80 && ratio > bestRatio) {
                best = candidates[i];
                bestRatio = ratio;
            }
        }
        if (best) return best;
    } catch (_) {}

    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_health' && start_time = {:start} && end_time = {:end}",
            { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
        );
    } catch (_) {}

    // Canonical fallback across ingestion adapters.
    try {
        var allSleep = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && start_time < {:end} && end_time > {:start}",
            "",
            20,
            0,
            { uid: userId, start: session.start.toISOString(), end: session.end.toISOString() }
        );
        var bestAny = null;
        var bestAnyRatio = 0;
        var sessionDurationAny = session.end.getTime() - session.start.getTime();
        for (var a = 0; a < allSleep.length; a++) {
            var as = __fitDate(allSleep[a].get("start_time"));
            var ae = __fitDate(allSleep[a].get("end_time"));
            if (!as || !ae || ae.getTime() <= as.getTime()) continue;
            var anyOverlap = __fitOverlapMs(session.start, session.end, as, ae);
            var anyShorter = Math.min(sessionDurationAny, ae.getTime() - as.getTime());
            var anyRatio = anyShorter > 0 ? anyOverlap / anyShorter : 0;
            if (anyRatio >= 0.80 && anyRatio > bestAnyRatio) {
                bestAny = allSleep[a];
                bestAnyRatio = anyRatio;
            }
        }
        if (bestAny) return bestAny;
    } catch (_) {}
    return null;
}

function __fitUpsert(app, userId, profile, category, session) {
    var existing = __fitFindExisting(app, userId, session);
    var record = existing || new Record(app.findCollectionByNameOrId("records"));
    var ru = String(profile.get("primary_language") || "").toLowerCase() === "ru";
    record.set("user_id", userId);
    record.set("record_id", existing ? record.get("record_id") : __fitUuid());
    record.set("status", "completed");
    record.set("title", ru ? "Сон" : "Sleep");
    record.set("start_time", session.start.toISOString());
    record.set("end_time", session.end.toISOString());
    record.set("category_id", category.id);
    record.set("category_link", category.id);
    record.set("type", "record");
    record.set("checklist", "[]");
    record.set("external_source", "google_fit");
    record.set("external_id", session.externalId);
    record.set("external_kind", "sleep");
    record.set("external_updated_at", session.modifiedAt.toISOString());
    record.set("sleep_source", "google_fit");
    record.set("sleep_external_id", session.externalId);
    app.save(record);
    return existing ? 0 : 1;
}

function __fitCleanupOwnedRecords(app, userId, start, sessions) {
    var removed = 0;
    var records = [];
    try {
        records = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && external_source = 'google_fit' && external_kind = 'sleep' && end_time >= {:start}",
            "",
            3000,
            0,
            { uid: userId, start: start.toISOString() }
        );
    } catch (_) { return 0; }

    for (var i = 0; i < records.length; i++) {
        var record = records[i];
        var rs = __fitDate(record.get("start_time"));
        var re = __fitDate(record.get("end_time"));
        if (!rs || !re || re.getTime() <= rs.getTime()) {
            try { app.delete(record); removed++; } catch (_) {}
            continue;
        }
        var rid = String(record.get("external_id") || "");
        var exact = false;
        var duplicate = false;
        for (var j = 0; j < sessions.length; j++) {
            var s = sessions[j];
            if (rid && rid === s.externalId) { exact = true; break; }
            var overlap = __fitOverlapMs(rs, re, s.start, s.end);
            var shorter = Math.min(re.getTime() - rs.getTime(), s.end.getTime() - s.start.getTime());
            if (shorter > 0 && overlap / shorter >= 0.80) duplicate = true;
        }
        if (!exact && duplicate) {
            try { app.delete(record); removed++; } catch (_) {}
        }
    }
    return removed;
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
    var now = new Date();
    var historyComplete = String(connection.get("last_full_sync_at") || "").length > 0;
    var segmentBackfillComplete = !!connection.get("segment_backfill_complete");
    var sessionStart = historyComplete
        ? new Date(now.getTime() - __fitCorrectionLookbackDays * 86400000)
        : __fitHistoryStart;
    var segmentStart = segmentBackfillComplete
        ? new Date(now.getTime() - __fitCorrectionLookbackDays * 86400000)
        : __fitSegmentHistoryStart;

    var sessions = __fitFetchSleep(accessToken, sessionStart, now);
    var recovery = __fitRecovery.recover(accessToken, segmentStart, now, sessions);
    sessions = recovery.sessions;

    var category = __fitSleepCategory(app, userId, profile.get("primary_language"));
    var imported = 0;
    for (var i = 0; i < sessions.length; i++) {
        imported += __fitUpsert(app, userId, profile, category, sessions[i]);
    }
    var cleaned = __fitCleanupOwnedRecords(app, userId, segmentStart, sessions);

    var local = __fitLocalClock(profile, now);
    connection.set("status", "connected");
    connection.set("last_sync_at", now.toISOString());
    connection.set("last_sync_local_day", local.day);
    connection.set("last_session_count", sessions.length);
    connection.set("last_imported_count", imported);
    connection.set("last_sleep_count", sessions.length);
    connection.set("last_activity_count", 0);
    if (!historyComplete) connection.set("last_full_sync_at", now.toISOString());
    if (!segmentBackfillComplete) connection.set("segment_backfill_complete", true);
    connection.set("last_error", "");
    app.save(connection);
    try {
        app.logger().info("google fit sleep sync complete", "sessions", sessions.length, "imported", imported, "segment_points", recovery.segmentPoints, "segment_episodes", recovery.recoveredEpisodes, "cleaned", cleaned);
    } catch (_) {}
    return {
        sessions: sessions.length,
        imported: imported,
        sleep: sessions.length,
        segmentPoints: recovery.segmentPoints,
        recoveredEpisodes: recovery.recoveredEpisodes,
        cleaned: cleaned
    };
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
        try { app.logger().error("google fit sleep sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

function status(e) {
    return e.json(200, __fitStatus(__fitConnection(e.app, e.auth.id, false)));
}

function connect(e) {
    var cfg = __fitGoogleConfig();
    __fitTokenKey(e.app);
    var connection = __fitConnection(e.app, e.auth.id, true);
    var state = $security.randomStringWithAlphabet(48, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
    connection.set("oauth_state", state);
    connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
    connection.set("status", "connecting");
    connection.set("last_error", "");
    e.app.save(connection);

    var url = "https://accounts.google.com/o/oauth2/v2/auth?" + __fitFormEncode({
        client_id: cfg.clientId,
        redirect_uri: cfg.redirectUri,
        response_type: "code",
        scope: __fitScope,
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
        connection.set("last_full_sync_at", "");
        connection.set("segment_backfill_complete", false);
        connection.set("last_error", "");
        e.app.save(connection);

        try { __fitRunSafe(e.app, connection); } catch (_) {}
        var returnUrl = __fitReturnUrl();
        return e.html(200,
            "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='2;url=" + returnUrl + "'>" +
            "<title>Life OS</title><h1>Google Fit connected</h1><p>Sleep history is being synchronized to Life OS.</p>"
        );
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        e.app.save(connection);
        return e.html(500, "<h1>Google Fit connection failed</h1><p>Return to Life OS and try again.</p>");
    }
}

function settings(e) {
    var body = e.requestInfo().body || {};
    var connection = __fitConnection(e.app, e.auth.id, true);
    if (body.enabled !== undefined) connection.set("enabled", !!body.enabled);
    if (body.daily_sync_minutes !== undefined) {
        var minutes = Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __fitDefaultMinutes));
        connection.set("daily_sync_minutes", Math.floor(minutes));
    }
    e.app.save(connection);
    return e.json(200, __fitStatus(connection));
}

function run(e) {
    var connection = __fitConnection(e.app, e.auth.id, false);
    if (!connection || !String(connection.get("refresh_token_enc") || "")) {
        return e.json(409, { error: "not_connected" });
    }
    try {
        var result = __fitRunSafe(e.app, connection);
        return e.json(200, {
            ok: true,
            sessions: result.sessions,
            imported: result.imported,
            sleep: result.sleep,
            segment_points: result.segmentPoints,
            recovered_episodes: result.recoveredEpisodes,
            cleaned: result.cleaned
        });
    } catch (err) {
        return e.json(502, { ok: false, error: String(err) });
    }
}

function remove(e) {
    var connection = __fitConnection(e.app, e.auth.id, false);
    if (connection) e.app.delete(connection);
    return e.json(200, { ok: true });
}

function cron(app) {
    var connections = [];
    try {
        connections = app.findRecordsByFilter(
            __fitCollection,
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
            if (__fitNeedsReconnect(connection.get("last_error"))) continue;
            if (!String(connection.get("last_full_sync_at") || "") || !connection.get("segment_backfill_complete")) {
                __fitRunSafe(app, connection);
                continue;
            }
            var profile = __fitProfile(app, String(connection.get("user_id") || ""));
            var local = __fitLocalClock(profile, now);
            var dueMinutes = Number(connection.get("daily_sync_minutes") || __fitDefaultMinutes);
            var lastDay = String(connection.get("last_sync_local_day") || "");
            var lastSync = __fitDate(connection.get("last_sync_at"));
            var stale = !lastSync || now.getTime() - lastSync.getTime() >= __fitCatchupIntervalMs;
            var dailyDue = local.minutes >= dueMinutes && lastDay !== local.day;
            if (!stale && !dailyDue) continue;
            __fitRunSafe(app, connection);
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
