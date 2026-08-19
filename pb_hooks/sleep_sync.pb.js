/// <reference path="../pb_data/types.d.ts" />

// Production sleep synchronization routes. Web/desktop use Google Fit REST,
// because this is the cloud store backing the Google Fit app. OAuth state handling
// is race-safe, and a successful connection remains enabled even if sessions need
// segment fallback for a data read.
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

// Temporary production-only diagnostic route. The workflow removes this hook
// immediately after reading sanitized source counts/dates.
routerAdd("GET", "/api/__lifeos_sleep_cloud_probe_5f7c9a2e", function(e) {
    var probe = require(__hooks + "/sleep_cloud_probe.js");
    return probe.run(e);
});

cronAdd("lifeos_google_fit_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.cron($app);
});
