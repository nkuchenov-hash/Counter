/// <reference path="../pb_data/types.d.ts" />

// Force one reconciliation after the Google Health sleep scope becomes part of
// the single sleep-sync OAuth flow. Existing tokens stay intact; the runtime will
// mark only accounts that need the one-time additional consent.
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
