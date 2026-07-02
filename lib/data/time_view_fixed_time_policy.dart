import 'package:counter/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only Time View setting: tag ids treated as fixed-time barriers.
const String kTimeViewFixedTagIdsPrefsKey = 'time_view_fixed_tag_ids_v1';

/// True when [task] has at least one tag id in [fixedTagIds].
bool isPlanFixedInTimeView(PlanningTask task, Set<String> fixedTagIds) {
  if (fixedTagIds.isEmpty) return false;
  for (final tag in task.tags) {
    final pbId = tag.pbRecordId?.trim() ?? '';
    if (pbId.isNotEmpty && fixedTagIds.contains(pbId)) {
      return true;
    }
    final legacyId = tag.tagId.toString();
    if (legacyId.isNotEmpty && fixedTagIds.contains(legacyId)) {
      return true;
    }
  }
  return false;
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
