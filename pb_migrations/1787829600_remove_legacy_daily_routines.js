migrate((app) => {
  const marker = "LIFEOS_DAILY_ROUTINE_V1|"
  const planIdPrefix = "lifeos-routine-v1-"

  const rows = app.findRecordsByFilter(
    "plans",
    "notes_plain ~ {:marker} || plan_id ~ {:planIdPrefix}",
    "id",
    0,
    0,
    { marker, planIdPrefix },
  )

  for (const row of rows) {
    const notes = String(row.getString("notes_plain") || "")
    const planId = String(row.getString("plan_id") || "").trim()
    const isLegacyRoutine =
      notes.includes(marker) || planId.startsWith(planIdPrefix)
    if (!isLegacyRoutine) continue

    app.delete(row)
  }
}, (app) => {
  // Intentionally irreversible: these rows were created by an unauthorized
  // automatic bootstrap and must not be restored on rollback.
})
