/// <reference path="../pb_data/types.d.ts" />

/** @param {RecordModel} rec @param {string} field */
function fieldStr(rec, field) {
    const v = rec.get(field);
    return v == null ? "" : String(v).trim();
}

/** @param {RecordModel} rec */
function isPrimaryRecord(rec) {
    return fieldStr(rec, "parent_id").length === 0;
}

/** @param {RecordModel} rec @param {string} field */
function parseTimeMs(rec, field) {
    const raw = rec.get(field);
    if (!raw) return null;
    const d = new Date(String(raw));
    const t = d.getTime();
    return Number.isNaN(t) ? null : t;
}

/** @param {RecordModel} rec */
function effectiveEndMs(rec) {
    const t = parseTimeMs(rec, "end_time");
    if (t != null) return t;
    return 8640000000000000;
}

/** @param {RecordModel} rec */
function validateStartEndOrder(rec) {
    const s = parseTimeMs(rec, "start_time");
    if (s == null) return;
    const e = parseTimeMs(rec, "end_time");
    if (e == null) return;
    if (e < s) {
        throw new BadRequestError("end_time must be >= start_time");
    }
}

/** @param {core.App} app @param {RecordModel} subject @param {string} subjectId */
function clampSubjectEndAgainstLaterStarts(app, subject, subjectId) {
    const uid = fieldStr(subject, "user_id");
    if (!uid) return;
    const subStart = parseTimeMs(subject, "start_time");
    if (subStart == null) return;
    const subEnd = parseTimeMs(subject, "end_time");
    if (subEnd == null) return;

    let others = [];
    try {
        others = app.findRecordsByFilter(
            "records",
            "user_id = {:uid}",
            "+start_time",
            2000,
            0,
            { uid: uid },
        );
    } catch (_) {
        return;
    }

    let minLaterStart = null;
    for (let i = 0; i < others.length; i++) {
        const o = others[i];
        if (!isPrimaryRecord(o)) continue;
        const oid = fieldStr(o, "id");
        if (subjectId && oid === subjectId) continue;
        const os = parseTimeMs(o, "start_time");
        if (os == null || os <= subStart) continue;
        if (minLaterStart == null || os < minLaterStart) minLaterStart = os;
    }

    if (minLaterStart == null || subEnd <= minLaterStart) return;
    subject.set("end_time", new Date(minLaterStart).toISOString());
    if (fieldStr(subject, "status") === "running") {
        subject.set("status", "stopped");
    }
}

/** @param {core.App} app @param {string} userId */
function sanitizeAllPrimaryIntervalsForUser(app, userId) {
    if (!userId) return;
    let rows = [];
    try {
        rows = app.findRecordsByFilter(
            "records",
            "user_id = {:uid}",
            "+start_time",
            2000,
            0,
            { uid: userId },
        );
    } catch (_) {
        return;
    }

    const primaries = [];
    for (let i = 0; i < rows.length; i++) {
        if (isPrimaryRecord(rows[i])) primaries.push(rows[i]);
    }
    if (primaries.length < 2) return;

    for (let i = 1; i < primaries.length; i++) {
        const prev = primaries[i - 1];
        const cur = primaries[i];
        const curStart = parseTimeMs(cur, "start_time");
        if (curStart == null) continue;
        if (effectiveEndMs(prev) <= curStart) continue;

        prev.set("end_time", new Date(curStart).toISOString());
        const st = fieldStr(prev, "status").toLowerCase();
        if (st === "running" || st.length === 0) {
            prev.set("status", "stopped");
        }
        try {
            app.saveNoValidate(prev);
        } catch (_) {}
    }
}

module.exports = {
    fieldStr,
    isPrimaryRecord,
    validateStartEndOrder,
    clampSubjectEndAgainstLaterStarts,
    sanitizeAllPrimaryIntervalsForUser,
};
