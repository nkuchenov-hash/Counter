var recovery = require(__hooks + "/google_fit_sleep_recovery.js");

function env(name) {
    try { return String($os.getenv(name) || "").trim(); } catch (_) { return ""; }
}

function form(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function tokenKey(app) {
    var key = env("SLEEP_SYNC_TOKEN_KEY");
    if (key.length === 32) return key;
    var encryptionEnv = String(app.encryptionEnv() || "").trim();
    var inherited = encryptionEnv ? env(encryptionEnv) : "";
    if (inherited.length === 32) return inherited;
    throw new Error("token key unavailable");
}

function accessToken(app, connection) {
    var refreshEnc = String(connection.get("refresh_token_enc") || "");
    if (!refreshEnc) throw new Error("refresh token unavailable");
    var clientId = env("SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID");
    var clientSecret = env("SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET");
    if (!clientId || !clientSecret) throw new Error("Google Fit OAuth environment unavailable");
    var res = $http.send({
        url: "https://oauth2.googleapis.com/token",
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: form({
            refresh_token: String($security.decrypt(refreshEnc, tokenKey(app))),
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

function day(ms) {
    return ms > 0 ? new Date(ms).toISOString().slice(0, 10) : "none";
}

function sessions(token, start, end) {
    var count = 0;
    var latest = 0;
    var pageToken = "";
    var page = 0;
    do {
        var query = { startTime: start.toISOString(), endTime: end.toISOString(), activityType: "72" };
        if (pageToken) query.pageToken = pageToken;
        var res = $http.send({
            url: "https://www.googleapis.com/fitness/v1/users/me/sessions?" + form(query),
            method: "GET",
            headers: { "authorization": "Bearer " + token, "accept": "application/json" },
            timeout: 60
        });
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
            return { status: res.statusCode, count: 0, latestDay: "none" };
        }
        var rows = res.json.session || [];
        count += rows.length;
        for (var i = 0; i < rows.length; i++) {
            var endMs = Number(rows[i].endTimeMillis || 0);
            if (isFinite(endMs) && endMs > latest) latest = endMs;
        }
        pageToken = String(res.json.nextPageToken || "").trim();
        page++;
        if (page > 100) break;
    } while (pageToken);
    return { status: 200, count: count, latestDay: day(latest) };
}

function run(e) {
    try {
        var connection = e.app.findFirstRecordByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            {}
        );
        var token = accessToken(e.app, connection);
        var end = new Date();
        var start = new Date(end.getTime() - 4 * 86400000);
        var sessionResult = sessions(token, start, end);
        var segmentResult = recovery.recover(token, start, end, []);
        return e.json(200, {
            sessions_status: sessionResult.status,
            sessions_count: sessionResult.count,
            latest_session_day: sessionResult.latestDay,
            aggregate_segment_points: segmentResult.aggregateSegmentPoints,
            latest_aggregate_day: segmentResult.latestAggregateEndDay,
            raw_segment_sources: segmentResult.rawSegmentSources,
            raw_segment_points: segmentResult.rawSegmentPoints,
            latest_raw_day: segmentResult.latestRawEndDay,
            merged_segment_points: segmentResult.segmentPoints,
            latest_merged_day: segmentResult.latestMergedEndDay,
            recovered_episodes: segmentResult.recoveredEpisodes
        });
    } catch (err) {
        return e.json(500, { error: "probe_failed", detail_class: String(err).indexOf("token") >= 0 ? "auth" : "other" });
    }
}

module.exports = { run: run };
