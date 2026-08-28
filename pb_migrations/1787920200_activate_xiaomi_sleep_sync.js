/// <reference path="../pb_data/types.d.ts" />

// Xiaomi is the production source for fresh sleep data. Earlier Google/Xiaomi
// transitions could leave an already-authorized Xiaomi row disabled even though
// its server-side token is valid. Normalize the persisted provider state once;
// the regular Xiaomi cron performs the actual cloud fetch after deployment.
migrate(function(app) {
    var rows = [];
    try {
        rows = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'xiaomi'",
            "",
            500,
            0
        );
    } catch (_) {
        return;
    }

    for (var i = 0; i < rows.length; i++) {
        var row = rows[i];
        var userId = String(row.get("user_id") || "");
        if (!userId) continue;

        row.set("enabled", true);
        row.set("status", "connected");
        row.set("last_error", "");
        row.set("last_sync_at", "");
        row.set("last_sync_local_day", "");
        try { row.set("last_full_sync_at", ""); } catch (_) {}
        app.save(row);

        var providers = ["google_fit", "google_health"];
        for (var j = 0; j < providers.length; j++) {
            try {
                var legacy = app.findFirstRecordByFilter(
                    "sleep_sync_connections",
                    "user_id = {:uid} && provider = {:provider}",
                    { uid: userId, provider: providers[j] }
                );
                legacy.set("enabled", false);
                app.save(legacy);
            } catch (_) {}
        }
    }
}, function(app) {
    try {
        var rows = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'xiaomi'",
            "",
            500,
            0
        );
        for (var i = 0; i < rows.length; i++) {
            rows[i].set("enabled", false);
            rows[i].set("status", "disconnected");
            app.save(rows[i]);
        }
    } catch (_) {}
});
