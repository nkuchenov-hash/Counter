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
    if (!clientId || !clientSecret) throw new Error("Google OAuth environment unavailable");
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

function classifyError(res) {
    var text = "";
    try { text = JSON.stringify(res.json || {}).toLowerCase(); } catch (_) {}
    if (res.statusCode === 401) return "auth";
    if (res.statusCode === 403) {
        if (text.indexOf("scope") >= 0 || text.indexOf("permission") >= 0 || text.indexOf("insufficient") >= 0) return "scope_or_permission";
        if (text.indexOf("disabled") >= 0 || text.indexOf("has not been used") >= 0 || text.indexOf("enable") >= 0) return "api_disabled";
        return "forbidden";
    }
    if (res.statusCode === 404) return "not_found";
    return "other";
}

function latestSleepDay(rows) {
    var latest = 0;
    for (var i = 0; i < rows.length; i++) {
        var sleep = (rows[i] || {}).sleep || {};
        var interval = sleep.interval || {};
        var raw = String(interval.endTime || interval.end_time || "");
        var ms = raw ? Date.parse(raw) : NaN;
        if (isFinite(ms) && ms > latest) latest = ms;
    }
    return latest > 0 ? new Date(latest).toISOString().slice(0, 10) : "none";
}

function platformCounts(rows) {
    var counts = {};
    for (var i = 0; i < rows.length; i++) {
        var ds = (rows[i] || {}).dataSource || (rows[i] || {}).data_source || {};
        var platform = String(ds.platform || "UNKNOWN");
        counts[platform] = Number(counts[platform] || 0) + 1;
    }
    return counts;
}

function run(e) {
    try {
        var connection = e.app.findFirstRecordByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            {}
        );
        var token = accessToken(e.app, connection);
        var cutoff = new Date(Date.now() - 4 * 86400000).toISOString().slice(0, 10);
        var query = {
            dataSourceFamily: "users/me/dataSourceFamilies/all-sources",
            pageSize: 25,
            filter: 'sleep.interval.civil_end_time >= "' + cutoff + '"'
        };
        var res = $http.send({
            url: "https://health.googleapis.com/v4/users/me/dataTypes/sleep/dataPoints:reconcile?" + form(query),
            method: "GET",
            headers: { "authorization": "Bearer " + token, "accept": "application/json" },
            timeout: 60
        });
        if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
            return e.json(200, {
                google_health_status: res.statusCode,
                error_class: classifyError(res),
                points: 0,
                latest_sleep_day: "none"
            });
        }
        var rows = res.json.dataPoints || res.json.data_points || [];
        return e.json(200, {
            google_health_status: res.statusCode,
            error_class: "none",
            points: rows.length,
            latest_sleep_day: latestSleepDay(rows),
            platforms: platformCounts(rows),
            has_more: !!String(res.json.nextPageToken || res.json.next_page_token || "")
        });
    } catch (err) {
        return e.json(200, {
            google_health_status: 0,
            error_class: String(err).toLowerCase().indexOf("token") >= 0 ? "auth" : "probe_failed",
            points: 0,
            latest_sleep_day: "none"
        });
    }
}

module.exports = { run: run };
