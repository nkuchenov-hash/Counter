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

// Retry every 15 minutes while the current local waking day has no Xiaomi sleep.
// Do not wait for an arbitrary morning clock time: if Xiaomi already published
// the completed night, LIFE OS should import it immediately.
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

    // Remove only genuine duplicate versions of the same Xiaomi night. Xiaomi
    // can revise bedtime/wake boundaries, which changes the source external id.
    // Strongly overlapping records are the same night; separate naps remain.
    for (var d = 0; d < rows.length; d++) {
        var dedupeUserId = String(rows[d].get("user_id") || "");
        if (!dedupeUserId) continue;
        var recentSleep = [];
        try {
            recentSleep = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi') && end_time >= {:cutoff}",
                "-end_time",
                100,
                0,
                { uid: dedupeUserId, cutoff: new Date(Date.now() - 45 * 24 * 60 * 60 * 1000).toISOString() }
            );
        } catch (_) { continue; }
        var removed = {};
        for (var a = 0; a < recentSleep.length; a++) {
            var first = recentSleep[a];
            if (removed[first.id]) continue;
            var firstStart = new Date(String(first.get("start_time") || ""));
            var firstEnd = new Date(String(first.get("end_time") || ""));
            if (isNaN(firstStart.getTime()) || isNaN(firstEnd.getTime()) || firstEnd.getTime() <= firstStart.getTime()) continue;
            for (var b = a + 1; b < recentSleep.length; b++) {
                var second = recentSleep[b];
                if (removed[second.id]) continue;
                var secondStart = new Date(String(second.get("start_time") || ""));
                var secondEnd = new Date(String(second.get("end_time") || ""));
                if (isNaN(secondStart.getTime()) || isNaN(secondEnd.getTime()) || secondEnd.getTime() <= secondStart.getTime()) continue;
                var overlap = Math.max(0, Math.min(firstEnd.getTime(), secondEnd.getTime()) - Math.max(firstStart.getTime(), secondStart.getTime()));
                var firstDuration = firstEnd.getTime() - firstStart.getTime();
                var secondDuration = secondEnd.getTime() - secondStart.getTime();
                var shorter = Math.min(firstDuration, secondDuration);
                if (shorter <= 0 || overlap / shorter < 0.60) continue;
                var keeper = firstDuration >= secondDuration ? first : second;
                var duplicate = keeper.id === first.id ? second : first;
                try {
                    app.delete(duplicate);
                    removed[duplicate.id] = true;
                } catch (_) {}
                if (keeper.id === second.id) {
                    first = second;
                    firstStart = secondStart;
                    firstEnd = secondEnd;
                    firstDuration = secondDuration;
                }
            }
        }
    }

    // Keep the primary timeline continuous around sleep. Once a completed Xiaomi
    // sleep exists, the nearest preceding non-sleep record may not continue
    // through sleep; close it exactly at sleep.start_time.
    for (var r = 0; r < rows.length; r++) {
        var reconcileUserId = String(rows[r].get("user_id") || "");
        if (!reconcileUserId) continue;
        var sleepRows = [];
        try {
            sleepRows = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi')",
                "-start_time",
                1,
                0,
                { uid: reconcileUserId }
            );
        } catch (_) { continue; }
        if (!sleepRows.length) continue;
        var sleep = sleepRows[0];
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

