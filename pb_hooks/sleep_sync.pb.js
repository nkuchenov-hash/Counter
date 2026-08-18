/// <reference path="../pb_data/types.d.ts" />

routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.remove(e);
}, $apis.requireAuth("profiles"));

// Lightweight watchdog: cron checks every minute, while the runtime only calls
// Google Health for the configured daily run or a 30-minute catch-up.
cronAdd("lifeos_google_health_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.cron($app);
});
