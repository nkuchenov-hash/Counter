/// <reference path="../pb_data/types.d.ts" />
// PocketBase: enforce non-overlapping primary `records` intervals per `user_id`.
// PocketBase JSVM serializes each hook handler into an isolated context, so
// reusable helpers must be required from a local module inside each handler.

onRecordCreateRequest((e) => {
    const h = require(`${__hooks}/records.interval_sanitize_helpers.js`);
    const rec = e.record;
    if (!h.isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    h.validateStartEndOrder(rec);
    h.clampSubjectEndAgainstLaterStarts(e.app, rec, "");
    e.next();
}, "records");

onRecordUpdateRequest((e) => {
    const h = require(`${__hooks}/records.interval_sanitize_helpers.js`);
    const rec = e.record;
    if (!h.isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    h.validateStartEndOrder(rec);
    h.clampSubjectEndAgainstLaterStarts(e.app, rec, h.fieldStr(rec, "id"));
    e.next();
}, "records");

onRecordAfterCreateSuccess((e) => {
    const h = require(`${__hooks}/records.interval_sanitize_helpers.js`);
    const rec = e.record;
    if (!h.isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    try {
        h.sanitizeAllPrimaryIntervalsForUser(e.app, h.fieldStr(rec, "user_id"));
    } catch (err) {
        try {
            e.app.logger().error(
                "records.interval_sanitize",
                "afterCreate",
                err,
            );
        } catch (_) {}
    }
    e.next();
}, "records");

onRecordAfterUpdateSuccess((e) => {
    const h = require(`${__hooks}/records.interval_sanitize_helpers.js`);
    const rec = e.record;
    if (!h.isPrimaryRecord(rec)) {
        e.next();
        return;
    }
    try {
        h.sanitizeAllPrimaryIntervalsForUser(e.app, h.fieldStr(rec, "user_id"));
    } catch (err) {
        try {
            e.app.logger().error(
                "records.interval_sanitize",
                "afterUpdate",
                err,
            );
        } catch (_) {}
    }
    e.next();
}, "records");
