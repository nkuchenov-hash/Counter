/// <reference path="../pb_data/types.d.ts" />
// Collaborative objects are server-mediated. Never open their collection REST
// rules: permissions are checked per request in pb_hooks/shares.pb.js.
migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles");
  const locked = {
    listRule: null, viewRule: null, createRule: null,
    updateRule: null, deleteRule: null,
  };
  if (!app.hasTable("shared_objects")) {
    app.save(new Collection({
      type: "base", name: "shared_objects", ...locked,
      fields: [
        {name: "owner_id", type: "relation", required: true, collectionId: profiles.id, maxSelect: 1, cascadeDelete: true},
        {name: "kind", type: "select", required: true, maxSelect: 1, values: ["plan_day", "plan", "note", "list", "path"]},
        {name: "title", type: "text", required: true, max: 160},
        {name: "wall_day", type: "text", max: 10},
        {name: "content", type: "json", required: true, maxSize: 65536},
        {name: "revision", type: "number", required: true, min: 1},
        {name: "archived", type: "bool"},
      ],
      indexes: [
        "CREATE INDEX idx_shared_objects_owner ON shared_objects(owner_id, wall_day)",
      ],
    }));
  }
  const objects = app.findCollectionByNameOrId("shared_objects");
  if (!app.hasTable("shared_members")) {
    app.save(new Collection({
      type: "base", name: "shared_members", ...locked,
      fields: [
        {name: "object_id", type: "relation", required: true, collectionId: objects.id, maxSelect: 1, cascadeDelete: true},
        {name: "user_id", type: "relation", required: true, collectionId: profiles.id, maxSelect: 1, cascadeDelete: true},
        {name: "invited_by", type: "relation", required: true, collectionId: profiles.id, maxSelect: 1},
        {name: "status", type: "select", required: true, maxSelect: 1, values: ["invited", "accepted", "declined", "revoked"]},
        {name: "role", type: "select", required: true, maxSelect: 1, values: ["commenter", "editor"]},
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_shared_members_unique ON shared_members(object_id, user_id)",
        "CREATE INDEX idx_shared_members_inbox ON shared_members(user_id, status)",
      ],
    }));
  }
  if (!app.hasTable("shared_messages")) {
    app.save(new Collection({
      type: "base", name: "shared_messages", ...locked,
      fields: [
        {name: "object_id", type: "relation", required: true, collectionId: objects.id, maxSelect: 1, cascadeDelete: true},
        {name: "author_id", type: "relation", required: true, collectionId: profiles.id, maxSelect: 1},
        {name: "kind", type: "select", required: true, maxSelect: 1, values: ["comment", "proposal"]},
        {name: "body", type: "text", max: 2000},
        {name: "patch", type: "json", maxSize: 4096},
        {name: "base_revision", type: "number", min: 0},
        {name: "status", type: "select", required: true, maxSelect: 1, values: ["none", "pending", "accepted", "rejected"]},
      ],
      indexes: [
        "CREATE INDEX idx_shared_messages_object ON shared_messages(object_id, created)",
      ],
    }));
  }
}, (app) => {
  for (const name of ["shared_messages", "shared_members", "shared_objects"]) {
    if (app.hasTable(name)) app.delete(app.findCollectionByNameOrId(name));
  }
});
