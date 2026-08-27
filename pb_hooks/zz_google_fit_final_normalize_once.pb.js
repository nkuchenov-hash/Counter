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

// Stale app builds are not allowed to recreate the removed seed.
onRecordCreateRequest(__lifeosRejectSeededRoutineRequest, "plans");
onRecordUpdateRequest(__lifeosRejectSeededRoutineRequest, "plans");

function __lifeosPurgeSeededRoutines(app) {
    var rows = app.findRecordsByFilter(
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
            app.delete(rows[i]);
        }
    }
}

// Keep cleanup out of the PocketBase bootstrap path. This cron primitive is
// already used by the production sleep runtime and cannot prevent server boot.
// It also acts as a durable cleanup net for any legacy rows already present.
cronAdd("lifeos_remove_legacy_daily_routines", "* * * * *", function() {
    __lifeosPurgeSeededRoutines($app);
});
