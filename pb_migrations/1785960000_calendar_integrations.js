/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var profiles = app.findCollectionByNameOrId("profiles");
    var categories = app.findCollectionByNameOrId("categories");
    var plans = app.findCollectionByNameOrId("plans");

    var integrations = new Collection({
        type: "base",
        name: "calendar_integrations",
        listRule: null,
        viewRule: null,
        createRule: null,
        updateRule: null,
        deleteRule: null,
        fields: [
            { name: "user_id", type: "relation", required: true, maxSelect: 1, collectionId: profiles.id, cascadeDelete: true },
            { name: "provider", type: "select", required: true, maxSelect: 1, values: ["microsoft", "google"] },
            { name: "account_id", type: "text", max: 500 },
            { name: "account_label", type: "text", max: 500 },
            { name: "enabled", type: "bool" },
            { name: "status", type: "select", maxSelect: 1, values: ["disconnected", "connecting", "connected", "syncing", "error"] },
            { name: "calendars_json", type: "json", maxSize: 200000 },
            { name: "sync_past_days", type: "number", min: 0, max: 3650, onlyInt: true },
            { name: "sync_future_days", type: "number", min: 1, max: 3650, onlyInt: true },
            { name: "refresh_token_enc", type: "text", max: 20000 },
            { name: "access_token_enc", type: "text", max: 20000 },
            { name: "access_token_expires_at", type: "date" },
            { name: "oauth_state", type: "text", max: 300 },
            { name: "oauth_state_expires_at", type: "date" },
            { name: "last_sync_at", type: "date" },
            { name: "last_error", type: "text", max: 4000 }
        ],
        indexes: [
            "CREATE UNIQUE INDEX idx_calendar_integrations_user_provider ON calendar_integrations (user_id, provider)"
        ]
    });
    app.save(integrations);

    function addText(name, max) {
        if (!plans.fields.getByName(name)) {
            plans.fields.add(new TextField({ name: name, max: max }));
        }
    }

    addText("external_provider", 50);
    addText("external_account_id", 500);
    addText("external_calendar_id", 1000);
    addText("external_event_id", 1000);
    addText("external_occurrence_key", 1000);
    addText("external_web_url", 4000);
    addText("external_join_url", 4000);

    if (!plans.fields.getByName("external_read_only")) {
        plans.fields.add(new BoolField({ name: "external_read_only" }));
    }
    if (!plans.fields.getByName("external_cancelled")) {
        plans.fields.add(new BoolField({ name: "external_cancelled" }));
    }
    if (!plans.fields.getByName("external_updated_at")) {
        plans.fields.add(new DateField({ name: "external_updated_at" }));
    }
    if (!plans.fields.getByName("external_auto_category_id")) {
        plans.fields.add(new RelationField({
            name: "external_auto_category_id",
            collectionId: categories.id,
            maxSelect: 1,
            cascadeDelete: false
        }));
    }

    plans.addIndex(
        "idx_plans_external_unique",
        true,
        "user_id, external_provider, external_account_id, external_calendar_id, external_event_id, external_occurrence_key",
        "external_provider != '' AND external_event_id != ''"
    );
    app.save(plans);
}, function(app) {
    try {
        var plans = app.findCollectionByNameOrId("plans");
        plans.removeIndex("idx_plans_external_unique");
        var names = [
            "external_provider",
            "external_account_id",
            "external_calendar_id",
            "external_event_id",
            "external_occurrence_key",
            "external_web_url",
            "external_join_url",
            "external_read_only",
            "external_cancelled",
            "external_updated_at",
            "external_auto_category_id"
        ];
        for (var i = 0; i < names.length; i++) {
            var field = plans.fields.getByName(names[i]);
            if (field) plans.fields.removeById(field.id);
        }
        app.save(plans);
    } catch (_) {}
    try { app.delete(app.findCollectionByNameOrId("calendar_integrations")); } catch (_) {}
});
