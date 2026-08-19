/// <reference path="../pb_data/types.d.ts" />

// Production sleep synchronization routes. Web/desktop use Google Fit REST,
// because this is the cloud store backing the Google Fit app. The newer Google
// Health API is the successor to Fitbit Web API and is not the source for the
// user's Google Fit sleep history. OAuth state handling is race-safe, and a
// successful OAuth connection remains enabled even if sessions need segment
// fallback for the first data read.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.remove(e);
}, $apis.requireAuth("profiles"));

// Lightweight watchdog: cron checks every minute, while the runtime only calls
// Google Fit for unfinished history work, the configured daily run, or a
// 30-minute catch-up of the most recent 30 days.
cronAdd("lifeos_google_fit_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.cron($app);
});
