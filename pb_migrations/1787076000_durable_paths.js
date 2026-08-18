migrate((app) => {
  const profiles = app.findCollectionByNameOrId("profiles")
  const categories = app.findCollectionByNameOrId("categories")

  // Revisions are created first because `paths.active_revision_link` is a real
  // relation to this collection. Revisions remain append-only from the client.
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

  const revisionsCollection = app.findCollectionByNameOrId("path_revisions")

  if (!app.hasTable("paths")) {
    const paths = new Collection({
      type: "base",
      name: "paths",
      listRule: "user_id = @request.auth.id",
      viewRule: "user_id = @request.auth.id",
      createRule:
        "@request.auth.id != '' && " +
        "@request.body.user_id = @request.auth.id && " +
        "category_link.user_id = @request.auth.id && " +
        "active_revision_link.user_id = @request.auth.id && " +
        "active_revision_link.path_id = path_id",
      updateRule:
        "user_id = @request.auth.id && " +
        "@request.body.user_id:changed = false && " +
        "@request.body.category_link:changed = false && " +
        "category_link.user_id = @request.auth.id && " +
        "active_revision_link.user_id = @request.auth.id && " +
        "active_revision_link.path_id = path_id",
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
        {
          name: "category_link",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: categories.id,
          cascadeDelete: false,
        },
        { name: "title", type: "text", required: true, max: 300 },
        {
          name: "active_revision_link",
          type: "relation",
          required: true,
          maxSelect: 1,
          collectionId: revisionsCollection.id,
          cascadeDelete: false,
        },
        { name: "archived", type: "bool" },
      ],
      indexes: [
        "CREATE UNIQUE INDEX idx_paths_owner_path ON paths (user_id, path_id)",
        "CREATE UNIQUE INDEX idx_paths_owner_category ON paths (user_id, category_link)",
      ],
    })
    app.save(paths)
  }

  const pathsCollection = app.findCollectionByNameOrId("paths")

  function resolveCategoryRecordId(ownerId, rawCategory) {
    const raw = String(rawCategory || "").trim()
    if (!raw) return ""

    try {
      const byId = app.findRecordById(categories, raw)
      if (byId && byId.getString("user_id") === ownerId) return byId.id
    } catch (_) {}

    try {
      const matches = app.findRecordsByFilter(
        categories,
        "user_id = {:owner} && category_id = {:category}",
        "id",
        1,
        0,
        { owner: ownerId, category: raw },
      )
      if (matches.length > 0) return matches[0].id
    } catch (_) {}
    return ""
  }

  // Import the shipped V2 plan-backed roots once. Current plan writes store
  // `plans.category_id` as the categories PocketBase row id; the resolver also
  // accepts older business category keys. Record-id ordering matches the old
  // read adapter's deterministic duplicate-root choice. Source rows are kept.
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
    const categoryRecordId = resolveCategoryRecordId(
      ownerId,
      root.getString("category_id"),
    )
    if (!ownerId || !categoryRecordId) continue
    const key = ownerId + ":" + categoryRecordId
    if (!selected[key]) {
      selected[key] = { root, ownerId, categoryRecordId }
    }
  }

  for (const key in selected) {
    const item = selected[key]
    const root = item.root
    const ownerId = item.ownerId
    const categoryRecordId = item.categoryRecordId

    const existing = app.findRecordsByFilter(
      pathsCollection,
      "user_id = {:owner} && category_link = {:category}",
      "id",
      1,
      0,
      { owner: ownerId, category: categoryRecordId },
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
    path.set("category_link", categoryRecordId)
    path.set("title", root.getString("title") || "Path")
    path.set("active_revision_link", revision.id)
    path.set("archived", false)
    app.save(path)
  }
}, (app) => {
  if (app.hasTable("paths")) {
    app.delete(app.findCollectionByNameOrId("paths"))
  }
  if (app.hasTable("path_revisions")) {
    app.delete(app.findCollectionByNameOrId("path_revisions"))
  }
})
