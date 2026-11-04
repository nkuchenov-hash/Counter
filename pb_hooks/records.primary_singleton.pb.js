/// <reference path="../pb_data/types.d.ts" />
// Transactions cover API operations AND internal server-side app.save calls.
function transactPrimary(e) {
    const h = require(__hooks + "/records.primary_singleton_helpers.js");
    if (!h.primary(e.record) ||
        String(e.record.get("status") || "") !== "running") {
        e.next();
        return;
    }
    const originalApp = e.app;
    try {
        originalApp.runInTransaction((txApp) => {
            e.app = txApp;
            h.handoff(txApp, e.record);
            e.next();
        });
    } finally {
        e.app = originalApp;
    }
}
onRecordCreate(transactPrimary, "records");
onRecordUpdate(transactPrimary, "records");
