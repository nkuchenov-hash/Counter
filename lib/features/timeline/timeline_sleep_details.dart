import 'package:counter/features/timeline/timeline_helpers.dart';

bool timelineRecordIsSleep(Map<String, dynamic> data) {
  final kind = (data['external_kind'] ?? '').toString().trim().toLowerCase();
  final source = (data['sleep_source'] ?? '').toString().trim();
  final title = (data['title'] ?? '').toString().trim().toLowerCase();
  return kind == 'sleep' || source.isNotEmpty || title == 'sleep' || title == 'сон';
}

String? timelineSleepWakeDateKey(Map<String, dynamic> data) {
  if (!timelineRecordIsSleep(data)) return null;
  final raw = data['end_time'] ?? data['endTime'];
  final endUtc = raw is DateTime
      ? raw.toUtc()
      : DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
  if (endUtc == null) return null;
  final wall = timelineUtcToDisplay(endUtc);
  return '${wall.year}-${wall.month.toString().padLeft(2, '0')}-${wall.day.toString().padLeft(2, '0')}';
}

List<Map<String, dynamic>> timelineProjectRecordsToWakeDay({
  required String targetDateKey,
  required Iterable<Map<String, dynamic>> startDayRecords,
  required Iterable<Map<String, dynamic>> priorStartDayRecords,
}) {
  final out = <Map<String, dynamic>>[];
  final seen = <String>{};

  void add(Map<String, dynamic> row) {
    final businessId = (row['record_id'] ?? '').toString().trim();
    final systemId = (row['id'] ?? row['_pb_record_id'] ?? '').toString().trim();
    final key = businessId.isNotEmpty
        ? businessId
        : systemId.isNotEmpty
            ? systemId
            : '${row['title']}|${row['start_time']}|${row['end_time']}';
    if (seen.add(key)) out.add(row);
  }

  for (final row in startDayRecords) {
    if (!timelineRecordIsSleep(row) ||
        timelineSleepWakeDateKey(row) == targetDateKey) {
      add(row);
    }
  }
  for (final row in priorStartDayRecords) {
    if (timelineRecordIsSleep(row) &&
        timelineSleepWakeDateKey(row) == targetDateKey) {
      add(row);
    }
  }
  return out;
}
