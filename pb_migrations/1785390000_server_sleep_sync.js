/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var profiles = app.findCollectionByNameOrId("profiles");
    var records = app.findCollectionByNameOrId("records");

    var connections = new Collection({
        type: "base",
        name: "sleep_sync_connections",
        listRule: null,
        viewRule: null,
        createRule: null,
        updateRule: null,
        deleteRule: null,
        fields: [
            { name: "user_id", type: "relation", required: true, maxSelect: 1, collectionId: profiles.id, cascadeDelete: true },
            { name: "provider", type: "select", required: true, maxSelect: 1, values: ["google_health"] },
            { name: "enabled", type: "bool" },
            { name: "daily_sync_minutes", type: "number", min: 0, max: 1439, onlyInt: true },
            { name: "status", type: "select", maxSelect: 1, values: ["disconnected", "connecting", "connected", "syncing", "error"] },
            { name: "refresh_token_enc", type: "text", max: 10000 },
            { name: "access_token_enc", type: "text", max: 10000 },
            { name: "access_token_expires_at", type: "date" },
            { name: "oauth_state", type: "text", max: 200 },
            { name: "oauth_state_expires_at", type: "date" },
            { name: "last_sync_at", type: "date" },
            { name: "last_sync_local_day", type: "text", max: 10 },
            { name: "last_session_count", type: "number", min: 0, onlyInt: true },
            { name: "last_imported_count", type: "number", min: 0, onlyInt: true },
            { name: "last_error", type: "text", max: 2000 }
        ],
        indexes: [
            "CREATE UNIQUE INDEX idx_sleep_sync_user_provider ON sleep_sync_connections (user_id, provider)"
        ]
    });
    app.save(connections);

    if (!records.fields.getByName("sleep_source")) {
        records.fields.add(new TextField({ name: "sleep_source", max: 100 }));
    }
    if (!records.fields.getByName("sleep_external_id")) {
        records.fields.add(new TextField({ name: "sleep_external_id", max: 500 }));
    }
    records.addIndex(
        "idx_records_sleep_external",
        true,
        "user_id, sleep_source, sleep_external_id",
        "sleep_external_id != ''"
    );
    app.save(records);
}, function(app) {
    try {
        var records = app.findCollectionByNameOrId("records");
        records.removeIndex("idx_records_sleep_external");
        var sourceField = records.fields.getByName("sleep_source");
        if (sourceField) records.fields.removeById(sourceField.id);
        var externalField = records.fields.getByName("sleep_external_id");
        if (externalField) records.fields.removeById(externalField.id);
        app.save(records);
    } catch (_) {}
    try { app.delete(app.findCollectionByNameOrId("sleep_sync_connections")); } catch (_) {}
});
