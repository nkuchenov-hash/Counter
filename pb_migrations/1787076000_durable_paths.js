migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles")

  if (!app.hasTable("paths")) {
    const paths = new Collection({
      type: "base",
      name: "paths",
      listRule: "user_id = @request.auth.id",
      viewRule: "user_id = @request.auth.id",
      createRule: "@request.auth.id != '' && @request.body.user_id = @request.auth.id",
      updateRule: "user_id = @request.auth.id && @request.body.user_id:changed = false",
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
        { name: "path_id", type: "text", required: true, max: 80 },
        { name: "category_id", type: "number", required: true, onlyInt: true },
        { name: "title", type: "text", required: true, max: 300 },
        { name: "active_revision_id", type: "text", required: true, max: 80 },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_paths_owner_path ON paths (user_id, path_id)",
        "CREATE UNIQUE INDEX idx_paths_owner_category ON paths (user_id, category_id)",
      ],
    })
    app.save(paths)
  }

  if (!app.hasTable("path_revisions")) {
    const revisions = new Collection({
      type: "base",
      name: "path_revisions",
      listRule: "user_id = @request.auth.id",
      viewRule: "user_id = @request.auth.id",
      createRule: "@request.auth.id != '' && @request.body.user_id = @request.auth.id",
      updateRule: null,
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
        { name: "path_id", type: "text", required: true, max: 80 },
        { name: "revision_id", type: "text", required: true, max: 80 },
        { name: "version", type: "number", required: true, onlyInt: true, min: 1 },
        {
          name: "lifecycle",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["draft", "reviewed", "published"],
        },
        { name: "goal", type: "text", required: true, max: 2000 },
        { name: "content", type: "json", required: true },
        {
          name: "source",
          type: "select",
          required: true,
          maxSelect: 1,
          values: ["manual", "migration", "ai", "system"],
        },
        { name: "parent_revision_id", type: "text", max: 80 },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_path_revisions_business ON path_revisions (user_id, path_id, revision_id)",
        "CREATE UNIQUE INDEX idx_path_revisions_version ON path_revisions (user_id, path_id, version)",
      ],
    })
    app.save(revisions)
  }

  // Import the shipped V2 plan-backed roots once. The deterministic record id
  // ordering matches the old read adapter's duplicate-root choice. Legacy rows
  // are intentionally left untouched so this migration is reversible.
  const legacyRoots = app.findRecordsByFilter(
    "plans",
    "notes_plain = {:marker}",
    "id",
    0,
    0,
    { marker: "LIFEOS_PATH::V2" },
  )
  const selected = {}
  for (const root of legacyRoots) {
    const ownerId = root.getString("user_id")
    const categoryId = root.getInt("category_id")
    if (!ownerId || categoryId <= 0) continue
    const key = ownerId + ":" + categoryId
    if (!selected[key]) selected[key] = root
  }

  const pathsCollection = app.findCollectionByNameOrId("paths")
  const revisionsCollection = app.findCollectionByNameOrId("path_revisions")
  for (const key in selected) {
    const root = selected[key]
    const ownerId = root.getString("user_id")
    const categoryId = root.getInt("category_id")

    let existing = []
    existing = app.findRecordsByFilter(
      pathsCollection,
      "user_id = {:owner} && category_id = {:category}",
      "id",
      1,
      0,
      { owner: ownerId, category: categoryId },
    )
    if (existing.length > 0) continue

    const pathId = "legacy-" + root.id
    const revisionId = pathId + "-v1"
    let rawChecklist = root.getRaw("checklist")
    if (typeof rawChecklist === "string") {
      try {
        rawChecklist = JSON.parse(rawChecklist)
      } catch (_) {
        rawChecklist = []
      }
    }
    if (!Array.isArray(rawChecklist)) rawChecklist = []

    const revision = new Record(revisionsCollection)
    revision.set("user_id", ownerId)
    revision.set("path_id", pathId)
    revision.set("revision_id", revisionId)
    revision.set("version", 1)
    revision.set("lifecycle", "published")
    revision.set("goal", root.getString("title") || "Path")
    revision.set("content", { stages: rawChecklist })
    revision.set("source", "migration")
    revision.set("parent_revision_id", "")
    app.save(revision)

    const path = new Record(pathsCollection)
    path.set("user_id", ownerId)
    path.set("path_id", pathId)
    path.set("category_id", categoryId)
    path.set("title", root.getString("title") || "Path")
    path.set("active_revision_id", revisionId)
    path.set("archived", false)
    app.save(path)
  }
}, (app) => {
  if (app.hasTable("path_revisions")) {
    app.delete(app.findCollectionByNameOrId("path_revisions"))
  }
  if (app.hasTable("paths")) {
    app.delete(app.findCollectionByNameOrId("paths"))
  }
})
