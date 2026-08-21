// Server-owned Xiaomi / Mi Fitness sleep synchronization for PocketBase JSVM.
// Xiaomi credentials live only in pb_data and are consumed by the Python bridge.

var __xiaomiCollection = "sleep_sync_connections";
var __xiaomiProvider = "xiaomi";
var __xiaomiDefaultMinutes = 8 * 60;
var __xiaomiCatchupMs = 30 * 60 * 1000;
var __xiaomiPython = "/opt/lifeos-xiaomi-sleep/bin/python";

function __xiaomiEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __xiaomiPublicBaseUrl() {
    return __xiaomiEnv("SLEEP_SYNC_PUBLIC_BASE_URL") || "https://217-114-0-201.sslip.io";
}

function __xiaomiReturnUrl() {
    return __xiaomiEnv("SLEEP_SYNC_RETURN_URL") || "https://nkuchenov-hash.github.io/Counter/";
}

function __xiaomiSafeUserId(userId) {
    var raw = String(userId || "");
    if (!/^[A-Za-z0-9_-]{1,80}$/.test(raw)) throw new Error("Invalid LIFE OS user id");
    return raw;
}

function __xiaomiDataDir() {
    return __hooks + "/../pb_data/xiaomi_sleep";
}

function __xiaomiTokenPath(userId) {
    return __xiaomiDataDir() + "/" + __xiaomiSafeUserId(userId) + ".token.json";
}

function __xiaomiStatePath(userId) {
    return __xiaomiDataDir() + "/" + __xiaomiSafeUserId(userId) + ".state.json";
}

function __xiaomiBridgePath() {
    return __hooks + "/xiaomi_sleep_bridge.py";
}

function __xiaomiExists(path) {
    try { $os.stat(path); return true; } catch (_) { return false; }
}

function __xiaomiRemove(path) {
    try { $os.remove(path); } catch (_) {}
}

function __xiaomiReadJson(path) {
    try {
        var raw = toString($os.readFile(path));
        if (!raw) return null;
        return JSON.parse(raw);
    } catch (_) { return null; }
}

function __xiaomiDate(value) {
    var d = value instanceof Date ? value : new Date(value);
    return isNaN(d.getTime()) ? null : d;
}

function __xiaomiUuid() {
    var raw = $security.randomStringWithAlphabet(32, "0123456789abcdef");
    return raw.slice(0, 8) + "-" + raw.slice(8, 12) + "-4" + raw.slice(13, 16) + "-a" + raw.slice(17, 20) + "-" + raw.slice(20, 32);
}

function __xiaomiConnection(app, userId, createIfMissing) {
    try {
        return app.findFirstRecordByFilter(
            __xiaomiCollection,
            "user_id = {:uid} && provider = 'xiaomi'",
            { uid: userId }
        );
    } catch (_) {
        if (!createIfMissing) return null;
    }
    var record = new Record(app.findCollectionByNameOrId(__xiaomiCollection));
    record.set("user_id", userId);
    record.set("provider", __xiaomiProvider);
    record.set("enabled", true);
    record.set("daily_sync_minutes", __xiaomiDefaultMinutes);
    record.set("status", "disconnected");
    app.save(record);
    return record;
}

function __xiaomiDisableGoogleFit(app, userId) {
    try {
        var fit = app.findFirstRecordByFilter(
            __xiaomiCollection,
            "user_id = {:uid} && provider = 'google_fit'",
            { uid: userId }
        );
        if (fit.get("enabled")) {
            fit.set("enabled", false);
            app.save(fit);
        }
    } catch (_) {}
}

function __xiaomiHasToken(userId) {
    return __xiaomiExists(__xiaomiTokenPath(userId));
}

