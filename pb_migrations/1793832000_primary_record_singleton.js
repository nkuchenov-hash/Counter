/// <reference path="../pb_data/types.d.ts" />
// Database-level one-open-primary invariant, independent of client/server hooks.
// Refuse applying on dirty legacy data: duplicate "running" rows make SQLite
// reject CREATE UNIQUE INDEX; user records are never silently overwritten.
migrate((app) => {
    app.db().newQuery(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_records_one_open_primary_per_owner " +
        "ON records (user_id) WHERE status = 'running' " +
        "AND (parent_id IS NULL OR parent_id = '') " +
        "AND (end_time IS NULL OR end_time = '')"
    ).execute();
}, (app) => {
    throw new Error("Do not roll back the primary running singleton index");
});
