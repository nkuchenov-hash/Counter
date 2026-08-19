/// <reference path="../pb_data/types.d.ts" />

// One-time production nudge after hardening the cloud Google Fit reader.
// Keep OAuth/token state intact; only force the next server cron to reread
// the recent 30-day sleep window with the current recovery implementation.
migrate(function(app) {
    var connections = [];
    try {
        connections = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            "",
            500,
            0
        );
    } catch (_) { return; }

    for (var i = 0; i < connections.length; i++) {
        var connection = connections[i];
        if (!String(connection.get("refresh_token_enc") || "")) continue;
        connection.set("status", "connected");
        connection.set("last_error", "");
        connection.set("last_sync_at", "");
        try { app.save(connection); } catch (_) {}
    }
}, function(app) {});
