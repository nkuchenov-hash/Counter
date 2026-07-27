import 'dart:convert';

const String kHealthSleepMarkerPrefix =
    '[[lifeos-health-connect-sleep:';

String healthSleepMarker(String externalId) =>
    '$kHealthSleepMarkerPrefix${base64Url.encode(utf8.encode(externalId))}]]';

bool isImportedHealthSleepRecord(Map<String, dynamic> row) {
  final note = (row['note'] ?? row['notes'] ?? '').toString();
  return note.contains(kHealthSleepMarkerPrefix);
}

bool isSleepTitle(dynamic raw) {
  final title = (raw ?? '').toString().trim().toLowerCase();
  return title == 'sleep' || title == 'сон';
}

String recordIdentityKey(Map<String, dynamic> row) {
  for (final key in <String>['_pb_record_id', 'id', 'record_id']) {
    final value = row[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

DateTime? recordUtc(dynamic raw) {
  if (raw is DateTime) return raw.toUtc();
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}

enum SleepConflictKind { trimToSleepStart, delete }

class SleepConflictAction {
  const SleepConflictAction({
    required this.recordKey,
    required this.kind,
  });

  final String recordKey;
  final SleepConflictKind kind;
}

List<SleepConflictAction> planSleepConflictActions({
  required Iterable<Map<String, dynamic>> records,
  required DateTime sleepStartUtc,
  required DateTime sleepEndUtc,
  String? existingSleepRecordKey,
}) {
  final start = sleepStartUtc.toUtc();
  final end = sleepEndUtc.toUtc();
  if (!end.isAfter(start)) return const <SleepConflictAction>[];

  final out = <SleepConflictAction>[];
  for (final row in records) {
    final key = recordIdentityKey(row);
    if (key.isEmpty || key == existingSleepRecordKey) continue;
    if (isImportedHealthSleepRecord(row)) continue;

    final rowStart = recordUtc(row['start_time'] ?? row['startTime']);
    if (rowStart == null || !rowStart.isBefore(end)) continue;
    final rowEnd = recordUtc(row['end_time'] ?? row['endTime']);
    if (rowEnd != null && !rowEnd.isAfter(start)) continue;

    out.add(
      SleepConflictAction(
        recordKey: key,
        kind: rowStart.isBefore(start)
            ? SleepConflictKind.trimToSleepStart
            : SleepConflictKind.delete,
      ),
    );
  }
  return out;
}

Map<String, dynamic>? findExistingSleepRecord({
  required Iterable<Map<String, dynamic>> records,
  required String externalId,
  required DateTime sleepStartUtc,
  required DateTime sleepEndUtc,
}) {
  final marker = healthSleepMarker(externalId);
  for (final row in records) {
    final note = (row['note'] ?? row['notes'] ?? '').toString();
    if (note.contains(marker)) return row;
  }

  Map<String, dynamic>? best;
  var bestOverlap = Duration.zero;
  for (final row in records) {
    if (!isSleepTitle(row['title'])) continue;
    final start = recordUtc(row['start_time'] ?? row['startTime']);
    final end = recordUtc(row['end_time'] ?? row['endTime']);
    if (start == null || end == null || !end.isAfter(start)) continue;
    final overlapStart = start.isAfter(sleepStartUtc) ? start : sleepStartUtc;
    final overlapEnd = end.isBefore(sleepEndUtc) ? end : sleepEndUtc;
    if (!overlapEnd.isAfter(overlapStart)) continue;
    final overlap = overlapEnd.difference(overlapStart);
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = row;
    }
  }
  if (best == null) return null;
  final sleepDuration = sleepEndUtc.difference(sleepStartUtc);
  return bestOverlap.inSeconds * 5 >= sleepDuration.inSeconds * 4
      ? best
      : null;
}

String noteWithHealthSleepMarker(dynamic existingNote, String externalId) {
  final note = existingNote?.toString().trim() ?? '';
  final marker = healthSleepMarker(externalId);
  if (note.contains(marker)) return note;
  if (note.isEmpty) return marker;
  return '$note\n$marker';
}
