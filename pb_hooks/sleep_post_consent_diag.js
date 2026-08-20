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
function accessToken(app, c) {
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
    body: form({ refresh_token: refresh, client_id: clientId, client_secret: clientSecret, grant_type: 'refresh_token' }),
    timeout: 30
  });
  if (res.statusCode < 200 || res.statusCode >= 300 || !res.json || !res.json.access_token) {
    throw new Error('token_refresh_' + res.statusCode);
  }
  return String(res.json.access_token);
}
function hasScope(scopeString, wanted) {
  var parts = String(scopeString || '').split(/\s+/);
  for (var i = 0; i < parts.length; i++) if (parts[i] === wanted) return true;
  return false;
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
function run(e) {
  try {
    var c = connection(e.app);
    var token = accessToken(e.app, c);
    var tokenInfo = $http.send({
      url: 'https://oauth2.googleapis.com/tokeninfo?access_token=' + encodeURIComponent(token),
      method: 'GET',
      headers: { 'accept': 'application/json' },
      timeout: 30
    });
    var scopeString = tokenInfo && tokenInfo.json ? String(tokenInfo.json.scope || '') : '';
    var healthScope = 'https://www.googleapis.com/auth/googlehealth.sleep.readonly';
    var fitScope = 'https://www.googleapis.com/auth/fitness.sleep.read';

    var start = new Date(Date.now() - 3 * 86400000).toISOString();
    var end = new Date().toISOString();
    var healthRes = $http.send({
      url: 'https://health.googleapis.com/v4/users/me/dataTypes/sleep/dataPoints:reconcile?' + form({
        pageSize: 25,
        dataSourceFamily: 'users/me/dataSourceFamilies/all-sources',
        filter: 'sleep.interval.end_time >= "' + start + '" AND sleep.interval.end_time < "' + end + '"'
      }),
      method: 'GET',
      headers: { 'authorization': 'Bearer ' + token, 'accept': 'application/json' },
      timeout: 60
    });

    var cutoff = new Date(Date.now() - 36 * 3600000).toISOString();
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
      refresh_token_present: String(c.get('refresh_token_enc') || '').length > 0,
      access_token_present: String(c.get('access_token_enc') || '').length > 0,
      health_scope_granted: hasScope(scopeString, healthScope),
      fit_scope_granted: hasScope(scopeString, fitScope),
      tokeninfo_status: tokenInfo ? tokenInfo.statusCode : 0,
      health_status: healthRes ? healthRes.statusCode : 0,
      health_points: 0,
      health_error_status: 'none',
      health_error_reason: 'none',
      pocketbase_sleep_last_36h: recent.length
    };
    if (healthRes && healthRes.statusCode >= 200 && healthRes.statusCode < 300 && healthRes.json) {
      var rows = healthRes.json.dataPoints || healthRes.json.data_points || [];
      payload.health_points = rows.length;
    } else if (healthRes) {
      var meta = errorMeta(healthRes);
      payload.health_error_status = meta.status;
      payload.health_error_reason = meta.reason;
    }
    return e.json(200, payload);
  } catch (err) {
    return e.json(200, { connection: false, diagnostic_error: String(err) });
  }
}
module.exports = { run: run };
