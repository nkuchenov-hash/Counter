migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles")

  if (!app.hasTable("people")) {
    const people = new Collection({
      type: "base",
      name: "people",
      listRule: "user_id = @request.auth.id",
      viewRule: "user_id = @request.auth.id",
      createRule:
        "@request.auth.id != '' && @request.body.user_id = @request.auth.id",
      updateRule:
        "user_id = @request.auth.id && @request.body.user_id:changed = false",
      deleteRule: "user_id = @request.auth.id",
      fields: [
        {
          name: "user_id",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: profiles.id,
          cascadeDelete: true,
        },
        { name: "name", type: "text", required: true, max: 200 },
        {
          name: "group",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["close", "family", "friends", "work", "other"],
        },
        { name: "birthday", type: "date", required: false },
        { name: "notes", type: "text", required: false, max: 2000 },
        {
          name: "source",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["manual", "google_contacts", "telegram", "vk", "facebook", "other"],
        },
        { name: "source_id", type: "text", required: false, max: 300 },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE INDEX idx_people_owner_group ON people (user_id, group)",
        "CREATE INDEX idx_people_owner_name ON people (user_id, name)",
        "CREATE UNIQUE INDEX idx_people_source_identity ON people (user_id, source, source_id) WHERE source_id != ''",
      ],
    })
    app.save(people)
  }
}, (app) => {
  if (app.hasTable("people")) {
    app.delete(app.findCollectionByNameOrId("people"))
  }
})