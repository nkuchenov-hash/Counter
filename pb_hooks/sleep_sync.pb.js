/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Clients only toggle synchronization and
// consume canonical PocketBase records; sleep ingestion is entirely cloud-side.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

// Route names are kept for Flutter compatibility; the OAuth request grants the
// Google cloud sleep scope used by the server runtime.
routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.remove(e);
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_google_cloud_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_cloud_sleep_runtime.js");
    return sync.cron($app);
});
