/// <reference path="../pb_data/types.d.ts" />

// Server-owned sleep synchronization. Xiaomi/Mi Fitness is the primary source
// for current nights; Google Fit remains available as legacy/history fallback.
routerAdd("GET", "/api/sleep-sync/status", function(e) {
    var xiaomi = require(__hooks + "/xiaomi_sleep_runtime.js");
    if (xiaomi.exists(e.app, e.auth.id)) return xiaomi.status(e);
    var fit = require(__hooks + "/google_fit_sleep_runtime.js");
    return fit.status(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/xiaomi/connect", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/xiaomi/authorize", function(e) {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.authorize(e);
});

// Legacy/history source. Kept so an existing Google authorization and historic
// records remain usable; new clients connect Xiaomi for fresh sleep.
routerAdd("POST", "/api/sleep-sync/google-fit/connect", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.connect(e);
}, $apis.requireAuth("profiles"));

routerAdd("GET", "/api/sleep-sync/google-fit/callback", function(e) {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.callback(e);
});

routerAdd("POST", "/api/sleep-sync/settings", function(e) {
    var xiaomi = require(__hooks + "/xiaomi_sleep_runtime.js");
    if (xiaomi.exists(e.app, e.auth.id)) return xiaomi.settings(e);
    var fit = require(__hooks + "/google_fit_sleep_runtime.js");
    return fit.settings(e);
}, $apis.requireAuth("profiles"));

routerAdd("POST", "/api/sleep-sync/run", function(e) {
    var xiaomi = require(__hooks + "/xiaomi_sleep_runtime.js");
    if (xiaomi.exists(e.app, e.auth.id)) return xiaomi.run(e);
    var fit = require(__hooks + "/google_fit_sleep_runtime.js");
    return fit.run(e);
}, $apis.requireAuth("profiles"));

routerAdd("DELETE", "/api/sleep-sync/connection", function(e) {
    var xiaomi = require(__hooks + "/xiaomi_sleep_runtime.js");
    if (xiaomi.exists(e.app, e.auth.id)) return xiaomi.remove(e);
    var fit = require(__hooks + "/google_fit_sleep_runtime.js");
    return fit.remove(e);
}, $apis.requireAuth("profiles"));

cronAdd("lifeos_xiaomi_sleep_sync", "*/15 * * * *", function() {
    var sync = require(__hooks + "/xiaomi_sleep_runtime.js");
    return sync.cron($app);
});

cronAdd("lifeos_google_fit_sleep_sync", "* * * * *", function() {
    var sync = require(__hooks + "/google_fit_sleep_runtime.js");
    return sync.cron($app);
});
