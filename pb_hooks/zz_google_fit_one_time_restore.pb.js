/// <reference path="../pb_data/types.d.ts" />

// Temporary one-time repair after the segment-recovery rollout. The earlier
// recovery pass cleaned historical provider duplicates while only the recent
// sessions window was loaded. Reset the full-session marker exactly once for the
// affected already-connected records; the normal watchdog then restores the
// complete Google Fit sessions history. Remove this hook after verification.
cronAdd("lifeos_google_fit_one_time_restore", "* * * * *", function() {
    var connections = [];
    try {
        connections = $app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit' && enabled = true && segment_backfill_complete = true && last_session_count < 100",
            "",
            50,
            0
        );
    } catch (_) { return; }

    for (var i = 0; i < connections.length; i++) {
        var connection = connections[i];
        if (!String(connection.get("last_full_sync_at") || "")) continue;
        connection.set("last_full_sync_at", "");
        connection.set("last_error", "");
        connection.set("status", "connected");
        $app.save(connection);
    }
});
