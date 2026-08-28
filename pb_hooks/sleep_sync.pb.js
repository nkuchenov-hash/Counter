/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Production source: Xiaomi Cloud.
// Xiaomi Cloud is the active provider for fresh sleep data. Historical Google
// records remain in PocketBase, but Google Health / Google Fit are no longer
// active background sync providers.
function __sleepSyncXiaomi() {
    return require(__hooks + "/xiaomi_sleep_runtime.js");
}

routerAdd("GET", "/api/sleep-sync/status", function(e) {
    return __sleepSyncXiaomi().status(e);
}, $apis.requireAuth("profiles"));

// Compatibility: existing Flutter builds may still call either historical
// Google endpoint. Both now start/use the single Xiaomi Cloud connection.
routerAdd("POST", "/api/sleep-sync/google-health/connect", function(e) {
    return __sleepSyncXiaomi().connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    return __sleepSyncXiaomi().connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    return __sleepSyncXiaomi().connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/xiaomi/authorize", function(e) {
    return __sleepSyncXiaomi().authorize(e);
});

// Keep the stale Google OAuth callback route only so an already-open old
// browser authorization page fails safely instead of becoming a 404. It is not
// used by the active sleep pipeline.
routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    return __sleepSyncXiaomi().settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    return __sleepSyncXiaomi().run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    return __sleepSyncXiaomi().remove(e);
}, $apis.requireAuth("profiles"));

// Temporary production reconciliation for accounts that were authorized while
// Google was still the active provider. A valid server token is authoritative;
// run the same exported Xiaomi sync path used by the authenticated endpoint so
// the first import cannot be skipped by stale scheduler state.
function __sleepSyncBootstrapBoundXiaomi(app) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter("sleep_sync_connections", "provider = 'xiaomi'", "", 500, 0);
    } catch (_) { return; }
    for (var i = 0; i < rows.length; i++) {
        try {
            var row = rows[i];
            var userId = String(row.get("user_id") || "");
            if (!/^[A-Za-z0-9_-]{1,80}$/.test(userId)) continue;
            $os.stat(__hooks + "/../pb_data/xiaomi_sleep/" + userId + ".token.json");
            row.set("enabled", true);
            row.set("status", "connected");
            row.set("last_error", "");
            app.save(row);

            __sleepSyncXiaomi().run({
                app: app,
                auth: { id: userId },
                json: function() { return null; }
            });
        } catch (err) {
            try { app.logger().error("xiaomi bootstrap reconciliation failed", "error", err); } catch (_) {}
        }
    }
}

// Database access is valid only after e.next(). Perform one immediate Xiaomi
// reconciliation after restart; the regular scheduler owns subsequent syncs.
onBootstrap(function(e) {
    e.next();
    __sleepSyncBootstrapBoundXiaomi(e.app);
});

// Eligibility is checked every minute; xiaomi_sleep_runtime.js throttles actual
// Xiaomi Cloud calls to the 30-minute catch-up interval plus the configured
// daily sync point, with a weekly 30-day reconciliation window.
cronAdd("lifeos_xiaomi_sleep_sync", "* * * * *", function() {
    return __sleepSyncXiaomi().cron($app);
});