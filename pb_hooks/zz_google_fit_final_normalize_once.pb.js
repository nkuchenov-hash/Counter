/// <reference path="../pb_data/types.d.ts" />

// Permanent server tombstone for the removed LIFE OS daily-routine bootstrap.
// PocketBase request/cron callbacks may execute without the hook file's outer
// JavaScript scope, so every registered callback below is deliberately
// self-contained and uses no top-level helper functions or variables.

// Stale app builds are not allowed to recreate the removed seed.
onRecordCreateRequest(function(e) {
    var notes = String(e.record.getString("notes_plain") || "");
    var planId = String(e.record.getString("plan_id") || "").trim();
    if (
        notes.indexOf("LIFEOS_DAILY_ROUTINE_V1|") >= 0 ||
        planId.indexOf("lifeos-routine-v1-") === 0
    ) {
        throw new BadRequestError(
            "Legacy automatic daily-routine plans are permanently disabled.",
        );
    }
    e.next();
}, "plans");

onRecordUpdateRequest(function(e) {
    var notes = String(e.record.getString("notes_plain") || "");
    var planId = String(e.record.getString("plan_id") || "").trim();
    if (
        notes.indexOf("LIFEOS_DAILY_ROUTINE_V1|") >= 0 ||
        planId.indexOf("lifeos-routine-v1-") === 0
    ) {
        throw new BadRequestError(
            "Legacy automatic daily-routine plans are permanently disabled.",
        );
    }
    e.next();
}, "plans");

// Keep cleanup out of the PocketBase bootstrap path. This cron primitive cannot
// prevent server boot and remains a durable cleanup net for historical rows.
cronAdd("lifeos_remove_legacy_daily_routines", "* * * * *", function() {
    var app = $app;
    var rows = app.findRecordsByFilter(
        "plans",
        "notes_plain ~ {:marker} || plan_id ~ {:planIdPrefix}",
        "id",
        0,
        0,
        {
            marker: "LIFEOS_DAILY_ROUTINE_V1|",
            planIdPrefix: "lifeos-routine-v1-",
        },
    );

    for (var i = 0; i < rows.length; i++) {
        var notes = String(rows[i].getString("notes_plain") || "");
        var planId = String(rows[i].getString("plan_id") || "").trim();
        if (
            notes.indexOf("LIFEOS_DAILY_ROUTINE_V1|") >= 0 ||
            planId.indexOf("lifeos-routine-v1-") === 0
        ) {
            app.delete(rows[i]);
        }
    }
});
