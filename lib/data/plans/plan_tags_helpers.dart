part of '../database_service.dart';

extension PlanTagsExtension on DatabaseService {
  Future<List<Tag>> _fetchPlanAndListTagCatalog() async {
    await fetchTagsForCurrentUser(scope: TagCatalogScope.plan);
    final all = cachedUserTagsCatalog;
    if (all.isNotEmpty) return all;
    return fetchTagsForCurrentUser(scope: TagCatalogScope.list);
  }

  Future<void> _syncPlanTagsPocket(String planRecordId, List<Tag> tags) async {
    final rid = planRecordId.trim();
    if (rid.isEmpty) return;
    try {
      final pbIds = await _pbTagRecordIdsFromTags(tags);
      if (tags.isNotEmpty &&
          pbIds.length < tags.where((t) => t.rendersAsChip).length &&
          kDebugMode) {
        debugPrint(
          '[PB] _syncPlanTagsPocket: resolved ${pbIds.length} link id(s) '
          'from ${tags.length} tag(s); missing rows need pbRecordId / tag_id in catalog. plan=$rid',
        );
      }
      await _pb
          .collection(PbCollections.plans)
          .update(rid, body: <String, dynamic>{kPbPlanTagsExpand: pbIds});
    } catch (e, st) {
      DatabaseService._log('SYNC_PLAN_TAGS_PB: $e');
      DatabaseService._log(st.toString());
    }
  }

  bool _planTagsEqual(List<Tag> a, List<Tag> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pbRecordId != b[i].pbRecordId ||
          a[i].name != b[i].name ||
          a[i].color != b[i].color) {
        return false;
      }
    }
    return true;
  }

  List<Tag> _refreshTaskTagsFromCatalog(List<Tag> tags) {
    if (tags.isEmpty || _userTagsCatalogCache.isEmpty) return tags;
    final byPb = <String, Tag>{
      for (final t in _userTagsCatalogCache)
        if ((t.pbRecordId ?? '').trim().isNotEmpty) t.pbRecordId!: t,
    };
    if (byPb.isEmpty) return tags;
    return [for (final tag in tags) byPb[tag.pbRecordId ?? ''] ?? tag];
  }

  /// After tag catalog PATCH/create/delete, refresh embedded tag chips on cached plans.
  void syncEmbeddedPlanTagsFromCatalog() {
    var changed = false;
    final nextCache = <PlanningTask>[];
    for (final t in _allPlansUserCache) {
      final nt = _refreshTaskTagsFromCatalog(t.tags);
      if (!_planTagsEqual(nt, t.tags)) {
        changed = true;
        nextCache.add(t.copyWith(tags: nt));
      } else {
        nextCache.add(t);
      }
    }
    if (changed) _allPlansUserCache = nextCache;
    for (final m in _planningOptimisticByDateKey.values) {
      for (final e in m.entries.toList()) {
        final nt = _refreshTaskTagsFromCatalog(e.value.tags);
        if (!_planTagsEqual(nt, e.value.tags)) {
          m[e.key] = e.value.copyWith(tags: nt);
          changed = true;
        }
      }
    }
    if (changed) {
      notifyPlanningRefresh(scheduleNetworkRefresh: false);
    }
  }
}
