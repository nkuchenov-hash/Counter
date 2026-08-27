/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization.
// Google Health remains the current status/run provider while Xiaomi Cloud is
// re-validated against fresh Mi Fitness data. The deployed client still calls
// the historical google-fit connect route, so that route intentionally starts
// the Xiaomi one-time authorization probe without changing the rest of the
// active sleep pipeline yet.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-health/connect", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

// Compatibility endpoint used by already deployed Flutter clients. For the
// current Xiaomi validation this starts the server-owned Xiaomi QR/browser
// login. The Xiaomi callback performs an immediate sleep sync after token save.
routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/xiaomi/authorize", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.authorize(e);
});

// The redirect URI is intentionally kept for the existing Google OAuth client.
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

// Poll eligibility every minute; google_health_sleep_runtime.js keeps the
// actual provider calls throttled to the configured 15-minute catch-up window.
cronAdd("lifeos_google_health_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.cron($app);
});

// Preserve the already-authorized Google Fit history path until Google Health
// completes its first successful sync; the Google Health runtime then disables
// this legacy connection without deleting historical records.
cronAdd("lifeos_google_fit_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.cron($app);
});