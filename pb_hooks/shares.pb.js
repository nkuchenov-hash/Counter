/// <reference path="../pb_data/types.d.ts" />
// Shared objects: all collections are private. Each route authenticates and
// authorizes against owner or an explicitly accepted member. No public profile
// enumeration; personal People contacts are never shared as a payload.
(function () {
  const idOk = x => /^[a-z0-9]{15}$/.test(String(x || ""));
  const dayOk = x => /^\d{4}-\d{2}-\d{2}$/.test(String(x || ""));
  const txt = (x, cap) => String(x == null ? "" : x).trim().slice(0, cap);
  const auth = e => {
    const who = e.requestInfo().auth;
    return who && idOk(who.id) ? who.id : "";
  };
  const fail = (e, status, code) => e.json(status, {error: code});
  const own = (row, uid) => row.getString("owner_id") === uid;
  const filtered = (table, expression, params, limit = 100) =>
    $app.findRecordsByFilter(table, expression, "-created", limit, 0, params);
  const readObject = sid => idOk(sid) ? $app.findRecordById("shared_objects", sid) : null;
  const getMember = (sid, uid) => {
    try {
      return $app.findFirstRecordByFilter(
        "shared_members", "object_id = {:sid} && user_id = {:uid}", {sid, uid}
      );
    } catch (_) { return null; }
  };
  const canRead = (row, uid) => own(row, uid) ||
    (getMember(row.id, uid)?.getString("status") === "accepted");
  const bodyOf = e => e.requestInfo().body || {};
  const contentOf = row => {
    const content = row.get("content");
    if (typeof content === "string") {
      try { return JSON.parse(content); } catch (_) { return {}; }
    }
    return content && typeof content === "object" ? content : {};
  };
  const make = (table, values) => {
    const record = new Record($app.findCollectionByNameOrId(table));
    for (const k of Object.keys(values)) record.set(k, values[k]);
    $app.save(record);
    return record;
  };
  const summary = row => ({
    id: row.id, kind: row.getString("kind"),
    title: row.getString("title"), wall_day: row.getString("wall_day"),
    owner_id: row.getString("owner_id"),
    revision: row.getInt("revision"), archived: row.getBool("archived"),
    created: row.getString("created"),
  });
  const memberDto = row => ({
    id: row.id, user_id: row.getString("user_id"),
    role: row.getString("role"), status: row.getString("status"),
  });
  // Personal state is never included in a different participant's response.
  // Missing row means "not completed" for this participant only.
  const personalCompletion = (sid, uid) => {
    const rows = filtered("shared_personal_state",
      "object_id = {:sid} && user_id = {:uid}", {sid, uid}, 60);
    const state = {};
    for (const row of rows) {
      if (idOk(row.getString("source_plan_id"))) {
        state[row.getString("source_plan_id")] = row.getBool("completed");
      }
    }
    return state;
  };
  const messageDto = row => ({
    id: row.id, author_id: row.getString("author_id"),
    kind: row.getString("kind"), body: row.getString("body"),
    patch: row.get("patch") || {}, base_revision: row.getInt("base_revision"),
    status: row.getString("status"), created: row.getString("created"),
  });
  const guarded = fn => e => {
    const uid = auth(e);
    if (!uid) return fail(e, 401, "auth_required");
    try { return fn(e, uid); }
    catch (err) {
      // Never return internal DB/PocketBase errors or recipient identity data.
      return fail(e, 500, "share_operation_failed");
    }
  };
  const accessible = (e, uid, sid) => {
    if (!idOk(sid)) return null;
    let row;
    try { row = readObject(sid); } catch (_) { return null; }
    return row && !row.getBool("archived") && canRead(row, uid) ? row : null;
  };
  const simpleTime = t => t === "" || (typeof t === "string" &&
    /^\d{4}-\d{2}-\d{2}[^\n]{0,35}$/.test(t) && !isNaN(Date.parse(t)));
  const proposalPatch = (raw, rows) => {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
    const keys = Object.keys(raw);
    if (!keys.length || keys.some(k => !["plan_id", "title", "start_time", "end_time"].includes(k))) return null;
    if (!idOk(raw.plan_id) || !rows.some(x => x.plan_id === raw.plan_id)) return null;
    const clean = {plan_id: raw.plan_id};
    let touched = false;
    if (Object.prototype.hasOwnProperty.call(raw, "title")) {
      if (typeof raw.title !== "string" || !raw.title.trim() || raw.title.length > 160) return null;
      clean.title = raw.title.trim(); touched = true;
    }
    for (const k of ["start_time", "end_time"]) {
      if (Object.prototype.hasOwnProperty.call(raw, k)) {
        if (typeof raw[k] !== "string" || !simpleTime(raw[k])) return null;
        clean[k] = raw[k]; touched = true;
      }
    }
    return touched ? clean : null;
  };

  // Create a deliberately limited shared projection, not a copy of the user's
  // categories, rich Notes, personal tags or actual time records.
  routerAdd("POST", "/api/shares", guarded((e, uid) => {
    const body = bodyOf(e);
    if (body.kind !== "plan_day" || !dayOk(body.wall_day) ||
        !Array.isArray(body.plan_ids) || body.plan_ids.length === 0 ||
        body.plan_ids.length > 40 || new Set(body.plan_ids).size !== body.plan_ids.length) {
      return fail(e, 400, "invalid_share_selection");
    }
    const items = [];
    for (const planId of body.plan_ids) {
      if (!idOk(planId)) return fail(e, 400, "invalid_plan_id");
      let plan;
      try { plan = $app.findRecordById("plans", planId); }
      catch (_) { return fail(e, 404, "plan_not_found"); }
      if (plan.getString("user_id") !== uid) return fail(e, 403, "plan_not_owned");
      items.push({
        plan_id: plan.id, title: txt(plan.getString("title"), 160),
        start_time: plan.getString("start_time"),
        end_time: plan.getString("end_time"),
        order: plan.getInt("order"),
      });
    }
    const row = make("shared_objects", {
      owner_id: uid, kind: "plan_day", title: txt(body.title, 160) ||
        "Shared plan " + body.wall_day,
      wall_day: body.wall_day, revision: 1,
      content: {items}, archived: false,
    });
    return e.json(201, {share: summary(row), content: {items}});
  }));

  // Owner and invited recipients discover only their own shares.
  routerAdd("GET", "/api/shares", guarded((e, uid) => {
    const owned = filtered("shared_objects",
      "owner_id = {:uid} && archived = false", {uid}, 60);
    const invites = filtered("shared_members",
      'user_id = {:uid} && status != "revoked"', {uid}, 100);
    const seen = new Set();
    const out = [];
    for (const row of owned) {
      seen.add(row.id);
      out.push({...summary(row), my_status: "owner"});
    }
    for (const member of invites) {
      if (seen.has(member.getString("object_id"))) continue;
      let row;
      try { row = readObject(member.getString("object_id")); } catch (_) { continue; }
      if (!row || row.getBool("archived")) continue;
      out.push({...summary(row), my_status: member.getString("status")});
    }
    return e.json(200, {shares: out});
  }));

  // Visible-day shared projection for Planner/Calendar. Only owner or
  // explicitly accepted members; invitations never reveal task content.
  // No per-participant plan writes and no private categories/notes.
  routerAdd("POST", "/api/shares/day", guarded((e, uid) => {
    const day = String(bodyOf(e).wall_day || "");
    if (!dayOk(day)) return fail(e, 400, "invalid_wall_day");
    const owned = filtered("shared_objects",
      "owner_id = {:uid} && wall_day = {:day} && archived = false",
      {uid, day}, 40);
    const memberships = filtered("shared_members",
      'user_id = {:uid} && status = "accepted"', {uid}, 100);
    const seen = new Set();
    const shares = [];
    const add = (row, status) => {
      if (!row || seen.has(row.id) || row.getBool("archived") ||
          row.getString("wall_day") !== day) return;
      seen.add(row.id);
      shares.push({...summary(row), my_status: status,
        content: contentOf(row),
        my_completed: personalCompletion(row.id, uid)});
    };
    for (const row of owned) add(row, "owner");
    for (const member of memberships) {
      let share;
      try { share = readObject(member.getString("object_id")); }
      catch (_) { continue; }
      // Defensive membership check if invitations change during the request.
      if (share && canRead(share, uid)) add(share, "accepted");
    }
    return e.json(200, {shares});
  }));

  routerAdd("GET", "/api/shares/{id}", guarded((e, uid) => {
    const row = accessible(e, uid, e.request.pathValue("id"));
    if (!row) return fail(e, 404, "share_not_found");
    const messages = filtered("shared_messages",
      "object_id = {:sid}", {sid: row.id}, 200).reverse();
    const members = filtered("shared_members",
      "object_id = {:sid}", {sid: row.id}, 80);
    return e.json(200, {
      share: summary(row), content: contentOf(row),
      my_completed: personalCompletion(row.id, uid),
      members: members.map(memberDto), messages: messages.map(messageDto),
    });
  }));

  // One participant's completion never changes shared schedule or another
  // participant's completion. The source plan must exist in the shared snapshot.
  routerAdd("POST", "/api/shares/{id}/completion", guarded((e, uid) => {
    const row = accessible(e, uid, e.request.pathValue("id"));
    if (!row) return fail(e, 404, "share_not_found");
    const body = bodyOf(e);
    const planId = String(body.plan_id || "");
    const items = contentOf(row).items || [];
    if (!idOk(planId) || !Array.isArray(items) ||
        !items.some(item => item.plan_id === planId) ||
        typeof body.completed !== "boolean") {
      return fail(e, 400, "invalid_personal_completion");
    }
    const params = {sid: row.id, uid, planId};
    let personal = null;
    try {
      personal = $app.findFirstRecordByFilter("shared_personal_state",
        "object_id = {:sid} && user_id = {:uid} && source_plan_id = {:planId}",
        params);
    } catch (_) {}
    if (personal) {
      personal.set("completed", body.completed);
      $app.save(personal);
    } else {
      personal = make("shared_personal_state", {
        object_id: row.id, user_id: uid, source_plan_id: planId,
        completed: body.completed,
      });
    }
    return e.json(200, {
      plan_id: planId, completed: personal.getBool("completed"),
    });
  }));

  // "People" is the only contact chooser. No raw email/profile-ID invitation.
  routerAdd("POST", "/api/shares/{id}/invite", guarded((e, uid) => {
    const sid = e.request.pathValue("id");
    const row = accessible(e, uid, sid);
    if (!row || !own(row, uid)) return fail(e, 403, "owner_required");
    const pid = txt(bodyOf(e).person_record_id, 40);
    if (!idOk(pid)) return fail(e, 400, "invalid_contact");
    let person;
    try { person = $app.findRecordById("people", pid); } catch (_) {
      return fail(e, 404, "contact_not_found");
    }
    if (person.getString("user_id") !== uid ||
        person.getBool("archived") ||
        ["ignored", "blocked"].includes(person.getString("relationship_status"))) {
      return fail(e, 403, "contact_not_eligible");
    }
    const email = txt(person.getString("primary_email"), 320).toLowerCase();
    if (!email || !email.includes("@")) return fail(e, 400, "contact_email_required");
    let recipient;
    try {
      recipient = $app.findFirstRecordByFilter(
        "profiles", "email = {:email} && verified = true", {email});
    } catch (_) { return fail(e, 409, "recipient_unavailable"); }
    if (recipient.id === uid) return fail(e, 409, "cannot_invite_self");
    let member = getMember(sid, recipient.id);
    if (member && member.getString("status") === "accepted") {
      return e.json(200, {member: memberDto(member)});
    }
    if (member) {
      member.set("status", "invited");
      member.set("role", "commenter");
      $app.save(member);
    } else {
      member = make("shared_members", {
        object_id: sid, user_id: recipient.id, invited_by: uid,
        status: "invited", role: "commenter",
      });
    }
    return e.json(200, {member: memberDto(member)});
  }));

  // Explicit owner revoke, and recipient leave. Membership rules are server
  // enforced; a revoked participant loses content immediately on next fetch.
  routerAdd("POST", "/api/shares/{id}/members/{userId}/revoke", guarded((e, uid) => {
    const sid = e.request.pathValue("id");
    let share;
    try { share = readObject(sid); } catch (_) { return fail(e, 404, "share_not_found"); }
    if (!share || !own(share, uid)) return fail(e, 403, "owner_required");
    const target = String(e.request.pathValue("userId") || "");
    if (!idOk(target) || target === uid) return fail(e, 400, "invalid_member");
    const member = getMember(sid, target);
    if (!member) return fail(e, 404, "member_not_found");
    member.set("status", "revoked");
    $app.save(member);
    return e.json(200, {member: memberDto(member)});
  }));

  routerAdd("POST", "/api/shares/{id}/leave", guarded((e, uid) => {
    const sid = e.request.pathValue("id");
    const member = getMember(sid, uid);
    if (!member || member.getString("status") === "revoked") {
      return fail(e, 404, "membership_not_found");
    }
    member.set("status", "revoked");
    $app.save(member);
    return e.json(200, {left: true});
  }));

  routerAdd("POST", "/api/shares/{id}/respond", guarded((e, uid) => {
    const sid = e.request.pathValue("id");
    const member = getMember(sid, uid);
    if (!member || member.getString("status") !== "invited") {
      return fail(e, 404, "invitation_not_found");
    }
    const answer = bodyOf(e).accept === true ? "accepted" : "declined";
    member.set("status", answer);
    $app.save(member);
    return e.json(200, {member: memberDto(member)});
  }));

  routerAdd("POST", "/api/shares/{id}/messages", guarded((e, uid) => {
    const row = accessible(e, uid, e.request.pathValue("id"));
    if (!row) return fail(e, 404, "share_not_found");
    const body = bodyOf(e);
    const kind = body.kind === "proposal" ? "proposal" : "comment";
    const message = txt(body.body, 2000);
    if (body.body && String(body.body).length > 2000) return fail(e, 413, "message_too_long");
    let patch = {}, baseRevision = 0, status = "none";
    if (kind === "proposal") {
      patch = proposalPatch(body.patch, contentOf(row).items || []);
      if (!patch) return fail(e, 400, "invalid_proposal");
      baseRevision = Number(body.base_revision);
      if (!Number.isInteger(baseRevision) || baseRevision !== row.getInt("revision")) {
        return fail(e, 409, "share_revision_conflict");
      }
      status = "pending";
    } else if (!message) {
      return fail(e, 400, "empty_message");
    }
    const entry = make("shared_messages", {
      object_id: row.id, author_id: uid, kind, body: message,
      patch, base_revision: baseRevision, status,
    });
    return e.json(201, {message: messageDto(entry)});
  }));

  routerAdd("POST", "/api/shares/{id}/proposals/{messageId}/decide", guarded((e, uid) => {
    const sid = e.request.pathValue("id");
    const mid = e.request.pathValue("messageId");
    const row = accessible(e, uid, sid);
    if (!row || !own(row, uid)) return fail(e, 403, "owner_required");
    if (!idOk(mid)) return fail(e, 400, "invalid_proposal");
    let message;
    try { message = $app.findRecordById("shared_messages", mid); }
    catch (_) { return fail(e, 404, "proposal_not_found"); }
    if (message.getString("object_id") !== sid ||
        message.getString("kind") !== "proposal" ||
        message.getString("status") !== "pending") {
      return fail(e, 409, "proposal_not_pending");
    }
    const accept = bodyOf(e).accept === true;
    if (accept && message.getInt("base_revision") !== row.getInt("revision")) {
      return fail(e, 409, "share_revision_conflict");
    }
    let nextContent = contentOf(row);
    if (accept) {
      const raw = message.get("patch") || {};
      const patch = typeof raw === "string" ? JSON.parse(raw) : raw;
      const items = Array.isArray(nextContent.items) ? nextContent.items : [];
      if (!items.some(item => item.plan_id === patch.plan_id)) {
        return fail(e, 409, "plan_no_longer_shared");
      }
      nextContent = {...nextContent, items: items.map(item =>
        item.plan_id === patch.plan_id ? {...item, ...patch} : item)};
    }
    // Both state transitions are committed together: retry cannot apply twice.
    $app.runInTransaction(tx => {
      const current = tx.findRecordById("shared_messages", mid);
      if (current.getString("status") !== "pending") throw new Error("already_decided");
      const currentShare = tx.findRecordById("shared_objects", sid);
      if (accept && currentShare.getInt("revision") !== row.getInt("revision")) {
        throw new Error("stale_share");
      }
      current.set("status", accept ? "accepted" : "rejected");
      tx.save(current);
      if (accept) {
        currentShare.set("content", nextContent);
        currentShare.set("revision", row.getInt("revision") + 1);
        tx.save(currentShare);
      }
    });
    return e.json(200, {
      status: accept ? "accepted" : "rejected",
      revision: accept ? row.getInt("revision") + 1 : row.getInt("revision"),
    });
  }));
})();
