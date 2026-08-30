/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Xiaomi Cloud is primary; an already
// authorized Google Health connection is used only as stale-data recovery.
// PocketBase JSVM serializes each route/cron handler into an isolated context,
// so reusable modules must be required inside each handler rather than through
// outer-scope helper functions.

routerAdd("GET", "/api/sleep-sync/status", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").status(e);
}, $apis.requireAuth("profiles"));

// Compatibility: existing Flutter builds may still call either historical
// Google endpoint. Both now start/use the single Xiaomi Cloud connection.
routerAdd("POST", "/api/sleep-sync/google-health/connect", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/xiaomi/authorize", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").authorize(e);
});

// Keep the stale Google OAuth callback route only so an already-open old
// browser authorization page fails safely instead of becoming a 404. It is not
// used by the active sleep pipeline.
routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    return require(__hooks + "/google_health_sleep_runtime.js").callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    return require(__hooks + "/xiaomi_sleep_runtime.js").remove(e);
}, $apis.requireAuth("profiles"));

// One scheduler tick per hour is sufficient. The runtime retries hourly in the
// wake-up window only while today's sleep is still missing, uses a six-hour
// repair cadence outside it, and retains the weekly 30-day reconciliation.
cronAdd("lifeos_xiaomi_sleep_sync", "0 * * * *", function() {
    return require(__hooks + "/xiaomi_sleep_runtime.js").cron($app);
});

// Immediately after each PocketBase restart, recover from a stale Xiaomi cloud
// feed through an existing Google Health authorization. This never asks for a
// second login and never runs when any recent sleep record is already present.
onBootstrap(function(e) {
    e.next();
    var app = e.app;
    var cutoff = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString();
    var rows = [];
    try { rows = app.findRecordsByFilter("sleep_sync_connections", "enabled = true && provider = 'xiaomi'", "", 500, 0); } catch (_) { return; }
    for (var i = 0; i < rows.length; i++) {
        var userId = String(rows[i].get("user_id") || "");
        if (!userId) continue;
        try {
            app.findFirstRecordByFilter("records", "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}", { uid: userId, cutoff: cutoff });
            continue;
        } catch (_) {}
        var health = null;
        try { health = app.findFirstRecordByFilter("sleep_sync_connections", "user_id = {:uid} && provider = 'google_health'", { uid: userId }); } catch (_) { continue; }
        if (!String(health.get("refresh_token_enc") || "")) continue;
        var originalEnabled = !!health.get("enabled");
        health.set("enabled", true);
        health.set("last_sync_at", "");
        try { app.save(health); } catch (_) { continue; }
        try {
            require(__hooks + "/google_health_sleep_runtime.js").cron(app);
        } catch (_) {
        } finally {
            try {
                health = app.findRecordById("sleep_sync_connections", health.id);
                health.set("enabled", originalEnabled);
                app.save(health);
            } catch (_) {}
        }
    }
});

// Keep the same recovery available between deployments. Xiaomi remains primary;
// Google Health is touched only while the database has no sleep in the last 36h.
cronAdd("lifeos_sleep_cloud_fallback", "17 * * * *", function() {
    var app = $app;
    var cutoff = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString();
    var rows = [];
    try { rows = app.findRecordsByFilter("sleep_sync_connections", "enabled = true && provider = 'xiaomi'", "", 500, 0); } catch (_) { return; }
    for (var i = 0; i < rows.length; i++) {
        var userId = String(rows[i].get("user_id") || "");
        if (!userId) continue;
        try {
            app.findFirstRecordByFilter("records", "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}", { uid: userId, cutoff: cutoff });
            continue;
        } catch (_) {}
        var health = null;
        try { health = app.findFirstRecordByFilter("sleep_sync_connections", "user_id = {:uid} && provider = 'google_health'", { uid: userId }); } catch (_) { continue; }
        if (!String(health.get("refresh_token_enc") || "")) continue;
        var originalEnabled = !!health.get("enabled");
        health.set("enabled", true);
        health.set("last_sync_at", "");
        try { app.save(health); } catch (_) { continue; }
        try {
            require(__hooks + "/google_health_sleep_runtime.js").cron(app);
        } catch (_) {
        } finally {
            try {
                health = app.findRecordById("sleep_sync_connections", health.id);
                health.set("enabled", originalEnabled);
                app.save(health);
            } catch (_) {}
        }
    }
});
