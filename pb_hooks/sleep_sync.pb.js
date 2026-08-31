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

// From the configured morning start onward, retry every 15 minutes until the
// current local day's Xiaomi sleep exists in PocketBase. Clearing last_sync_at
// only for a missing day bypasses the runtime's maintenance throttle without
// generating any extra Xiaomi calls after today's record has arrived.
cronAdd("lifeos_xiaomi_sleep_sync", "*/15 * * * *", function() {
    var app = $app;
    var rows = [];
    try { rows = app.findRecordsByFilter("sleep_sync_connections", "enabled = true && provider = 'xiaomi'", "", 500, 0); } catch (_) { return; }
    var now = new Date();
    for (var i = 0; i < rows.length; i++) {
        var connection = rows[i];
        var userId = String(connection.get("user_id") || "");
        if (!userId) continue;
        var profile = null;
        try { profile = app.findRecordById("profiles", userId); } catch (_) { continue; }
        var offsetHours = Number(profile.get("timezone_offset") || 0);
        var local = new Date(now.getTime() + offsetHours * 60 * 60 * 1000);
        var localMinutes = local.getUTCHours() * 60 + local.getUTCMinutes();
        var requestedStart = Number(connection.get("daily_sync_minutes") || 8 * 60);
        var morningStart = requestedStart >= 4 * 60 && requestedStart < 12 * 60 ? requestedStart : 8 * 60;
        if (localMinutes < morningStart) continue;
        var localDayStartMs = Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()) - offsetHours * 60 * 60 * 1000;
        var localDayEndMs = localDayStartMs + 24 * 60 * 60 * 1000;
        try {
            app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi') && end_time >= {:start} && end_time < {:end}",
                { uid: userId, start: new Date(localDayStartMs).toISOString(), end: new Date(localDayEndMs).toISOString() }
            );
            continue;
        } catch (_) {}
        connection.set("last_sync_at", "");
        try { app.save(connection); } catch (_) {}
    }

    try { require(__hooks + "/xiaomi_sleep_runtime.js").cron(app); } catch (_) {}

    // Keep the primary timeline continuous around sleep. Once a completed Xiaomi
    // sleep exists, the nearest preceding non-sleep record may not continue
    // through sleep; close it exactly at sleep.start_time. The entire reconcile
    // stays inside this cron handler because PocketBase JSVM isolates handlers.
    for (var r = 0; r < rows.length; r++) {
        var reconcileUserId = String(rows[r].get("user_id") || "");
        if (!reconcileUserId) continue;
        var sleep = null;
        try {
            sleep = app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi')",
                { uid: reconcileUserId }
            );
        } catch (_) { continue; }
        var sleepStart = new Date(String(sleep.get("start_time") || ""));
        if (isNaN(sleepStart.getTime())) continue;
        var prior = [];
        try {
            prior = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && start_time < {:sleepStart}",
                "-start_time",
                30,
                0,
                { uid: reconcileUserId, sleepStart: sleepStart.toISOString() }
            );
        } catch (_) { continue; }
        for (var p = 0; p < prior.length; p++) {
            var previous = prior[p];
            var previousTitle = String(previous.get("title") || "").trim().toLowerCase();
            var previousKind = String(previous.get("external_kind") || "").trim().toLowerCase();
            var previousSleepSource = String(previous.get("sleep_source") || "").trim().toLowerCase();
            if (previousTitle === "sleep" || previousTitle === "сон" || previousKind === "sleep" || previousSleepSource) continue;
            var previousStart = new Date(String(previous.get("start_time") || ""));
            if (isNaN(previousStart.getTime()) || previousStart.getTime() >= sleepStart.getTime()) continue;
            var previousEndRaw = String(previous.get("end_time") || "").trim();
            var previousEnd = previousEndRaw ? new Date(previousEndRaw) : null;
            if (previousEnd && !isNaN(previousEnd.getTime()) && previousEnd.getTime() <= sleepStart.getTime()) break;
            previous.set("end_time", sleepStart.toISOString());
            previous.set("status", "completed");
            try { app.save(previous); } catch (_) {}
            break;
        }
    }
});

