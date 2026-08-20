/// <reference path="../pb_data/types.d.ts" />

// Existing Google Fit OAuth tokens predate the Google Health sleep scope. Mark
// them explicitly so the single Sleep sync switch immediately asks for the one
// additional consent instead of waiting for a failed background API call.
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
        row.set("last_error", "google_health_scope_required");
        row.set("status", "connected");
        try { app.save(row); } catch (_) {}
    }
}, function(app) {});
