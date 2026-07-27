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
  const SleepConflictAction({required this.recordKey, required this.kind});

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
  required DateTime sleepStartUtc,
  required DateTime sleepEndUtc,
}) {
  final targetStart = sleepStartUtc.toUtc();
  final targetEnd = sleepEndUtc.toUtc();
  if (!targetEnd.isAfter(targetStart)) return null;

  Map<String, dynamic>? best;
  int? bestScore;
  for (final row in records) {
    if (!isSleepTitle(row['title'])) continue;
    final start = recordUtc(row['start_time'] ?? row['startTime']);
    final end = recordUtc(row['end_time'] ?? row['endTime']);
    if (start == null || end == null || !end.isAfter(start)) continue;

    final overlapStart = start.isAfter(targetStart) ? start : targetStart;
    final overlapEnd = end.isBefore(targetEnd) ? end : targetEnd;
    final overlapSeconds = overlapEnd.isAfter(overlapStart)
        ? overlapEnd.difference(overlapStart).inSeconds
        : 0;
    final startDrift = start.difference(targetStart).inSeconds.abs();
    final endDrift = end.difference(targetEnd).inSeconds.abs();
    final boundaryMatch =
        startDrift <= const Duration(hours: 3).inSeconds &&
        endDrift <= const Duration(hours: 3).inSeconds;
    if (overlapSeconds == 0 && !boundaryMatch) continue;

    final score = overlapSeconds * 10 - startDrift - endDrift;
    if (bestScore == null || score > bestScore) {
      bestScore = score;
      best = row;
    }
  }
  return best;
}
