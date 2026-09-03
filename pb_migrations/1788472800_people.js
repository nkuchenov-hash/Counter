/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles")

  const ownedRules = {
    listRule: "user_id = @request.auth.id",
    viewRule: "user_id = @request.auth.id",
    createRule:
      "@request.auth.id != '' && @request.body.user_id = @request.auth.id",
    updateRule:
      "user_id = @request.auth.id && @request.body.user_id:changed = false",
    deleteRule: "user_id = @request.auth.id",
  }

  if (!app.hasTable("people_circles")) {
    const circles = new Collection({
      type: "base",
      name: "people_circles",
      ...ownedRules,
      fields: [
        {
          name: "user_id",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: profiles.id,
          cascadeDelete: true,
        },
        { name: "circle_id", type: "text", required: true, max: 80 },
        { name: "name", type: "text", required: true, max: 160 },
        { name: "sort_order", type: "number", onlyInt: true, min: 0 },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_people_circles_owner_business ON people_circles (user_id, circle_id)",
      ],
    })
    app.save(circles)
  }

  const circles = app.findCollectionByNameOrId("people_circles")

  if (!app.hasTable("people")) {
    const people = new Collection({
      type: "base",
      name: "people",
      ...ownedRules,
      fields: [
        {
          name: "user_id",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: profiles.id,
          cascadeDelete: true,
        },
        { name: "person_id", type: "text", required: true, max: 80 },
        { name: "display_name", type: "text", required: true, max: 240 },
        {
          name: "relationship_status",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["important", "known", "reference", "ignored", "blocked"],
        },
        { name: "birthday_month", type: "number", onlyInt: true, min: 1, max: 12 },
        { name: "birthday_day", type: "number", onlyInt: true, min: 1, max: 31 },
        { name: "birthday_year", type: "number", onlyInt: true, min: 1, max: 9999 },
        { name: "birthday_notifications_enabled", type: "bool" },
        { name: "birthday_reminder_days", type: "json", maxSize: 10000 },
        {
          name: "circles_link",
          type: "relation",
          maxSelect: 50,
          collectionId: circles.id,
          cascadeDelete: false,
        },
        { name: "notes", type: "text", max: 20000 },
        { name: "source_refs", type: "json", maxSize: 100000 },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_people_owner_business ON people (user_id, person_id)",
        "CREATE INDEX idx_people_owner_status ON people (user_id, relationship_status, archived)",
      ],
    })
    app.save(people)
  }

  const people = app.findCollectionByNameOrId("people")

  if (!app.hasTable("people_source_contacts")) {
    const sourceContacts = new Collection({
      type: "base",
      name: "people_source_contacts",
      ...ownedRules,
      fields: [
        {
          name: "user_id",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: profiles.id,
          cascadeDelete: true,
        },
        {
          name: "provider",
          type: "select",
          required: true,
          maxSelect: 1,
          values: [
            "device_contacts",
            "google_contacts",
            "microsoft",
            "vk",
            "telegram",
            "facebook",
            "manual",
          ],
        },
        { name: "external_id", type: "text", required: true, max: 1000 },
        { name: "display_name", type: "text", max: 240 },
        { name: "birthday_month", type: "number", onlyInt: true, min: 1, max: 12 },
        { name: "birthday_day", type: "number", onlyInt: true, min: 1, max: 31 },
        { name: "birthday_year", type: "number", onlyInt: true, min: 1, max: 9999 },
        { name: "source_group", type: "text", max: 500 },
        {
          name: "import_state",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["unknown", "candidate", "linked", "ignored", "blocked"],
        },
        {
          name: "person_link",
          type: "relation",
          maxSelect: 1,
          collectionId: people.id,
          cascadeDelete: false,
        },
        { name: "raw_meta", type: "json", maxSize: 100000 },
        { name: "last_seen_at", type: "date" },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_people_source_identity ON people_source_contacts (user_id, provider, external_id)",
        "CREATE INDEX idx_people_source_review ON people_source_contacts (user_id, import_state, provider)",
      ],
    })
    app.save(sourceContacts)
  }
}, (app) => {
  if (app.hasTable("people_source_contacts")) {
    app.delete(app.findCollectionByNameOrId("people_source_contacts"))
  }
  if (app.hasTable("people")) {
    app.delete(app.findCollectionByNameOrId("people"))
  }
  if (app.hasTable("people_circles")) {
    app.delete(app.findCollectionByNameOrId("people_circles"))
  }
})
