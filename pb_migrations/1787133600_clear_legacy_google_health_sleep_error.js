/// <reference path="../pb_data/types.d.ts" />

// The sleep connection was temporarily routed through Google Health during the
// Google Fit migration work. A successful Google Fit OAuth may therefore still
// have a stale Google Health read error stored on the same connection record.
// That error must not force an already-authorized Google Fit connection back to
// the disconnected UI state.
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
    } catch (_) {
        return;
    }

    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var hasRefresh = String(row.get("refresh_token_enc") || "").length > 0;
        if (!hasRefresh) continue;

        var error = String(row.get("last_error") || "");
        var lower = error.toLowerCase();
        var staleGoogleHealth = lower.indexOf("google health") >= 0;
        if (!staleGoogleHealth) continue;

        row.set("last_error", "");
        if (String(row.get("status") || "").toLowerCase() === "error" ||
            String(row.get("status") || "").toLowerCase() === "disconnected") {
            row.set("status", "connected");
        }
        app.save(row);
    }
}, function(app) {});
