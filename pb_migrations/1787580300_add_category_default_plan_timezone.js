/// <reference path="../pb_data/types.d.ts" />

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
