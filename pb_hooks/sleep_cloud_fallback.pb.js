/// <reference path="../pb_data/types.d.ts" />

// Recover immediately after a PocketBase restart if Xiaomi Cloud is stale.
onBootstrap(function(e) {
    e.next();
    try {
        require(__hooks + "/sleep_cloud_fallback_runtime.js").run(e.app);
    } catch (err) {
        try { e.app.logger().error("sleep cloud bootstrap fallback failed", "error", err); } catch (_) {}
    }
});

// Re-check hourly. The runtime is a no-op while any recent sleep record exists.
cronAdd("lifeos_sleep_cloud_fallback", "17 * * * *", function() {
    return require(__hooks + "/sleep_cloud_fallback_runtime.js").run($app);
});
