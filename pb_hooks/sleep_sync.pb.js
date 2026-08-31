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

// A completed sleep interval is authoritative for the primary timeline boundary.
// If the immediately preceding root record still crosses into sleep, close it
// exactly at sleep.start_time. Child/subrecords are intentionally left alone.
function reconcilePreviousRecordToSleep(app, userId) {
    var sleeps = [];
    try {
        sleeps = app.findRecordsByFilter(
            "records",
            "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi')",
            "-start_time",
            30,
            0,
            { uid: userId }
        );
    } catch (_) { return; }

    for (var s = 0; s < sleeps.length; s++) {
        var sleep = sleeps[s];
        var sleepStart = new Date(String(sleep.get("start_time") || ""));
        if (isNaN(sleepStart.getTime())) continue;

        var prior = [];
        try {
            prior = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && start_time < {:sleepStart}",
                "-start_time",
                50,
                0,
                { uid: userId, sleepStart: sleepStart.toISOString() }
            );
        } catch (_) { continue; }

        for (var p = 0; p < prior.length; p++) {
            var row = prior[p];
            if (row.id === sleep.id) continue;
            var source = String(row.get("sleep_source") || row.get("external_source") || "").toLowerCase();
            var kind = String(row.get("external_kind") || "").toLowerCase();
            var title = String(row.get("title") || "").trim().toLowerCase();
            if (source === "xiaomi" || source === "google_health" || source === "google_fit" || kind === "sleep" || title === "sleep" || title === "сон") continue;
            if (String(row.get("parent_id") || "").trim()) continue;

            var rowEndRaw = String(row.get("end_time") || "").trim();
            var rowEnd = rowEndRaw ? new Date(rowEndRaw) : null;
            if (rowEnd && !isNaN(rowEnd.getTime()) && rowEnd.getTime() <= sleepStart.getTime()) break;

            row.set("end_time", sleepStart.toISOString());
            row.set("status", "completed");
            try { app.save(row); } catch (_) {}
            break;
        }
    }
}

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
    for (var r = 0; r < rows.length; r++) {
        var reconcileUserId = String(rows[r].get("user_id") || "");
        if (reconcileUserId) reconcilePreviousRecordToSleep(app, reconcileUserId);
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
    for (var xr = 0; xr < xiaomiRows.length; xr++) {
        var bootstrapUserId = String(xiaomiRows[xr].get("user_id") || "");
        if (bootstrapUserId) reconcilePreviousRecordToSleep(app, bootstrapUserId);
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
