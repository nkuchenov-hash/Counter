/// <reference path="../pb_data/types.d.ts" />
// Server-owned encrypted BYOK credentials for Viktor. Never expose direct
// collection REST access, even to the owner; use authenticated hooks only.
migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles");
  if (!app.hasTable("viktor_connections")) {
    const collection = new Collection({
      type: "base",
      name: "viktor_connections",
      listRule: null,
      viewRule: null,
      createRule: null,
      updateRule: null,
      deleteRule: null,
      fields: [
        {
          name: "user_id", type: "relation", required: true,
          maxSelect: 1, collectionId: profiles.id, cascadeDelete: true,
        },
        {
          name: "provider", type: "select", required: true,
          maxSelect: 1, values: [
            "yandex", "gigachat", "openai", "groq", "gemini", "openrouter",
          ],
        },
        {name: "model", type: "text", required: true, max: 100},
        {name: "payload_enc", type: "text", required: true, max: 10000},
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_viktor_connections_owner_provider " +
          "ON viktor_connections (user_id, provider)",
      ],
    });
    app.save(collection);
  }
}, (app) => {
  if (app.hasTable("viktor_connections")) {
    app.delete(app.findCollectionByNameOrId("viktor_connections"));
  }
});
