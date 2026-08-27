/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var plans = app.findCollectionByNameOrId("plans");

    if (!plans.fields.getByName("initial_date_key")) {
        plans.fields.add(new TextField({
            name: "initial_date_key",
            max: 10
        }));
    }
    if (!plans.fields.getByName("is_postponed")) {
        plans.fields.add(new BoolField({
            name: "is_postponed"
        }));
    }

    app.save(plans);
}, function(app) {
    var plans = app.findCollectionByNameOrId("plans");

    var postponed = plans.fields.getByName("is_postponed");
    if (postponed) plans.fields.removeById(postponed.id);

    var initialDateKey = plans.fields.getByName("initial_date_key");
    if (initialDateKey) plans.fields.removeById(initialDateKey.id);

    app.save(plans);
});
