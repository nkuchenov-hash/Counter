/// <reference path="../pb_data/types.d.ts" />
// Two Timeline Record edits must be all-or-nothing. The authenticated owner,
// expected row revisions, adjacency, time order and global interval conflicts
// are checked inside the same PocketBase transaction as both writes.
routerAdd("POST", "/api/viktor/records/resize-adjacent", function(e) {
  const info = e.requestInfo();
  if (!info.auth || !info.auth.id) {
    return e.json(401, {error:"sign_in_required"});
  }
  const owner = String(info.auth.id);
  const body = info.body || {};
  const first = body.first;
  const second = body.second;
  const allowedKeys = (value, keys) => value &&
    typeof value === "object" && !Array.isArray(value) &&
    Object.keys(value).every(k => keys.includes(k)) &&
    Object.keys(value).length === keys.length;
  const fieldsFirst = ["id", "expected_title", "expected_status",
    "expected_updated", "expected_start", "expected_end", "new_end"];
  const fieldsSecond = ["id", "expected_title", "expected_status",
    "expected_updated", "expected_start", "expected_end", "new_start"];
  const idValid = id => typeof id === "string" &&
      /^[a-z0-9]{15}$/.test(id);
  const epoch = raw => {
    if (typeof raw !== "string" || raw.length > 48) {
      throw new Error("invalid_time");
    }
    const n = Date.parse(raw.replace(" ", "T"));
    if (!Number.isFinite(n)) throw new Error("invalid_time");
    return n;
  };
  const optionalEpoch = raw => raw === null ? null : epoch(raw);
  const same = (a, b) => a !== null && b !== null &&
      Math.abs(a - b) < 1000 || a === null && b === null;
  let firstOldStart;
  let firstOldEnd;
  let secondOldStart;
  let secondOldEnd;
  let boundary;
  try {
    if (typeof body.request_id !== "string" ||
        !/^viktor_[A-Za-z0-9_-]{8,90}$/.test(body.request_id) ||
        !allowedKeys(first, fieldsFirst) ||
        !allowedKeys(second, fieldsSecond) ||
        !idValid(first.id) || !idValid(second.id) ||
        first.id === second.id ||
        !["stopped", "completed"].includes(first.expected_status) ||
        !["running", "stopped", "completed"].includes(second.expected_status) ||
        typeof first.expected_title !== "string" ||
        typeof second.expected_title !== "string" ||
        first.expected_title.length < 1 ||
        second.expected_title.length < 1 ||
        first.expected_title.length > 160 ||
        second.expected_title.length > 160) {
      throw new Error("invalid_fields");
    }
    firstOldStart = epoch(first.expected_start);
    firstOldEnd = epoch(first.expected_end);
    secondOldStart = epoch(second.expected_start);
    secondOldEnd = optionalEpoch(second.expected_end);
    boundary = epoch(first.new_end);
    if (boundary !== epoch(second.new_start) ||
        !(firstOldStart < boundary && boundary < firstOldEnd) ||
        !(firstOldEnd <= secondOldStart) ||
        !(boundary < secondOldStart) ||
        (secondOldEnd !== null && !(secondOldStart < secondOldEnd)) ||
        (secondOldEnd !== null && !(boundary < secondOldEnd)) ||
        secondOldStart - firstOldStart > 24 * 3600000 ||
        !Number.isFinite(epoch(first.expected_updated)) ||
        !Number.isFinite(epoch(second.expected_updated)) ||
        (second.expected_status === "running") !==
          (second.expected_end === null)) {
      throw new Error("invalid_boundaries");
    }
  } catch (_) {
    return e.json(400, {error:"invalid_record_resize_request"});
  }
  try {
    e.app.runInTransaction(function(txApp) {
      const a = txApp.findRecordById("records", first.id);
      const b = txApp.findRecordById("records", second.id);
      const read = (record, field) => record.getString(field);
      const stamp = (record, field) => {
        const raw = read(record, field);
        return raw ? epoch(raw) : null;
      };
      for (const [r, expected] of [[a, first], [b, second]]) {
        if (read(r, "user_id") !== owner) throw new Error("not_owned");
        if (read(r, "parent_id")) throw new Error("nested_record");
        if (read(r, "title") !== expected.expected_title ||
            read(r, "status") !== expected.expected_status ||
            stamp(r, "updated") !== epoch(expected.expected_updated) ||
            !same(stamp(r, "start_time"), epoch(expected.expected_start)) ||
            !same(stamp(r, "end_time"),
                  optionalEpoch(expected.expected_end))) {
          throw new Error("stale_record");
        }
      }
      const currentStart = stamp(a, "start_time");
      const currentFinish = secondOldEnd === null ?
          Date.now() : secondOldEnd;
      if (currentFinish <= boundary || currentStart >= boundary) {
        throw new Error("invalid_interval");
      }
      // Even a previous-day running Record must be considered. This query
      // includes all overlapping records, not merely those on the UI day.
      const overlaps = txApp.findRecordsByFilter("records",
        "user_id = {:owner} && start_time < {:finish} && " +
          "(end_time = '' || end_time > {:begin})",
        "+start_time", 501, 0, {
          owner:owner, begin:new Date(firstOldStart).toISOString(),
          finish:new Date(currentFinish).toISOString(),
        });
      if (overlaps.length >= 501) throw new Error("too_many_records");
      for (const existing of overlaps) {
        if (read(existing, "parent_id") ||
            existing.id === a.id || existing.id === b.id) continue;
        const oldStart = stamp(existing, "start_time");
        const oldEnd = stamp(existing, "end_time") ?? Date.now();
        if (oldStart !== null && oldStart < currentFinish &&
            oldEnd > firstOldStart) {
          throw new Error("record_overlap");
        }
      }
      // No third primary record may start between these two entries.
      const between = txApp.findRecordsByFilter("records",
        "user_id = {:owner} && start_time > {:first} && " +
          "start_time < {:second}",
        "", 101, 0, {
          owner:owner, first:new Date(firstOldStart).toISOString(),
          second:new Date(secondOldStart).toISOString(),
        });
      if (between.some(r => !read(r, "parent_id") &&
          r.id !== a.id && r.id !== b.id)) {
        throw new Error("not_adjacent");
      }
      // Only these two allowed boundary fields change. Transaction rollback
      // on either save failure prevents partial Timeline corruption.
      a.set("end_time", new Date(boundary).toISOString());
      b.set("start_time", new Date(boundary).toISOString());
      txApp.save(a);
      txApp.save(b);
    });
    return e.json(200, {ok:true, updated:2,
      ids:[first.id, second.id]});
  } catch (error) {
    const reason = String(error && error.message || error);
    const expected = ["not_owned", "nested_record", "stale_record",
      "invalid_interval", "too_many_records", "record_overlap",
      "not_adjacent"];
    return e.json(409, {ok:false,
      error:expected.includes(reason) ? reason :
          "record_transaction_failed"});
  }
});
