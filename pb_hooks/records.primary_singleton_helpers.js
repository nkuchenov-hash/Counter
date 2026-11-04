/// <reference path="../pb_data/types.d.ts" />
// Atomic Highlander for primary records only. All changes occur BEFORE
// INSERT/UPDATE and in the SAME PocketBase SQLite transaction. The partial
// unique index 1793832000 provides an independent database invariant.
function str(rec, field) {
    const value = rec.get(field);
    return value == null ? "" : String(value).trim();
}
function primary(rec) {
    return !str(rec, "parent_id");
}
function open(rec) {
    return primary(rec) && str(rec, "status") === "running" && !str(rec, "end_time");
}
function startMs(rec) {
    const value = str(rec, "start_time");
    const time = value ? new Date(value).getTime() : NaN;
    if (!Number.isFinite(time)) {
        throw new BadRequestError("Running record must have valid start_time");
    }
    return time;
}
function iso(value) { return new Date(value).toISOString(); }

/**
 * An open primary is only the chronologically latest one.
 * A stale offline create arriving after a later record is *closed* at the
 * next known start, never left running in the past. On same start, newest
 * incoming record wins; older row becomes stopped at zero duration.
 */
function handoff(txApp, incoming) {
    if (!primary(incoming) || str(incoming, "status") !== "running") return;
    if (str(incoming, "end_time")) {
        incoming.set("status", "stopped");
        return;
    }
    const owner = str(incoming, "user_id");
    if (!owner) throw new BadRequestError("Running record must have an owner");
    const subjectId = str(incoming, "id");
    const subjectStart = startMs(incoming);
    const rows = txApp.findRecordsByFilter(
        "records", "user_id = {:owner} && status = 'running'",
        "+start_time", 5000, 0, { owner: owner }
    );
    if (rows.length >= 5000) {
        throw new BadRequestError("Too many open records; cannot reconcile safely");
    }
    const entries = [{ record: incoming, start: subjectStart, incoming: true }];
    for (let i = 0; i < rows.length; i++) {
        const old = rows[i];
        if (!open(old)) continue;
        if (subjectId && str(old, "id") === subjectId) continue;
        entries.push({ record: old, start: startMs(old), incoming: false });
    }
    entries.sort((a, b) => {
        if (a.start !== b.start) return a.start - b.start;
        if (a.incoming !== b.incoming) return a.incoming ? 1 : -1;
        const aid = str(a.record, "id"), bid = str(b.record, "id");
        return aid < bid ? -1 : aid > bid ? 1 : 0;
    });

    // Prevent a queued historical "start" from becoming active after newer
    // finished records. Query only next later start (bounded DB query).
    const newer = txApp.findRecordsByFilter(
        "records", "user_id = {:owner} && start_time > {:start} && parent_id = ''",
        "+start_time", 1, 0, { owner: owner, start: iso(subjectStart) }
    );
    const laterStart = newer.length ? startMs(newer[0]) : null;
    for (let i = 0; i < entries.length; i++) {
        const current = entries[i];
        let end = i + 1 < entries.length ? entries[i + 1].start : null;
        if (current.incoming && laterStart !== null &&
            laterStart >= current.start &&
            (end === null || laterStart < end)) {
            end = laterStart;
        }
        if (end === null) continue;
        current.record.set("status", "stopped");
        current.record.set("end_time", iso(end));
        if (!current.incoming) txApp.saveNoValidate(current.record);
    }
}
module.exports = { handoff, primary, open };
