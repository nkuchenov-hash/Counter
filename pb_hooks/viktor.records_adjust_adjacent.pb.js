// Atomic adjustment of two existing adjacent Timeline records.
// No direct arbitrary CRUD, no partial success and no retry after uncertain ACK.
routerAdd("POST", "/api/viktor/records/adjust-adjacent", function(e) {
  const info = e.requestInfo();
  if (!info.auth || !info.auth.id) return e.json(401, {error:"sign_in_required"});
  const owner = String(info.auth.id);
  const body = info.body || {};
  if (typeof body.request_id !== "string" ||
      !/^viktor_[A-Za-z0-9_-]{8,90}$/.test(body.request_id)) {
    return e.json(400, {error:"invalid_request_id"});
  }
  const allowed = new Set(["id", "expected_title", "expected_updated",
    "expected_start", "expected_end", "expected_status",
    "start_time", "end_time"]);
  function timestamp(value, nullable) {
    if (nullable && value == null) return null;
    if (typeof value !== "string" || value.length > 45) {
      throw new Error("invalid_time");
    }
    const t = Date.parse(value.replace(" ", "T"));
    if (!Number.isFinite(t)) throw new Error("invalid_time");
    return t;
  }
  function sameTime(stored, expected) {
    if (expected == null) return !stored;
    return !!stored && Math.abs(timestamp(stored) - expected) < 1000;
  }
  function parsePatch(patch) {
    if (!patch || typeof patch !== "object" || Array.isArray(patch) ||
        Object.keys(patch).some(key => !allowed.has(key))) {
      throw new Error("invalid_patch");
    }
    if (typeof patch.id !== "string" ||
        !/^[A-Za-z0-9]{15}$/.test(patch.id) ||
        typeof patch.expected_title !== "string" ||
        !patch.expected_title.trim() ||
        typeof patch.expected_status !== "string") {
      throw new Error("invalid_original_fields");
    }
    const expectedStart = timestamp(patch.expected_start);
    const expectedEnd = timestamp(patch.expected_end, true);
    const revision = timestamp(patch.expected_updated);
    const start = timestamp(patch.start_time);
    const end = timestamp(patch.end_time);
    if (end <= start || end - start > 24 * 60 * 60 * 1000) {
      throw new Error("invalid_new_interval");
    }
    return {patch, expectedStart, expectedEnd, revision, start, end};
  }
  let first, second;
  try {
    first = parsePatch(body.first);
    second = parsePatch(body.second);
    if (first.patch.id === second.patch.id ||
        first.expectedEnd == null ||
        first.start !== first.expectedStart ||
        first.end >= first.expectedEnd ||
        second.start !== first.end ||
        second.expectedStart < first.expectedEnd ||
        second.end <= second.expectedStart ||
        (second.expectedEnd != null && second.end <= second.expectedEnd) ||
        second.end > Date.now() + 120000) {
      throw new Error("invalid_adjacent_adjustment");
    }
  } catch (_) {
    return e.json(400, {error:"invalid_adjacent_adjustment"});
  }
  try {
    e.app.runInTransaction(function(txApp) {
      const a = txApp.findRecordById("records", first.patch.id);
      const b = txApp.findRecordById("records", second.patch.id);
      function sameRevision(model, item) {
        return timestamp(model.getString("updated")) === item.revision;
      }
      function validate(model, item) {
        if (model.getString("user_id") !== owner) {
          throw new Error("record_not_owned");
        }
        if (model.getString("title") !== item.patch.expected_title ||
            model.getString("status") !== item.patch.expected_status ||
            !sameRevision(model, item) ||
            !sameTime(model.getString("start_time"), item.expectedStart) ||
            !sameTime(model.getString("end_time"), item.expectedEnd)) {
          throw new Error("stale_record");
        }
      }
      validate(a, first);
      validate(b, second);
      if (a.getString("parent_id") || b.getString("parent_id")) {
        throw new Error("subrecord_requires_manual_edit");
      }
      // Discover competing activities near the newly extended time span.
      const earliest = new Date(first.start).toISOString();
      const latest = new Date(second.end).toISOString();
      const nearby = txApp.findRecordsByFilter("records",
        "user_id = {:owner} && start_time < {:latest} && " +
        "(start_time >= {:earliest} || end_time > {:earliest} || status = 'running')",
        "", 501, 0, {owner, earliest, latest});
      if (nearby.length >= 501) throw new Error("too_many_records");
      const candidates = nearby.filter(r =>
        r.id !== a.id && r.id !== b.id);
      for (const row of candidates) {
        const s = timestamp(row.getString("start_time"));
        const rawEnd = row.getString("end_time");
        const t = rawEnd ? timestamp(rawEnd) : Date.now();
        if (s < second.end && t > first.end) {
          throw new Error("other_record_overlap");
        }
      }
      // From this point, both writes are part of ONE PocketBase transaction.
      a.set("end_time", first.patch.end_time);
      a.set("status", "stopped");
      b.set("start_time", second.patch.start_time);
      b.set("end_time", second.patch.end_time);
      b.set("status", "stopped");
      txApp.save(a);
      txApp.save(b);
    });
    return e.json(200, {ok:true, updated:2});
  } catch (error) {
    const reason = String(error && error.message || error);
    const known = new Set([
      "record_not_owned", "stale_record", "subrecord_requires_manual_edit",
      "too_many_records", "other_record_overlap"
    ]);
    return e.json(409, {ok:false,
      error:known.has(reason) ? reason : "record_transaction_failed"});
  }
});
