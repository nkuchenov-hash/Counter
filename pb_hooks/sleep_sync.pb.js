/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Xiaomi/Mi Fitness is the primary source
// for current nights. Google Fit is retained only for historical backfill.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

// Compatibility alias for already-deployed clients. Their internal method name
// still says Google Fit, but authorization now correctly starts Xiaomi cloud.
routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/xiaomi/authorize", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.authorize(e);
});

// Keep the old callback alive only for an OAuth page that may already be open.
routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.remove(e);
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_xiaomi_sleep_sync", "*/15 * * * *", function() {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.cron($app);
});

// Historical fallback only. It is automatically disabled after Xiaomi connects.
cronAdd("lifeos_google_fit_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.cron($app);
});
