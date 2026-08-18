/// <reference path="../pb_data/types.d.ts" />

migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");

    if (!records.fields.getByName("sleep_stages")) {
        records.fields.add(new JSONField({
            name: "sleep_stages",
            maxSize: 200000
        }));
    }
    if (!records.fields.getByName("sleep_source_name")) {
        records.fields.add(new TextField({
            name: "sleep_source_name",
            max: 500
        }));
    }
    if (!records.fields.getByName("sleep_recovered_from_segments")) {
        records.fields.add(new BoolField({
            name: "sleep_recovered_from_segments"
        }));
    }
    if (!records.fields.getByName("sleep_segment_points")) {
        records.fields.add(new NumberField({
            name: "sleep_segment_points",
            min: 0,
            onlyInt: true
        }));
    }

    app.save(records);
}, function(app) {
    var records = app.findCollectionByNameOrId("records");
    var names = [
        "sleep_stages",
        "sleep_source_name",
        "sleep_recovered_from_segments",
        "sleep_segment_points"
    ];
    for (var i = 0; i < names.length; i++) {
        var field = records.fields.getByName(names[i]);
        if (field) records.fields.removeById(field.id);
    }
    app.save(records);
});