// Immediately after each PocketBase restart, force one Xiaomi pass when the
// configured morning start has passed and today's Xiaomi sleep is still absent.
// This also makes a deployment self-healing instead of waiting for the next
// quarter-hour scheduler tick.
onBootstrap(function(e) {
    e.next();
    var app = e.app;
    var now = new Date();
    var xiaomiRows = [];
    try { xiaomiRows = app.findRecordsByFilter("sleep_sync_connections", "enabled = true && provider = 'xiaomi'", "", 500, 0); } catch (_) {}
    for (var x = 0; x < xiaomiRows.length; x++) {
        var xiaomi = xiaomiRows[x];
        var xiaomiUserId = String(xiaomi.get("user_id") || "");
        if (!xiaomiUserId) continue;
        var xiaomiProfile = null;
        try { xiaomiProfile = app.findRecordById("profiles", xiaomiUserId); } catch (_) { continue; }
        var xiaomiOffset = Number(xiaomiProfile.get("timezone_offset") || 0);
        var xiaomiLocal = new Date(now.getTime() + xiaomiOffset * 60 * 60 * 1000);
        var xiaomiMinutes = xiaomiLocal.getUTCHours() * 60 + xiaomiLocal.getUTCMinutes();
        var xiaomiRequestedStart = Number(xiaomi.get("daily_sync_minutes") || 8 * 60);
        var xiaomiMorningStart = xiaomiRequestedStart >= 4 * 60 && xiaomiRequestedStart < 12 * 60 ? xiaomiRequestedStart : 8 * 60;
        if (xiaomiMinutes < xiaomiMorningStart) continue;
        var xiaomiDayStartMs = Date.UTC(xiaomiLocal.getUTCFullYear(), xiaomiLocal.getUTCMonth(), xiaomiLocal.getUTCDate()) - xiaomiOffset * 60 * 60 * 1000;
        var xiaomiDayEndMs = xiaomiDayStartMs + 24 * 60 * 60 * 1000;
        try {
            app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi') && end_time >= {:start} && end_time < {:end}",
                { uid: xiaomiUserId, start: new Date(xiaomiDayStartMs).toISOString(), end: new Date(xiaomiDayEndMs).toISOString() }
            );
            continue;
        } catch (_) {}
        xiaomi.set("last_sync_at", "");
        try { app.save(xiaomi); } catch (_) {}
    }
    try { require(__hooks + "/xiaomi_sleep_runtime.js").cron(app); } catch (_) {}

    // Run the same boundary repair once at startup so an already-imported sleep
    // immediately repairs a stale running record without waiting for :00/:15/:30/:45.
    for (var xr = 0; xr < xiaomiRows.length; xr++) {
        var startupUserId = String(xiaomiRows[xr].get("user_id") || "");
        if (!startupUserId) continue;
        var startupSleep = null;
        try {
            startupSleep = app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi')",
                { uid: startupUserId }
            );
        } catch (_) { continue; }
        var startupSleepStart = new Date(String(startupSleep.get("start_time") || ""));
        if (isNaN(startupSleepStart.getTime())) continue;
        var startupPrior = [];
        try {
            startupPrior = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && start_time < {:sleepStart}",
                "-start_time",
                30,
                0,
                { uid: startupUserId, sleepStart: startupSleepStart.toISOString() }
            );
        } catch (_) { continue; }
        for (var sp = 0; sp < startupPrior.length; sp++) {
            var startupPrevious = startupPrior[sp];
            var startupTitle = String(startupPrevious.get("title") || "").trim().toLowerCase();
            var startupKind = String(startupPrevious.get("external_kind") || "").trim().toLowerCase();
            var startupSleepSource = String(startupPrevious.get("sleep_source") || "").trim().toLowerCase();
            if (startupTitle === "sleep" || startupTitle === "сон" || startupKind === "sleep" || startupSleepSource) continue;
            var startupEndRaw = String(startupPrevious.get("end_time") || "").trim();
            var startupEnd = startupEndRaw ? new Date(startupEndRaw) : null;
            if (startupEnd && !isNaN(startupEnd.getTime()) && startupEnd.getTime() <= startupSleepStart.getTime()) break;
            startupPrevious.set("end_time", startupSleepStart.toISOString());
            startupPrevious.set("status", "completed");
            try { app.save(startupPrevious); } catch (_) {}
            break;
        }
    }

    // Recover from a stale Xiaomi cloud feed through an existing Google Health
    // authorization. This never asks for a second login and never runs when any
    // recent sleep record is already present.
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
