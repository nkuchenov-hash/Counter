// Google Fit cloud sleep recovery helper.
// The merged com.google.sleep.segment stream is canonical. For freshness, recent
// visible raw/derived sleep streams are also read from the same Google Fit account
// and merged before reconstructing the simple asleep -> awake interval.

var SLEEP_DATA_TYPE = "com.google.sleep.segment";
var MIN_EPISODE_MS = 20 * 60 * 1000;
var MAX_SEGMENT_GAP_MS = 90 * 60 * 1000;
var FULL_SCAN_CHUNK_MS = 90 * 86400000;
var RAW_FALLBACK_LOOKBACK_MS = 3 * 86400000;

function formEncode(values) {
    var parts = [];
    for (var key in values) {
        if (!Object.prototype.hasOwnProperty.call(values, key)) continue;
        parts.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(values[key])));
    }
    return parts.join("&");
}

function aggregateChunk(accessToken, start, end) {
    var res = $http.send({
        url: "https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate",
        method: "POST",
        headers: {
            "authorization": "Bearer " + accessToken,
            "accept": "application/json",
            "content-type": "application/json"
        },
        body: JSON.stringify({
            aggregateBy: [{ dataTypeName: SLEEP_DATA_TYPE }],
            startTimeMillis: start.getTime(),
            endTimeMillis: end.getTime()
        }),
        timeout: 60
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) {
        var detail = "";
        try { detail = JSON.stringify(res.json || {}); } catch (_) {}
        throw new Error("Google Fit sleep segment request failed: HTTP " + res.statusCode + (detail ? " " + detail : ""));
    }
    var points = [];
    var buckets = res.json.bucket || [];
    for (var i = 0; i < buckets.length; i++) {
        var datasets = (buckets[i] || {}).dataset || [];
        for (var j = 0; j < datasets.length; j++) {
            var rows = (datasets[j] || {}).point || [];
            for (var k = 0; k < rows.length; k++) points.push(rows[k]);
        }
    }
    return points;
}

function normalizePoint(row, fallbackSource) {
    row = row || {};
    var startNs = Number(row.startTimeNanos || 0);
    var endNs = Number(row.endTimeNanos || 0);
    if (!isFinite(startNs) || !isFinite(endNs) || startNs <= 0 || endNs <= startNs) return null;
    var startMs = Math.floor(startNs / 1000000);
    var endMs = Math.floor(endNs / 1000000);
    var values = row.value || [];
    var stage = values.length ? Number(values[0].intVal) : 0;
    if (!isFinite(stage) || stage < 0 || stage > 6) stage = 0;
    return {
        start: new Date(startMs),
        end: new Date(endMs),
        stage: stage,
        source: String(row.originDataSourceId || fallbackSource || "")
    };
}

function listVisibleSleepSources(accessToken) {
    var res = $http.send({
        url: "https://www.googleapis.com/fitness/v1/users/me/dataSources?" + formEncode({ dataTypeName: SLEEP_DATA_TYPE }),
        method: "GET",
        headers: {
            "authorization": "Bearer " + accessToken,
            "accept": "application/json"
        },
        timeout: 60
    });
    if (res.statusCode < 200 || res.statusCode >= 300 || !res.json) return [];
    var rows = res.json.dataSource || [];
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i] || {};
        var dataType = row.dataType || {};
        var id = String(row.dataStreamId || "").trim();
        if (id && String(dataType.name || "") === SLEEP_DATA_TYPE) out.push(id);
    }
    return out;
}

function datasetId(start, end) {
    // Preserve nanosecond identifiers as decimal strings instead of JS Numbers.
    return String(start.getTime()) + "000000-" + String(end.getTime()) + "000000";
}

