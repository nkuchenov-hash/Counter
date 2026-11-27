/// <reference path="../pb_data/types.d.ts" />

const PAGE = 256;
const INFINITY = 8640000000000000;
function fieldStr(rec, field) {
    if (typeof rec.getString === "function") return rec.getString(field).trim();
    const v = rec.get(field);
    return v == null ? "" : String(v).trim();
}
function rowId(rec) { return String(rec.id || fieldStr(rec, "id")); }
function isPrimaryRecord(rec) { return fieldStr(rec, "parent_id") === ""; }
function isImportedSleep(rec) {
    return fieldStr(rec, "external_kind").toLowerCase() === "sleep" ||
        fieldStr(rec, "sleep_source") !== "" ||
        (fieldStr(rec, "external_source") === "xiaomi" &&
         /^(sleep|сон)$/i.test(fieldStr(rec, "title")));
}
function parseTimeMs(rec, field) {
    const raw = fieldStr(rec, field);
    if (!raw) return null;
    const value = Date.parse(raw.replace(" ", "T"));
    if (!Number.isFinite(value)) throw new Error("invalid_record_" + field);
    return value;
}
function effectiveEndMs(rec) {
    const end = parseTimeMs(rec, "end_time");
    return end == null ? INFINITY : end;
}
function validateStartEndOrder(rec) {
    const start = parseTimeMs(rec, "start_time");
    const end = parseTimeMs(rec, "end_time");
    if (start == null || (end != null && end < start)) {
        throw new BadRequestError("Invalid primary record interval");
    }
    if (isImportedSleep(rec) && (end == null || end <= start)) {
        throw new BadRequestError("Imported sleep must be a completed positive interval");
    }
}
function iso(ms) { return new Date(ms).toISOString(); }
// PocketBase date filters compare stored strings (space, not ISO T).
function pbDate(ms) { return iso(ms).replace("T", " "); }
function closeAt(rec, time, sleepBoundary = false) {
    rec.set("end_time", iso(time));
    const status = fieldStr(rec, "status").toLowerCase();
    if (sleepBoundary) rec.set("status", "completed");
    else if (status === "running" || !status) rec.set("status", "stopped");
}
function primaryPage(app, filter, order, limit, offset, params) {
    return app.findRecordsByFilter("records",
        "user_id = {:uid} && parent_id = ''" + (filter ? " && " + filter : ""),
        order, limit, offset, params);
}
// Only the immediately relevant later root row is required. Never fetch the
// oldest N records. An open timer is bounded by the next record as well.
function clampSubjectEndAgainstLaterStarts(app, subject, subjectId) {
    const uid = fieldStr(subject, "user_id");
    const start = parseTimeMs(subject, "start_time");
    if (!uid || start == null) throw new BadRequestError("Missing record owner or start");
    const end = effectiveEndMs(subject);
    const later = primaryPage(app,
        "id != {:id} && start_time >= {:start}",
        "+start_time,+id", 1, 0,
        {uid: uid, id: subjectId || rowId(subject), start: pbDate(start)});
    if (!later.length) return;
    const nextStart = parseTimeMs(later[0], "start_time");
    if (nextStart == null || end <= nextStart) return;
    if (nextStart === start || isImportedSleep(subject)) {
        throw new BadRequestError("Conflicting primary record or authoritative sleep interval");
    }
    closeAt(subject, nextStart, isImportedSleep(later[0]));
}
// Collect before writing: shortening rows changes the query predicate, so
// updating while paginating by offset would skip matches.
function overlappingPredecessors(app, subject) {
    const uid = fieldStr(subject, "user_id");
    const start = parseTimeMs(subject, "start_time");
    const params = {uid: uid, id: rowId(subject), start: pbDate(start)};
    const matches = [];
    for (let offset = 0;; offset += PAGE) {
        const rows = primaryPage(app,
            "id != {:id} && start_time < {:start} && (end_time = '' || end_time > {:start})",
            "+start_time,+id", PAGE, offset, params);
        for (const row of rows) {
            if (isImportedSleep(row)) {
                throw new BadRequestError("Record starts inside authoritative sleep");
            }
            matches.push(row);
        }
        if (rows.length < PAGE) break;
    }
    return matches;
}
// Model hook entrypoint, covering REST, server imports and offline replay.
// Save subject and corrections within one transaction. Corrective saves also
// run the model hook but no longer overlap their successor.
function reconcileRecordWrite(event) {
    if (!isPrimaryRecord(event.record)) { event.next(); return; }
    const originalApp = event.app;
    try {
        originalApp.runInTransaction((tx) => {
            event.app = tx;
            const subject = event.record;
            validateStartEndOrder(subject);
            clampSubjectEndAgainstLaterStarts(tx, subject, rowId(subject));
            const predecessors = overlappingPredecessors(tx, subject);
            const start = parseTimeMs(subject, "start_time");
            event.next();
            // Work from latest to earliest so each correction sees its
            // already-corrected successor, not a stale overlapping interval.
            for (let i = predecessors.length - 1; i >= 0; i--) {
                const previous = tx.findRecordById("records", rowId(predecessors[i]));
                if (effectiveEndMs(previous) <= start) continue;
                closeAt(previous, start, isImportedSleep(subject));
                tx.saveNoValidate(previous);
            }
        });
    } finally { event.app = originalApp; }
}
// Explicit maintenance, never on a normal write: page the whole history before
// making any changes. Fail closed on ambiguous same-start/sleep conflicts.
function sanitizeAllPrimaryIntervalsForUser(app, userId) {
    if (!userId) return;
    const rows = [];
    for (let offset = 0;; offset += PAGE) {
        const page = primaryPage(app, "", "+start_time,+id", PAGE, offset, {uid: userId});
        rows.push(...page);
        if (page.length < PAGE) break;
    }
    for (let i = 1; i < rows.length; i++) {
        const previous = rows[i-1], current = rows[i];
        const start = parseTimeMs(current, "start_time");
        if (start == null || effectiveEndMs(previous) <= start) continue;
        if (isImportedSleep(previous) || parseTimeMs(previous, "start_time") === start) {
            throw new BadRequestError("Ambiguous historical interval conflict requires review");
        }
        closeAt(previous, start, isImportedSleep(current));
        app.saveNoValidate(previous);
    }
}
// Repair a previously imported completed sleep without rewriting its bounds.
// Existing scheduled/startup recovery calls this in a transaction.
function repairSleepPredecessors(app, sleep) {
    if (!isPrimaryRecord(sleep) || !isImportedSleep(sleep)) return;
    app.runInTransaction((tx) => {
        const fresh = tx.findRecordById("records", rowId(sleep));
        validateStartEndOrder(fresh);
        const start = parseTimeMs(fresh, "start_time");
        const rows = overlappingPredecessors(tx, fresh);
        for (let i = rows.length - 1; i >= 0; i--) {
            const previous = tx.findRecordById("records", rowId(rows[i]));
            if (effectiveEndMs(previous) <= start) continue;
            closeAt(previous, start, true);
            tx.saveNoValidate(previous);
        }
    });
}
module.exports = {
    fieldStr, isPrimaryRecord, isImportedSleep, validateStartEndOrder,
    clampSubjectEndAgainstLaterStarts, sanitizeAllPrimaryIntervalsForUser,
    reconcileRecordWrite, repairSleepPredecessors,
};
