/// <reference path="../pb_data/types.d.ts" />

// Rich Notes parity for Timeline records: keep a searchable plain projection
// in records.note and persist the canonical LIFE OS block document separately.
migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");

    if (!records.fields.getByName("notes_delta")) {
        records.fields.add(new JSONField({
            name: "notes_delta",
            maxSize: 5242880
        }));
    }

    app.save(records);
}, function(app) {
    var records = app.findCollectionByNameOrId("records");
    var field = records.fields.getByName("notes_delta");
    if (field) records.fields.removeById(field.id);
    app.save(records);
});
