from pathlib import Path


def replace_once(path: str, old: str, new: str, label: str) -> None:
    p = Path(path)
    text = p.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected 1 match, found {count}")
    p.write_text(text.replace(old, new, 1), encoding="utf-8")


plan = "lib/data/plan_service.dart"
replace_once(
    plan,
    '''      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return null;
      final uid = _escapeForPbFilter(authId);
      final esc = _escapeForPbFilter(key);
      final rec = await _pb
          .collection(PbCollections.plans)
          .getFirstListItem('plan_id = "$esc" && user_id = "$uid"');
''',
    '''      final ownerFilter = _pocketBaseOwnerFilterClauseForRecords();
      if (ownerFilter == null || ownerFilter.isEmpty) return null;
      final esc = _escapeForPbFilter(key);
      final rec = await _pb
          .collection(PbCollections.plans)
          .getFirstListItem('plan_id = "$esc" && $ownerFilter');
''',
    "plan id resolution",
)
replace_once(
    plan,
    '''    final authId = _userIdForWhere;
    if (authId == null || authId.isEmpty) return [];
    final uid = _escapeForPbFilter(authId);
    final sw = Stopwatch()..start();
''',
    '''    final ownerFilter = _pocketBaseOwnerFilterClauseForRecords();
    if (ownerFilter == null || ownerFilter.isEmpty) return [];
    final sw = Stopwatch()..start();
''',
    "all plans owner setup",
)
replace_once(
    plan,
    '''            expand: kPbPlanTagsExpand,
            filter: 'user_id = "$uid"',
            batch: 200,
''',
    '''            expand: kPbPlanTagsExpand,
            filter: ownerFilter,
            batch: 200,
''',
    "all plans query",
)
replace_once(
    plan,
    '''      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb
          .collection(PbCollections.plans)
          .getFullList(filter: 'user_id = "$uid"', expand: kPbPlanTagsExpand);
''',
    '''      final ownerFilter = _pocketBaseOwnerFilterClauseForRecords();
      if (ownerFilter == null || ownerFilter.isEmpty) return [];
      final list = await _pb
          .collection(PbCollections.plans)
          .getFullList(filter: ownerFilter, expand: kPbPlanTagsExpand);
''',
    "fetchPlans query",
)
replace_once(
    plan,
    '''  String? _pocketBaseOwnerFilterClauseForPlans() {
    final uid = _userIdForWhere?.trim() ?? '';
    if (uid.isEmpty) return null;
    return 'user_id = "${_escapeForPbFilter(uid)}"';
  }
''',
    '''  String? _pocketBaseOwnerFilterClauseForPlans() {
    return _pocketBaseOwnerFilterClauseForRecords();
  }
''',
    "plans realtime filter",
)

notes = "lib/data/plans/notes_brain_helpers.dart"
replace_once(
    notes,
    '''      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return;
      final uid = _escapeForPbFilter(authId);
      final rows = await _pb
          .collection(PbCollections.plans)
          .getFullList(
            filter: 'user_id = "$uid"',
            fields: 'id,created,updated',
''',
    '''      final ownerFilter = _pocketBaseOwnerFilterClauseForRecords();
      if (ownerFilter == null || ownerFilter.isEmpty) return;
      final rows = await _pb
          .collection(PbCollections.plans)
          .getFullList(
            filter: ownerFilter,
            fields: 'id,created,updated',
''',
    "notes timestamp query",
)

tags = "lib/data/profile/tag_catalog.dart"
replace_once(
    tags,
    '''      final authId = _userIdForWhere;
      if (authId == null || authId.isEmpty) return [];
      final uid = _escapeForPbFilter(authId);
      final list = await _pb
          .collection(PbCollections.tags)
          .getFullList(filter: 'user_id = "$uid"');
''',
    '''      final ownerFilter = _pocketBaseOwnerFilterClauseForRecords();
      if (ownerFilter == null || ownerFilter.isEmpty) return [];
      final list = await _pb
          .collection(PbCollections.tags)
          .getFullList(filter: ownerFilter);
''',
    "tags query",
)

plan_text = Path(plan).read_text(encoding="utf-8")
notes_text = Path(notes).read_text(encoding="utf-8")
tags_text = Path(tags).read_text(encoding="utf-8")
assert "getFirstListItem('plan_id = \"$esc\" && $ownerFilter')" in plan_text
assert "getFullList(filter: ownerFilter, expand: kPbPlanTagsExpand)" in plan_text
assert "return _pocketBaseOwnerFilterClauseForRecords();" in plan_text
assert "filter: ownerFilter," in notes_text
assert "getFullList(filter: ownerFilter)" in tags_text
