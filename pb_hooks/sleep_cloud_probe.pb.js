/// <reference path="../pb_data/types.d.ts" />

// Temporary production diagnostic. It never writes user sleep records and returns
// only counts plus UTC calendar dates, never sleep times or OAuth tokens.

function __probeEnv(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function __probeForm(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function __probeTokenKey(app) {
    var key = __probeEnv("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    try {
        var encryptionEnv = String(app.encryptionEnv() || "").trim();
        var inherited = encryptionEnv ? __probeEnv(encryptionEnv) : "";
        if (inherited.length === 32) return inherited;
    } catch (_) {}
    throw new Error("token key unavailable");
}

function __probeAccessToken(app, connection) {
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("refresh token unavailable");
    var clientId = __probeEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = __probeEnv("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
    if (!clientId || !clientSecret) throw new Error("Google Fit OAuth environment unavailable");
    var refresh = String($security.decrypt(refreshEnc, __probeTokenKey(app)));
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: __probeForm({
            refresh_token: refresh,
            client_id: clientId,
            client_secret: clientSecret,
            grant_type: "refresh_token"
        }),
        timeout: 30
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
        throw new Error("token refresh HTTP " + res.statusCode);
    }
    return String(res.json.access_token);
}

function __probeDayFromMs(ms) {
    if (!isFinite(ms) || ms <= 0) return "none";
    return new Date(ms).toISOString().slice(0, 10);
}

function __probeLatestMs(current, candidate) {
    candidate = Number(candidate || 0);
    return isFinite(candidate) && candidate > current ? candidate : current;
}

function __probeSessions(token, start, end) {
    var count = 0;
    var latest = 0;
    var pageToken = "";
    var page = 0;
    do {
        var query = {
            startTime: start.toISOString(),
            endTime: end.toISOString(),
            activityType: "72"
        };
        if (pageToken) query.pageToken = pageToken;
        var res = $http.send({
            url: "https://www.googleapis.com/fitness/v1/users/me/sessions?" + __probeForm(query),
            method: "GET",
            headers: { "authorization": "Bearer " + token, "accept": "application/json" },
            timeout: 60
        });
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
            return { count: 0, latest: 0, status: res.statusCode };
        }
        var rows = res.json.session || [];
        count += rows.length;
        for (var i = 0; i < rows.length; i++) latest = __probeLatestMs(latest, rows[i].endTimeMillis);
        pageToken = String(res.json.nextPageToken || "").trim();
        page++;
        if (page > 100) break;
    } while (pageToken);
    return { count: count, latest: latest, status: 200 };
}

function __probeAggregate(token, start, end) {
    var res = $http.send({
        url: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate",
        method: "POST",
        headers: {
            "authorization": "Bearer " + token,
            "accept": "application/json",
            "content-type": "application/json"
        },
        body: JSON.stringify({
            aggregateBy: [{ dataTypeName: "com.google.sleep.segment" }],
            startTimeMillis: start.getTime(),
            endTimeMillis: end.getTime()
        }),
        timeout: 60
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        return { count: 0, latest: 0, status: res.statusCode };
    }
    var count = 0;
    var latest = 0;
    var buckets = res.json.bucket || [];
    for (var i = 0; i < buckets.length; i++) {
        var datasets = (buckets[i] || {}).dataset || [];
        for (var j = 0; j < datasets.length; j++) {
            var points = (datasets[j] || {}).point || [];
            count += points.length;
            for (var k = 0; k < points.length; k++) {
                latest = __probeLatestMs(latest, Math.floor(Number(points[k].endTimeNanos || 0) / 1000000));
            }
        }
    }
    return { count: count, latest: latest, status: 200 };
}

function __probeRaw(token, start, end) {
    var list = $http.send({
        url: "https://www.googleapis.com/fitness/v1/users/me/dataSources?" + __probeForm({ dataTypeName: "com.google.sleep.segment" }),
        method: "GET",
        headers: { "authorization": "Bearer " + token, "accept": "application/json" },
        timeout: 60
    });
    if (list.statusCode < 200 || list.statusCode >= 300 || !list.json) {
        return { sources: 0, count: 0, latest: 0, status: list.statusCode };
    }
    var sources = list.json.dataSource || [];
    var count = 0;
    var latest = 0;
    var dataset = String(start.getTime()) + "000000-" + String(end.getTime()) + "000000";
    var visible = 0;
    for (var i = 0; i < sources.length; i++) {
        var source = sources[i] || {};
        var type = source.dataType || {};
        var id = String(source.dataStreamId || "").trim();
        if (!id || String(type.name || "") !== "com.google.sleep.segment") continue;
        visible++;
        var pageToken = "";
        var page = 0;
        do {
            var query = { limit: 1000 };
            if (pageToken) query.pageToken = pageToken;
            var res = $http.send({
                url: "https://www.googleapis.com/fitness/v1/users/me/dataSources/" + encodeURIComponent(id) + "/datasets/" + dataset + "?" + __probeForm(query),
                method: "GET",
                headers: { "authorization": "Bearer " + token, "accept": "application/json" },
                timeout: 60
            });
            if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) break;
            var points = res.json.point || [];
            count += points.length;
            for (var p = 0; p < points.length; p++) {
                latest = __probeLatestMs(latest, Math.floor(Number(points[p].endTimeNanos || 0) / 1000000));
            }
            pageToken = String(res.json.nextPageToken || "").trim();
            page++;
            if (page > 100) break;
        } while (pageToken);
    }
    return { sources: visible, count: count, latest: latest, status: 200 };
}

routerAdd("GET", "/api/__lifeos_sleep_cloud_probe_5f7c9a2e", function(e) {
    try {
        var connection = e.app.findFirstRecordByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            {}
        );
        var token = __probeAccessToken(e.app, connection);
        var end = new Date();
        var start = new Date(end.getTime() - 4 * 86400000);
        var sessions = __probeSessions(token, start, end);
        var aggregate = __probeAggregate(token, start, end);
        var raw = __probeRaw(token, start, end);
        return e.json(200, {
            sessions_status: sessions.status,
            sessions_count: sessions.count,
            latest_session_day: __probeDayFromMs(sessions.latest),
            aggregate_status: aggregate.status,
            aggregate_points: aggregate.count,
            latest_aggregate_day: __probeDayFromMs(aggregate.latest),
            raw_status: raw.status,
            raw_sources: raw.sources,
            raw_points: raw.count,
            latest_raw_day: __probeDayFromMs(raw.latest)
        });
    } catch (err) {
        return e.json(500, { error: "probe_failed", detail_class: String(err).indexOf("token") >= 0 ? "auth" : "other" });
    }
});
