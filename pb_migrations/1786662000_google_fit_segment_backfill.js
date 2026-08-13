/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var connections = app.findCollectionByNameOrId("sleep_sync_connections");
    if (!connections.fields.getByName("segment_backfill_complete")) {
        connections.fields.add(new BoolField({ name: "segment_backfill_complete" }));
    }
    app.save(connections);
}, function(app) {
    try {
        var connections = app.findCollectionByNameOrId("sleep_sync_connections");
        var field = connections.fields.getByName("segment_backfill_complete");
        if (field) connections.fields.removeById(field.id);
        app.save(connections);
    } catch (_) {}
});
