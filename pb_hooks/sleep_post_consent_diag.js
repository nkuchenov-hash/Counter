function env(name) {
  try { return String($os.getenv(name) || '').trim(); } catch (_) { return ''; }
}
function form(values) {
  var parts = [];
  for (var key in values) if (Object.prototype.hasOwnProperty.call(values, key)) {
    parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(String(values[key])));
  }
  return parts.join('&');
}
function tokenKey(app) {
  var key = env('SLEEP_SYNC_TOKEN_KEY');
  if (key.length === 32) return key;
  try {
    var envName = String(app.encryptionEnv() || '').trim();
    var inherited = envName ? env(envName) : '';
    if (inherited.length === 32) return inherited;
  } catch (_) {}
  throw new Error('token_key_unavailable');
}
function connection(app) {
  return app.findFirstRecordByFilter('sleep_sync_connections', "provider = 'google_fit'", {});
}
function accessToken(app, c, scope) {
  var refreshEnc = String(c.get('refresh_token_enc') || '');
  if (!refreshEnc) throw new Error('refresh_token_missing');
  var clientId = env('SLEEP_SYNC_GOOGLE_FIT_CLIENT_ID');
  var clientSecret = env('SLEEP_SYNC_GOOGLE_FIT_CLIENT_SECRET');
  if (!clientId || !clientSecret) throw new Error('oauth_client_missing');
  var refresh = String($security.decrypt(refreshEnc, tokenKey(app)));
  var res = $http.send({
    url: 'https://oauth2.googleapis.com/token',
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: form({ refresh_token: refresh, client_id: clientId, client_secret: clientSecret, grant_type: 'refresh_token', scope: scope }),
    timeout: 30
  });
  if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
    throw new Error('token_refresh_' + res.statusCode);
  }
  return String(res.json.access_token);
}
function errorMeta(res) {
  var status = '';
  var reason = '';
  try {
    var root = res.json && res.json.error ? res.json.error : {};
    status = String(root.status || root.code || '');
    var details = root.details || [];
    for (var i = 0; i < details.length; i++) {
      var r = String((details[i] || {}).reason || '');
      if (r) { reason = r; break; }
      var metadata = (details[i] || {}).metadata || {};
      var service = String(metadata.service || '');
      if (service) { reason = service; break; }
    }
  } catch (_) {}
  return { status: status || ('HTTP_' + res.statusCode), reason: reason || 'unknown' };
}
function countActivitySleep(res, cutoffMs) {
  var total = 0;
  var recent = 0;
  if (!res || !res.json) return { total: total, recent: recent };
  var buckets = res.json.bucket || [];
  for (var i = 0; i < buckets.length; i++) {
    var datasets = (buckets[i] || {}).dataset || [];
    for (var j = 0; j < datasets.length; j++) {
      var points = (datasets[j] || {}).point || [];
      for (var k = 0; k < points.length; k++) {
        var p = points[k] || {};
        var vals = p.value || [];
        var activity = vals.length ? Number(vals[0].intVal) : -1;
        if (activity !== 72) continue;
        total++;
        var endNs = Number(p.endTimeNanos || 0);
        var endMs = isFinite(endNs) ? Math.floor(endNs / 1000000) : 0;
        if (endMs >= cutoffMs) recent++;
      }
    }
  }
  return { total: total, recent: recent };
}
function run(e) {
  try {
    var c = connection(e.app);
    var fitScope = 'https://www.googleapis.com/auth/fitness.sleep.read';
    var token = accessToken(e.app, c, fitScope);
    var nowMs = Date.now();
    var startMs = nowMs - 3 * 86400000;
    var cutoffMs = nowMs - 36 * 3600000;

    var sourcesRes = $http.send({
      url: 'https://www.googleapis.com/fitness/v1/users/me/dataSources?' + form({ dataTypeName: 'com.google.activity.segment' }),
      method: 'GET',
      headers: { 'authorization': 'Bearer ' + token, 'accept': 'application/json' },
      timeout: 60
    });

    var aggregateRes = $http.send({
      url: 'https://www.googleapis.com/fitness/v1/users/me/dataset:aggregate',
      method: 'POST',
      headers: { 'authorization': 'Bearer ' + token, 'accept': 'application/json', 'content-type': 'application/json' },
      body: JSON.stringify({
        aggregateBy: [{ dataTypeName: 'com.google.activity.segment' }],
        startTimeMillis: startMs,
        endTimeMillis: nowMs
      }),
      timeout: 60
    });

    var sleepCounts = countActivitySleep(aggregateRes, cutoffMs);
    var cutoff = new Date(cutoffMs).toISOString();
    var recent = [];
    try {
      recent = e.app.findRecordsByFilter(
        'records',
        "(title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}",
        '', 100, 0, { cutoff: cutoff }
      );
    } catch (_) {}

    var payload = {
      connection: true,
      enabled: !!c.get('enabled'),
      stored_error: String(c.get('last_error') || '') || 'none',
      fit_activity_sources_status: sourcesRes ? sourcesRes.statusCode : 0,
      fit_activity_sources_count: 0,
      fit_activity_aggregate_status: aggregateRes ? aggregateRes.statusCode : 0,
      fit_activity_sleep_segments_3d: sleepCounts.total,
      fit_activity_sleep_segments_36h: sleepCounts.recent,
      fit_activity_sources_error: 'none',
      fit_activity_aggregate_error: 'none',
      pocketbase_sleep_last_36h: recent.length
    };
    if (sourcesRes && sourcesRes.statusCode >= 200 && sourcesRes.statusCode < 300 && sourcesRes.json) {
      payload.fit_activity_sources_count = (sourcesRes.json.dataSource || []).length;
    } else if (sourcesRes) {
      var sm = errorMeta(sourcesRes);
      payload.fit_activity_sources_error = sm.status + ':' + sm.reason;
    }
    if (aggregateRes && !(aggregateRes.statusCode >= 200 && aggregateRes.statusCode < 300)) {
      var am = errorMeta(aggregateRes);
      payload.fit_activity_aggregate_error = am.status + ':' + am.reason;
    }
    return e.json(200, payload);
  } catch (err) {
    return e.json(200, { connection: false, diagnostic_error: String(err) });
  }
}
module.exports = { run: run };
