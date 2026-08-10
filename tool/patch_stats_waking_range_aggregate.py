from pathlib import Path

p = Path('lib/data/categories/category_stats.dart')
s = p.read_text()

if 'DateTime? rangeStartWall' in s:
    raise SystemExit(0)

old = '''  List<StatsNode> getAggregatedStats(
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
'''
new = '''  List<StatsNode> getAggregatedStats(
    List<Map<String, dynamic>> records,
    DateTime selectedDay, {
    DateTime? rangeStartWall,
    DateTime? rangeEndWall,
  }) {
    final key = Object.hash(
      CategoryServiceExtension.statsRecordsSignature(records, selectedDay),
      rangeStartWall?.millisecondsSinceEpoch ?? 0,
      rangeEndWall?.millisecondsSinceEpoch ?? 0,
    );
    if (key == _lastAggregatedKey && _lastStatsNodeRoots != null) {
      return _lastStatsNodeRoots!;
    }
    final oh = _settings.timezoneOffsetHours;
    final tzLabel = _settings.preferredTimeZone;

    int durationFor(Map<String, dynamic> rec) {
      if (rangeStartWall == null || rangeEndWall == null) {
        return CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
          rec,
          selectedDay,
          oh,
          tzLabel,
        );
      }
      final type = rec['type'] as String? ?? 'record';
      if (type == 'planned') return 0;
      final startUtc = CategoryServiceExtension.startTimeFromRecord(rec);
      if (startUtc == null) return 0;
      final endParsed = CategoryServiceExtension.endTimeFromRecord(rec);
      final status = (rec['status'] as String? ?? '').toLowerCase();
      final DateTime endUtc;
      if (endParsed != null) {
        endUtc = endParsed;
      } else if (status == 'running') {
        endUtc = DatabaseService.getPlanetaryNow();
      } else {
        return 0;
      }
      var startWall = applyUserOffset(startUtc);
      var endWall = applyUserOffset(endUtc);
      if (startWall.isBefore(rangeStartWall)) startWall = rangeStartWall;
      if (endWall.isAfter(rangeEndWall)) endWall = rangeEndWall;
      if (!endWall.isAfter(startWall)) return 0;
      return endWall.difference(startWall).inSeconds;
    }

    final Map<String, _BuildNode> roots = {};
'''
if old not in s:
    raise SystemExit('missing getAggregatedStats header')
s = s.replace(old, new, 1)

old = '''      final sec = CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
        rec,
        selectedDay,
        oh,
        tzLabel,
      );
'''
if old not in s:
    raise SystemExit('missing node duration')
s = s.replace(old, '      final sec = durationFor(rec);\n', 1)

old = '''            groupSec += CategoryServiceExtension.recordDurationSecondsWithinDayFromTimestamps(
              r,
              selectedDay,
              oh,
              tzLabel,
            );
'''
if old not in s:
    raise SystemExit('missing group duration')
s = s.replace(old, '            groupSec += durationFor(r);\n', 1)
p.write_text(s)

p = Path('lib/features/stats/stats_view.dart')
s = p.read_text()
old = '''      aggregated = DatabaseService.instance.getAggregatedStats(
        statsRecords,
        widget.selectedDate,
      );
'''
new = '''      aggregated = DatabaseService.instance.getAggregatedStats(
        statsRecords,
        widget.selectedDate,
        rangeStartWall: wakingWindow.wakeWall,
        rangeEndWall: wakingWindow.bedWall,
      );
'''
if old not in s:
    if 'rangeStartWall: wakingWindow.wakeWall' in s:
        raise SystemExit(0)
    raise SystemExit('missing StatsView aggregate call')
s = s.replace(old, new, 1)
p.write_text(s)
