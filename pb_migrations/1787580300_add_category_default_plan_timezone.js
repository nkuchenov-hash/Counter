/// <reference path="../pb_data/types.d.ts" />

// Required by Plans > Time View category default schedules. Kept idempotent so
// redeploying the PocketBase bundle safely repairs schema drift in production.
// Deployment reconciliation trigger: 2026-08-24.
// GitHub-native production deployment trigger: 2026-08-24.
migrate(function(app) {
    var categories = app.findCollectionByNameOrId("categories");
    if (!categories.fields.getByName("default_plan_timezone")) {
        categories.fields.add(new TextField({
            name: "default_plan_timezone",
            max: 255
        }));
        app.save(categories);
    }
}, function(app) {
    try {
        var categories = app.findCollectionByNameOrId("categories");
        var field = categories.fields.getByName("default_plan_timezone");
        if (field) {
            categories.fields.removeById(field.id);
            app.save(categories);
        }
    } catch (_) {}
});