// Immediately after each PocketBase restart, force one Xiaomi pass whenever
// today's Xiaomi sleep is absent. This makes deploy/restart self-healing and is
// intentionally independent from a configured morning clock time.
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

    // Run duplicate repair at startup as well, so historical revised Xiaomi
    // sessions are cleaned immediately instead of waiting for the next cron tick.
    for (var xd = 0; xd < xiaomiRows.length; xd++) {
        var startupDedupeUserId = String(xiaomiRows[xd].get("user_id") || "");
        if (!startupDedupeUserId) continue;
        var startupRecentSleep = [];
        try {
            startupRecentSleep = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi') && end_time >= {:cutoff}",
                "-end_time",
                100,
                0,
                { uid: startupDedupeUserId, cutoff: new Date(Date.now() - 45 * 24 * 60 * 60 * 1000).toISOString() }
            );
        } catch (_) { continue; }
        var startupRemoved = {};
        for (var sa = 0; sa < startupRecentSleep.length; sa++) {
            var startupFirst = startupRecentSleep[sa];
            if (startupRemoved[startupFirst.id]) continue;
            var startupFirstStart = new Date(String(startupFirst.get("start_time") || ""));
            var startupFirstEnd = new Date(String(startupFirst.get("end_time") || ""));
            if (isNaN(startupFirstStart.getTime()) || isNaN(startupFirstEnd.getTime()) || startupFirstEnd.getTime() <= startupFirstStart.getTime()) continue;
            for (var sb = sa + 1; sb < startupRecentSleep.length; sb++) {
                var startupSecond = startupRecentSleep[sb];
                if (startupRemoved[startupSecond.id]) continue;
                var startupSecondStart = new Date(String(startupSecond.get("start_time") || ""));
                var startupSecondEnd = new Date(String(startupSecond.get("end_time") || ""));
                if (isNaN(startupSecondStart.getTime()) || isNaN(startupSecondEnd.getTime()) || startupSecondEnd.getTime() <= startupSecondStart.getTime()) continue;
                var startupOverlap = Math.max(0, Math.min(startupFirstEnd.getTime(), startupSecondEnd.getTime()) - Math.max(startupFirstStart.getTime(), startupSecondStart.getTime()));
                var startupFirstDuration = startupFirstEnd.getTime() - startupFirstStart.getTime();
                var startupSecondDuration = startupSecondEnd.getTime() - startupSecondStart.getTime();
                var startupShorter = Math.min(startupFirstDuration, startupSecondDuration);
                if (startupShorter <= 0 || startupOverlap / startupShorter < 0.60) continue;
                var startupKeeper = startupFirstDuration >= startupSecondDuration ? startupFirst : startupSecond;
                var startupDuplicate = startupKeeper.id === startupFirst.id ? startupSecond : startupFirst;
                try {
                    app.delete(startupDuplicate);
                    startupRemoved[startupDuplicate.id] = true;
                } catch (_) {}
                if (startupKeeper.id === startupSecond.id) {
                    startupFirst = startupSecond;
                    startupFirstStart = startupSecondStart;
                    startupFirstEnd = startupSecondEnd;
                    startupFirstDuration = startupSecondDuration;
                }
            }
        }
    }

    // Run the same boundary repair once at startup so an already-imported sleep
    // immediately repairs a stale running record without waiting for :00/:15/:30/:45.
    for (var xr = 0; xr < xiaomiRows.length; xr++) {
        var startupUserId = String(xiaomiRows[xr].get("user_id") || "");
        if (!startupUserId) continue;
        var startupSleepRows = [];
        try {
            startupSleepRows = app.findRecordsByFilter(
                "records",
                "user_id = {:uid} && (sleep_source = 'xiaomi' || external_source = 'xiaomi')",
                "-start_time",
                1,
                0,
                { uid: startupUserId }
            );
        } catch (_) { continue; }
        if (!startupSleepRows.length) continue;
        var startupSleep = startupSleepRows[0];
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
    var fallbackRows = [];
    try { fallbackRows = app.findRecordsByFilter("sleep_sync_connections", "enabled = true && provider = 'xiaomi'", "", 500, 0); } catch (_) { return; }
    for (var fi = 0; fi < fallbackRows.length; fi++) {
        var fallbackUserId = String(fallbackRows[fi].get("user_id") || "");
        if (!fallbackUserId) continue;
        try {
            app.findFirstRecordByFilter("records", "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}", { uid: fallbackUserId, cutoff: cutoff });
            continue;
        } catch (_) {}
        var health = null;
        try { health = app.findFirstRecordByFilter("sleep_sync_connections", "user_id = {:uid} && provider = 'google_health'", { uid: fallbackUserId }); } catch (_) { continue; }
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
