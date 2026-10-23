/// <reference path="../pb_data/types.d.ts" />
// Owner-scoped append-only dialogue; no secret/provider credentials.
// One row per turn avoids last-writer-wins overwriting another device's chat.
migrate((app) => {
  if (app.hasTable("viktor_turns")) return;
  const profiles = app.findCollectionByNameOrId("profiles");
  const ownerRule = "user_id = @request.auth.id";
  const collection = new Collection({
    type: "base",
    name: "viktor_turns",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: ownerRule,
    updateRule: null, // immutable dialogue history
    deleteRule: ownerRule,
    fields: [
      {
        name: "user_id", type: "relation", required: true, maxSelect: 1,
        collectionId: profiles.id, cascadeDelete: true,
      },
      {name: "conversation_id", type: "text", required: true, max: 80},
      {name: "client_turn_id", type: "text", required: true, max: 96},
      {name: "role", type: "select", required: true, maxSelect: 1,
       values: ["user", "assistant"]},
      {name: "body", type: "text", required: true, max: 6000},
      {name: "created", type: "autodate", onCreate: true, onUpdate: false},
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_viktor_turns_owner_client " +
        "ON viktor_turns (user_id, client_turn_id)",
      "CREATE INDEX idx_viktor_turns_owner_thread_time " +
        "ON viktor_turns (user_id, conversation_id, created)",
    ],
  });
  app.save(collection);
}, (app) => {
  if (app.hasTable("viktor_turns")) {
    app.delete(app.findCollectionByNameOrId("viktor_turns"));
  }
});