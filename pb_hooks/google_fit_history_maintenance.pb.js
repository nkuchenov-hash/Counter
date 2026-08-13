/// <reference path="../pb_data/types.d.ts" />

function resetGoogleFitHistoryMarkers(fullSegments) {
    var connections = [];
    try {
        connections = $app.findRecordsByFilter(
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
        connection.set("last_full_sync_at", "");
        if (fullSegments) connection.set("segment_backfill_complete", false);
        $app.save(connection);
    }
}

// Weekly full sessions refresh catches provider records that arrive or are
// corrected outside the normal 30-day window. The main watchdog performs the
// actual Google call on its next minute tick.
cronAdd("lifeos_google_fit_weekly_full_sessions", "17 4 * * 0", function() {
    resetGoogleFitHistoryMarkers(false);
});

// Monthly full sessions + sleep-stage recovery catches very late historical
// segment data while keeping the frequent sync lightweight.
cronAdd("lifeos_google_fit_monthly_full_segments", "43 4 1 * *", function() {
    resetGoogleFitHistoryMarkers(true);
});
