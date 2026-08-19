/// <reference path="../pb_data/types.d.ts" />

// A granted Google Fit refresh token defines the connection. Import errors are
// transient sync state and must not silently disable the user's setting.
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
    } catch (_) {
        return;
    }

    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (!String(row.get("refresh_token_enc") || "")) continue;
        row.set("status", "connected");
        row.set("last_error", "");
        row.set("last_full_sync_at", "");
        row.set("segment_backfill_complete", false);
        row.set("last_sync_at", "");
        app.save(row);
    }
}, function(app) {});
