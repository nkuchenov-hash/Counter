/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");
    var connections = app.findCollectionByNameOrId("sleep_sync_connections");

    function addText(name, max) {
        if (!records.fields.getByName(name)) {
            records.fields.add(new TextField({ name: name, max: max }));
        }
    }

    addText("external_source", 100);
    addText("external_id", 1000);
    addText("external_kind", 100);
    if (!records.fields.getByName("external_updated_at")) {
        records.fields.add(new DateField({ name: "external_updated_at" }));
    }
    records.addIndex(
        "idx_records_external_unique",
        true,
        "user_id, external_source, external_id",
        "external_source != '' AND external_id != ''"
    );
    app.save(records);

    if (!connections.fields.getByName("last_sleep_count")) {
        connections.fields.add(new NumberField({ name: "last_sleep_count", min: 0, onlyInt: true }));
    }
    if (!connections.fields.getByName("last_activity_count")) {
        connections.fields.add(new NumberField({ name: "last_activity_count", min: 0, onlyInt: true }));
    }
    app.save(connections);
}, function(app) {
    try {
        var connections = app.findCollectionByNameOrId("sleep_sync_connections");
        var connectionNames = ["last_sleep_count", "last_activity_count"];
        for (var i = 0; i < connectionNames.length; i++) {
            var connectionField = connections.fields.getByName(connectionNames[i]);
            if (connectionField) connections.fields.removeById(connectionField.id);
        }
        app.save(connections);
    } catch (_) {}

    try {
        var records = app.findCollectionByNameOrId("records");
        records.removeIndex("idx_records_external_unique");
        var names = ["external_source", "external_id", "external_kind", "external_updated_at"];
        for (var j = 0; j < names.length; j++) {
            var field = records.fields.getByName(names[j]);
            if (field) records.fields.removeById(field.id);
        }
        app.save(records);
    } catch (_) {}
});