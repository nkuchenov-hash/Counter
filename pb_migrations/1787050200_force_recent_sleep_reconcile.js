/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var connections = [];
    try {
        connections = app.findRecordsByFilter(
            "sleep_sync_connections",
            "enabled = true && provider = 'google_fit'",
            "",
            500,
            0
        );
    } catch (_) {
        return;
    }

    for (var i = 0; i < connections.length; i++) {
        var connection = connections[i];
        connection.set("last_sync_at", "");
        connection.set("last_sync_local_day", "");
        app.save(connection);
    }
}, function(app) {});
