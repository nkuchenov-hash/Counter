// Server-side stale-sleep recovery. Xiaomi remains primary; Google Health is
// used only when no recent sleep exists in PocketBase and an existing Google
// Health refresh token is available.

function run(app) {
    var xiaomi = [];
    try {
        xiaomi = app.findRecordsByFilter(
            "sleep_sync_connections",
            "enabled = true && provider = 'xiaomi'",
            "",
            500,
            0
        );
    } catch (_) { return { attempted: 0, recovered: 0 }; }

    var attempted = 0;
    var recovered = 0;
    var cutoff = new Date(Date.now() - 36 * 60 * 60 * 1000).toISOString();

    for (var i = 0; i < xiaomi.length; i++) {
        var userId = String(xiaomi[i].get("user_id") || "");
        if (!userId) continue;

        // Any recent sleep record is sufficient; do not duplicate healthy data
        // merely because the primary provider differs.
        try {
            app.findFirstRecordByFilter(
                "records",
                "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}",
                { uid: userId, cutoff: cutoff }
            );
            continue;
        } catch (_) {}

        var health = null;
        try {
            health = app.findFirstRecordByFilter(
                "sleep_sync_connections",
                "user_id = {:uid} && provider = 'google_health'",
                { uid: userId }
            );
        } catch (_) { continue; }

        if (!String(health.get("refresh_token_enc") || "")) continue;
        attempted++;

        // google_health_sleep_runtime.cron() intentionally processes enabled
        // connections only. Enable this one only for the synchronous fallback,
        // force a reconcile, then restore the user's Xiaomi-primary state.
        health.set("enabled", true);
        health.set("last_sync_at", "");
        try { app.save(health); } catch (_) { continue; }

        try {
            require(__hooks + "/google_health_sleep_runtime.js").cron(app);
            try {
                app.findFirstRecordByFilter(
                    "records",
                    "user_id = {:uid} && (title = 'Sleep' || title = 'Сон') && end_time >= {:cutoff}",
                    { uid: userId, cutoff: cutoff }
                );
                recovered++;
            } catch (_) {}
        } catch (_) {
            // Error detail is persisted by the Google Health runtime itself.
        } finally {
            try {
                health = app.findRecordById("sleep_sync_connections", health.id);
                health.set("enabled", false);
                app.save(health);
            } catch (_) {}
        }
    }

    try {
        app.logger().info(
            "sleep cloud fallback complete",
            "attempted", attempted,
            "recovered", recovered
        );
    } catch (_) {}
    return { attempted: attempted, recovered: recovered };
}

module.exports = { run: run };
