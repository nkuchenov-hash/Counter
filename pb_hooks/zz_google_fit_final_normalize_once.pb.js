/// <reference path="../pb_data/types.d.ts" />

// Temporary one-time normalization for the already-connected production account.
// It is time-gated so it cannot repeat after the resulting full sync. Remove after
// verification.
cronAdd("lifeos_google_fit_final_normalize_once", "* * * * *", function() {
    var connections = [];
    try {
        connections = $app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true",
            "",
            50,
            0
        );
    } catch (_) { return; }

    var cutoff = Date.UTC(2026, 7, 13, 23, 37, 0);
    for (var i = 0; i < connections.length; i++) {
        var connection = connections[i];
        var raw = String(connection.get("last_full_sync_at") || "");
        if (!raw) continue;
        var lastFull = new Date(raw);
        if (isNaN(lastFull.getTime()) || lastFull.getTime() >= cutoff) continue;
        connection.set("last_full_sync_at", "");
        connection.set("segment_backfill_complete", false);
        connection.set("last_error", "");
        connection.set("status", "connected");
        $app.save(connection);
    }
});
