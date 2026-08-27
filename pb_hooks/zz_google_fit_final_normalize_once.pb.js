/// <reference path="../pb_data/types.d.ts" />

// Permanent server tombstone for the removed LIFE OS daily-routine bootstrap.
// The historical filename is retained to avoid adding a new tracked hook solely
// for this compatibility cleanup. The previous ETNIKA one-shot stays retired.

var __lifeosRoutineMarker = "LIFEOS_DAILY_ROUTINE_V1|";
var __lifeosRoutinePlanIdPrefix = "lifeos-routine-v1-";

function __lifeosIsSeededRoutine(record) {
    var notes = String(record.getString("notes_plain") || "");
    var planId = String(record.getString("plan_id") || "").trim();
    return notes.indexOf(__lifeosRoutineMarker) >= 0 ||
        planId.indexOf(__lifeosRoutinePlanIdPrefix) === 0;
}

function __lifeosRejectSeededRoutineRequest(e) {
    if (__lifeosIsSeededRoutine(e.record)) {
        throw new BadRequestError(
            "Legacy automatic daily-routine plans are permanently disabled.",
        );
    }
    e.next();
}

// Request hooks are intentionally used because they are part of the production
// PocketBase runtime already exercised by records.interval_sanitize.pb.js.
onRecordCreateRequest(__lifeosRejectSeededRoutineRequest, "plans");
onRecordUpdateRequest(__lifeosRejectSeededRoutineRequest, "plans");

// PocketBase restarts after each production hook deployment. Purge every
// historical seeded series for every owner during bootstrap.
onBootstrap(function(e) {
    e.next();

    var rows = e.app.findRecordsByFilter(
        "plans",
        "notes_plain ~ {:marker} || plan_id ~ {:planIdPrefix}",
        "id",
        0,
        0,
        {
            marker: __lifeosRoutineMarker,
            planIdPrefix: __lifeosRoutinePlanIdPrefix,
        },
    );

    for (var i = 0; i < rows.length; i++) {
        if (__lifeosIsSeededRoutine(rows[i])) {
            e.app.delete(rows[i]);
        }
    }
});
