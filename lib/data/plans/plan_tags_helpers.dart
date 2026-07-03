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
}
