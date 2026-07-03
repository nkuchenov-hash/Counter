part of '../database_service.dart';

extension CategoryStatsExtension on DatabaseService {
  List<Map<String, dynamic>> getRecordsByCategoryId(
    int categoryId,
    List<Map<String, dynamic>> allRecords,
  ) {
    final ids = getRecordIdsInSubtree(categoryId);
    return allRecords.where((rec) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      return id != null && ids.contains(id);
    }).toList();
  }

  Duration getDurationForCategory(
    int categoryId,
    List<Map<String, dynamic>> records,
  ) {
    final ids = getRecordIdsInSubtree(categoryId);
    var sec = 0;
    for (final rec in records) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      if (id != null && ids.contains(id)) {
        sec += CategoryServiceExtension.recordDurationSeconds(rec);
      }
    }
    return Duration(seconds: sec);
  }

  Duration getDurationForCategoryWithinDay(
    int categoryId,
    List<Map<String, dynamic>> records,
    DateTime selectedDay,
  ) {
    final ids = getRecordIdsInSubtree(categoryId);
    var sec = 0;
    for (final rec in records) {
      final cid = rec['categoryId'];
      final id = cid is int ? cid : int.tryParse(cid?.toString() ?? '');
      if (id != null && ids.contains(id)) {
        sec += CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
          rec,
          selectedDay,
          _settings.timezoneOffsetHours,
          _settings.preferredTimeZone,
        );
      }
    }
    return Duration(seconds: sec);
  }

  List<StatsNode> getAggregatedStats(
    List<Map<String, dynamic>> records,
    DateTime selectedDay,
  ) {
    final key = CategoryServiceExtension.statsRecordsSignature(records, selectedDay);
    if (key == _lastAggregatedKey && _lastStatsNodeRoots != null) {
      return _lastStatsNodeRoots!;
    }
    final oh = _settings.timezoneOffsetHours;
    final tzLabel = _settings.preferredTimeZone;
    final Map<String, _BuildNode> roots = {};
    for (final rec in records) {
      final pathStr = resolvedCategoryPathForRecord(rec);
      var segments = pathStr
          .split(' > ')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.isEmpty) segments = ['Legacy Data'];
      final sec = CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
        rec,
        selectedDay,
        oh,
        tzLabel,
      );
      Map<String, _BuildNode> current = roots;
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        final isLeaf = i == segments.length - 1;
        final node = current.putIfAbsent(segment, () => _BuildNode(segment));
        node.totalSeconds += sec;
        if (isLeaf) {
          final title = (rec['title'] as String?)?.trim();
          final taskLabel = (title != null && title.isNotEmpty)
              ? title
              : 'Untitled';
          final groupKey = CategoryServiceExtension._normalize(taskLabel);
          node.sessionGroups.putIfAbsent(groupKey, () => []);
          node.sessionGroups[groupKey]?.add(rec);
        } else {
          current = node.children;
        }
      }
    }
    List<StatsNode> toNodeList(Map<String, _BuildNode> map) {
      final list = map.values.toList();
      list.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
      return list.map((n) {
        final sortedGroups = n.sessionGroups.entries.map((e) {
          var groupSec = 0;
          for (final r in e.value) {
            groupSec += CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
              r,
              selectedDay,
              oh,
              tzLabel,
            );
          }
          final actualTitles = e.value
              .map((r) => (r['title'] as String?)?.trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toSet();
          final sortedByStart = List<Map<String, dynamic>>.from(e.value);
          sortedByStart.sort((a, b) {
            final at = CategoryServiceExtension.startTimeFromRecord(a);
            final bt = CategoryServiceExtension.startTimeFromRecord(b);
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });
          var displayLabel =
              (sortedByStart.isNotEmpty && sortedByStart.first['title'] != null)
              ? (sortedByStart.first['title'] as String).trim()
              : '';
          if (displayLabel.isEmpty) displayLabel = e.key;
          return SessionGroup(
            label: displayLabel,
            totalSeconds: groupSec,
            records: e.value,
            actualTitles: actualTitles,
          );
        }).toList();
        sortedGroups.sort((a, b) => b.totalSeconds.compareTo(a.totalSeconds));
        return StatsNode(
          label: n.label,
          totalSeconds: n.totalSeconds,
          children: n.children.isEmpty ? const [] : toNodeList(n.children),
          sessionGroups: sortedGroups,
        );
      }).toList();
    }

    final result = toNodeList(roots);
    _lastAggregatedKey = key;
    _lastStatsNodeRoots = result;
    return result;
  }
}