function fetchVisibleSourcePoints(accessToken, start, end) {
    var sources = [];
    try { sources = listVisibleSleepSources(accessToken); } catch (_) { return { points: [], sources: 0 }; }
    var points = [];
    for (var i = 0; i < sources.length; i++) {
        var sourceId = sources[i];
        var pageToken = "";
        var page = 0;
        do {
            var query = { limit: 1000 };
            if (pageToken) query.pageToken = pageToken;
            var url = "https://www.googleapis.com/fitness/v1/users/me/dataSources/" +
                encodeURIComponent(sourceId) + "/datasets/" + datasetId(start, end) + "?" + formEncode(query);
            var res = null;
            try {
                res = $http.send({
                    url: url,
                    method: "GET",
                    headers: {
                        "authorization": "Bearer " + accessToken,
                        "accept": "application/json"
                    },
                    timeout: 60
                });
            } catch (_) { break; }
            if (!res || res.statusCode < 200 || res.statusCode >= 300 || !res.json) break;
            var rows = res.json.point || [];
            for (var r = 0; r < rows.length; r++) {
                var point = normalizePoint(rows[r], sourceId);
                if (point && point.end.getTime() <= Date.now()) points.push(point);
            }
            pageToken = String(res.json.nextPageToken || "").trim();
            page++;
            if (page > 100) break;
        } while (pageToken);
    }
    return { points: points, sources: sources.length };
}

function pointKey(point) {
    return point.start.getTime() + "|" + point.end.getTime() + "|" + point.stage;
}

function fetchPoints(accessToken, start, end) {
    var aggregatePoints = [];
    var cursor = new Date(start.getTime());
    while (cursor.getTime() < end.getTime()) {
        var chunkEnd = new Date(Math.min(end.getTime(), cursor.getTime() + FULL_SCAN_CHUNK_MS));
        var chunk = aggregateChunk(accessToken, cursor, chunkEnd);
        for (var i = 0; i < chunk.length; i++) {
            var point = normalizePoint(chunk[i], "");
            if (point && point.end.getTime() <= Date.now()) aggregatePoints.push(point);
        }
        cursor = chunkEnd;
    }

    // The aggregate-by-data-type stream remains canonical because Google merges
    // data from different apps/devices there. Recent visible source streams are a
    // supplementary freshness path for a night that has reached the fitness store
    // but has not yet appeared in the merged aggregate response.
    var rawStart = new Date(Math.max(start.getTime(), end.getTime() - RAW_FALLBACK_LOOKBACK_MS));
    var raw = fetchVisibleSourcePoints(accessToken, rawStart, end);
    var byKey = {};
    var merged = [];
    function add(point) {
        var key = pointKey(point);
        if (byKey[key]) return;
        byKey[key] = true;
        merged.push(point);
    }
    for (var a = 0; a < aggregatePoints.length; a++) add(aggregatePoints[a]);
    for (var b = 0; b < raw.points.length; b++) add(raw.points[b]);

    merged.sort(function(a, b) {
        var d = a.start.getTime() - b.start.getTime();
        return d || (a.end.getTime() - b.end.getTime());
    });
    return {
        points: merged,
        aggregatePoints: aggregatePoints.length,
        rawPoints: raw.points.length,
        rawSources: raw.sources
    };
}

function episodeId(start, end) {
    // Stable enough across small provider corrections: key by UTC end date and rounded start hour.
    var y = end.getUTCFullYear();
    var m = String(end.getUTCMonth() + 1).padStart(2, "0");
    var d = String(end.getUTCDate()).padStart(2, "0");
    var h = String(start.getUTCHours()).padStart(2, "0");
    return "segments|" + y + "-" + m + "-" + d + "|" + h;
}

