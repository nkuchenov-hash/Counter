/// <reference path="../pb_data/types.d.ts" />
// Correct the single 2026-11-21 Tara Brooch card: this is personal, NOT RCC.
// Never change other days, users, or entries when matching is ambiguous.
migrate((app) => {
  const matches = app.findRecordsByFilter(
    "plans", "initial_date_key = {:day}", "", 1000, 0,
    {day: "2026-11-21"}
  ).filter(row =>
    String(row.getString("title") || "").toLowerCase().trim() === "tara brooch"
  );
  if (matches.length !== 1) return;
  const plan = matches[0];
  const owner = plan.getString("user_id");
  if (!owner) return;
  const categories = app.findRecordsByFilter(
    "categories", "user_id = {:owner}", "", 500, 0, {owner}
  );
  const normalized = s => String(s || "").toLowerCase().trim();
  const names = ["досуг", "личное", "жизнь", "leisure", "personal", "life"];
  let selected = null;
  for (const name of names) {
    const candidates = categories.filter(category =>
      !category.getBool("is_archived") &&
      normalized(category.getString("name")) === name
    );
    if (candidates.length === 1) {
      selected = candidates[0];
      break;
    }
  }
  if (!selected) return;
  let changed = false;
  if (plan.getString("category_id") !== selected.id) {
    plan.set("category_id", selected.id);
    changed = true;
  }
  const note = plan.getString("notes_plain");
  const corrected = note.replace(
    "Встреча RCC, 19:00–22:00/23:00. Филиал необходимо подтвердить",
    "Вечер в Tara Brooch, 19:00–22:00/23:00. Филиал необходимо подтвердить"
  );
  if (corrected !== note) {
    plan.set("notes_plain", corrected);
    changed = true;
  }
  if (changed) {
    app.save(plan);
    if (typeof console !== "undefined" && console.log) {
      console.log("lifeos_tara_category_repair: updated=1");
    }
  }
}, (app) => {
  // No destructive rollback of a real user plan.
});
