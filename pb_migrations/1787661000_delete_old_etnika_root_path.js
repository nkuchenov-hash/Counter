migrate((app) => {
  const roots = app.findRecordsByFilter(
    "categories",
    "name = {:name} && is_archived = false",
    "id",
    0,
    0,
    { name: "ЭТНИКА" },
  )
  if (roots.length !== 1) {
    throw new Error("expected exactly one active ETNIKA category, got " + String(roots.length))
  }

  const root = roots[0]
  const owner = root.getString("user_id")
  if (!owner) throw new Error("ETNIKA owner is empty")

  const oldPaths = app.findRecordsByFilter(
    "paths",
    "user_id = {:owner} && category_link = {:category}",
    "id",
    0,
    0,
    { owner: owner, category: root.id },
  )
  for (const path of oldPaths) {
    app.delete(path)
  }

  // Remove only the premature Plans from the discarded draft. New Plans are
  // forbidden until the user explicitly approves the replacement Path.
  for (let day = 25; day <= 31; day++) {
    const planId = "etnika-homepage-redesign-2026-08-" + String(day).padStart(2, "0")
    const rows = app.findRecordsByFilter(
      "plans",
      "user_id = {:owner} && plan_id = {:plan}",
      "id",
      0,
      0,
      { owner: owner, plan: planId },
    )
    for (const row of rows) app.delete(row)
  }
}, (app) => {
  // Intentionally irreversible: deleting an obsolete user-requested Path must
  // never depend on whether a replacement Path can be created later.
})
