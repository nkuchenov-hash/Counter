/// <reference path="../pb_data/types.d.ts" />

// Sleep is intentionally a plain canonical interval: start_time -> end_time.
// Remove experimental detail fields if they reached an earlier deployment.
migrate(function(app) {
    var records = app.findCollectionByNameOrId("records");
    var names = [
        "sleep_stages",
        "sleep_metrics",
        "sleep_source_name",
        "sleep_recovered_from_segments",
        "sleep_segment_points",
        "sleep_metric_points"
    ];
    var changed = false;
    for (var i = 0; i < names.length; i++) {
        if (records.fields.fieldNames().indexOf(names[i]) >= 0) {
            records.fields.removeByName(names[i]);
            changed = true;
        }
    }
    if (changed) app.save(records);
}, function(app) {});
