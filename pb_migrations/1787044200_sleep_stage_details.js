/// <reference path="../pb_data/types.d.ts" />

function hasField(fields, name) {
    return fields.fieldNames().indexOf(name) >= 0;
}

migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");

    if (!hasField(records.fields, "sleep_stages")) {
        records.fields.add(new JSONField({
            name: "sleep_stages",
            maxSize: 200000
        }));
    }
    if (!hasField(records.fields, "sleep_source_name")) {
        records.fields.add(new TextField({
            name: "sleep_source_name",
            max: 500
        }));
    }
    if (!hasField(records.fields, "sleep_recovered_from_segments")) {
        records.fields.add(new BoolField({
            name: "sleep_recovered_from_segments"
        }));
    }
    if (!hasField(records.fields, "sleep_segment_points")) {
        records.fields.add(new NumberField({
            name: "sleep_segment_points",
            min: 0,
            onlyInt: true
        }));
    }

    app.save(records);
}, function(app) {
    var records = app.findCollectionByNameOrId("records");
    records.fields.removeByName("sleep_stages");
    records.fields.removeByName("sleep_source_name");
    records.fields.removeByName("sleep_recovered_from_segments");
    records.fields.removeByName("sleep_segment_points");
    app.save(records);
});
