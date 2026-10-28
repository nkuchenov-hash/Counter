/// <reference path="../pb_data/types.d.ts" />
// Per-user completion for an accepted shared object. Separate from private
// plans.is_done and from other participants' state.
migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles");
  const objects = app.findCollectionByNameOrId("shared_objects");
  if (!app.hasTable("shared_personal_state")) {
    app.save(new Collection({
      type: "base", name: "shared_personal_state",
      listRule: null, viewRule: null, createRule: null,
      updateRule: null, deleteRule: null,
      fields: [
        {name: "object_id", type: "relation", required: true,
          collectionId: objects.id, maxSelect: 1, cascadeDelete: true},
        {name: "user_id", type: "relation", required: true,
          collectionId: profiles.id, maxSelect: 1, cascadeDelete: true},
        {name: "source_plan_id", type: "text", required: true, max: 15},
        {name: "completed", type: "bool"},
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_shared_personal_owner_item ON " +
          "shared_personal_state (object_id, user_id, source_plan_id)",
      ],
    }));
  }
}, (app) => {
  if (app.hasTable("shared_personal_state")) {
    app.delete(app.findCollectionByNameOrId("shared_personal_state"));
  }
});
