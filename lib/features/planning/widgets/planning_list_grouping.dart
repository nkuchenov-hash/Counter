import 'package:counter/data/database_service.dart';
import 'package:counter/data/models.dart';

/// Sentinel group id for plans with no chip tags (matches quick-add “No Tags”).
const int kPlanningUntaggedPlanGroupId = -1;

int planningTaskSortCmp(
  PlanningTask a,
  PlanningTask b, {
  required bool Function(PlanningTask task) sortTreatAsDone,
}) {
  if (sortTreatAsDone(a) != sortTreatAsDone(b)) {
    return sortTreatAsDone(a) ? 1 : -1;
  }
  final o = a.order.compareTo(b.order);
  if (o != 0) return o;
  return a.title.compareTo(b.title);
}

Map<String, List<PlanningTask>> groupPlanningTasksByCategoryPath(
  List<PlanningTask> tasks, {
  required bool Function(PlanningTask task) sortTreatAsDone,
}) {
  final groups = <String, List<PlanningTask>>{};
  for (final t in tasks) {
    final path = DatabaseService.instance.getCategoryPath(t.categoryId);
    groups.putIfAbsent(path, () => []).add(t);
  }
  for (final e in groups.entries) {
    e.value.sort(
      (a, b) => planningTaskSortCmp(
        a,
        b,
        sortTreatAsDone: sortTreatAsDone,
      ),
    );
  }
  return groups;
}

/// Bar index for [tagId] in [masterBarOrder]; tags not in the bar sort after all bar tags.
int planningMasterBarIndexForTag(int tagId, List<Tag> masterBarOrder) {
  for (var i = 0; i < masterBarOrder.length; i++) {
    if (masterBarOrder[i].tagId == tagId) return i;
  }
  return 1 << 20;
}

/// Chip tag that appears earliest in the quick-pick / master sequence wins the group.
/// Canonical [Tag] is taken from [masterBarOrder] when present, else the task tag.
Tag? planningPriorityTagForPlanByMasterBar(
  PlanningTask p,
  List<Tag> masterBarOrder,
) {
  Tag? best;
  var bestIdx = 1 << 30;
  var bestBiz = 1 << 30;
  for (final tg in p.tags) {
    if (!tg.rendersAsChip) continue;
    final idx = planningMasterBarIndexForTag(tg.tagId, masterBarOrder);
    final id = tg.tagId;
    if (idx < bestIdx || (idx == bestIdx && id < bestBiz)) {
      bestIdx = idx;
      bestBiz = id;
      Tag? canonical;
      for (final m in masterBarOrder) {
        if (m.tagId == id) {
          canonical = m;
          break;
        }
      }
      best = canonical ?? tg;
    }
  }
  return best;
}

List<Tag> planningTagSortMasterBarOrder({
  required List<Tag> quickAddAvailableTags,
  required List<Tag> cachedUserTagsCatalog,
  required Tag syntheticNoTagsTag,
}) {
  final raw = quickAddAvailableTags.isNotEmpty
      ? quickAddAvailableTags
      : List<Tag>.from(cachedUserTagsCatalog);
  if (raw.any((t) => t.tagId == kPlanningUntaggedPlanGroupId)) {
    return raw;
  }
  return [...raw, syntheticNoTagsTag];
}

Map<int, List<PlanningTask>> groupPlanningTasksByMasterBar(
  List<PlanningTask> tasks,
  List<Tag> masterBarOrder, {
  required bool Function(PlanningTask task) sortTreatAsDone,
}) {
  final groups = <int, List<PlanningTask>>{};
  for (final p in tasks) {
    final pt = planningPriorityTagForPlanByMasterBar(p, masterBarOrder);
    final gid = pt == null ? kPlanningUntaggedPlanGroupId : pt.tagId;
    groups.putIfAbsent(gid, () => []).add(p);
  }
  for (final e in groups.entries) {
    e.value.sort(
      (a, b) => planningTaskSortCmp(
        a,
        b,
        sortTreatAsDone: sortTreatAsDone,
      ),
    );
  }
  return groups;
}

/// Group column order: follow [masterBarOrder] (including synthetic “No Tags” at [-1]),
/// then orphan tag ids (by id). Untagged tasks appear where [-1] sits in the bar order.
List<int> planningGroupIdsInMasterBarSequence(
  Map<int, List<PlanningTask>> groups,
  List<Tag> masterBarOrder,
) {
  final seen = <int>{};
  final out = <int>[];
  for (final t in masterBarOrder) {
    final id = t.tagId;
    if (id == 0) continue;
    if (id == kPlanningUntaggedPlanGroupId) {
      final bucket = groups[kPlanningUntaggedPlanGroupId];
      if (bucket != null &&
          bucket.isNotEmpty &&
          !seen.contains(kPlanningUntaggedPlanGroupId)) {
        seen.add(kPlanningUntaggedPlanGroupId);
        out.add(kPlanningUntaggedPlanGroupId);
      }
      continue;
    }
    final bucket = groups[id];
    if (bucket != null && bucket.isNotEmpty && !seen.contains(id)) {
      seen.add(id);
      out.add(id);
    }
  }
  final orphan =
      groups.keys
          .where((k) => k != kPlanningUntaggedPlanGroupId && !seen.contains(k))
          .toList()
        ..sort();
  out.addAll(orphan);
  if (!seen.contains(kPlanningUntaggedPlanGroupId)) {
    final untagged = groups[kPlanningUntaggedPlanGroupId];
    if (untagged != null && untagged.isNotEmpty) {
      out.add(kPlanningUntaggedPlanGroupId);
    }
  }
  return out;
}
