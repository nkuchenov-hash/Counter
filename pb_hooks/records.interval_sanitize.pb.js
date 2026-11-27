/// <reference path="../pb_data/types.d.ts" />
// All ordinary PocketBase model writes, including internal server imports,
// offline replays and REST calls, share the same transaction-bound rule.
// Never repair a conflict in an after-success hook: the write has committed.
onRecordCreate((e) => {
    require(`${__hooks}/records.interval_sanitize_helpers.js`).reconcileRecordWrite(e);
}, "records");

onRecordUpdate((e) => {
    require(`${__hooks}/records.interval_sanitize_helpers.js`).reconcileRecordWrite(e);
}, "records");
