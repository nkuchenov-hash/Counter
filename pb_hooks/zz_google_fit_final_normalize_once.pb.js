/// <reference path="../pb_data/types.d.ts" />

// Permanent server tombstone for the removed LIFE OS daily-routine bootstrap.
// This file keeps its historical filename to avoid adding another tracked hook
// solely for the cleanup contract. The previous ETNIKA one-shot is retired.

const __lifeosRoutineMarker = "LIFEOS_DAILY_ROUTINE_V1|";
const __lifeosRoutinePlanIdPrefix = "lifeos-routine-v1-";

function __lifeosIsSeededRoutine(record) {
    const notes = String(record.getString("notes_plain") || "");
    const planId = String(record.getString("plan_id") || "").trim();
    return notes.includes(__lifeosRoutineMarker) ||
        planId.startsWith(__lifeosRoutinePlanIdPrefix);
}

function __lifeosRejectSeededRoutine(e) {
    if (__lifeosIsSeededRoutine(e.record)) {
        throw new BadRequestError(
            "Legacy automatic daily-routine plans are permanently disabled.",
        );
    }
    e.next();
}

// Blocks stale app builds and any server code from recreating the removed seed.
onRecordCreate(__lifeosRejectSeededRoutine, "plans");
onRecordUpdate(__lifeosRejectSeededRoutine, "plans");

// PocketBase restarts after each production hook deployment. Purge every
// historical seeded series for every owner before normal operation continues.
onBootstrap((e) => {
    e.next();

    const rows = e.app.findRecordsByFilter(
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

    for (const row of rows) {
        if (__lifeosIsSeededRoutine(row)) {
            e.app.delete(row);
        }
    }
});
