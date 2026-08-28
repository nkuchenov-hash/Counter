/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Production source: Xiaomi Cloud.
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