function buildEpisodes(points) {
    if (!points.length) return [];
    var groups = [];
    var current = null;
    for (var i = 0; i < points.length; i++) {
        var p = points[i];
        if (!current || p.start.getTime() - current.end.getTime() > MAX_SEGMENT_GAP_MS) {
            if (current) groups.push(current);
            current = {
                start: p.start,
                end: p.end,
                modifiedAt: p.end,
                points: 1
            };
        } else {
            if (p.start.getTime() < current.start.getTime()) current.start = p.start;
            if (p.end.getTime() > current.end.getTime()) current.end = p.end;
            if (p.end.getTime() > current.modifiedAt.getTime()) current.modifiedAt = p.end;
            current.points++;
        }
    }
    if (current) groups.push(current);

    var episodes = [];
    for (var g = 0; g < groups.length; g++) {
        var group = groups[g];
        if (group.end.getTime() - group.start.getTime() < MIN_EPISODE_MS) continue;
        episodes.push({
            externalId: episodeId(group.start, group.end),
            start: group.start,
            end: group.end,
            modifiedAt: group.modifiedAt,
            application: "google_fit_segments",
            recoveredFromSegments: true,
            segmentPoints: group.points
        });
    }
    return episodes;
}

function overlapMs(a, b) {
    return Math.max(0, Math.min(a.end.getTime(), b.end.getTime()) - Math.max(a.start.getTime(), b.start.getTime()));
}

function durationMs(a) {
    return Math.max(0, a.end.getTime() - a.start.getTime());
}

function isDuplicate(a, b) {
    var overlap = overlapMs(a, b);
    if (!overlap) return false;
    var shorter = Math.min(durationMs(a), durationMs(b));
    if (shorter <= 0) return true;
    return overlap / shorter >= 0.80;
}

function cleanSessions(sessions) {
    var valid = [];
    for (var i = 0; i < sessions.length; i++) {
        if (durationMs(sessions[i]) >= MIN_EPISODE_MS) valid.push(sessions[i]);
    }
    valid.sort(function(a, b) {
        var d = a.start.getTime() - b.start.getTime();
        if (d) return d;
        return durationMs(b) - durationMs(a);
    });
    var out = [];
    for (var j = 0; j < valid.length; j++) {
        var candidate = valid[j];
        var duplicateIndex = -1;
        for (var k = 0; k < out.length; k++) {
            if (isDuplicate(out[k], candidate)) { duplicateIndex = k; break; }
        }
        if (duplicateIndex < 0) {
            out.push(candidate);
        } else if (durationMs(candidate) > durationMs(out[duplicateIndex])) {
            out[duplicateIndex] = candidate;
        }
    }
    out.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return out;
}

function mergeSessionsAndEpisodes(sessions, episodes) {
    var out = cleanSessions(sessions);
    for (var i = 0; i < episodes.length; i++) {
        var episode = episodes[i];
        var matched = -1;
        for (var j = 0; j < out.length; j++) {
            if (isDuplicate(out[j], episode)) { matched = j; break; }
        }
        if (matched < 0) {
            out.push(episode);
            continue;
        }
        // Sessions remain canonical IDs, but segment bounds can repair truncated sessions.
        var target = out[matched];
        if (episode.start.getTime() < target.start.getTime()) target.start = episode.start;
        if (episode.end.getTime() > target.end.getTime()) target.end = episode.end;
        if (episode.modifiedAt.getTime() > target.modifiedAt.getTime()) target.modifiedAt = episode.modifiedAt;
    }
    out.sort(function(a, b) { return a.start.getTime() - b.start.getTime(); });
    return cleanSessions(out);
}

function recover(accessToken, start, end, sessions) {
    var fetched = fetchPoints(accessToken, start, end);
    var episodes = buildEpisodes(fetched.points);
    return {
        sessions: mergeSessionsAndEpisodes(sessions || [], episodes),
        segmentPoints: fetched.points.length,
        aggregateSegmentPoints: fetched.aggregatePoints,
        rawSegmentPoints: fetched.rawPoints,
        rawSegmentSources: fetched.rawSources,
        recoveredEpisodes: episodes.length
    };
}

module.exports = {
    recover: recover,
    cleanSessions: cleanSessions
};