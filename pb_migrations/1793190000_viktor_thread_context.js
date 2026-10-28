/// <reference path="../pb_data/types.d.ts" />
// Keep existing main dialogue intact.
migrate((app) => {
  const turns = app.findCollectionByNameOrId("viktor_turns");
  for (const name of ["sent_at_utc", "message_day", "message_timezone"]) {
    if (!turns.fields.getByName(name)) {
      turns.fields.add(new TextField({name, max: 80}));
    }
  }
  app.save(turns);
  if (app.hasTable("viktor_threads")) return;
  const profiles = app.findCollectionByNameOrId("profiles");
  const rule = "user_id = @request.auth.id";
  app.save(new Collection({
    type: "base", name: "viktor_threads",
    listRule: rule, viewRule: rule, createRule: rule, updateRule: rule, deleteRule: rule,
    fields: [
      {name: "user_id", type: "relation", required: true,
       maxSelect: 1, collectionId: profiles.id, cascadeDelete: true},
      {name: "thread_key", type: "text", required: true, max: 80},
      {name: "title", type: "text", required: true, max: 120},
      {name: "created", type: "autodate", onCreate: true, onUpdate: false},
      {name: "updated", type: "autodate", onCreate: true, onUpdate: true}
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_viktor_threads_owner_key ON viktor_threads (user_id, thread_key)",
      "CREATE INDEX idx_viktor_threads_owner_updated ON viktor_threads (user_id, updated)"
    ]
  }));
}, (app) => {
  if (app.hasTable("viktor_threads")) {
    app.delete(app.findCollectionByNameOrId("viktor_threads"));
  }
});