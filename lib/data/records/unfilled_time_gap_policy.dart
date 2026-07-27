class TimelineGap {
  const TimelineGap({required this.startUtc, required this.endUtc});

  final DateTime startUtc;
  final DateTime endUtc;

  Duration get duration => endUtc.difference(startUtc);
  String get key =>
      '${startUtc.toUtc().toIso8601String()}|${endUtc.toUtc().toIso8601String()}';
}

DateTime? _gapRecordUtc(dynamic raw) {
  if (raw is DateTime) return raw.toUtc();
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

List<TimelineGap> findUnfilledTimeGaps({
  required Iterable<Map<String, dynamic>> records,
  required DateTime windowStartUtc,
  required DateTime windowEndUtc,
  required Duration minimumDuration,
}) {
  final windowStart = windowStartUtc.toUtc();
  final windowEnd = windowEndUtc.toUtc();
  if (!windowEnd.isAfter(windowStart)) return const <TimelineGap>[];

  final intervals = <({DateTime start, DateTime end})>[];
  for (final row in records) {
    final rawStart = _gapRecordUtc(row['start_time'] ?? row['startTime']);
    if (rawStart == null) continue;
    final rawEnd =
        _gapRecordUtc(row['end_time'] ?? row['endTime']) ?? windowEnd;
    if (!rawEnd.isAfter(rawStart)) continue;
    if (!rawStart.isBefore(windowEnd) || !rawEnd.isAfter(windowStart)) {
      continue;
    }
    final start = rawStart.isBefore(windowStart) ? windowStart : rawStart;
    final end = rawEnd.isAfter(windowEnd) ? windowEnd : rawEnd;
    if (end.isAfter(start)) intervals.add((start: start, end: end));
  }
  if (intervals.isEmpty) return const <TimelineGap>[];
  intervals.sort((a, b) => a.start.compareTo(b.start));

  final gaps = <TimelineGap>[];
  var cursor = intervals.first.start;
  for (final interval in intervals) {
    if (interval.start.isAfter(cursor)) {
      final gap = TimelineGap(startUtc: cursor, endUtc: interval.start);
      if (gap.duration >= minimumDuration) gaps.add(gap);
    }
    if (interval.end.isAfter(cursor)) cursor = interval.end;
  }
  if (windowEnd.isAfter(cursor)) {
    final gap = TimelineGap(startUtc: cursor, endUtc: windowEnd);
    if (gap.duration >= minimumDuration) gaps.add(gap);
  }
  return gaps;
}
