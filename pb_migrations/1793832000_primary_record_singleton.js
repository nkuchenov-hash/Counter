/// <reference path="../pb_data/types.d.ts" />
//
// Database-level primary Highlander invariant, including raw SQL and
// simultaneous network clients. Existing nonempty end times are authoritative:
// changing status from "running" to "stopped" does not invent any date/time.
//
// All other inconsistent duplicate open rows BLOCK this migration. Deliberate
// refusal is safer than guessing which record should remain running.
migrate((app) => {
    app.db().newQuery(
        "UPDATE records SET status = 'stopped' " +
        "WHERE status = 'running' " +
        "AND end_time IS NOT NULL AND end_time != ''"
    ).execute();

    app.db().newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_records_one_open_primary_per_owner " +
        "ON records (user_id) WHERE status = 'running' " +
        "AND (parent_id IS NULL OR parent_id = '') " +
        "AND (end_time IS NULL OR end_time = '')"
    ).execute();

    // A running row may never have a finite end. The model hook normally
    // normalizes this case to stopped; triggers are a final SQL safety net.
    app.db().newQuery(
        "CREATE TRIGGER IF NOT EXISTS trg_records_running_end_insert " +
        "BEFORE INSERT ON records " +
        "WHEN NEW.status = 'running' AND NEW.end_time IS NOT NULL AND NEW.end_time != '' " +
        "BEGIN SELECT RAISE(ABORT, 'running record cannot have end_time'); END"
    ).execute();
    app.db().newQuery(
        "CREATE TRIGGER IF NOT EXISTS trg_records_running_end_update " +
        "BEFORE UPDATE ON records " +
        "WHEN NEW.status = 'running' AND NEW.end_time IS NOT NULL AND NEW.end_time != '' " +
        "BEGIN SELECT RAISE(ABORT, 'running record cannot have end_time'); END"
    ).execute();
}, (app) => {
    throw new Error("Do not roll back the primary running singleton index");
});
