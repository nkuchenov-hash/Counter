// Viktor's protected atomic multi-day schedule commit. Input is a Brain
// preview of existing owned plan rows only. No arbitrary fields/CRUD.
routerAdd("POST", "/api/viktor/schedule/commit", function(e) {
  const info = e.requestInfo();
  if (!info.auth || !info.auth.id) return e.json(401, {error:"sign_in_required"});
  const owner = String(info.auth.id);
  const body = info.body || {};
  const updates = body.patches;
  if (!Array.isArray(updates) || updates.length < 1 ||
      updates.length > 80 || typeof body.request_id !== "string" ||
      !/^viktor_[A-Za-z0-9_-]{8,90}$/.test(body.request_id)) {
    return e.json(400, {error:"invalid_atomic_schedule_request"});
  }
  function epoch(value) {
    if (typeof value !== "string" || value.length > 45) {
      throw new Error("invalid_date");
    }
    const parsed = Date.parse(value.replace(" ", "T"));
    if (!Number.isFinite(parsed)) throw new Error("invalid_date");
    return parsed;
  }
  function sameMoment(a, b) {
    return Math.abs(epoch(a) - epoch(b)) < 1000;
  }
  const seen = new Set();
  const proposed = [];
  try {
    for (const raw of updates) {
      if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
        throw new Error("invalid_patch");
      }
      const keys = Object.keys(raw);
      const allowed = new Set(["id", "expected_updated", "expected_start",
        "expected_end", "expected_title", "expected_is_done",
        "start_time", "end_time", "initial_date_key", "is_postponed"]);
      if (keys.some(k => !allowed.has(k))) throw new Error("invalid_patch_field");
      if (typeof raw.id !== "string" || !/^[a-zA-Z0-9]{15}$/.test(raw.id) ||
          seen.has(raw.id)) throw new Error("duplicate_or_invalid_id");
      seen.add(raw.id);
      if (typeof raw.expected_title !== "string" ||
          typeof raw.expected_is_done !== "boolean") {
        throw new Error("missing_original_fields");
      }
      const start = epoch(raw.start_time);
      const end = epoch(raw.end_time);
      if (end <= start || end - start > 24 * 3600000) {
        throw new Error("invalid_new_interval");
      }
      epoch(raw.expected_start);
      epoch(raw.expected_end);
      epoch(raw.expected_updated);
      if (raw.initial_date_key != null &&
          (typeof raw.initial_date_key !== "string" ||
           !/^\d{4}-\d{2}-\d{2}$/.test(raw.initial_date_key))) {
        throw new Error("invalid_audit_date");
      }
      if (raw.is_postponed != null &&
          typeof raw.is_postponed !== "boolean") {
        throw new Error("invalid_postponed_flag");
      }
      proposed.push({raw, start, end});
    }
  } catch (_) {
    return e.json(400, {error:"invalid_schedule_fields"});
  }
  try {
    e.app.runInTransaction(function(txApp) {
      const records = [];
      for (const item of proposed) {
        const p = txApp.findRecordById("plans", item.raw.id);
        if (p.getString("user_id") !== owner) {
          throw new Error("plan_not_owned");
        }
        if (p.getString("rrule").trim() ||
            p.getString("recurrence_instance_date_key").trim() ||
            p.getBool("external_read_only")) {
          throw new Error("protected_plan");
        }
        if (p.getString("title") !== item.raw.expected_title ||
            p.getBool("is_done") !== item.raw.expected_is_done ||
            !sameMoment(p.getString("updated"), item.raw.expected_updated) ||
            !sameMoment(p.getString("start_time"), item.raw.expected_start) ||
            !sameMoment(p.getString("end_time"), item.raw.expected_end)) {
          throw new Error("stale_plan");
        }
        // The planner rejects fixed-time categories; enforce the immediate
        // category lock again on the server in case it changed meanwhile.
        const categoryId = p.getString("category_id");
        if (categoryId) {
          const category = txApp.findRecordById("categories", categoryId);
          if (category.getString("default_plan_time").trim()) {
            throw new Error("fixed_time_category");
          }
        }
        records.push({record:p, item});
      }
      // Check all proposed intervals against each other and against every
      // persisted overlapping owned plan under the *same* transaction.
      for (let i = 0; i < proposed.length; i++) {
        const a = proposed[i];
        for (let j = i + 1; j < proposed.length; j++) {
          const b = proposed[j];
          if (a.start < b.end && a.end > b.start) {
            throw new Error("new_plan_overlap");
          }
        }
      }
      const earliest = Math.min(...proposed.map(p => p.start));
      const latest = Math.max(...proposed.map(p => p.end));
      const overlaps = txApp.findRecordsByFilter("plans",
        "user_id = {:owner} && start_time < {:latest} && end_time > {:earliest}",
        "", 501, 0, {
          owner:owner, earliest:new Date(earliest).toISOString(),
          latest:new Date(latest).toISOString(),
        });
      if (overlaps.length >= 501) throw new Error("too_many_affected_plans");
      for (const original of overlaps) {
        if (seen.has(original.id)) continue;
        const oldStart = Date.parse(original.getString("start_time").replace(" ", "T"));
        const oldEnd = Date.parse(original.getString("end_time").replace(" ", "T"));
        if (!Number.isFinite(oldStart) || !Number.isFinite(oldEnd)) {
          throw new Error("invalid_existing_plan");
        }
        for (const target of proposed) {
          if (oldStart < target.end && oldEnd > target.start) {
            throw new Error("existing_plan_overlap");
          }
        }
      }
      // No DB write above this line. Any thrown save rolls ALL records back.
      for (const pair of records) {
        pair.record.set("start_time", pair.item.raw.start_time);
        pair.record.set("end_time", pair.item.raw.end_time);
        if (pair.item.raw.initial_date_key != null) {
          pair.record.set("initial_date_key", pair.item.raw.initial_date_key);
        }
        if (pair.item.raw.is_postponed != null) {
          pair.record.set("is_postponed", pair.item.raw.is_postponed);
        }
        txApp.save(pair.record);
      }
    });
    return e.json(200, {ok:true, updated:proposed.length,
      ids:proposed.map(p=>p.raw.id)});
  } catch (error) {
    const reason = String(error && error.message || error);
    const safe = new Set(["plan_not_owned", "protected_plan", "stale_plan",
      "fixed_time_category", "new_plan_overlap", "existing_plan_overlap",
      "too_many_affected_plans", "invalid_existing_plan"]);
    return e.json(409, {ok:false,
      error:safe.has(reason) ? reason : "schedule_transaction_failed"});
  }
});