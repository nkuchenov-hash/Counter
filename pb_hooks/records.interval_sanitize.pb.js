/// <reference path="../pb_data/types.d.ts" />
// PocketBase: enforce non-overlapping primary `records` intervals per `user_id`.
// Deploy: copy `pb_hooks/` next to the pocketbase executable (same as official docs).

var __recordsIntervalSanitizeDepth = 0;

/** @param {RecordModel} rec @param {string} field */
function __fieldStr(rec, field) {
    const v = rec.get(field);
    return v == null ? "" : String(v).trim();
}

/** @param {RecordModel} rec */
function __isPrimaryRecord(rec) {
    const p = __fieldStr(rec, "parent_id");
    return p.length === 0;
}

/** @param {RecordModel} rec */
function __parseTimeMs(rec, field) {
    const raw = rec.get(field);
    if (!raw) return null;
    const d = new Date(String(raw));
    const t = d.getTime();
    return Number.isNaN(t) ? null : t;
}

/**
 * Effective end instant: missing end_time => open-ended (running).
 * @param {RecordModel} rec
 * @returns {number}
 */
function __effectiveEndMs(rec) {
    const t = __parseTimeMs(rec, "end_time");
    if (t != null) return t;
    return 8640000000000000; // far future — open interval
}

/** @param {RecordModel} rec */
function __validateStartEndOrder(rec) {
    const s = __parseTimeMs(rec, "start_time");
    if (s == null) return;
    const e = __parseTimeMs(rec, "end_time");
    if (e == null) return;
    if (e < s) {
        throw new BadRequestError("end_time must be >= start_time");
    }
}

/**
 * Clamp this record's end_time to the next primary interval's start_time if it overlaps.
 * @param {core.App} app
 * @param {RecordModel} subject
 * @param {string} subjectId 15-char id or "" for create (not yet in DB)
 */
function __clampSubjectEndAgainstLaterStarts(app, subject, subjectId) {
    const uid = __fieldStr(subject, "user_id");
    if (!uid) return;

    const subStart = __parseTimeMs(subject, "start_time");
    if (subStart == null) return;

    let subEnd = __parseTimeMs(subject, "end_time");
    const hadEnd = subEnd != null;

    /** @type {RecordModel[]} */
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
        if (!__isPrimaryRecord(o)) continue;
        const oid = __fieldStr(o, "id");
        if (subjectId && oid === subjectId) continue;
        const os = __parseTimeMs(o, "start_time");
        if (os == null) continue;
        if (os <= subStart) continue;
        if (minLaterStart == null || os < minLaterStart) minLaterStart = os;
    }

    if (minLaterStart == null) return;

    if (!hadEnd) return;

    if (subEnd != null && subEnd > minLaterStart) {
        subject.set("end_time", new Date(minLaterStart).toISOString());
        if (__fieldStr(subject, "status") === "running") {
            subject.set("status", "stopped");
        }
    }
}

/**
 * Single pass: sort primary rows by start_time and truncate any interval that
 * protrudes into the next one's start (Sacred Singleton / multi-device).
 * Uses saveRecord to persist sibling fixes.
 * @param {core.App} app
 * @param {string} userId
 */
function __sanitizeAllPrimaryIntervalsForUser(app, userId) {
    if (!userId) return;

    /** @type {RecordModel[]} */
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

    /** @type {RecordModel[]} */
    const primaries = [];
    for (let i = 0; i < rows.length; i++) {
        if (__isPrimaryRecord(rows[i])) primaries.push(rows[i]);
    }
    if (primaries.length < 2) return;

    for (let i = 1; i < primaries.length; i++) {
        const prev = primaries[i - 1];
        const cur = primaries[i];
        const curStart = __parseTimeMs(cur, "start_time");
        if (curStart == null) continue;

        const prevEndOpen = __effectiveEndMs(prev);
        if (prevEndOpen > curStart) {
            prev.set("end_time", new Date(curStart).toISOString());
            const st = (__fieldStr(prev, "status") || "").toLowerCase();
            if (st === "running" || st.length === 0) {
                prev.set("status", "stopped");
            }
            try {
                app.saveNoValidate(prev);
            } catch (_) {}
        }
    }
}

// --- Request-phase: reject illegal intervals + clamp end vs later rows ---

onRecordCreateRequest((e) => {
    const rec = e.record;
    if (!__isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    __validateStartEndOrder(rec);
    __clampSubjectEndAgainstLaterStarts(e.app, rec, "");
    e.next();
}, "records");

onRecordUpdateRequest((e) => {
    const rec = e.record;
    if (!__isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    __validateStartEndOrder(rec);
    __clampSubjectEndAgainstLaterStarts(e.app, rec, __fieldStr(rec, "id"));
    e.next();
}, "records");

// --- After persistence: full overlap sweep (handles running + cross-updates) ---

onRecordAfterCreateSuccess((e) => {
    if (__recordsIntervalSanitizeDepth > 0) {
        e.next();
        return;
    }
    const rec = e.record;
    if (!__isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    __recordsIntervalSanitizeDepth++;
    try {
        __sanitizeAllPrimaryIntervalsForUser(e.app, __fieldStr(rec, "user_id"));
    } catch (err) {
        try {
            e.app.logger().error(
                "records.interval_sanitize",
                "afterCreate",
                err,
            );
        } catch (_) {}
    } finally {
        __recordsIntervalSanitizeDepth--;
    }
    e.next();
}, "records");

onRecordAfterUpdateSuccess((e) => {
    if (__recordsIntervalSanitizeDepth > 0) {
        e.next();
        return;
    }
    const rec = e.record;
    if (!__isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    __recordsIntervalSanitizeDepth++;
    try {
        __sanitizeAllPrimaryIntervalsForUser(e.app, __fieldStr(rec, "user_id"));
    } catch (err) {
        try {
            e.app.logger().error(
                "records.interval_sanitize",
                "afterUpdate",
                err,
            );
        } catch (_) {}
    } finally {
        __recordsIntervalSanitizeDepth--;
    }
    e.next();
}, "records");
