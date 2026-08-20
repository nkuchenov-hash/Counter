/// <reference path="../pb_data/types.d.ts" />

// Restore the existing server-side Google Fit connection after the abandoned
// alternate cloud-source experiment. Preserve the refresh token and user setting,
// discard only the cached access token/error state, and force an immediate reread.
migrate(function(app) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit'",
            "",
            500,
            0
        );
    } catch (_) { return; }

    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        if (!String(row.get("refresh_token_enc") || "")) continue;
        row.set("enabled", true);
        row.set("status", "connected");
        row.set("last_error", "");
        row.set("access_token_enc", "");
        row.set("access_token_expires_at", "");
        row.set("last_sync_at", "");
        try { app.save(row); } catch (_) {}
    }
}, function(app) {});
