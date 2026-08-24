/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization.
// Google Health is the current brand-neutral cloud source because its reconciled
// sleep stream can include data uploaded from Health Connect. Legacy Google Fit
// stays enabled only as a historical fallback until Google Health connects.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/google-health/connect", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

// Compatibility endpoint used by already deployed Flutter clients.
routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

// Compatibility endpoint used by the short-lived Mi Fitness web fallback.
// Cached web clients now receive standard Google Health consent instead of a
// Xiaomi-specific login page.
routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    var sync = require(__hooks + "/google_health_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

// Leave this route only so an already-open stale Xiaomi page fails gracefully;
// no current LIFE OS client starts this flow anymore.
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

cronAdd("lifeos_google_health_sleep_sync", "*/15 * * * *", function() {
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
