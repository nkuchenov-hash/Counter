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
  // `updated` is a concurrency token: a second edit within 1s must not
  // pass stale-preview validation. Stored times can tolerate subsecond drift.
  function sameRevision(a, b) {
    return epoch(a) === epoch(b);
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
            !sameRevision(p.getString("updated"), item.raw.expected_updated) ||
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

// Protected atomic multi-create. The model cannot call this endpoint directly;
// only an authenticated LIFE OS executor sends owner-scoped, approved rows.
routerAdd("POST", "/api/viktor/schedule/create", function(e) {
  const auth = e.requestInfo().auth;
  if (!auth || !auth.id) return e.json(401, {error:"sign_in_required"});
  const owner = String(auth.id);
  const body = e.requestInfo().body || {};
  const creates = body.creates;
  if (typeof body.request_id !== "string" ||
      !/^viktor_[A-Za-z0-9_-]{8,90}$/.test(body.request_id) ||
      !Array.isArray(creates) || creates.length < 2 || creates.length > 12) {
    return e.json(400, {error:"invalid_batch"});
  }
  const seenIds = new Set();
  const proposed = [];
  const cleanFields = new Set([
    "plan_id", "title", "category_id", "start_time", "end_time",
    "initial_date_key"
  ]);
  try {
    for (const raw of creates) {
      if (!raw || typeof raw !== "object" || Array.isArray(raw) ||
          Object.keys(raw).some(key => !cleanFields.has(key)) ||
          typeof raw.plan_id !== "string" ||
          !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(raw.plan_id) ||
          seenIds.has(raw.plan_id) ||
          typeof raw.title !== "string" || !raw.title.trim() ||
          raw.title.length > 160 ||
          typeof raw.category_id !== "string" ||
          !/^[a-zA-Z0-9]{15}$/.test(raw.category_id) ||
          typeof raw.initial_date_key !== "string" ||
          !/^\d{4}-\d{2}-\d{2}$/.test(raw.initial_date_key) ||
          typeof raw.start_time !== "string" ||
          typeof raw.end_time !== "string" ||
          !raw.start_time.endsWith("Z") || !raw.end_time.endsWith("Z")) {
        throw new Error("invalid_fields");
      }
      seenIds.add(raw.plan_id);
      const start = Date.parse(raw.start_time), end = Date.parse(raw.end_time);
      if (!Number.isFinite(start) || !Number.isFinite(end) ||
          start >= end || end - start > 24 * 3600000) {
        throw new Error("invalid_interval");
      }
      proposed.push({raw, start, end});
    }
    for (let i = 0; i < proposed.length; i++) {
      for (let j = i + 1; j < proposed.length; j++) {
        if (proposed[i].start < proposed[j].end &&
            proposed[i].end > proposed[j].start) {
          throw new Error("batch_overlap");
        }
      }
    }
  } catch (err) {
    const reason = String(err && err.message || err);
    return e.json(400, {error:
      reason === "batch_overlap" ? reason : "invalid_batch_fields"});
  }
  try {
    let ids = [];
    let replay = false;
    e.app.runInTransaction(function(txApp) {
      const existing = [];
      for (const p of proposed) {
        const matches = txApp.findRecordsByFilter("plans",
          "user_id = {:owner} && plan_id = {:pid}", "", 2, 0,
          {owner:owner, pid:p.raw.plan_id});
        if (matches.length > 1) throw new Error("duplicate_business_id");
        existing.push(matches.length === 1 ? matches[0] : null);
        const category = txApp.findRecordById("categories", p.raw.category_id);
        if (category.getString("user_id") !== owner ||
            category.getBool("is_archived")) {
          throw new Error("category_not_owned");
        }
      }
      // Idempotent replay: accept only if ALL rows are exactly the original
      // committed batch; never silently complete a partially persisted set.
      if (existing.some(x => x !== null)) {
        if (existing.some(x => x === null)) throw new Error("partial_replay");
        for (let i = 0; i < existing.length; i++) {
          const old = existing[i], req = proposed[i];
          const oldStart = Date.parse(old.getString("start_time").replace(" ", "T"));
          const oldEnd = Date.parse(old.getString("end_time").replace(" ", "T"));
          if (old.getString("title") !== req.raw.title ||
              old.getString("category_id") !== req.raw.category_id ||
              old.getString("initial_date_key") !== req.raw.initial_date_key ||
              old.getBool("is_done") ||
              Math.abs(oldStart - req.start) >= 1000 ||
              Math.abs(oldEnd - req.end) >= 1000) {
            throw new Error("changed_replay");
          }
        }
        ids = existing.map(x => x.id);
        replay = true;
        return;
      }
      const earliest = Math.min(...proposed.map(x => x.start));
      const latest = Math.max(...proposed.map(x => x.end));
      const overlaps = txApp.findRecordsByFilter("plans",
        "user_id = {:owner} && start_time < {:latest} && end_time > {:earliest}",
        "", 501, 0, {owner:owner, earliest:new Date(earliest).toISOString(),
          latest:new Date(latest).toISOString()});
      if (overlaps.length >= 501) throw new Error("too_many_plans");
      for (const old of overlaps) {
        const start = Date.parse(old.getString("start_time").replace(" ", "T"));
        const end = Date.parse(old.getString("end_time").replace(" ", "T"));
        if (!Number.isFinite(start) || !Number.isFinite(end)) {
          throw new Error("invalid_existing_interval");
        }
        for (const p of proposed) {
          if (start < p.end && end > p.start) throw new Error("existing_overlap");
        }
      }
      const collection = txApp.findCollectionByNameOrId("plans");
      // No write before all ownership, idempotency and collision checks pass.
      for (let i = 0; i < proposed.length; i++) {
        const p = proposed[i].raw;
        const row = new Record(collection);
        row.set("plan_id", p.plan_id);
        row.set("user_id", owner);
        row.set("category_id", p.category_id);
        row.set("title", p.title);
        row.set("is_done", false);
        row.set("checklist", []);
        row.set("order", i);
        row.set("start_time", p.start_time);
        row.set("end_time", p.end_time);
        row.set("initial_date_key", p.initial_date_key);
        row.set("is_postponed", false);
        txApp.save(row);
        ids.push(row.id);
      }
    });
    return e.json(200, {ok:true, count:ids.length, ids:ids, replay:replay});
  } catch (err) {
    const reason = String(err && err.message || err);
    const permitted = new Set([
      "duplicate_business_id", "category_not_owned", "partial_replay",
      "changed_replay", "too_many_plans", "invalid_existing_interval",
      "existing_overlap"
    ]);
    return e.json(409, {ok:false,
      error:permitted.has(reason) ? reason : "batch_transaction_failed"});
  }
});
