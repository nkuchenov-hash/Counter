import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only Time View setting: tag ids treated as fixed-time barriers.
const String kTimeViewFixedTagIdsPrefsKey = 'time_view_fixed_tag_ids_v1';

/// Meeting/call appointments are schedule anchors, not flexible work.
/// This rule is independent of the browser's local tag-settings cache. The
/// explicit fixed-tag selection extends this built-in protection.
const Set<String> kInherentlyFixedTimeTagNames = {
  'meeting', 'meetings', 'встреча', 'встречи',
  'appointment', 'appointments', 'созвон', 'созвоны',
  'call', 'calls', 'звонок', 'звонки',
};

/// A locked appointment MUST keep its persisted start and end unless the
/// user explicitly edits that appointment or confirms Viktor's exact change.
/// Never make protection conditional on local SharedPreferences being loaded.
bool isPlanFixedInTimeView(PlanningTask task, Set<String> fixedTagIds) {
  for (final tag in task.tags) {
    if (kInherentlyFixedTimeTagNames.contains(
      tag.name.trim().toLowerCase(),
    )) return true;
    final pbId = tag.pbRecordId?.trim() ?? '';
    if (pbId.isNotEmpty && fixedTagIds.contains(pbId)) return true;
    if (tag.tagId != 0 && fixedTagIds.contains(tag.tagId.toString())) {
      return true;
    }
  }
  return false;
}

/// Return the first protected row changed by an automatic schedule rewrite.
/// Both start AND end are immutable. An explicit manual edit must be handled
/// separately from a generic cascade/reflow.
PlanningTask? firstAutomaticallyChangedFixedPlan({
  required List<PlanningTask> before,
  required List<PlanningTask> after,
  Set<String> fixedTagIds = const {},
  Set<String> explicitlyEditedPlanIds = const {},
}) {
  final byId = {for (final task in after) task.planRowIdForBackend: task};
  for (final task in before) {
    final id = task.planRowIdForBackend;
    if (explicitlyEditedPlanIds.contains(id) ||
        !isPlanFixedInTimeView(task, fixedTagIds)) continue;
    final next = byId[id];
    if (next != null && (task.startTime != next.startTime ||
        task.endDateTime != next.endDateTime)) return task;
  }
  return null;
}

/// Fixed-time tag ids for Time View cascade barriers (SharedPreferences, profile-local).
class TimeViewFixedTagPrefs {
  TimeViewFixedTagPrefs._();

  static Future<Set<String>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(kTimeViewFixedTagIdsPrefsKey);
    if (raw == null || raw.isEmpty) return {};
    if (kDebugMode) {
      debugPrint('[TIME_VIEW_FIXED_TAGS_LOADED] count=${raw.length}');
    }
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> save(Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    final sorted = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
      ..sort();
    await p.setStringList(kTimeViewFixedTagIdsPrefsKey, sorted);
  }

  /// Optional suggestions only — user must confirm in settings UI.
  static Set<String> suggestFixedTagIdsFromNames(Iterable<Tag> tags) {
    const needles = [
      'meeting',
      'call',
      'звонок',
      'созвон',
      'встреча',
    ];
    final out = <String>{};
    for (final tag in tags) {
      final name = tag.name.trim().toLowerCase();
      if (name.isEmpty) continue;
      final matches = needles.any(
        (n) => name == n || name.contains(n),
      );
      if (!matches) continue;
      final pbId = tag.pbRecordId?.trim();
      if (pbId != null && pbId.isNotEmpty) {
        out.add(pbId);
        continue;
      }
      out.add(tag.tagId.toString());
    }
    return out;
  }
}


/// Only the dragged task and its connected collision chain may move.
/// Existing unrelated overlaps elsewhere on the day are not normalized by a
/// single drag. A fixed plan rejects the move only if this chain reaches it.
List<PlanningTask>? cascadeTimeViewAffectedChain({
  required List<PlanningTask> orderedTasks,
  required Set<String> draggedPlanIds,
  required Set<String> fixedPlanIds,
  required int Function(PlanningTask task) durationMinutes,
}) {
  final out = <PlanningTask>[];
  DateTime? occupiedUntil;
  var activeChain = draggedPlanIds.isEmpty;
  for (final task in orderedTasks) {
    final originalStart = task.startTime;
    if (originalStart == null) {
      out.add(task);
      continue;
    }
    final id = task.planRowIdForBackend;
    final moved = draggedPlanIds.contains(id);
    var start = originalStart;
    final collision = occupiedUntil != null && start.isBefore(occupiedUntil);
    if (moved) activeChain = true;
    if (collision && activeChain) {
      if (fixedPlanIds.contains(id) && !moved) return null;
      start = occupiedUntil!;
    } else if (!collision && !moved && draggedPlanIds.isNotEmpty) {
      activeChain = false;
    }
    final inferredEnd = start.add(Duration(minutes: durationMinutes(task)));
    // A non-selected fixed-time card is an immutable absolute interval,
    // including its explicit end; do not overwrite it with tag defaults.
    final protected = !moved &&
        (fixedPlanIds.contains(id) || isPlanFixedInTimeView(task, const {}));
    if (protected && start != originalStart) return null;
    final end = protected
        ? (task.endDateTime ?? inferredEnd)
        : inferredEnd;
    out.add(protected
        ? task
        : task.copyWith(startTime: start, endDateTime: end, clearEnd: false));
    if (occupiedUntil == null || end.isAfter(occupiedUntil)) {
      occupiedUntil = end;
    }
  }
  return out;
}

/// Reject overlaps caused by the move, not pre-existing conflicts between
/// untouched plans somewhere else on the day.
bool timeViewAffectedPlansHaveOverlap({
  required List<PlanningTask> original,
  required List<PlanningTask> resolved,
  required Set<String> draggedPlanIds,
  required int Function(PlanningTask task) durationMinutes,
}) {
  final before = {for (final task in original) task.planRowIdForBackend: task};
  final scheduled = resolved.where((task) => task.startTime != null).toList();
  for (final task in scheduled) {
    final id = task.planRowIdForBackend;
    if (!draggedPlanIds.contains(id) && before[id]?.startTime == task.startTime) {
      continue;
    }
    final start = task.startTime!;
    final end = start.add(Duration(minutes: durationMinutes(task)));
    for (final other in scheduled) {
      if (other.planRowIdForBackend == id) continue;
      final otherStart = other.startTime!;
      final otherEnd = otherStart.add(Duration(minutes: durationMinutes(other)));
      if (start.isBefore(otherEnd) && otherStart.isBefore(end)) return true;
    }
  }
  return false;
}
