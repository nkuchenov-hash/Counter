/// <reference path="../pb_data/types.d.ts" />
// Permanent tombstone for the unauthorized legacy daily-routine bootstrap.
// Any client/server code that still tries to persist those reserved rows is
// rejected. Normal user-created plans, including user-created recurring plans,
// are unaffected.

const __lifeosLegacyRoutineMarker = "LIFEOS_DAILY_ROUTINE_V1|";
const __lifeosLegacyRoutinePlanIdPrefix = "lifeos-routine-v1-";

function __lifeosIsLegacyRoutinePlan(record) {
    const notes = String(record.getString("notes_plain") || "");
    const planId = String(record.getString("plan_id") || "").trim();
    return notes.includes(__lifeosLegacyRoutineMarker) ||
        planId.startsWith(__lifeosLegacyRoutinePlanIdPrefix);
}

function __lifeosRejectLegacyRoutinePlan(e) {
    if (__lifeosIsLegacyRoutinePlan(e.record)) {
        throw new BadRequestError(
            "Legacy automatic daily-routine plans are permanently disabled.",
        );
    }
    e.next();
}

onRecordCreate(__lifeosRejectLegacyRoutinePlan, "plans");
onRecordUpdate(__lifeosRejectLegacyRoutinePlan, "plans");
