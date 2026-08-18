/// <reference path="../pb_data/types.d.ts" />

function hasSleepField(fields, name) {
    return fields.fieldNames().indexOf(name) >= 0;
}

migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");

    // Idempotent follow-up migration: the first sleep-detail migration may
    // already have been applied in production before later fields were added.
    if (!hasSleepField(records.fields, "sleep_stages")) {
        records.fields.add(new JSONField({ name: "sleep_stages", maxSize: 200000 }));
    }
    if (!hasSleepField(records.fields, "sleep_metrics")) {
        records.fields.add(new JSONField({ name: "sleep_metrics", maxSize: 500000 }));
    }
    if (!hasSleepField(records.fields, "sleep_source_name")) {
        records.fields.add(new TextField({ name: "sleep_source_name", max: 500 }));
    }
    if (!hasSleepField(records.fields, "sleep_recovered_from_segments")) {
        records.fields.add(new BoolField({ name: "sleep_recovered_from_segments" }));
    }
    if (!hasSleepField(records.fields, "sleep_segment_points")) {
        records.fields.add(new NumberField({
            name: "sleep_segment_points",
            min: 0,
            onlyInt: true
        }));
    }
    if (!hasSleepField(records.fields, "sleep_metric_points")) {
        records.fields.add(new NumberField({
            name: "sleep_metric_points",
            min: 0,
            onlyInt: true
        }));
    }
    app.save(records);

    // Existing users already completed the old segment recovery pass before
    // stage detail was persisted. Mark only that pass incomplete so the next
    // Google Fit cron/run re-reads the available segment history and enriches
    // existing sleep records by overlap instead of duplicating them.
    var connections = [];
    try {
        connections = app.findRecordsByFilter(
            "sleep_sync_connections",
            "provider = 'google_fit'",
            "",
            500,
            0
        );
    } catch (_) {}
    for (var i = 0; i < connections.length; i++) {
        connections[i].set("segment_backfill_complete", false);
        app.save(connections[i]);
    }
}, function(app) {
    var records = app.findCollectionByNameOrId("records");
    records.fields.removeByName("sleep_metrics");
    records.fields.removeByName("sleep_metric_points");
    app.save(records);
});
