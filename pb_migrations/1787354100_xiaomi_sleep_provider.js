/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var connections = app.findCollectionByNameOrId("sleep_sync_connections");
    var provider = connections.fields.getByName("provider");
    if (!provider) throw new Error("sleep_sync_connections.provider is missing");
    provider.values = ["google_fit", "xiaomi"];
    app.save(connections);
}, function(app) {
    try {
        var rows = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'xiaomi'",
            "",
            500,
            0
        );
        for (var i = 0; i < rows.length; i++) app.delete(rows[i]);
    } catch (_) {}
    var connections = app.findCollectionByNameOrId("sleep_sync_connections");
    var provider = connections.fields.getByName("provider");
    if (provider) {
        provider.values = ["google_fit"];
        app.save(connections);
    }
});
