/// <reference path="../pb_data/types.d.ts" />
// Disaster recovery baseline for a NEW/EMPTY PocketBase database.
//
// Source of field and ownership contracts:
// - docs/DATA_MAP.md
// - docs/POCKETBASE_MANIFEST.md
// - subsequent pb_migrations (which must run after this file)
//
// This is a reconstructed baseline, NOT an export of the lost Beget database.
// On an existing installation, all five core collections MUST already exist.
// In that case this migration is a strict no-op, preserving IDs, schema and data.
// A partially provisioned database is refused instead of silently changing it.

migrate((app) => {
  const coreNames = ["profiles", "categories", "tags", "plans", "records"];
  const existing = coreNames.filter((name) => {
    try {
      app.findCollectionByNameOrId(name);
      return true;
    } catch (_) {
      return false;
    }
  });

  if (existing.length === coreNames.length) return;
  if (existing.length !== 0) {
    throw new Error(
      "LIFE OS bootstrap aborted: partial core schema (found " +
      existing.join(", ") + "). Restore a complete database or use a fresh one."
    );
  }

  const ownerRule = "user_id = @request.auth.id";
  const createOwnerRule =
    "@request.auth.id != '' && @request.body.user_id = @request.auth.id";
  const updateOwnerRule =
    ownerRule + " && @request.body.user_id:changed = false";
  const timeFields = [
    { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
  ];
  const relation = (name, target, required = false, maxSelect = 1) => ({
    name,
    type: "relation",
    collectionId: target,
    required,
    maxSelect,
    cascadeDelete: false,
  });

  const profiles = new Collection({
    type: "auth",
    name: "profiles",
    listRule: "id = @request.auth.id",
    viewRule: "id = @request.auth.id",
    createRule:
      "@request.body.is_admin:isset = false && " +
      "@request.body.tier:isset = false",
    updateRule:
      "id = @request.auth.id && " +
      "@request.body.is_admin:changed = false && " +
      "@request.body.tier:changed = false && " +
      "@request.body.user_id:changed = false",
    deleteRule: null,
    manageRule: null,
    passwordAuth: { enabled: true, identityFields: ["email"] },
    fields: [
      { name: "user_id", type: "text" },
      { name: "name", type: "text" },
      { name: "display_name", type: "text" },
      { name: "avatar_url", type: "text" },
      { name: "primary_language", type: "text" },
      { name: "theme_mode", type: "select", maxSelect: 1, values: ["light", "dark", "system"] },
      { name: "preferred_timezone", type: "text" },
      { name: "timezone_offset", type: "number" },
      { name: "biometric_enabled", type: "bool" },
      { name: "is_admin", type: "bool" },
      { name: "tier", type: "select", maxSelect: 1, values: ["free", "pro"] },
      { name: "default_category_id", type: "text" },
      { name: "active_languages", type: "json" },
      { name: "data_region", type: "text" },
      { name: "has_seeded", type: "bool" },
      { name: "tag_display_mode", type: "text" },
      { name: "list_completion_behavior", type: "text" },
      ...timeFields,
    ],
  });
  app.save(profiles);

  const categories = new Collection({
    type: "base",
    name: "categories",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: createOwnerRule,
    updateRule: updateOwnerRule,
    deleteRule: ownerRule,
    fields: [
      relation("user_id", profiles.id, true),
      { name: "category_id", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "normalized_id", type: "text" },
      { name: "keywords", type: "json" },
      { name: "localized_names", type: "json" },
      { name: "color", type: "text" },
      { name: "color_value", type: "number", onlyInt: true },
      { name: "icon", type: "text" },
      { name: "icon_code_point", type: "number", onlyInt: true },
      { name: "default_plan_time", type: "text" },
      // default_plan_timezone is added by migration 1787580300.
      { name: "order", type: "number", onlyInt: true },
      { name: "is_archived", type: "bool" },
      ...timeFields,
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_categories_owner_business ON categories (user_id, category_id)",
    ],
  });
  app.save(categories);
  categories.fields.add(new RelationField(relation("parent_id", categories.id)));
  app.save(categories);

  const tags = new Collection({
    type: "base",
    name: "tags",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: createOwnerRule,
    updateRule: updateOwnerRule,
    deleteRule: ownerRule,
    fields: [
      relation("user_id", profiles.id, true),
      { name: "tag_id", type: "text", required: true },
      { name: "name", type: "text", required: true },
      { name: "color", type: "text" },
      { name: "icon", type: "text" },
      { name: "sort_order", type: "number", onlyInt: true },
      { name: "domain", type: "select", maxSelect: 1, values: ["plan", "list"] },
      { name: "default_plan_duration_minutes", type: "number", onlyInt: true, min: 0, max: 1440 },
      ...timeFields,
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_tags_owner_business ON tags (user_id, tag_id)",
    ],
  });
  app.save(tags);

  const plans = new Collection({
    type: "base",
    name: "plans",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: createOwnerRule + " && category_id.user_id = @request.auth.id",
    updateRule: updateOwnerRule + " && category_id.user_id = @request.auth.id",
    deleteRule: ownerRule,
    fields: [
      relation("user_id", profiles.id, true),
      { name: "plan_id", type: "text", required: true },
      relation("category_id", categories.id, true),
      { name: "title", type: "text", required: true },
      { name: "is_done", type: "bool" },
      { name: "start_time", type: "date" },
      { name: "end_time", type: "date" },
      { name: "checklist", type: "json" },
      { name: "order", type: "number", onlyInt: true },
      { name: "notes_delta", type: "json" },
      { name: "notes_plain", type: "text" },
      { name: "tags", type: "text" },
      relation("tags_link", tags.id, false, 99),
      { name: "rrule", type: "text" },
      { name: "exception_dates", type: "json" },
      { name: "recurrence_instance_date_key", type: "text" },
      { name: "reminder_offset", type: "number", onlyInt: true },
      // initial_date_key/is_postponed are added by migration 1787842200.
      ...timeFields,
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_plans_owner_business ON plans (user_id, plan_id)",
    ],
  });
  app.save(plans);
  plans.fields.add(new RelationField(relation("parent_plan_id", plans.id)));
  app.save(plans);

  const records = new Collection({
    type: "base",
    name: "records",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule:
      createOwnerRule +
      " && category_id.user_id = @request.auth.id" +
      " && category_link.user_id = @request.auth.id" +
      " && (source_plan_id = '' || source_plan_id.user_id = @request.auth.id)",
    updateRule:
      updateOwnerRule +
      " && category_id.user_id = @request.auth.id" +
      " && category_link.user_id = @request.auth.id" +
      " && (source_plan_id = '' || source_plan_id.user_id = @request.auth.id)",
    deleteRule: ownerRule,
    fields: [
      relation("user_id", profiles.id, true),
      { name: "record_id", type: "text", required: true },
      { name: "title", type: "text", required: true },
      { name: "start_time", type: "date", required: true },
      { name: "end_time", type: "date" },
      relation("category_id", categories.id, true),
      relation("category_link", categories.id, true),
      { name: "status", type: "select", required: true, maxSelect: 1, values: ["running", "stopped", "completed"] },
      { name: "type", type: "text", required: true },
      relation("source_plan_id", plans.id),
      { name: "tags", type: "text" },
      relation("tags_link", tags.id, false, 99),
      { name: "checklist", type: "json" },
      { name: "note", type: "text" },
      // notes_delta, sleep_* and external_* are added by later migrations.
      ...timeFields,
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_records_owner_business ON records (user_id, record_id)",
    ],
  });
  app.save(records);
  records.fields.add(new RelationField(relation("parent_id", records.id)));
  app.save(records);
}, (app) => {
  // A potentially restored production DB must never be destroyed by
  // an accidental rollback of the recovery baseline.
  throw new Error("LIFE OS recovery bootstrap cannot be rolled back automatically.");
});