function __xiaomiStatus(app, connection) {
    if (!connection) {
        return {
            configured: false,
            provider: __xiaomiProvider,
            enabled: false,
            daily_sync_minutes: __xiaomiDefaultMinutes,
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
    var userId = String(connection.get("user_id") || "");
    var configured = !!userId && __xiaomiHasToken(userId);
    var phase = String(connection.get("status") || "disconnected");
    if (configured && (phase === "connecting" || phase === "disconnected")) {
        phase = "connected";
        connection.set("status", "connected");
        connection.set("last_error", "");
        try { app.save(connection); } catch (_) {}
        __xiaomiDisableGoogleFit(app, userId);
    }
    var lastError = String(connection.get("last_error") || "");
    return {
        configured: configured,
        provider: __xiaomiProvider,
        enabled: configured && !!connection.get("enabled"),
        daily_sync_minutes: Number(connection.get("daily_sync_minutes") || __xiaomiDefaultMinutes),
        status: configured ? phase : (phase === "connecting" ? "connecting" : "disconnected"),
        last_sync_at: connection.get("last_sync_at") || null,
        last_session_count: Number(connection.get("last_session_count") || 0),
        last_imported_count: Number(connection.get("last_imported_count") || 0),
        last_sleep_count: Number(connection.get("last_sleep_count") || 0),
        last_activity_count: 0,
        history_complete: configured,
        last_error: lastError || null
    };
}

function __xiaomiProfile(app, userId) {
    return app.findRecordById("profiles", userId);
}

function __xiaomiSleepCategory(app, userId, language) {
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

function __xiaomiOverlapMs(aStart, aEnd, bStart, bEnd) {
    return Math.max(0, Math.min(aEnd.getTime(), bEnd.getTime()) - Math.max(aStart.getTime(), bStart.getTime()));
}

function __xiaomiFindExisting(app, userId, session) {
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && external_source = 'xiaomi' && external_id = {:external}",
            { uid: userId, external: session.externalId }
        );
    } catch (_) {}
    try {
        return app.findFirstRecordByFilter(
            "records",
            "user_id = {:uid} && sleep_source = 'xiaomi' && sleep_external_id = {:external}",
            { uid: userId, external: session.externalId }
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
        var duration = session.end.getTime() - session.start.getTime();
        var best = null;
        var bestRatio = 0;
        for (var i = 0; i < rows.length; i++) {
            var rs = __xiaomiDate(rows[i].get("start_time"));
            var re = __xiaomiDate(rows[i].get("end_time"));
            if (!rs || !re || re.getTime() <= rs.getTime()) continue;
            var overlap = __xiaomiOverlapMs(session.start, session.end, rs, re);
            var shorter = Math.min(duration, re.getTime() - rs.getTime());
            var ratio = shorter > 0 ? overlap / shorter : 0;
            if (ratio >= 0.80 && ratio > bestRatio) {
                best = rows[i];
                bestRatio = ratio;
            }
        }
        if (best) return best;
    } catch (_) {}
    return null;
}

function __xiaomiUpsert(app, userId, profile, category, session) {
    var existing = __xiaomiFindExisting(app, userId, session);
    var record = existing || new Record(app.findCollectionByNameOrId("records"));
    var ru = String(profile.get("primary_language") || "").toLowerCase() === "ru";
    record.set("user_id", userId);
    record.set("record_id", existing ? record.get("record_id") : __xiaomiUuid());
    record.set("status", "completed");
    record.set("title", ru ? "Сон" : "Sleep");
    record.set("start_time", session.start.toISOString());
    record.set("end_time", session.end.toISOString());
    record.set("category_id", category.id);
    record.set("category_link", category.id);
    record.set("type", "record");
    record.set("checklist", "[]");
    record.set("external_source", "xiaomi");
    record.set("external_id", session.externalId);
    record.set("external_kind", "sleep");
    record.set("external_updated_at", new Date().toISOString());
    record.set("sleep_source", "xiaomi");
    record.set("sleep_external_id", session.externalId);
    app.save(record);
    return existing ? 0 : 1;
}

function __xiaomiNormalizeSessions(payload) {
    var raw = payload && payload.sessions ? payload.sessions : [];
    var out = [];
    var seen = {};
    for (var i = 0; i < raw.length; i++) {
        var row = raw[i] || {};
        var start = __xiaomiDate(row.start);
        var end = __xiaomiDate(row.end);
        var externalId = String(row.external_id || "").trim();
        if (!start || !end || end.getTime() <= start.getTime() || end.getTime() > Date.now() + 300000) continue;
        var elapsed = end.getTime() - start.getTime();
        if (elapsed < 20 * 60000 || elapsed > 36 * 3600000) continue;
        if (!externalId) externalId = "xiaomi:" + start.toISOString() + ":" + end.toISOString();
        if (seen[externalId]) continue;
        seen[externalId] = true;
        out.push({ externalId: externalId, start: start, end: end });
    }
    out.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return out;
}

function __xiaomiRunBridge(userId, days) {
    var cmd = $os.cmd(
        "timeout",
        "90",
        __xiaomiPython,
        __xiaomiBridgePath(),
        "sync",
        "--token-path",
        __xiaomiTokenPath(userId),
        "--days",
        String(days || 7)
    );
    var raw = toString(cmd.output()).trim();
    if (!raw) throw new Error("Xiaomi sleep bridge returned no data");
    var payload = null;
    try { payload = JSON.parse(raw); } catch (_) { throw new Error("Xiaomi sleep bridge returned invalid data"); }
    if (!payload || payload.ok !== true) {
        throw new Error("Xiaomi sleep cloud request failed" + (payload && payload.error_class ? ": " + payload.error_class : ""));
    }
    return payload;
}

function __xiaomiLocalClock(profile, now) {
    var offsetHours = Number(profile.get("timezone_offset") || 0);
    var local = new Date(now.getTime() + offsetHours * 3600000);
    return {
        minutes: local.getUTCHours() * 60 + local.getUTCMinutes(),
        day: local.getUTCFullYear() + "-" + String(local.getUTCMonth() + 1).padStart(2, "0") + "-" + String(local.getUTCDate()).padStart(2, "0")
    };
}

function __xiaomiRunConnection(app, connection) {
    var userId = String(connection.get("user_id") || "");
    if (!userId || !__xiaomiHasToken(userId)) throw new Error("Xiaomi authorization is required");
    var profile = __xiaomiProfile(app, userId);
    var payload = __xiaomiRunBridge(userId, 7);
    var sessions = __xiaomiNormalizeSessions(payload);
    var category = __xiaomiSleepCategory(app, userId, profile.get("primary_language"));
    var imported = 0;
    for (var i = 0; i < sessions.length; i++) {
        imported += __xiaomiUpsert(app, userId, profile, category, sessions[i]);
    }
    var now = new Date();
    var local = __xiaomiLocalClock(profile, now);
    connection.set("status", "connected");
    connection.set("enabled", true);
    connection.set("last_sync_at", now.toISOString());
    connection.set("last_sync_local_day", local.day);
    connection.set("last_session_count", sessions.length);
    connection.set("last_imported_count", imported);
    connection.set("last_sleep_count", sessions.length);
    connection.set("last_activity_count", 0);
    if (!String(connection.get("last_full_sync_at") || "")) connection.set("last_full_sync_at", now.toISOString());
    connection.set("last_error", "");
    app.save(connection);
    __xiaomiDisableGoogleFit(app, userId);
    try { app.logger().info("xiaomi sleep sync complete", "sessions", sessions.length, "imported", imported); } catch (_) {}
    return { sessions: sessions.length, imported: imported, sleep: sessions.length };
}

function __xiaomiRunSafe(app, connection) {
    try {
        connection.set("status", "syncing");
        connection.set("last_error", "");
        app.save(connection);
        return __xiaomiRunConnection(app, connection);
    } catch (err) {
        connection.set("status", "error");
        connection.set("last_error", String(err));
        connection.set("last_sync_at", new Date().toISOString());
        app.save(connection);
        try { app.logger().error("xiaomi sleep sync failed", "connection", connection.id, "error", err); } catch (_) {}
        throw err;
    }
}

function __xiaomiHtmlEscape(value) {
    return String(value || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/\"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function exists(app, userId) {
    return __xiaomiConnection(app, userId, false) !== null;
}

function status(e) {
    return e.json(200, __xiaomiStatus(e.app, __xiaomiConnection(e.app, e.auth.id, false)));
}

function connect(e) {
    var userId = String(e.auth.id || "");
    var connection = __xiaomiConnection(e.app, userId, true);
    $os.mkdirAll(__xiaomiDataDir(), 448);

    if (__xiaomiHasToken(userId)) {
        connection.set("enabled", true);
        connection.set("status", "connected");
        connection.set("last_error", "");
        e.app.save(connection);
        __xiaomiDisableGoogleFit(e.app, userId);
        return e.json(200, __xiaomiStatus(e.app, connection));
    }

    var previous = __xiaomiReadJson(__xiaomiStatePath(userId));
    var previousStatus = previous ? String(previous.status || "") : "";
    var previousUrl = previous ? String(previous.login_url || "") : "";
    var oauthState = String(connection.get("oauth_state") || "");
    var expires = __xiaomiDate(connection.get("oauth_state_expires_at"));
    var reusable = previousStatus === "awaiting_scan" && previousUrl && oauthState && expires && expires.getTime() > Date.now() + 60000;

    if (!reusable) {
        __xiaomiRemove(__xiaomiStatePath(userId));
        oauthState = connection.id + "." + $security.randomStringWithAlphabet(40, "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
        connection.set("oauth_state", oauthState);
        connection.set("oauth_state_expires_at", new Date(Date.now() + 10 * 60000).toISOString());
        connection.set("enabled", true);
        connection.set("status", "connecting");
        connection.set("last_error", "");
        e.app.save(connection);

        var command = "nohup " +
            "'" + __xiaomiPython + "' " +
            "'" + __xiaomiBridgePath() + "' login --token-path '" + __xiaomiTokenPath(userId) +
            "' --state-path '" + __xiaomiStatePath(userId) +
            "' --max-wait 300 >/dev/null 2>&1 &";
        $os.cmd("sh", "-c", command).run();

        var waitScript = "for i in $(seq 1 80); do " +
            "if [ -s '" + __xiaomiStatePath(userId) + "' ]; then " +
            "grep -q '\"status\":\"awaiting_scan\"' '" + __xiaomiStatePath(userId) + "' && cat '" + __xiaomiStatePath(userId) + "' && exit 0; fi; " +
            "sleep 0.1; done; exit 1";
        try { $os.cmd("sh", "-c", waitScript).output(); } catch (_) {}
    }

    var stateDoc = __xiaomiReadJson(__xiaomiStatePath(userId));
    if (!stateDoc || String(stateDoc.status || "") !== "awaiting_scan") {
        connection.set("status", "error");
        connection.set("last_error", "Xiaomi authorization could not be started");
        e.app.save(connection);
        return e.json(502, { error: "xiaomi_authorization_start_failed" });
    }

    return e.json(200, {
        authorization_url: __xiaomiPublicBaseUrl() + "/api/sleep-sync/xiaomi/authorize?state=" + encodeURIComponent(oauthState)
    });
}

function authorize(e) {
    var query = e.requestInfo().query || {};
    var state = String(query.state || "");
    if (!state) return e.html(400, "<h1>Invalid Xiaomi authorization</h1>");
    var connection = null;
    try {
        connection = e.app.findFirstRecordByFilter(
            __xiaomiCollection,
            "provider = 'xiaomi' && oauth_state = {:state}",
            { state: state }
        );
    } catch (_) {}
    if (!connection) return e.html(400, "<h1>Invalid or expired Xiaomi authorization</h1>");
    var expires = __xiaomiDate(connection.get("oauth_state_expires_at"));
    if (!expires || expires.getTime() < Date.now()) return e.html(400, "<h1>Xiaomi authorization expired</h1>");

    var userId = String(connection.get("user_id") || "");
    if (__xiaomiHasToken(userId)) {
        connection.set("enabled", true);
        connection.set("status", "connected");
        connection.set("last_error", "");
        e.app.save(connection);
        __xiaomiDisableGoogleFit(e.app, userId);
        try { __xiaomiRunSafe(e.app, connection); } catch (_) {}
        var returnUrl = __xiaomiHtmlEscape(__xiaomiReturnUrl());
        return e.html(200,
            "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='1;url=" + returnUrl + "'>" +
            "<title>Life OS</title><h1>Xiaomi connected</h1><p>Sleep is being synchronized. Returning to Life OS…</p>"
        );
    }

    var doc = __xiaomiReadJson(__xiaomiStatePath(userId)) || {};
    var phase = String(doc.status || "starting");
    if (phase === "error") {
        return e.html(500,
            "<!doctype html><meta charset='utf-8'><title>Life OS</title><h1>Xiaomi authorization failed</h1>" +
            "<p>Return to Life OS and turn sleep synchronization on again.</p>"
        );
    }
    var qr = __xiaomiHtmlEscape(doc.qr_image_url || "");
    var login = __xiaomiHtmlEscape(doc.login_url || "");
    var content = "<!doctype html><meta charset='utf-8'><meta http-equiv='refresh' content='3'>" +
        "<meta name='viewport' content='width=device-width,initial-scale=1'><title>Connect Xiaomi to Life OS</title>" +
        "<style>body{font:16px system-ui;max-width:560px;margin:40px auto;padding:0 20px;color:#171717}img{display:block;max-width:280px;width:100%;margin:24px auto;border-radius:16px}a{display:inline-block;padding:12px 18px;border-radius:12px;background:#111;color:#fff;text-decoration:none}p{line-height:1.5;color:#555}</style>" +
        "<h1>Connect Xiaomi to Life OS</h1><p>Scan the QR code with the Xiaomi Account app. This is required only once.</p>";
    if (qr) content += "<img src='" + qr + "' alt='Xiaomi login QR'>";
    if (login) content += "<p><a target='_blank' rel='noopener' href='" + login + "'>Open Xiaomi login</a></p>";
    content += "<p>This page will return to Life OS automatically after authorization.</p>";
    return e.html(200, content);
}

function settings(e) {
    var body = e.requestInfo().body || {};
    var connection = __xiaomiConnection(e.app, e.auth.id, false);
    if (!connection) return e.json(409, { error: "not_connected" });
    if (body.enabled !== undefined) connection.set("enabled", !!body.enabled);
    if (body.daily_sync_minutes !== undefined) {
        var minutes = Math.max(0, Math.min(1439, Number(body.daily_sync_minutes) || __xiaomiDefaultMinutes));
        connection.set("daily_sync_minutes", Math.floor(minutes));
    }
    e.app.save(connection);
    if (body.enabled !== undefined && !body.enabled) {
        try {
            var fit = e.app.findFirstRecordByFilter(__xiaomiCollection, "user_id = {:uid} && provider = 'google_fit'", { uid: e.auth.id });
            fit.set("enabled", false);
            e.app.save(fit);
        } catch (_) {}
    }
    return e.json(200, __xiaomiStatus(e.app, connection));
}

function run(e) {
    var connection = __xiaomiConnection(e.app, e.auth.id, false);
    if (!connection || !__xiaomiHasToken(e.auth.id)) return e.json(409, { error: "not_connected" });
    try {
        var result = __xiaomiRunSafe(e.app, connection);
        return e.json(200, { ok: true, sessions: result.sessions, imported: result.imported, sleep: result.sleep });
    } catch (err) {
        return e.json(502, { ok: false, error: String(err) });
    }
}

function remove(e) {
    var connection = __xiaomiConnection(e.app, e.auth.id, false);
    __xiaomiRemove(__xiaomiTokenPath(e.auth.id));
    __xiaomiRemove(__xiaomiStatePath(e.auth.id));
    if (connection) e.app.delete(connection);
    try {
        var fit = e.app.findFirstRecordByFilter(__xiaomiCollection, "user_id = {:uid} && provider = 'google_fit'", { uid: e.auth.id });
        fit.set("enabled", false);
        e.app.save(fit);
    } catch (_) {}
    return e.json(200, { ok: true });
}

function cron(app) {
    var connections = [];
    try {
        connections = app.findRecordsByFilter(__xiaomiCollection, "enabled = true && provider = 'xiaomi'", "", 500, 0);
    } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < connections.length; i++) {
        try {
            var connection = connections[i];
            var userId = String(connection.get("user_id") || "");
            if (!userId || !__xiaomiHasToken(userId)) continue;
            var profile = __xiaomiProfile(app, userId);
            var local = __xiaomiLocalClock(profile, now);
            var dueMinutes = Number(connection.get("daily_sync_minutes") || __xiaomiDefaultMinutes);
            var lastDay = String(connection.get("last_sync_local_day") || "");
            var lastSync = __xiaomiDate(connection.get("last_sync_at"));
            var stale = !lastSync || now.getTime() - lastSync.getTime() >= __xiaomiCatchupMs;
            var dailyDue = local.minutes >= dueMinutes && lastDay !== local.day;
            if (!stale && !dailyDue) continue;
            __xiaomiRunSafe(app, connection);
        } catch (_) {}
    }
}

module.exports = {
    exists: exists,
    status: status,
    connect: connect,
    authorize: authorize,
    settings: settings,
    run: run,
    remove: remove,
    cron: cron
};
