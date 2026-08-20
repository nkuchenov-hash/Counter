/// <reference path="../pb_data/types.d.ts" />

// Clear the cached access token as well as the sync timestamp so the first
// post-deploy reconciliation definitely refreshes authorization state and tests
// the newly required Google Health sleep scope immediately.
migrate(function(app) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            "",
            500,
            0
        );
    } catch (_) { return; }
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (!String(row.get("refresh_token_enc") || "")) continue;
        row.set("access_token_enc", "");
        row.set("access_token_expires_at", "");
        row.set("last_sync_at", "");
        row.set("last_error", "");
        row.set("status", "connected");
        try { app.save(row); } catch (_) {}
    }
}, function(app) {});
