/// <reference path="../pb_data/types.d.ts" />
// Deployment marker: publish the verified People server bundle after documentation gates cleared.

migrate(function(app) {
    var connections = app.findCollectionByNameOrId("sleep_sync_connections");
    if (!connections.fields.getByName("last_full_sync_at")) {
        connections.fields.add(new DateField({ name: "last_full_sync_at" }));
    }
    app.save(connections);
}, function(app) {
    try {
        var connections = app.findCollectionByNameOrId("sleep_sync_connections");
        var field = connections.fields.getByName("last_full_sync_at");
        if (field) connections.fields.removeById(field.id);
        app.save(connections);
    } catch (_) {}
});